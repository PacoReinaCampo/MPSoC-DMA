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
  component mpsoc_dma_ahb3_top
    generic (
      ADDR_WIDTH             : integer := 64;
      DATA_WIDTH             : integer := 64;
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

      ahb3_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      ahb3_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      ahb3_if_hmastlock : in  std_logic;
      ahb3_if_hsel      : in  std_logic;
      ahb3_if_hwrite    : in  std_logic;
      ahb3_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      ahb3_if_hready    : out std_logic;
      ahb3_if_hresp     : out std_logic;

      ahb3_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      ahb3_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      ahb3_hmastlock : out std_logic;
      ahb3_hsel      : out std_logic;
      ahb3_hprot     : out std_logic_vector(3 downto 0);
      ahb3_hwrite    : out std_logic;
      ahb3_hsize     : out std_logic_vector(2 downto 0);
      ahb3_hburst    : out std_logic_vector(2 downto 0);
      ahb3_htrans    : out std_logic_vector(1 downto 0);
      ahb3_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      ahb3_hready    : in  std_logic;

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

  -- AHB3
  signal noc_ahb3_in_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_ahb3_in_req_valid : std_logic;
  signal noc_ahb3_in_req_ready : std_logic;

  signal noc_ahb3_in_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_ahb3_in_res_valid : std_logic;
  signal noc_ahb3_in_res_ready : std_logic;

  signal noc_ahb3_out_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_ahb3_out_req_valid : std_logic;
  signal noc_ahb3_out_req_ready : std_logic;

  signal noc_ahb3_out_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_ahb3_out_res_valid : std_logic;
  signal noc_ahb3_out_res_ready : std_logic;

  signal ahb3_if_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal ahb3_if_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ahb3_if_hmastlock : std_logic;
  signal ahb3_if_hsel      : std_logic;
  signal ahb3_if_hwrite    : std_logic;
  signal ahb3_if_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ahb3_if_hready    : std_logic;
  signal ahb3_if_hresp     : std_logic;

  signal ahb3_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal ahb3_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ahb3_hmastlock : std_logic;
  signal ahb3_hsel      : std_logic;
  signal ahb3_hprot     : std_logic_vector(3 downto 0);
  signal ahb3_hwrite    : std_logic;
  signal ahb3_hsize     : std_logic_vector(2 downto 0);
  signal ahb3_hburst    : std_logic_vector(2 downto 0);
  signal ahb3_htrans    : std_logic_vector(1 downto 0);
  signal ahb3_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ahb3_hready    : std_logic;

  signal irq_ahb3 : std_logic_vector(TABLE_ENTRIES-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --DUT AHB3
  ahb3_top : mpsoc_dma_ahb3_top
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

      noc_in_req_flit  => noc_ahb3_in_req_flit,
      noc_in_req_valid => noc_ahb3_in_req_valid,
      noc_in_req_ready => noc_ahb3_in_req_ready,

      noc_in_res_flit  => noc_ahb3_in_res_flit,
      noc_in_res_valid => noc_ahb3_in_res_valid,
      noc_in_res_ready => noc_ahb3_in_res_ready,

      noc_out_req_flit  => noc_ahb3_out_req_flit,
      noc_out_req_valid => noc_ahb3_out_req_valid,
      noc_out_req_ready => noc_ahb3_out_req_ready,

      noc_out_res_flit  => noc_ahb3_out_res_flit,
      noc_out_res_valid => noc_ahb3_out_res_valid,
      noc_out_res_ready => noc_ahb3_out_res_ready,

      ahb3_if_haddr     => ahb3_if_haddr,
      ahb3_if_hrdata    => ahb3_if_hrdata,
      ahb3_if_hmastlock => ahb3_if_hmastlock,
      ahb3_if_hsel      => ahb3_if_hsel,
      ahb3_if_hwrite    => ahb3_if_hwrite,
      ahb3_if_hwdata    => ahb3_if_hwdata,
      ahb3_if_hready    => ahb3_if_hready,
      ahb3_if_hresp     => ahb3_if_hresp,

      ahb3_haddr     => ahb3_haddr,
      ahb3_hwdata    => ahb3_hwdata,
      ahb3_hmastlock => ahb3_hmastlock,
      ahb3_hsel      => ahb3_hsel,
      ahb3_hprot     => ahb3_hprot,
      ahb3_hwrite    => ahb3_hwrite,
      ahb3_hsize     => ahb3_hsize,
      ahb3_hburst    => ahb3_hburst,
      ahb3_htrans    => ahb3_htrans,
      ahb3_hrdata    => ahb3_hrdata,
      ahb3_hready    => ahb3_hready,

      irq => irq_ahb3
      );
end RTL;
