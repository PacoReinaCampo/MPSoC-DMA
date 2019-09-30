-- Converted from verilog/riscv_mpb/riscv_mpb_endpoint.sv
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
--              Network on Chip Message Passing Buffer End-Point              //
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

entity riscv_mpb_endpoint is
  generic (
    PLEN : integer := 32;
    XLEN : integer := 32;
    SIZE : integer := 16
  );
  port (
    --Common signals
    HRESETn : in std_ulogic;
    HCLK    : in std_ulogic;

    --NoC Interface
    noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
    noc_in_last  : in  std_ulogic;
    noc_in_valid : in  std_ulogic;
    noc_in_ready : out std_ulogic;

    noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
    noc_out_last  : out std_ulogic;
    noc_out_valid : out std_ulogic;
    noc_out_ready : in  std_ulogic;

    --AHB interface
    HSEL      : in  std_ulogic;
    HADDR     : in  std_ulogic_vector(PLEN-1 downto 0);
    HWDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
    HRDATA    : out std_ulogic_vector(XLEN-1 downto 0);
    HWRITE    : in  std_ulogic;
    HSIZE     : in  std_ulogic_vector(2 downto 0);
    HBURST    : in  std_ulogic_vector(2 downto 0);
    HPROT     : in  std_ulogic_vector(3 downto 0);
    HTRANS    : in  std_ulogic_vector(1 downto 0);
    HMASTLOCK : in  std_ulogic;
    HREADYOUT : out std_ulogic;
    HRESP     : out std_ulogic
  );
end riscv_mpb_endpoint;

architecture RTL of riscv_mpb_endpoint is
  component riscv_dma_buffer
    generic (
      BUFFER_DEPTH : integer := 4
    );
    port (
      -- the width of the index
      clk : in std_ulogic;
      rst : in std_ulogic;

      --FIFO input side
      in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
      in_last  : in  std_ulogic;
      in_valid : in  std_ulogic;
      in_ready : out std_ulogic;

      --FIFO output side
      out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
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

  constant SIZE_WIDTH : integer := integer(log2(real(SIZE+1)));

  -- States of output state machine
  constant OUT_IDLE    : std_ulogic_vector(1 downto 0) := "00";
  constant OUT_FIRST   : std_ulogic_vector(1 downto 0) := "01";
  constant OUT_PAYLOAD : std_ulogic_vector(1 downto 0) := "10";

  -- States of input state machine
  constant INPUT_IDLE : std_ulogic := '0';
  constant INPUT_FLIT : std_ulogic := '1';

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Connect from the outgoing state machine to the packet buffer
  signal out_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal out_last  : std_ulogic;
  signal out_valid : std_ulogic;
  signal out_ready : std_ulogic;

  signal in_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal in_last  : std_ulogic;
  signal in_valid : std_ulogic;
  signal in_ready : std_ulogic;

  signal enabled     : std_ulogic;
  signal nxt_enabled : std_ulogic;

  signal if_fifo_in_en     : std_ulogic;
  signal if_fifo_in_ready  : std_ulogic;
  signal if_fifo_in_data   : std_ulogic_vector(XLEN-1 downto 0);
  signal if_fifo_out_en    : std_ulogic;
  signal if_fifo_out_ready : std_ulogic;

  --  * Simple writes to 0x0
  --  *  * Start transfer and set size S
  --  *  * For S flits: Write flit

  -- State register
  signal state_out     : std_ulogic_vector(1 downto 0);
  signal nxt_state_out : std_ulogic_vector(1 downto 0);

  signal state_in     : std_ulogic;
  signal nxt_state_in : std_ulogic;

  -- Size register that is also used to count down the remaining
  -- flits to be send out
  signal size_out     : std_ulogic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_size_out : std_ulogic_vector(SIZE_WIDTH-1 downto 0);

  signal size_in : std_ulogic_vector(SIZE_WIDTH-1 downto 0);

  signal ingress_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal ingress_last  : std_ulogic;
  signal ingress_valid : std_ulogic;
  signal ingress_ready : std_ulogic;

  signal egress_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal egress_last  : std_ulogic;
  signal egress_valid : std_ulogic;
  signal egress_ready : std_ulogic;

  signal control_flit        : std_ulogic_vector(PLEN-1 downto 0);
  signal nxt_control_flit    : std_ulogic_vector(PLEN-1 downto 0);
  signal control_pending     : std_ulogic;
  signal nxt_control_pending : std_ulogic;

  signal noc_out_valid_sgn : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  out_flit <= HWDATA;

  --  * +------+---+------------------------+
  --  * | 0x0  | R | Read from Ingress FIFO |
  --  * +------+---+------------------------+
  --  * |      | W | Write to Egress FIFO   |
  --  * +------+---+------------------------+
  --  * | 0x4  | W | Enable interface       |
  --  * +------+---+------------------------+
  --  * |      | R | Status                 |
  --  * +------+---+------------------------+

  processing_0 : process (HADDR, HSEL, HWRITE, enabled, if_fifo_in_data, if_fifo_in_ready, if_fifo_out_ready, in_valid, noc_out_valid_sgn)
  begin
    HREADYOUT <= '0';
    HRESP     <= '0';
    HRDATA    <= (others => 'X');

    nxt_enabled <= enabled;

    if_fifo_in_en  <= '0';
    if_fifo_out_en <= '0';

    if (HSEL = '1') then
      if (HADDR(5 downto 2) = X"0") then
        if (HWRITE = '0') then
          if_fifo_in_en <= '1';
          HREADYOUT     <= if_fifo_in_ready;
          HRDATA        <= if_fifo_in_data;
        else
          if_fifo_out_en <= '1';
          HREADYOUT      <= if_fifo_out_ready;
        end if;
      elsif (HADDR(5 downto 2) = X"1") then
        HREADYOUT <= '1';
        if (HWRITE = '1') then
          nxt_enabled <= '1';
        else
          HRDATA <= (X"0" & noc_out_valid_sgn & in_valid);
        end if;
      else
        HRESP <= '1';
      end if;
    end if;
  end process;
  -- if (HSEL)
  -- always @ begin

  processing_1 : process (HCLK)
  begin
    if (rising_edge(HCLK)) then
      if (HRESETn = '1') then
        enabled <= '0';
      else
        enabled <= nxt_enabled;
      end if;
    end if;
  end process;
  -- Combinational part of input state machine

  processing_2 : process (if_fifo_in_en, in_flit, in_valid, size_in, state_in)
  begin
    in_ready         <= '0';
    if_fifo_in_ready <= '0';
    if_fifo_in_data  <= (others => 'X');
    nxt_state_in     <= state_in;
    case (state_in) is
      when INPUT_IDLE =>
        if (if_fifo_in_en = '1') then
          if (in_valid = '1') then
            if_fifo_in_data  <= std_ulogic_vector(to_unsigned(0, XLEN-SIZE_WIDTH)) & size_in;
            if_fifo_in_ready <= '1';
            if (size_in /= std_ulogic_vector(to_unsigned(0, SIZE_WIDTH))) then
              nxt_state_in <= INPUT_FLIT;
            end if;
          else
            if_fifo_in_data  <= (others => '0');
            if_fifo_in_ready <= '1';
            nxt_state_in     <= INPUT_IDLE;
          end if;
        else
          nxt_state_in <= INPUT_IDLE;
        end if;
      when INPUT_FLIT =>
        if (if_fifo_in_en = '1') then
          if_fifo_in_data  <= in_flit(31 downto 0);
          in_ready         <= '1';
          if_fifo_in_ready <= '1';
          if (size_in = std_ulogic_vector(to_unsigned(1, SIZE_WIDTH))) then
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
  processing_3 : process (HSEL, HWDATA, HWRITE, if_fifo_out_en, out_ready, size_out, state_out)
  begin
    -- default values
    out_valid         <= '0';           -- no flit
    nxt_size_out      <= size_out;      -- keep size
    if_fifo_out_ready <= '0';           -- don't acknowledge
    out_last          <= 'X';           -- Default is undefined
    case (state_out) is
      when OUT_IDLE =>
        -- Transition from IDLE to FIRST
        -- when write on bus, which is the size
        if (if_fifo_out_en = '1') then
          -- Store the written value as size
          nxt_size_out      <= HWDATA(SIZE_WIDTH-1 downto 0);
          -- Acknowledge to the bus
          if_fifo_out_ready <= '1';
          nxt_state_out     <= OUT_FIRST;
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
          if (size_out = std_ulogic_vector(to_unsigned(1, SIZE_WIDTH))) then
            out_last <= '1';
          end if;
          if (out_ready = '1') then
            -- When the output packet buffer is ready this cycle
            -- the flit has been stored in the packet buffer
            -- Decrement size
            nxt_size_out      <= std_ulogic_vector(unsigned(size_out)-to_unsigned(1, SIZE_WIDTH));
            -- Acknowledge to the bus
            if_fifo_out_ready <= '1';
            if (size_out = std_ulogic_vector(to_unsigned(1, SIZE_WIDTH))) then
              -- When this was the only flit, go to IDLE again
              nxt_state_out <= OUT_IDLE;
            else                    -- Otherwise accept further flis as payload
              nxt_state_out <= OUT_PAYLOAD;
            end if;
          else                          -- if (out_ready)
            -- If the packet buffer is not ready, we simply hold
            -- the data and valid and wait another cycle for the
            -- packet buffer to become ready
            nxt_state_out <= OUT_FIRST;
          end if;
        else                            -- if (HWRITE && HSEL)
          -- Wait for the bus
          nxt_state_out <= OUT_FIRST;
        end if;
      when OUT_PAYLOAD =>
        -- After the first flit (HEADER) further flits are
        -- forwarded in this state. The essential difference to the
        -- FIRST state is in the output type which can here be
        -- PAYLOAD or LAST
        if (HWRITE = '1' and HSEL = '1') then
          -- When the bus writes, the data is statically assigned
          -- to out_flit. Set out_valid to signal the flit should
          -- be output
          out_valid <= '1';
          if (size_out = std_ulogic_vector(to_unsigned(1, SIZE_WIDTH))) then
            out_last <= '1';
          end if;
          if (out_ready = '1') then
            -- When the output packet buffer is ready this cycle
            -- the flit has been stored in the packet buffer
            -- Decrement size
            nxt_size_out      <= std_ulogic_vector(unsigned(size_out)-to_unsigned(1, SIZE_WIDTH));
            -- Acknowledge to the bus
            if_fifo_out_ready <= '1';
            if (size_out = std_ulogic_vector(to_unsigned(1, SIZE_WIDTH))) then
              -- When this was the last flit, go to IDLE again
              nxt_state_out <= OUT_IDLE;
            else                    -- Otherwise accept further flis as payload
              nxt_state_out <= OUT_PAYLOAD;
            end if;
          else                          -- if (out_ready)
            -- If the packet buffer is not ready, we simply hold
            -- the data and valid and wait another cycle for the
            -- packet buffer to become ready
            nxt_state_out <= OUT_PAYLOAD;
          end if;
        else                            -- if (HWRITE && HSEL)
          -- Wait for the bus
          nxt_state_out <= OUT_PAYLOAD;
        end if;
      when others =>
        -- Defaulting to go to idle
        nxt_state_out <= OUT_IDLE;
    end case;
  end process;

  -- Sequential part of both state machines
  processing_4 : process (HCLK)
  begin
    if (rising_edge(HCLK)) then
      if (HRESETn = '1') then
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

  processing_5 : process (control_flit, control_pending, egress_flit, egress_last, egress_valid, enabled, ingress_ready, noc_in_flit, noc_in_last, noc_in_valid, noc_out_ready)
  begin
    noc_in_ready        <= not control_pending and ingress_ready;
    ingress_flit        <= noc_in_flit;
    nxt_control_pending <= control_pending;
    nxt_control_flit    <= control_flit;
    -- Ingress part
    ingress_valid       <= noc_in_valid;
    ingress_last        <= noc_in_last;
    if ((noc_in_valid and not control_pending) = '1' and (noc_in_flit(26 downto 24) = "111") and noc_in_flit(0) = '0') then
      nxt_control_pending            <= '1';
      nxt_control_flit(31 downto 27) <= noc_in_flit(23 downto 19);
      nxt_control_flit(26 downto 24) <= "111";
      nxt_control_flit(23 downto 19) <= noc_in_flit(31 downto 27);
      nxt_control_flit(18 downto 2)  <= noc_in_flit(18 downto 2);
      nxt_control_flit(1)            <= enabled;
      nxt_control_flit(0)            <= '1';
      ingress_valid                  <= '0';
      ingress_last                   <= '1';
    end if;
    -- Egress part
    if (egress_valid = '1' and egress_last = '0') then
      egress_ready      <= noc_out_ready;
      noc_out_valid_sgn <= egress_valid;
      noc_out_flit      <= egress_flit;
      noc_out_last      <= egress_last;
    elsif (control_pending = '1') then
      egress_ready      <= '0';
      noc_out_valid_sgn <= '1';
      noc_out_flit      <= control_flit;
      noc_out_last      <= '1';
      if (noc_out_ready = '1') then
        nxt_control_pending <= '0';
      end if;
    else
      egress_ready      <= noc_out_ready;
      noc_out_valid_sgn <= egress_valid;
      noc_out_last      <= egress_last;
      noc_out_flit      <= egress_flit;
    end if;
  end process;

  noc_out_valid <= noc_out_valid_sgn;

  processing_6 : process (HCLK)
  begin
    if (rising_edge(HCLK)) then
      if (HRESETn = '1') then
        control_pending <= '0';
        control_flit    <= (others => 'X');
      else
        control_pending <= nxt_control_pending;
        control_flit    <= nxt_control_flit;
      end if;
    end if;
  end process;

  -- The output packet buffer
  packetbuffer_out : riscv_dma_buffer
    generic map (
      BUFFER_DEPTH => SIZE
    )
    port map (
      clk         => HCLK,
      rst         => HRESETn,
      in_ready    => out_ready,
      in_flit     => out_flit,
      in_last     => out_last,
      in_valid    => out_valid,
      packet_size => open,
      out_flit    => egress_flit,
      out_last    => egress_last,
      out_valid   => egress_valid,
      out_ready   => egress_ready
    );

  -- The input packet buffer
  packetbuffer_in : riscv_dma_buffer
    generic map (
      BUFFER_DEPTH => SIZE
    )
    port map (
      clk         => HCLK,
      rst         => HRESETn,
      in_ready    => ingress_ready,
      in_flit     => ingress_flit,
      in_last     => ingress_last,
      in_valid    => ingress_valid,
      packet_size => size_in,
      out_flit    => in_flit,
      out_last    => in_last,
      out_valid   => in_valid,
      out_ready   => in_ready
    );
end RTL;
