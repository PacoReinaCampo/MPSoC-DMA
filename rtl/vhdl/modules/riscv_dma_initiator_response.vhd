-- Converted from rtl/verilog/modules/riscv_dma_initiator_response.sv
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

use work.riscv_dma_pkg.all;

entity riscv_dma_initiator_response is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    NOC_PACKET_SIZE : integer := 16;

    TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)))
  );
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
    noc_in_last  : in  std_ulogic;
    noc_in_valid : in  std_ulogic;
    noc_in_ready : out std_ulogic;

    -- AHB interface for L2R data fetch
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
    HRESP     : in  std_ulogic;

    ctrl_done_pos : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_done_en  : out std_ulogic
  );
end riscv_dma_initiator_response;

architecture RTL of riscv_dma_initiator_response is
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
  constant STATE_WIDTH    : integer                       := 2;
  constant STATE_IDLE     : std_ulogic_vector(1 downto 0) := "00";
  constant STATE_GET_ADDR : std_ulogic_vector(1 downto 0) := "01";
  constant STATE_DATA     : std_ulogic_vector(1 downto 0) := "10";
  constant STATE_GET_SIZE : std_ulogic_vector(1 downto 0) := "11";

  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
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
  -- Variables
  --

  -- State registers and next state logic
  signal state                       : std_ulogic_vector(STATE_WIDTH-1 downto 0);
  signal nxt_state                   : std_ulogic_vector(STATE_WIDTH-1 downto 0);
  signal res_address                 : std_ulogic_vector(PLEN-1 downto 0);
  signal nxt_res_address             : std_ulogic_vector(PLEN-1 downto 0);
  signal last_packet_of_response     : std_ulogic;
  signal nxt_last_packet_of_response : std_ulogic;
  signal res_id                      : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal nxt_res_id                  : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  -- There is a buffer between the NoC input and the wishbone
  -- handling by the state machine. Those are the connection signals
  -- from buffer to wishbone
  signal buf_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal buf_last  : std_ulogic;
  signal buf_valid : std_ulogic;
  signal buf_ready : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  dma_buffer : riscv_dma_buffer
    generic map (
      HADDR_SIZE   => PLEN,
      BUFFER_DEPTH => NOC_PACKET_SIZE,
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

  HADDR <= res_address;  --alias

  HWDATA <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);

  -- We only do word transfers
  HPROT <= X"F";

  -- Next state, wishbone combinatorial signals and counting
  processing_0 : process (state)
  begin
    -- Signal defaults
    HSEL      <= '0';
    HMASTLOCK <= '0';
    HWRITE    <= '0';
    HTRANS    <= (others => '0');
    HBURST    <= (others => '0');

    ctrl_done_en  <= '0';
    ctrl_done_pos <= (others => '0');

    -- Default values are old values
    nxt_res_id                  <= res_id;
    nxt_res_address             <= res_address;
    nxt_last_packet_of_response <= last_packet_of_response;

    buf_ready <= '0';

    case (state) is
      when STATE_IDLE =>
        buf_ready <= '1';
        if (buf_valid = '1') then
          nxt_res_id                  <= buf_flit(PACKET_ID_MSB downto PACKET_ID_LSB);
          nxt_last_packet_of_response <= buf_flit(PACKET_RES_LAST);

          if (unsigned(buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)) = to_unsigned(PACKET_TYPE_L2R_RESP, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1)) then
            nxt_state     <= STATE_IDLE;
            ctrl_done_en  <= '1';
            ctrl_done_pos <= nxt_res_id;
          elsif (unsigned(buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)) = to_unsigned(PACKET_TYPE_R2L_RESP, PACKET_TYPE_MSB-PACKET_TYPE_LSB+1)) then
            nxt_state <= STATE_GET_SIZE;
          else                          -- now we have a problem...
            -- must not happen
            nxt_state <= STATE_IDLE;
          end if;
        else                            -- if (buf_valid)
          nxt_state <= STATE_IDLE;
        end if;
      when STATE_GET_SIZE =>
        buf_ready <= '1';
        nxt_state <= STATE_GET_ADDR;
      when STATE_GET_ADDR =>
        buf_ready       <= '1';
        nxt_res_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        nxt_state       <= STATE_DATA;
      when STATE_DATA =>
        if (buf_last = '1') then
          HBURST <= "111";
        else
          HBURST <= "010";
        end if;
        HTRANS    <= "00";
        HMASTLOCK <= '1';
        HSEL      <= '1';
        HWRITE    <= '1';
        if (HREADY = '1') then
          nxt_res_address <= std_ulogic_vector(unsigned(res_address)+to_unsigned(4, PLEN));
          buf_ready       <= '1';
          if (buf_last = '1') then
            nxt_state <= STATE_IDLE;
            if (last_packet_of_response = '1') then
              ctrl_done_en  <= '1';
              ctrl_done_pos <= res_id;
            end if;
          else
            nxt_state <= STATE_DATA;
          end if;
        else
          buf_ready <= '0';
          nxt_state <= STATE_DATA;
        end if;
      when others =>
        nxt_state <= STATE_IDLE;
    end case;
  end process;
  -- case (state)
  -- always @ (*)

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state                   <= STATE_IDLE;
        res_address             <= (others => '0');
        last_packet_of_response <= '0';
        res_id                  <= (others => '0');
      else
        state                   <= nxt_state;
        res_address             <= nxt_res_address;
        last_packet_of_response <= nxt_last_packet_of_response;
        res_id                  <= nxt_res_id;
      end if;
    end if;
  end process;

  HSIZE <= "000";
end RTL;
