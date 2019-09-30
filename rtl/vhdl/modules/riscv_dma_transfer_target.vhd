-- Converted from rtl/verilog/modules/riscv_dma_transfer_target.sv
-- by verilog2vhdl - QueenField

--//////////////////////////////////////////////////////////////////////////////
--                                            __ _      _     _               //
--                                           / _(_)    | |   | |              //
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
--                  | |                                                       //
--                  |_|                                                       //
--                                                                            //
--                                                                            //
--              MPSoC-RISCV CPU                                               //
--              Network on Chip Direct Memory Access                          //
--              AMBA3 AHB-Lite Bus Interface                                  //
--              Mesh Topology                                                 //
--                                                                            //
--//////////////////////////////////////////////////////////////////////////////

-- Copyright (c) 2018-2019 by the author(s)
-- *
-- * Permission is hereby granted, free of charge, to any person obtaining a copy
-- * of this software and associated documentation files (the "Software"), to deal
-- * in the Software without restriction, including without limitation the rights
-- * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- * copies of the Software, and to permit persons to whom the Software is
-- * furnished to do so, subject to the following conditions:
-- *
-- * The above copyright notice and this permission notice shall be included in
-- * all copies or substantial portions of the Software.
-- *
-- * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- * THE SOFTWARE.
-- *
-- * =============================================================================
-- * Author(s):
-- *   Francisco Javier Reina Campo <frareicam@gmail.com>
-- */


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.riscv_mpsoc_pkg.all;
use work.riscv_dma_pkg.all;

entity riscv_dma_transfer_target is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    NOC_PACKET_SIZE : integer := 16
  );
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    -- NOC-Interface
    noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
    noc_out_last  : out std_ulogic;
    noc_out_valid : out std_ulogic;
    noc_out_ready : in  std_ulogic;

    noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
    noc_in_last  : in  std_ulogic;
    noc_in_valid : in  std_ulogic;
    noc_in_ready : out std_ulogic;

    -- AHB interface for L2R data store
    HSEL      : out std_ulogic;
    HADDR     : out std_ulogic_vector(PLEN-1 downto 0);
    HWDATA    : out std_ulogic_vector(XLEN-1 downto 0);
    HRDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
    HWRITE    : out std_ulogic;
    HSIZE     : out std_ulogic_vector(2 downto 0);
    HBURST    : out std_ulogic_vector(2 downto 0);
    HPROT     : out std_ulogic_vector(3 downto 0);
    HTRANS    : out std_ulogic_vector(1 downto 0);
    HMASTLOCK : out std_ulogic;
    HREADY    : in  std_ulogic;
    HRESP     : in  std_ulogic
  );
end riscv_dma_transfer_target;

architecture RTL of riscv_dma_transfer_target is
  component riscv_dma_buffer
    generic (
      HADDR_SIZE   : integer := 64;
      BUFFER_DEPTH : integer := 4;
      FULLPACKET   : integer := 1
    );
    port (
      -- the width of the index
      clk : in std_ulogic;
      rst : in std_ulogic;

      --FIFO input side
      in_flit  : in  std_ulogic_vector(HADDR_SIZE-1 downto 0);
      in_last  : in  std_ulogic;
      in_valid : in  std_ulogic;
      in_ready : out std_ulogic;

      --FIFO output side
      out_flit  : out std_ulogic_vector(HADDR_SIZE-1 downto 0);
      out_last  : out std_ulogic;
      out_valid : out std_ulogic;
      out_ready : in  std_ulogic;

      packet_size : out std_ulogic_vector(integer(log2(real(BUFFER_DEPTH))) downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  --TODO: set nxt_ahb_waiting = 1'b0 in certain states like idle, or genheader.
  -- Not important since we just loose one cycle in the worst case
  constant STATE_WIDTH        : integer                       := 4;
  constant STATE_IDLE         : std_ulogic_vector(3 downto 0) := "0000";
  constant STATE_L2R_GETADDR  : std_ulogic_vector(3 downto 0) := "0001";
  constant STATE_L2R_DATA     : std_ulogic_vector(3 downto 0) := "0010";
  constant STATE_L2R_SENDRESP : std_ulogic_vector(3 downto 0) := "0011";

  constant STATE_R2L_GETLADDR : std_ulogic_vector(3 downto 0) := "0100";
  constant STATE_R2L_GETRADDR : std_ulogic_vector(3 downto 0) := "0101";
  constant STATE_R2L_GENHDR   : std_ulogic_vector(3 downto 0) := "0110";
  constant STATE_R2L_GENADDR  : std_ulogic_vector(3 downto 0) := "0111";
  constant STATE_R2L_DATA     : std_ulogic_vector(3 downto 0) := "1000";

  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function reduce_nor (
    reduce_nor_in : std_ulogic_vector
  ) return std_ulogic is
    variable reduce_nor_out : std_ulogic := '0';
  begin
    for i in reduce_nor_in'range loop
      reduce_nor_out := reduce_nor_out nor reduce_nor_in(i);
    end loop;
    return reduce_nor_out;
  end reduce_nor;

  function to_stdlogic (
    input : boolean
  ) return std_ulogic is
  begin
    if input then
      return('1');
    else
      return('0');
    end if;
  end function to_stdlogic;

  --////////////////////////////////////////////////////////////////
  --
  -- Types
  --
  type M_2_XLEN is array (2 downto 0) of std_ulogic_vector(XLEN-1 downto 0);

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- There is a buffer between the NoC input and the AHB
  -- handling by the state machine. Those are the connection signals
  -- from buffer to AHB
  signal buf_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal buf_last  : std_ulogic;
  signal buf_valid : std_ulogic;
  signal buf_ready : std_ulogic;

  --  * One FSM that handles the flow from the input
  --  * buffer to the AHB interface

  -- FSM state
  signal state     : std_ulogic_vector(STATE_WIDTH-1 downto 0);
  signal nxt_state : std_ulogic_vector(STATE_WIDTH-1 downto 0);

  --FSM hidden state
  signal ahb_waiting     : std_ulogic;
  signal nxt_ahb_waiting : std_ulogic;

  -- Store request parameters: address, last packet and source
  signal src_address        : std_ulogic_vector(PLEN-1 downto 0);
  signal nxt_src_address    : std_ulogic_vector(PLEN-1 downto 0);
  signal address            : std_ulogic_vector(PLEN-1 downto 0);
  signal nxt_address        : std_ulogic_vector(PLEN-1 downto 0);
  signal end_of_request     : std_ulogic;
  signal nxt_end_of_request : std_ulogic;
  signal src_tile           : std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
  signal nxt_src_tile       : std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
  signal packet_id          : std_ulogic_vector(PACKET_ID_WIDTH-1 downto 0);
  signal nxt_packet_id      : std_ulogic_vector(PACKET_ID_WIDTH-1 downto 0);

  -- Counter for flits/words in request
  signal noc_res_wcounter     : std_ulogic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_noc_res_wcounter : std_ulogic_vector(SIZE_WIDTH-1 downto 0);

  -- Current packet flit/word counter
  signal noc_res_packet_wcount     : std_ulogic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_noc_res_packet_wcount : std_ulogic_vector(SIZE_WIDTH-1 downto 0);

  -- Current packet total number of flits/words
  signal noc_res_packet_wsize     : std_ulogic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_noc_res_packet_wsize : std_ulogic_vector(SIZE_WIDTH-1 downto 0);

  -- TODO: correct define!
  signal res_wsize         : std_ulogic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  signal nxt_res_wsize     : std_ulogic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  signal ahb_res_count     : std_ulogic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);
  signal nxt_ahb_res_count : std_ulogic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);

  --FIFO-Stuff

  signal data_fifo_valid : std_ulogic;
  signal data_fifo       : M_2_XLEN;    -- data storage
  signal data_fifo_pop   : std_ulogic;  -- NOC pushes
  signal data_fifo_push  : std_ulogic;  -- WB pops

  signal data_fifo_out : std_ulogic_vector(XLEN-1 downto 0);  -- Current first element
  signal data_fifo_in  : std_ulogic_vector(XLEN-1 downto 0);  -- Push element
  -- Shift register for current position (4th bit is full mark)
  signal data_fifo_pos : std_ulogic_vector(3 downto 0);

  signal data_fifo_empty : std_ulogic;  -- FIFO empty
  signal data_fifo_ready : std_ulogic;  -- FIFO accepts new elements

  -- NOC-Interface
  signal noc_out_flit_sgn  : std_ulogic_vector(PLEN-1 downto 0);
  signal noc_out_valid_sgn : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  -- Input buffer that stores flits until we have one complete packet
  dma_buffer : riscv_dma_buffer
    generic map(
      HADDR_SIZE   => PLEN,
      BUFFER_DEPTH => BUFFER_DEPTH,
      FULLPACKET   => 0
    )
    port map (
      clk => clk,
      rst => rst,

      in_flit  => noc_in_flit(PLEN-1 downto 0),
      in_last  => noc_in_last,
      in_valid => noc_in_valid,
      in_ready => noc_in_ready,

      out_flit  => buf_flit(PLEN-1 downto 0),
      out_last  => buf_last,
      out_valid => buf_valid,
      out_ready => buf_ready,

      packet_size => open
    );

  -- The intermediate store a FIFO of three elements
  --
  -- There should be no combinatorial path from input to output, so
  -- that it takes one cycle before the AHB interface knows
  -- about back pressure from the NoC. Additionally, the AHB
  -- interface needs one extra cycle for burst termination. The data
  -- should be stored and not discarded. Finally, there is one
  -- element in the FIFO that is the normal timing decoupling.

  -- Connect the fifo signals to the ports
  -- assign data_fifo_pop = res_data_ready;
  data_fifo_valid <= not data_fifo_empty;
  data_fifo_empty <= data_fifo_pos(0);  -- Empty when pushing to first one
  data_fifo_ready <= reduce_nor(data_fifo_pos(3 downto 2));  --equal to not full
  data_fifo_in    <= HRDATA;
  data_fifo_out   <= data_fifo(0);      -- First element is out

  -- FIFO position pointer logic
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        data_fifo_pos <= "0001";
      elsif (data_fifo_push = '1' and not data_fifo_pop = '1') then
        -- push and no pop
        data_fifo_pos <= std_ulogic_vector(unsigned(data_fifo_pos) sll 1);
      elsif (data_fifo_push = '0' and data_fifo_pop = '1') then
        -- pop and no push
        data_fifo_pos <= std_ulogic_vector(unsigned(data_fifo_pos) srl 1);
      else                              -- * no push or pop or
        -- * both push and pop
        data_fifo_pos <= data_fifo_pos;
      end if;
    end if;
  end process;

  -- FIFO data shifting logic
  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      -- Iterate all fifo elements, starting from lowest
      for i in 0 to 2 loop
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

  -- AHB signal generation

  -- We only do word transfers
  HPROT <= X"f";

  -- The data of the payload flits
  HWDATA <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);

  -- Assign stored (and incremented) address to AHB interface
  HADDR <= address;

  --FSM

  -- Next state, counting, control signals
  processing_2 : process (HREADY, address, ahb_res_count, ahb_waiting, buf_flit, buf_last, buf_valid, data_fifo_out, data_fifo_ready, data_fifo_valid, end_of_request, noc_out_flit_sgn, noc_out_ready, noc_out_valid_sgn, noc_res_packet_wcount, noc_res_packet_wsize, noc_res_wcounter, packet_id, res_wsize, src_address, src_tile, state)
  begin
    -- Default values are old values
    nxt_address               <= address;
    nxt_res_wsize             <= res_wsize;
    nxt_end_of_request        <= end_of_request;
    nxt_src_address           <= src_address;
    nxt_src_tile              <= src_tile;
    nxt_end_of_request        <= end_of_request;
    nxt_packet_id             <= packet_id;
    nxt_ahb_res_count         <= ahb_res_count;
    nxt_noc_res_packet_wcount <= noc_res_packet_wcount;
    nxt_noc_res_packet_wsize  <= noc_res_packet_wsize;
    nxt_ahb_waiting           <= ahb_waiting;
    nxt_noc_res_wcounter      <= noc_res_wcounter;
    -- Default control signals
    HMASTLOCK                 <= '0';
    HSEL                      <= '0';
    HWRITE                    <= '0';
    HTRANS                    <= (others => '0');
    HBURST                    <= (others => '0');
    noc_out_valid_sgn         <= '0';
    noc_out_last              <= '0';
    noc_out_flit_sgn          <= (others => '0');
    data_fifo_push            <= '0';
    data_fifo_pop             <= '0';
    buf_ready                 <= '0';
    case (state) is
      when STATE_IDLE =>
        buf_ready            <= '1';
        nxt_end_of_request   <= buf_flit(PACKET_REQ_LAST);
        nxt_src_tile         <= buf_flit(SOURCE_MSB downto SOURCE_LSB);
        nxt_res_wsize        <= buf_flit(SIZE_MSB downto SIZE_LSB);
        nxt_packet_id        <= buf_flit(PACKET_ID_MSB downto PACKET_ID_LSB);
        nxt_noc_res_wcounter <= (others => '0');
        nxt_ahb_res_count    <= (0      => '1', others => '0');
        if (buf_valid = '1') then
          if (unsigned(buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)) = to_unsigned(PACKET_TYPE_L2R_REQ, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1)) then
            nxt_state <= STATE_L2R_GETADDR;
          elsif (unsigned(buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)) = to_unsigned(PACKET_TYPE_R2L_REQ, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1)) then
            nxt_state <= STATE_R2L_GETLADDR;
          else                          -- now we have a problem...
            -- must not happen
            nxt_state <= STATE_IDLE;
          end if;
        else
          nxt_state <= STATE_IDLE;
        end if;
      -- case: STATE_IDLE
      --L2R-handling
      when STATE_L2R_GETADDR =>
        buf_ready   <= '1';
        nxt_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_L2R_DATA;
        else
          nxt_state <= STATE_L2R_GETADDR;
        end if;
      when STATE_L2R_DATA =>
        if (buf_last = '1') then
          HBURST <= "111";
        else
          HBURST <= "010";
        end if;
        HMASTLOCK <= '1';
        HSEL      <= '1';
        HWRITE    <= '1';
        if (HREADY = '1') then
          nxt_address <= std_ulogic_vector(unsigned(address)+to_unsigned(4, PLEN));
          buf_ready   <= '1';
          if (buf_last = '1') then
            if (end_of_request = '1') then
              nxt_state <= STATE_L2R_SENDRESP;
            else
              nxt_state <= STATE_IDLE;
            end if;
          else
            nxt_state <= STATE_L2R_DATA;
          end if;
        else
          buf_ready <= '0';
          nxt_state <= STATE_L2R_DATA;
        end if;
      -- case: STATE_L2R_DATA
      when STATE_L2R_SENDRESP =>
        noc_out_valid_sgn                                          <= '1';
        noc_out_last                                               <= noc_out_flit_sgn(FLIT_TYPE_MSB);
        noc_out_flit_sgn(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= std_ulogic_vector(to_unsigned(FLIT_TYPE_SINGLE, FLIT_TYPE_MSB-FLIT_TYPE_LSB+1));
        noc_out_flit_sgn(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= src_tile;
        noc_out_flit_sgn(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit_sgn(PACKET_ID_MSB downto PACKET_ID_LSB)       <= packet_id;
        noc_out_flit_sgn(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= std_ulogic_vector(to_unsigned(PACKET_TYPE_L2R_RESP, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1));
        if (noc_out_ready = '1') then
          nxt_state <= STATE_IDLE;
        else
          nxt_state <= STATE_L2R_SENDRESP;
        end if;
      -- case: STATE_L2R_SENDRESP
      --R2L handling
      when STATE_R2L_GETLADDR =>
        buf_ready   <= '1';
        nxt_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_R2L_GETRADDR;
        else
          nxt_state <= STATE_R2L_GETLADDR;
        end if;
      when STATE_R2L_GETRADDR =>
        buf_ready       <= '1';
        nxt_src_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_R2L_GENHDR;
        else
          nxt_state <= STATE_R2L_GETRADDR;
        end if;
      when STATE_R2L_GENHDR =>
        noc_out_valid_sgn                                          <= '1';
        noc_out_last                                               <= noc_out_flit_sgn(FLIT_TYPE_MSB);
        noc_out_flit_sgn(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= std_ulogic_vector(to_unsigned(FLIT_TYPE_HEADER, FLIT_TYPE_MSB-FLIT_TYPE_LSB+1));
        noc_out_flit_sgn(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= src_tile;
        noc_out_flit_sgn(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit_sgn(PACKET_ID_MSB downto PACKET_ID_LSB)       <= packet_id;
        noc_out_flit_sgn(SOURCE_MSB downto SOURCE_LSB)             <= std_ulogic_vector(to_unsigned(TILE_ID, SOURCE_MSB-SOURCE_LSB+1));
        noc_out_flit_sgn(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= std_ulogic_vector(to_unsigned(PACKET_TYPE_R2L_RESP, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1));
        if ((unsigned(noc_res_wcounter)+to_unsigned(NOC_PACKET_SIZE-2, SIZE_WIDTH)) < unsigned(res_wsize)) then
          -- This is not the last packet in the respuest ((NOC_PACKET_SIZE -2) words*4 bytes=120)
          -- Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
          -- because we need a header-flit and an address-flit, too.
          noc_out_flit_sgn(SIZE_MSB downto SIZE_LSB) <= std_ulogic_vector(to_unsigned(1, SIZE_MSB-SIZE_LSB+1));
          noc_out_flit_sgn(PACKET_RES_LAST)          <= '0';
          nxt_noc_res_packet_wsize                   <= std_ulogic_vector(to_unsigned(NOC_PACKET_SIZE-2, SIZE_WIDTH));
          -- count is the current transfer number
          nxt_noc_res_packet_wcount                  <= std_ulogic_vector(to_unsigned(1, SIZE_WIDTH));
        else    -- This is the last packet in the respuest
          noc_out_flit_sgn(SIZE_MSB downto SIZE_LSB) <= std_ulogic_vector(unsigned(res_wsize)-unsigned(noc_res_wcounter));
          noc_out_flit_sgn(PACKET_RES_LAST)          <= '1';
          nxt_noc_res_packet_wsize                   <= std_ulogic_vector(unsigned(res_wsize)-unsigned(noc_res_wcounter));
          -- count is the current transfer number
          nxt_noc_res_packet_wcount                  <= std_ulogic_vector(to_unsigned(1, SIZE_WIDTH));
        end if;
        -- else: !if((noc_res_wcounter + (NOC_PACKET_SIZE -2)) < res_wsize)
        -- change to next state if successful
        if (noc_out_ready = '1') then
          nxt_state <= STATE_R2L_GENADDR;
        else
          nxt_state <= STATE_R2L_GENHDR;
        end if;
      -- case: STATE_R2L_GENHDR
      when STATE_R2L_GENADDR =>
        noc_out_valid_sgn                                          <= '1';
        noc_out_last                                               <= noc_out_flit_sgn(FLIT_TYPE_MSB);
        noc_out_flit_sgn(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= std_ulogic_vector(to_unsigned(FLIT_TYPE_PAYLOAD, FLIT_TYPE_MSB-FLIT_TYPE_LSB+1));
        noc_out_flit_sgn(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= std_ulogic_vector(unsigned(src_address)+(unsigned(noc_res_wcounter) sll 2));
        if (noc_out_ready = '1') then
          nxt_state <= STATE_R2L_DATA;
        else
          nxt_state <= STATE_R2L_GENADDR;
        end if;
      -- case: NOC_res_R2L_GENADDR
      when STATE_R2L_DATA =>
        -- NOC-handling
        -- transfer data to noc if available
        noc_out_valid_sgn                                          <= data_fifo_valid;
        noc_out_last                                               <= noc_out_flit_sgn(FLIT_TYPE_MSB);
        noc_out_flit_sgn(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= data_fifo_out;
        --TODO: Rearange ifs
        if (noc_res_packet_wcount = noc_res_packet_wsize) then
          noc_out_last                                         <= noc_out_flit_sgn(FLIT_TYPE_MSB);
          noc_out_flit_sgn(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= std_ulogic_vector(to_unsigned(FLIT_TYPE_LAST, FLIT_TYPE_MSB-FLIT_TYPE_LSB+1));
          if (noc_out_valid_sgn = '1' and noc_out_ready = '1') then
            data_fifo_pop <= '1';
            if ((unsigned(noc_res_wcounter)+to_unsigned(NOC_PACKET_SIZE-2, SIZE_WIDTH)) < unsigned(res_wsize)) then
              -- Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
              -- because we need a header-flit and an address-flit, too.
              --this was not the last packet of the response
              nxt_state            <= STATE_R2L_GENHDR;
              nxt_noc_res_wcounter <= std_ulogic_vector(unsigned(noc_res_wcounter)+unsigned(noc_res_packet_wcount));
            else                     --this is the last packet of the response
              nxt_state <= STATE_IDLE;
            end if;
          else
            nxt_state <= STATE_R2L_DATA;
          end if;
        else
          --not LAST
          noc_out_last                                         <= noc_out_flit_sgn(FLIT_TYPE_MSB);
          noc_out_flit_sgn(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= std_ulogic_vector(to_unsigned(FLIT_TYPE_PAYLOAD, FLIT_TYPE_MSB-FLIT_TYPE_LSB+1));
          if (noc_out_valid_sgn = '1' and noc_out_ready = '1') then
            data_fifo_pop             <= '1';
            nxt_noc_res_packet_wcount <= std_ulogic_vector(unsigned(noc_res_packet_wcount)+"00001");
          end if;
          nxt_state <= STATE_R2L_DATA;
        end if;
        --FIFO-handling
        if (ahb_waiting = '1') then     --hidden state
          --don't get data from the bus
          HSEL           <= '0';
          HMASTLOCK      <= '0';
          data_fifo_push <= '0';
          if (data_fifo_ready = '1') then
            nxt_ahb_waiting <= '0';
          else
            nxt_ahb_waiting <= '1';
          end if;
        --not ahb_waiting
        -- Signal cycle and strobe. We do bursts, but don't insert
        -- wait states, so both of them are always equal.
        elsif ((noc_res_packet_wcount = noc_res_packet_wsize) and noc_out_valid_sgn = '1' and noc_out_ready = '1') then
          HSEL      <= '0';
          HMASTLOCK <= '0';
        else
          HSEL      <= '1';
          HMASTLOCK <= '1';
          -- TODO: why not generate address from the base address + counter<<2?
          if (data_fifo_ready = '0' or (ahb_res_count = res_wsize)) then
            HBURST <= "111";
          else
            HBURST <= "111";
          end if;
          if (HREADY = '1') then
            -- When this was successfull..
            if (data_fifo_ready = '0' or (ahb_res_count = res_wsize)) then
              nxt_ahb_waiting <= '1';
            else
              nxt_ahb_waiting <= '0';
            end if;
            nxt_ahb_res_count <= std_ulogic_vector(unsigned(ahb_res_count)+to_unsigned(1, DMA_RESPFIELD_SIZE_WIDTH-2));
            nxt_address       <= std_ulogic_vector(unsigned(address)+to_unsigned(4, PLEN));
            data_fifo_push    <= '1';
          else  -- ..otherwise we still wait for the acknowledgement
            nxt_ahb_res_count <= ahb_res_count;
            nxt_address       <= address;
            data_fifo_push    <= '0';
            nxt_ahb_waiting   <= '0';
          end if;
        end if;
      -- else: !if(ahb_waiting)
      -- case: STATE_R2L_DATA
      when others =>
        nxt_state <= STATE_IDLE;
    end case;
  end process;  -- case (state)

  noc_out_flit  <= noc_out_flit_sgn;
  noc_out_valid <= noc_out_valid_sgn;

  processing_3 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state   <= STATE_IDLE;
        address <= (others => '0');

        end_of_request <= '0';
        src_tile       <= (others => '0');
        res_wsize      <= (others => '0');
        packet_id      <= (others => '0');

        src_address           <= (others => '0');
        noc_res_wcounter      <= (others => '0');
        noc_res_packet_wsize  <= (others => '0');
        noc_res_packet_wcount <= (others => '0');

        ahb_res_count <= (others => '0');
        ahb_waiting   <= '0';
      else
        state   <= nxt_state;
        address <= nxt_address;

        end_of_request <= nxt_end_of_request;

        src_tile  <= nxt_src_tile;
        res_wsize <= nxt_res_wsize;
        packet_id <= nxt_packet_id;

        src_address           <= nxt_src_address;
        noc_res_wcounter      <= nxt_noc_res_wcounter;
        noc_res_packet_wsize  <= nxt_noc_res_packet_wsize;
        noc_res_packet_wcount <= nxt_noc_res_packet_wcount;

        ahb_res_count <= nxt_ahb_res_count;
        ahb_waiting   <= nxt_ahb_waiting;
      end if;
    end if;
  end process;

  HSIZE <= "000";
end RTL;
