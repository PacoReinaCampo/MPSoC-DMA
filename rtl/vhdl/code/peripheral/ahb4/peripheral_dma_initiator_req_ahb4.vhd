--------------------------------------------------------------------------------
--                                            __ _      _     _               --
--                                           / _(_)    | |   | |              --
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              --
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              --
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              --
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              --
--                  | |                                                       --
--                  |_|                                                       --
--                                                                            --
--                                                                            --
--              MPSoC-RISCV CPU                                               --
--              Direct Access Memory Interface                                --
--              AMBA3 AHB-Lite Bus Interface                                  --
--                                                                            --
--------------------------------------------------------------------------------

-- Copyright (c) 2018-2019 by the author(s)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--------------------------------------------------------------------------------
-- Author(s):
--   Stefan Wallentowitz <stefan@wallentowitz.de>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.peripheral_dma_pkg.all;

entity peripheral_dma_initiator_req_ahb4 is
  generic (
    ADDR_WIDTH : integer := 64;
    DATA_WIDTH : integer := 64
    );
  port (
    clk : in std_logic;
    rst : in std_logic;

    ahb4_req_hready    : in  std_logic;
    ahb4_req_hmastlock : out std_logic;
    ahb4_req_hsel      : out std_logic;
    ahb4_req_hwrite    : out std_logic;
    ahb4_req_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    ahb4_req_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    ahb4_req_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    ahb4_req_hburst    : out std_logic_vector(2 downto 0);
    ahb4_req_htrans    : out std_logic_vector(1 downto 0);
    ahb4_req_hprot     : out std_logic_vector(3 downto 0);

    req_start      : in  std_logic;
    req_is_l2r     : in  std_logic;
    req_size       : in  std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
    req_laddr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    req_data_valid : out std_logic;
    req_data       : out std_logic_vector(DATA_WIDTH-1 downto 0);
    req_data_ready : in  std_logic
    );
end peripheral_dma_initiator_req_ahb4;

architecture rtl of peripheral_dma_initiator_req_ahb4 is
  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------

  -- Wishbone state machine
  constant WB_REQ_WIDTH : integer := 2;

  constant WB_REQ_IDLE : std_logic_vector(1 downto 0) := "00";
  constant WB_REQ_DATA : std_logic_vector(1 downto 0) := "01";
  constant WB_REQ_WAIT : std_logic_vector(1 downto 0) := "10";

  ------------------------------------------------------------------------------
  -- Types
  ------------------------------------------------------------------------------
  type M_2_DATA_WIDTH is array (2 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------

  -- State logic
  signal ahb4_req_state     : std_logic_vector(WB_REQ_WIDTH-1 downto 0);
  signal nxt_ahb4_req_state : std_logic_vector(WB_REQ_WIDTH-1 downto 0);

  -- Counter for the state machine for loaded words
  signal ahb4_req_count     : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  signal nxt_ahb4_req_count : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);

  -- The wishbone data fetch and the NoC interface are seperated by a FIFO.
  -- This FIFO relaxes problems with bursts and their termination and decouples
  -- the timing of the NoC side and the wishbone side (in terms of termination).

  -- The intermediate store a FIFO of three elements

  -- There should be no combinatorial path from input to output, so
  -- that it takes one cycle before the wishbone interface knows
  -- about back pressure from the NoC. Additionally, the wishbone
  -- interface needs one extra cycle for burst termination. The data
  -- should be stored and not discarded. Finally, there is one
  -- element in the FIFO that is the normal timing decoupling.

  signal data_fifo      : M_2_DATA_WIDTH;  -- data storage
  signal data_fifo_pop  : std_logic;       -- NoC pops
  signal data_fifo_push : std_logic;       -- WB pushes

  signal data_fifo_out : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Current first element
  signal data_fifo_in  : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Push element
  -- Shift register for current position (4th bit is full mark)
  signal data_fifo_pos : std_logic_vector(3 downto 0);

  signal data_fifo_empty : std_logic;   -- FIFO empty
  signal data_fifo_ready : std_logic;   -- FIFO accepts new elements

  ------------------------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------------------------
  function reduce_nor (
    reduce_nor_in : std_logic_vector
    ) return std_logic is
    variable reduce_nor_out : std_logic := '0';
  begin
    for i in reduce_nor_in'range loop
      reduce_nor_out := reduce_nor_out nor reduce_nor_in(i);
    end loop;
    return reduce_nor_out;
  end reduce_nor;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- Connect the fifo signals to the ports
  data_fifo_pop  <= req_data_ready;
  req_data_valid <= not data_fifo_empty;
  req_data       <= data_fifo_out;

  data_fifo_empty <= data_fifo_pos(0);  -- Empty when pushing to first one
  data_fifo_out   <= data_fifo(0);      -- First element is out

  -- FIFO is not ready when back-pressure would result in discarded data,
  -- that is, we need one store element (high-water).
  data_fifo_ready <= reduce_nor(data_fifo_pos(3 downto 2));

  -- FIFO position pointer logic
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        data_fifo_pos <= "0001";
      elsif (data_fifo_push = '1' and data_fifo_pop = '0') then
        -- push and no pop
        data_fifo_pos <= std_logic_vector(unsigned(data_fifo_pos) sll 1);
      elsif (data_fifo_push = '0' and data_fifo_pop = '1') then
        -- pop and no push
        data_fifo_pos <= std_logic_vector(unsigned(data_fifo_pos) srl 1);
      else                              -- no push or pop or
        -- both push and pop
        data_fifo_pos <= data_fifo_pos;
      end if;
    end if;
  end process;

  -- FIFO data shifting logic
  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      -- Iterate all fifo elements, starting from lowest
      for i in 0 to 3 - 1 loop
        if (data_fifo_pop = '1') then
          -- when popping data..
          if (data_fifo_push = '1' and data_fifo_pos(i+1) = '1') then
            -- .. and we also push this cycle, we need to check
            -- whether the pointer was on the next one
            data_fifo(i) <= data_fifo_in;
          elsif (i < 2) then
            -- .. otherwise shift if not last
            data_fifo(i) <= data_fifo(i+1);
          else                          -- the last stays static
            data_fifo(i) <= data_fifo(i);
          end if;
        elsif (data_fifo_push = '1' and data_fifo_pos(i) = '1') then
          -- when pushing only and this is the current write
          -- position
          data_fifo(i) <= data_fifo_in;
        else                            -- else just keep
          data_fifo(i) <= data_fifo(i);
        end if;
      end loop;
    end if;
  end process;

  -- Wishbone interface logic

  -- Statically zero (this interface reads)
  ahb4_req_hwdata <= X"0000_0000";
  ahb4_req_hwrite <= '0';

  -- We only support full (aligned) word transfers
  ahb4_req_hprot <= "1111";

  -- We only need linear bursts
  ahb4_req_htrans <= "00";

  -- The input to the fifo is the data from the bus
  data_fifo_in <= ahb4_req_hrdata;

  -- Next state, wishbone combinatorial signals and counting
  processing_2 : process (ahb4_req_state)
  begin
    -- Signal defaults
    nxt_ahb4_req_count <= ahb4_req_count;
    ahb4_req_hsel      <= '0';
    ahb4_req_hmastlock <= '0';
    data_fifo_push     <= '0';

    ahb4_req_haddr  <= (others => 'X');
    ahb4_req_hburst <= "000";

    case (ahb4_req_state) is
      when WB_REQ_IDLE =>
        -- We are idle'ing

        -- Always reset counter

        nxt_ahb4_req_count <= (others => '0');
        if (req_start = '1' and req_is_l2r = '1') then
          -- start when new request is handled and it is a L2R
          -- request. Direct transition to data fetching from bus,
          -- as the FIFO is always empty at this point.
          nxt_ahb4_req_state <= WB_REQ_DATA;
        else                            -- otherwise keep idle'ing
          nxt_ahb4_req_state <= WB_REQ_IDLE;
        end if;
      when WB_REQ_DATA =>
        -- We get data from the bus

        -- Signal cycle and strobe. We do bursts, but don't insert
        -- wait states, so both of them are always equal.
        ahb4_req_hsel      <= '1';
        ahb4_req_hmastlock <= '1';

        -- The address is the base address plus the counter
        -- Counter counts words, not bytes
        ahb4_req_haddr <= std_logic_vector(unsigned(req_laddr)+(unsigned(ahb4_req_count) sll 2));

        if (data_fifo_ready = '0' or (unsigned(ahb4_req_count) = unsigned(req_size)-to_unsigned(1, DMA_REQFIELD_SIZE_WIDTH-2))) then
          -- If fifo gets full next cycle, do cycle termination
          ahb4_req_hburst <= "111";
        else  -- As long as we can also store the _next_ element in
          -- the fifo, signal we are in an incrementing burst
          ahb4_req_hburst <= "010";
        end if;

        if (ahb4_req_hready = '1') then
          -- When this request was successfull..

          -- increment word counter
          nxt_ahb4_req_count <= std_logic_vector(unsigned(ahb4_req_count)+to_unsigned(1, DMA_REQFIELD_SIZE_WIDTH-2));
          -- signal push to data fifo
          data_fifo_push     <= '1';

          if (unsigned(ahb4_req_count) = unsigned(req_size)-to_unsigned(1, DMA_REQFIELD_SIZE_WIDTH-2)) then
            -- This was the last word
            nxt_ahb4_req_state <= WB_REQ_IDLE;
          elsif (data_fifo_ready = '1') then
            -- when FIFO can still get data, we stay here
            nxt_ahb4_req_state <= WB_REQ_DATA;
          else  -- .. otherwise we wait for FIFO to become ready
            nxt_ahb4_req_state <= WB_REQ_WAIT;
          end if;
        else                            -- if (ahb4_req_hready)
          -- ..otherwise we still wait for the acknowledgement
          nxt_ahb4_req_state <= WB_REQ_DATA;
        end if;
      when WB_REQ_WAIT =>
        -- Waiting for FIFO to accept new data
        if (data_fifo_ready = '1') then
          -- FIFO ready, restart burst
          nxt_ahb4_req_state <= WB_REQ_DATA;
        else                            -- wait
          nxt_ahb4_req_state <= WB_REQ_WAIT;
        end if;
      when others =>
        nxt_ahb4_req_state <= WB_REQ_IDLE;
    end case;
  end process;

  -- Sequential part of the state machine
  processing_3 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        ahb4_req_state <= WB_REQ_IDLE;
        ahb4_req_count <= (others => '0');
      else
        ahb4_req_state <= nxt_ahb4_req_state;
        ahb4_req_count <= nxt_ahb4_req_count;
      end if;
    end if;
  end process;
end rtl;
