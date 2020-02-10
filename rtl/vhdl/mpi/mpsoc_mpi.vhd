-- Converted from mpsoc_mpi.sv
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
--              Message Passing Interface                                     //
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

-- *
-- *                   +-> Input path <- packet buffer <-- Ingress
-- *                   |    * raise interrupt (!empty)
-- * Bus interface --> +    * read size flits from packet buffer
-- *                   |
-- *                   +-> Output path -> packet buffer --> Egress
-- *                        * set size
-- *                        * write flits to packet buffer
-- *
-- * Ingress <---+----- NoC
-- *             |
-- *       Handle control message
-- *             |
-- *  Egress ----+----> NoC

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpsoc_mpi is
  generic (
    NoC_DATA_WIDTH       : integer := 32;
    NoC_TYPE_WIDTH       : integer := 2;
    FIFO_DEPTH           : integer := 16;
    NoC_FLIT_WIDTH       : integer := 4;
    SIZE_WIDTH           : integer := 5;

    PACKET_CLASS_CONTROL : std_logic_vector(2 downto 0) := "111"
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    -- NoC interface
    noc_out_flit  : out std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
    noc_out_valid : out std_logic;
    noc_out_ready : in  std_logic;

    noc_in_flit  : in  std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
    noc_in_valid : in  std_logic;
    noc_in_ready : out std_logic;

    -- Bus side (generic)
    bus_addr     : in  std_logic_vector(5 downto 0);
    bus_we       : in  std_logic;
    bus_en       : in  std_logic;
    bus_data_in  : in  std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
    bus_data_out : out std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
    bus_ack      : out std_logic;

    irq : out std_logic
  );
end mpsoc_mpi;

architecture RTL of mpsoc_mpi is
  component mpsoc_packet_buffer
    generic (
      DATA_WIDTH : integer   := 32;
      FIFO_DEPTH : integer   := 16;
      FLIT_WIDTH : integer   := 34;
      SIZE_WIDTH : integer   := 5;

      READY : std_logic := '0';
      BUSY  : std_logic := '1'
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      --inputs
      in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      in_valid : in  std_logic;
      in_ready : out std_logic;

      --outputs
      out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      out_valid : out std_logic;
      out_ready : in  std_logic;

      out_size : out std_logic_vector(SIZE_WIDTH-1 downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- States of output state machine
  constant OUT_IDLE    : std_logic_vector(1 downto 0) := "00";
  constant OUT_FIRST   : std_logic_vector(1 downto 0) := "01";
  constant OUT_PAYLOAD : std_logic_vector(1 downto 0) := "10";

  -- States of input state machine
  constant INPUT_IDLE : std_logic := '0';
  constant INPUT_FLIT : std_logic := '1';

  constant DATA_WIDTH : integer   := 32;
  constant FLIT_WIDTH : integer   := 34;

  constant READY : std_logic := '0';
  constant BUSY  : std_logic := '1';

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Connect from the outgoing state machine to the packet buffer
  signal out_ready : std_logic;
  signal out_valid : std_logic;
  signal out_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal out_type  : std_logic_vector(1 downto 0);

  signal in_ready : std_logic;
  signal in_valid : std_logic;
  signal in_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);

  signal enabled     : std_logic;
  signal nxt_enabled : std_logic;

  signal if_fifo_in_en   : std_logic;
  signal if_fifo_in_ack  : std_logic;
  signal if_fifo_in_data : std_logic_vector(31 downto 0);
  signal if_fifo_out_en  : std_logic;
  signal if_fifo_out_ack : std_logic;

  --  * Simple writes to 0x0
  --  *  * Start transfer and set size S
  --  *  * For S flits: Write flit

  -- State register
  signal state_out     : std_logic_vector(1 downto 0);
  signal nxt_state_out : std_logic_vector(1 downto 0);

  signal state_in     : std_logic;
  signal nxt_state_in : std_logic;

  -- Size register that is also used to count down the remaining
  -- flits to be send out
  signal size_out     : std_logic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_size_out : std_logic_vector(SIZE_WIDTH-1 downto 0);

  signal size_in : std_logic_vector(SIZE_WIDTH-1 downto 0);

  signal ingress_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal ingress_valid : std_logic;
  signal ingress_ready : std_logic;

  signal egress_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal egress_valid : std_logic;
  signal egress_ready : std_logic;

  signal control_flit        : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal nxt_control_flit    : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal control_pending     : std_logic;
  signal nxt_control_pending : std_logic;

  signal output_valid : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  irq <= in_valid;

  -- If the output type width is larger than 2 (e.g. multicast support)
  -- the respective bits are set to zero.
  -- Concatenate the type and directly forward the bus input to the
  -- packet buffer
  generating_0 : if (NoC_TYPE_WIDTH > 2) generate
    out_flit <= (std_logic_vector(to_unsigned(0, NoC_TYPE_WIDTH-2)) & out_type & bus_data_in);
  elsif (NoC_TYPE_WIDTH <= 2) generate
    out_flit <= (out_type & bus_data_in);
  end generate;

  --  * +------+---+------------------------+
  --  * | 0x0  | R | Read from Ingress FIFO |
  --  * +------+---+------------------------+
  --  * |      | W | Write to Egress FIFO   |
  --  * +------+---+------------------------+
  --  * | 0x4  | W | Enable interface       |
  --  * +------+---+------------------------+
  --  * |      | R | Status                 |
  --  * +------+---+------------------------+

  processing_0 : process (bus_en)
  begin
    bus_ack      <= '0';
    bus_data_out <= "0000000000000000000000000000000X";
    nxt_enabled  <= enabled;

    if_fifo_in_en  <= '0';
    if_fifo_out_en <= '0';

    if (bus_en = '1') then
      if (bus_addr(5 downto 2) = X"0") then
        if (bus_we = '0') then
          if_fifo_in_en <= '1';
          bus_ack       <= if_fifo_in_ack;
          bus_data_out  <= if_fifo_in_data;
        else
          if_fifo_out_en <= '1';
          bus_ack        <= if_fifo_out_ack;
        end if;
      elsif (bus_addr(5 downto 2) = X"1") then
        bus_ack <= '1';
        if (bus_we = '1') then
          nxt_enabled <= '1';
        else
          bus_data_out <= (X"0" & output_valid & in_valid);
        end if;
      end if;
    end if;
  end process;

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        enabled <= '0';
      else
        enabled <= nxt_enabled;
      end if;
    end if;
  end process;

  -- Combinational part of input state machine
  processing_2 : process (state_in)
  begin
    in_ready        <= '0';
    if_fifo_in_ack  <= '0';
    if_fifo_in_data <= "0000000000000000000000000000000X";
    nxt_state_in    <= state_in;

    case ((state_in)) is
      when INPUT_IDLE =>
        if (if_fifo_in_en = '1') then
          if (in_valid = '1') then
            if_fifo_in_data <= size_in;
            if_fifo_in_ack  <= '1';
            if (to_integer(unsigned(size_in)) /= 0) then
              nxt_state_in <= INPUT_FLIT;
            end if;
          else
            if_fifo_in_data <= (others => '0');
            if_fifo_in_ack  <= '1';
            nxt_state_in    <= INPUT_IDLE;
          end if;
        else
          nxt_state_in <= INPUT_IDLE;
        end if;
      when INPUT_FLIT =>
        if (if_fifo_in_en = '1') then
          if_fifo_in_data <= in_flit(31 downto 0);
          in_ready        <= '1';
          if_fifo_in_ack  <= '1';
          if (to_integer(unsigned(size_in)) = 1) then
            nxt_state_in <= INPUT_IDLE;
          else
            nxt_state_in <= INPUT_FLIT;
          end if;
        else
          nxt_state_in <= INPUT_FLIT;
        end if;
      -- case: INPUT_FLIT
      when others =>
        nxt_state_in <= INPUT_IDLE;
    end case;
  end process;

  -- Combinational part of output state machine
  processing_3 : process (state_out)
  begin
    -- default values
    out_valid       <= '0';             -- no flit
    nxt_size_out    <= size_out;        -- keep size
    if_fifo_out_ack <= '0';             -- don't acknowledge
    out_type        <= "XX";            -- Default is undefined

    case ((state_out)) is
      when OUT_IDLE =>
        -- Transition from IDLE to FIRST
        -- when write on bus, which is the size
        if (if_fifo_out_en = '1') then
          -- Store the written value as size
          nxt_size_out    <= bus_data_in(SIZE_WIDTH-1 downto 0);
          -- Acknowledge to the bus
          if_fifo_out_ack <= '1';
          nxt_state_out   <= OUT_FIRST;
        else
          nxt_state_out <= OUT_IDLE;
        end if;
      when OUT_FIRST =>
        -- The first flit is written from the bus now.
        -- This can be either the only flit (size==1)
        -- or a further flits will follow.
        -- Forward the flits to the packet buffer.
        if (if_fifo_out_en = '1') then
          -- When the bus writes, the data is statically assigned
          -- to out_flit. Set out_valid to signal the flit should
          -- be output
          out_valid <= '1';

          -- The type is either SINGLE (size==1) or HEADER
          if (to_integer(unsigned(size_out)) = 1) then
            out_type <= "11";
          else
            out_type <= "01";
          end if;
          if (out_ready = '1') then
            -- When the output packet buffer is ready this cycle
            -- the flit has been stored in the packet buffer

            -- Decrement size
            nxt_size_out <= std_logic_vector(unsigned(size_out)-to_unsigned(1, SIZE_WIDTH));

            -- Acknowledge to the bus
            if_fifo_out_ack <= '1';

            if (to_integer(unsigned(size_out)) = 1) then
              -- When this was the only flit, go to IDLE again
              nxt_state_out <= OUT_IDLE;
            else  -- Otherwise accept further flis as payload
              nxt_state_out <= OUT_PAYLOAD;
            end if;
          else
            -- If the packet buffer is not ready, we simply hold
            -- the data and valid and wait another cycle for the
            -- packet buffer to become ready
            nxt_state_out <= OUT_FIRST;
          end if;
        else  -- Wait for the bus
          nxt_state_out <= OUT_FIRST;
        end if;
      when OUT_PAYLOAD =>
        -- After the first flit (HEADER) further flits are
        -- forwarded in this state. The essential difference to the
        -- FIRST state is in the output type which can here be
        -- PAYLOAD or LAST
        if (bus_we = '1' and bus_en = '1') then
          -- When the bus writes, the data is statically assigned
          -- to out_flit. Set out_valid to signal the flit should
          -- be output
          out_valid <= '1';

          -- The type is either LAST (size==1) or PAYLOAD
          if (to_integer(unsigned(size_out)) = 1) then
            out_type <= "10";
          else
            out_type <= "00";
          end if;
          if (out_ready = '1') then
            -- When the output packet buffer is ready this cycle
            -- the flit has been stored in the packet buffer

            -- Decrement size
            nxt_size_out <= std_logic_vector(unsigned(size_out)-to_unsigned(1, SIZE_WIDTH));

            -- Acknowledge to the bus
            if_fifo_out_ack <= '1';

            if (to_integer(unsigned(size_out)) = 1) then
              -- When this was the last flit, go to IDLE again
              nxt_state_out <= OUT_IDLE;
            else  -- Otherwise accept further flis as payload
              nxt_state_out <= OUT_PAYLOAD;
            end if;
          else
            -- If the packet buffer is not ready, we simply hold
            -- the data and valid and wait another cycle for the
            -- packet buffer to become ready
            nxt_state_out <= OUT_PAYLOAD;
          end if;
        else  -- Wait for the bus
          nxt_state_out <= OUT_PAYLOAD;
        end if;
      when others =>
        -- Defaulting to go to idle
        nxt_state_out <= OUT_IDLE;
    end case;
  end process;

  -- Sequential part of both state machines
  processing_4 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state_out <= OUT_IDLE;          -- Start in idle state
        -- size does not require a reset value (not used before set)
        state_in  <= INPUT_IDLE;
      else                              -- Register combinational values
        state_out <= nxt_state_out;
        size_out  <= nxt_size_out;
        state_in  <= nxt_state_in;
      end if;
    end if;
  end process;

  processing_5 : process (control_pending)
  begin
    noc_in_ready        <= not control_pending and ingress_ready;
    ingress_flit        <= noc_in_flit;
    nxt_control_pending <= control_pending;
    nxt_control_flit    <= control_flit;

    -- Ingress part
    if (noc_in_valid = '1' and control_pending = '0') then
      if ((noc_in_flit(33 downto 32) = "11") and (noc_in_flit(26 downto 24) = "111") and (noc_in_flit(0) = '0')) then
        nxt_control_pending            <= '1';
        nxt_control_flit(33 downto 32) <= "11";
        nxt_control_flit(31 downto 27) <= noc_in_flit(23 downto 19);
        nxt_control_flit(26 downto 24) <= "111";
        nxt_control_flit(23 downto 19) <= noc_in_flit(31 downto 27);
        nxt_control_flit(18 downto 2)  <= (others => '0');
        nxt_control_flit(1)            <= enabled;
        nxt_control_flit(0)            <= '1';
        ingress_valid                  <= '0';
      else
        ingress_valid <= noc_in_valid;
      end if;
    else
      ingress_valid <= noc_in_valid;
    end if;

    -- Egress part
    if (egress_valid = '1' and egress_flit(33) = '0') then
      egress_ready  <= noc_out_ready;
      noc_out_valid <= egress_valid;
      noc_out_flit  <= egress_flit;
      output_valid  <= egress_valid;
    elsif (control_pending = '1') then
      egress_ready  <= '0';
      noc_out_valid <= '1';
      noc_out_flit  <= control_flit;
      output_valid  <= '1';
      if (noc_out_ready = '1') then
        nxt_control_pending <= '0';
      end if;
    else
      egress_ready  <= noc_out_ready;
      noc_out_valid <= egress_valid;
      noc_out_flit  <= egress_flit;
      output_valid  <= egress_valid;
    end if;
  end process;

  processing_6 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        control_pending <= '0';
        control_flit    <= "000000000000000000000000000000000X";
      else
        control_pending <= nxt_control_pending;
        control_flit    <= nxt_control_flit;
      end if;
    end if;
  end process;

  -- The output packet buffer
  u_packetbuffer_out : mpsoc_packet_buffer
    generic map (
      DATA_WIDTH => DATA_WIDTH,
      FIFO_DEPTH => FIFO_DEPTH,
      FLIT_WIDTH => FLIT_WIDTH,
      SIZE_WIDTH => SIZE_WIDTH,

      READY => READY,
      BUSY  => BUSY
    )
    port map (
      clk => clk,
      rst => rst,

      -- Inputs
      in_flit   => out_flit(NoC_FLIT_WIDTH-1 downto 0),
      in_valid  => out_valid,
      out_ready => egress_ready,

      -- Outputs
      in_ready  => out_ready,
      out_flit  => egress_flit(NoC_FLIT_WIDTH-1 downto 0),
      out_valid => egress_valid,

      out_size => open
    );

  u_packetbuffer_in : mpsoc_packet_buffer
    generic map (
      DATA_WIDTH => DATA_WIDTH,
      FIFO_DEPTH => FIFO_DEPTH,
      FLIT_WIDTH => FLIT_WIDTH,
      SIZE_WIDTH => SIZE_WIDTH,

      READY => READY,
      BUSY  => BUSY
    )
    port map (
      clk => clk,
      rst => rst,

      -- Inputs
      in_flit   => ingress_flit(NoC_FLIT_WIDTH-1 downto 0),
      in_valid  => ingress_valid,
      out_ready => in_ready,

      -- Outputs
      in_ready  => ingress_ready,
      out_flit  => in_flit(NoC_FLIT_WIDTH-1 downto 0),
      out_valid => in_valid,

      out_size => size_in
    );
end RTL;
