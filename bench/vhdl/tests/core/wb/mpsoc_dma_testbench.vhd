-- Converted from bench/verilog/regression/mpsoc_dma_testbench.sv
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
--              AMBA3 AHB-Lite Bus Interface                                  //
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_testbench is
end mpsoc_dma_testbench;

architecture RTL of mpsoc_dma_testbench is
  component mpsoc_dma_wb_top
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      TILEID                 : integer := 0;
      NOC_PACKET_SIZE        : integer := 16;
      GENERATE_INTERRUPT     : integer := 1
      );
    port (
      clk : in std_logic;
      rst : in std_logic;

      noc_in_req_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_in_req_valid : in  std_logic;
      noc_in_req_ready : out std_logic;

      noc_in_res_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_in_res_valid : in  std_logic;
      noc_in_res_ready : out std_logic;

      noc_out_req_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_out_req_valid : out std_logic;
      noc_out_req_ready : in  std_logic;

      noc_out_res_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_out_res_valid : out std_logic;
      noc_out_res_ready : in  std_logic;

      wb_if_addr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_if_dat_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_if_cyc_i  : in  std_logic;
      wb_if_stb_i  : in  std_logic;
      wb_if_we_i   : in  std_logic;
      wb_if_dat_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_if_ack_o  : out std_logic;
      wb_if_err_o  : out std_logic;
      wb_if_rty_o  : out std_logic;

      wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_cyc_o : out std_logic;
      wb_stb_o : out std_logic;
      wb_sel_o : out std_logic_vector(3 downto 0);
      wb_we_o  : out std_logic;
      wb_cab_o : out std_logic;
      wb_cti_o : out std_logic_vector(2 downto 0);
      wb_bte_o : out std_logic_vector(1 downto 0);
      wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_ack_i : in  std_logic;

      irq : out std_logic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant ADDR_WIDTH : integer := 32;
  constant DATA_WIDTH : integer := 32;

  constant TABLE_ENTRIES          : integer := 4;
  constant TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
  constant TILEID                 : integer := 0;
  constant NOC_PACKET_SIZE        : integer := 16;
  constant GENERATE_INTERRUPT     : integer := 1;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal clk : std_logic;
  signal rst : std_logic;

  -- WB
  signal noc_wb_in_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_wb_in_req_valid : std_logic;
  signal noc_wb_in_req_ready : std_logic;

  signal noc_wb_in_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_wb_in_res_valid : std_logic;
  signal noc_wb_in_res_ready : std_logic;

  signal noc_wb_out_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_wb_out_req_valid : std_logic;
  signal noc_wb_out_req_ready : std_logic;

  signal noc_wb_out_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_wb_out_res_valid : std_logic;
  signal noc_wb_out_res_ready : std_logic;

  signal wb_if_addr_i : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_if_dat_i  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_if_cyc_i  : std_logic;
  signal wb_if_stb_i  : std_logic;
  signal wb_if_we_i   : std_logic;
  signal wb_if_dat_o  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_if_ack_o  : std_logic;
  signal wb_if_err_o  : std_logic;
  signal wb_if_rty_o  : std_logic;

  signal wb_adr_o : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_cyc_o : std_logic;
  signal wb_stb_o : std_logic;
  signal wb_sel_o : std_logic_vector(3 downto 0);
  signal wb_we_o  : std_logic;
  signal wb_cab_o : std_logic;
  signal wb_cti_o : std_logic_vector(2 downto 0);
  signal wb_bte_o : std_logic_vector(1 downto 0);
  signal wb_dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_ack_i : std_logic;

  signal irq_wb : std_logic_vector(TABLE_ENTRIES-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --DUT WB
  wb_top : mpsoc_dma_wb_top
    generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH,

      TABLE_ENTRIES          => TABLE_ENTRIES,
      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH,
      TILEID                 => TILEID,
      NOC_PACKET_SIZE        => NOC_PACKET_SIZE,
      GENERATE_INTERRUPT     => GENERATE_INTERRUPT
      )
    port map (
      clk => clk,
      rst => rst,

      noc_in_req_flit  => noc_wb_in_req_flit,
      noc_in_req_valid => noc_wb_in_req_valid,
      noc_in_req_ready => noc_wb_in_req_ready,

      noc_in_res_flit  => noc_wb_in_res_flit,
      noc_in_res_valid => noc_wb_in_res_valid,
      noc_in_res_ready => noc_wb_in_res_ready,

      noc_out_req_flit  => noc_wb_out_req_flit,
      noc_out_req_valid => noc_wb_out_req_valid,
      noc_out_req_ready => noc_wb_out_req_ready,

      noc_out_res_flit  => noc_wb_out_res_flit,
      noc_out_res_valid => noc_wb_out_res_valid,
      noc_out_res_ready => noc_wb_out_res_ready,

      wb_if_addr_i => wb_if_addr_i,
      wb_if_dat_i  => wb_if_dat_i,
      wb_if_cyc_i  => wb_if_cyc_i,
      wb_if_stb_i  => wb_if_stb_i,
      wb_if_we_i   => wb_if_we_i,
      wb_if_dat_o  => wb_if_dat_o,
      wb_if_ack_o  => wb_if_ack_o,
      wb_if_err_o  => wb_if_err_o,
      wb_if_rty_o  => wb_if_rty_o,

      wb_adr_o => wb_adr_o,
      wb_dat_o => wb_dat_o,
      wb_cyc_o => wb_cyc_o,
      wb_stb_o => wb_stb_o,
      wb_sel_o => wb_sel_o,
      wb_we_o  => wb_we_o,
      wb_cab_o => wb_cab_o,
      wb_cti_o => wb_cti_o,
      wb_bte_o => wb_bte_o,
      wb_dat_i => wb_dat_i,
      wb_ack_i => wb_ack_i,

      irq => irq_wb
      );
end RTL;
