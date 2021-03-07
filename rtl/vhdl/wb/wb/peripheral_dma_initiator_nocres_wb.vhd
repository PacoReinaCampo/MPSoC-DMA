-- Converted from rtl/verilog/wb/mpsoc_dma_wb_initiator_nocres.sv
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
--              Direct Access Memory Interface                                //
--              WishBone Bus Interface                                        //
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
-- *   Stefan Wallentowitz <stefan@wallentowitz.de>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_wb_initiator_nocres is
  generic (
    ADDR_WIDTH             : integer := 64;
    DATA_WIDTH             : integer := 64;
    FLIT_WIDTH             : integer := FLIT_WIDTH;
    TABLE_ENTRIES          : integer := 4;
    TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
    NOC_PACKET_SIZE        : integer := 16;
    STATE_WIDTH            : integer := 2;

    STATE_IDLE     : std_logic_vector(1 downto 0) := "00";
    STATE_GET_ADDR : std_logic_vector(1 downto 0) := "01";
    STATE_DATA     : std_logic_vector(1 downto 0) := "10";
    STATE_GET_SIZE : std_logic_vector(1 downto 0) := "11"
    );
  port (
    clk : in std_logic;
    rst : in std_logic;

    noc_in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
    noc_in_valid : in  std_logic;
    noc_in_ready : out std_logic;

    -- Wishbone interface for L2R data fetch
    wb_ack_i : in  std_logic;
    wb_cyc_o : out std_logic;
    wb_stb_o : out std_logic;
    wb_we_o  : out std_logic;
    wb_dat_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_dat_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_cti_o : out std_logic_vector(2 downto 0);
    wb_bte_o : out std_logic_vector(1 downto 0);
    wb_sel_o : out std_logic_vector(3 downto 0);

    ctrl_done_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_done_en  : out std_logic
    );
end mpsoc_dma_wb_initiator_nocres;

architecture RTL of mpsoc_dma_wb_initiator_nocres is
  component mpsoc_dma_packet_buffer
    generic (
      DATA_WIDTH : integer := 32;
      FLIT_WIDTH : integer := 34;
      FIFO_DEPTH : integer := 16;
      SIZE_WIDTH : integer := integer(log2(real(17)));

      READY : std_logic := '0';
      BUSY  : std_logic := '1'
      );
    port (
      --inputs
      clk : in std_logic;
      rst : in std_logic;

      in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      in_valid : in  std_logic;
      in_ready : out std_logic;

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

  -- State registers and next state logic
  signal state                       : std_logic_vector(1 downto 0);
  signal nxt_state                   : std_logic_vector(STATE_WIDTH-1 downto 0);
  signal resp_address                : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal nxt_resp_address            : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal last_packet_of_response     : std_logic;
  signal nxt_last_packet_of_response : std_logic;
  signal resp_id                     : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal nxt_resp_id                 : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  -- There is a buffer between the NoC input and the wishbone
  -- handling by the state machine. Those are the connection signals
  -- from buffer to wishbone
  signal buf_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal buf_valid : std_logic;
  signal buf_ready : std_logic;

  signal buf_last_flit : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  packet_buffer : mpsoc_dma_packet_buffer
    generic map (
      FIFO_DEPTH => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      in_ready  => noc_in_ready,                        -- Templated
      out_flit  => buf_flit(FLIT_WIDTH-1 downto 0),     -- Templated
      out_valid => buf_valid,                           -- Templated
      out_size  => open,
      -- Templated
      -- Inputs
      clk       => clk,
      rst       => rst,
      in_flit   => noc_in_flit(FLIT_WIDTH-1 downto 0),  -- Templated
      in_valid  => noc_in_valid,                        -- Templated
      out_ready => buf_ready                            -- Templated
      );

  -- Is this the last flit of a packet?
  buf_last_flit <= to_stdlogic(buf_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) = FLIT_TYPE_LAST) or
                   to_stdlogic(buf_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) = FLIT_TYPE_SINGLE);

  wb_adr_o <= resp_address;             --alias

  wb_dat_o <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);

  -- We only do word transfers
  wb_sel_o <= X"f";

  -- Next state, wishbone combinatorial signals and counting
  processing_0 : process (state)
  begin
    -- Signal defaults
    wb_stb_o <= '0';
    wb_cyc_o <= '0';
    wb_we_o  <= '0';
    wb_bte_o <= "00";
    wb_cti_o <= "000";

    ctrl_done_en  <= '0';
    ctrl_done_pos <= (others => '0');

    -- Default values are old values
    nxt_resp_id                 <= resp_id;
    nxt_resp_address            <= resp_address;
    nxt_last_packet_of_response <= last_packet_of_response;

    buf_ready <= '0';

    case (state) is
      when "00" =>
        buf_ready <= '1';
        if (buf_valid = '1') then
          nxt_resp_id                 <= buf_flit(PACKET_ID_MSB downto PACKET_ID_LSB);
          nxt_last_packet_of_response <= buf_flit(PACKET_RESP_LAST);
          if (buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB) = PACKET_TYPE_L2R_RESP) then
            nxt_state     <= STATE_IDLE;
            ctrl_done_en  <= '1';
            ctrl_done_pos <= nxt_resp_id;
          elsif (buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB) = PACKET_TYPE_R2L_RESP) then
            nxt_state <= STATE_GET_SIZE;
          else  -- now we have a problem...
            -- must not happen
            nxt_state <= STATE_IDLE;
          end if;
        else  -- if (buf_valid)
          nxt_state <= STATE_IDLE;
        end if;
      when "11" =>
        buf_ready <= '1';
        nxt_state <= STATE_GET_ADDR;
      when "01" =>
        buf_ready        <= '1';
        nxt_resp_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        nxt_state        <= STATE_DATA;
      when "10" =>
        if (buf_last_flit = '1') then
          wb_cti_o <= "111";
        else
          wb_cti_o <= "010";
        end if;
        wb_bte_o <= "00";
        wb_cyc_o <= '1';
        wb_stb_o <= '1';
        wb_we_o  <= '1';
        if (wb_ack_i = '1') then
          nxt_resp_address <= std_logic_vector(unsigned(resp_address)+to_unsigned(4, ADDR_WIDTH));
          buf_ready        <= '1';
          if (buf_last_flit = '1') then
            nxt_state <= STATE_IDLE;
            if (last_packet_of_response = '1') then
              ctrl_done_en  <= '1';
              ctrl_done_pos <= resp_id;
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

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state                   <= STATE_IDLE;
        resp_address            <= (others => '0');
        last_packet_of_response <= '0';
        resp_id                 <= (others => '0');
      else
        state                   <= nxt_state;
        resp_address            <= nxt_resp_address;
        last_packet_of_response <= nxt_last_packet_of_response;
        resp_id                 <= nxt_resp_id;
      end if;
    end if;
  end process;
end RTL;
