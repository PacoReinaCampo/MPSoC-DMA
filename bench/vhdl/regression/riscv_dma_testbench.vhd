-- Converted from bench/verilog/regression/riscv_dma_testbench.sv
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

entity riscv_dma_testbench is
end riscv_dma_testbench;

architecture RTL of riscv_dma_testbench is

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant XLEN : integer := 64;
  constant PLEN : integer := 64;

  constant CHANNELS : integer := 2;

  constant NOC_PACKET_SIZE : integer := 16;

  constant TABLE_ENTRIES : integer := 4;
  constant DMA_REQMASK_WIDTH : integer := 5;
  constant DMA_REQUEST_WIDTH : integer := 199;
  constant DMA_REQFIELD_SIZE_WIDTH : integer := 64;
  constant TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(TABLE_ENTRIES)));

  component riscv_dma
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      NOC_PACKET_SIZE : integer := 16;

      TABLE_ENTRIES : integer := 4;
      DMA_REQMASK_WIDTH : integer := 5;
      DMA_REQUEST_WIDTH : integer := 199;
      DMA_REQFIELD_SIZE_WIDTH : integer := 64;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)))
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      noc_in_req_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
      noc_in_req_last  : in  std_ulogic;
      noc_in_req_valid : in  std_ulogic;
      noc_in_req_ready : out std_ulogic;

      noc_in_res_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
      noc_in_res_last  : in  std_ulogic;
      noc_in_res_valid : in  std_ulogic;
      noc_in_res_ready : out std_ulogic;

      noc_out_req_flit  : out std_ulogic_vector(PLEN-1 downto 0);
      noc_out_req_last  : out std_ulogic;
      noc_out_req_valid : out std_ulogic;
      noc_out_req_ready : in  std_ulogic;

      noc_out_res_flit  : out std_ulogic_vector(PLEN-1 downto 0);
      noc_out_res_last  : out std_ulogic;
      noc_out_res_valid : out std_ulogic;
      noc_out_res_ready : in  std_ulogic;

      irq : out std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

      --AHB master interface
      mst_HSEL      : in  std_ulogic;
      mst_HADDR     : in  std_ulogic_vector(PLEN-1 downto 0);
      mst_HWDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      mst_HRDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      mst_HWRITE    : in  std_ulogic;
      mst_HSIZE     : in  std_ulogic_vector(2 downto 0);
      mst_HBURST    : in  std_ulogic_vector(2 downto 0);
      mst_HPROT     : in  std_ulogic_vector(3 downto 0);
      mst_HTRANS    : in  std_ulogic_vector(1 downto 0);
      mst_HMASTLOCK : in  std_ulogic;
      mst_HREADYOUT : out std_ulogic;
      mst_HRESP     : out std_ulogic;

      --AHB slave interface
      slv_HSEL      : out std_ulogic;
      slv_HADDR     : out std_ulogic_vector(PLEN-1 downto 0);
      slv_HWDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      slv_HRDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      slv_HWRITE    : out std_ulogic;
      slv_HSIZE     : out std_ulogic_vector(2 downto 0);
      slv_HBURST    : out std_ulogic_vector(2 downto 0);
      slv_HPROT     : out std_ulogic_vector(3 downto 0);
      slv_HTRANS    : out std_ulogic_vector(1 downto 0);
      slv_HMASTLOCK : out std_ulogic;
      slv_HREADY    : in  std_ulogic;
      slv_HRESP     : in  std_ulogic
    );
  end component;

  component riscv_mpb
    generic (
      PLEN     : integer := 64;
      XLEN     : integer := 64;
      CHANNELS : integer := 2;
      SIZE     : integer := 16
    );
    port (
      --Common signals
      HRESETn : in std_ulogic;
      HCLK    : in std_ulogic;

      --NoC Interface
      noc_in_flit  : in  M_CHANNELS_PLEN;
      noc_in_last  : in  std_ulogic_vector(CHANNELS-1 downto 0);
      noc_in_valid : in  std_ulogic_vector(CHANNELS-1 downto 0);
      noc_in_ready : out std_ulogic_vector(CHANNELS-1 downto 0);

      noc_out_flit  : out M_CHANNELS_PLEN;
      noc_out_last  : out std_ulogic_vector(CHANNELS-1 downto 0);
      noc_out_valid : out std_ulogic_vector(CHANNELS-1 downto 0);
      noc_out_ready : in  std_ulogic_vector(CHANNELS-1 downto 0);

      --AHB input interface
      mst_HSEL      : in  std_ulogic;
      mst_HADDR     : in  std_ulogic_vector(PLEN-1 downto 0);
      mst_HWDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      mst_HRDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      mst_HWRITE    : in  std_ulogic;
      mst_HSIZE     : in  std_ulogic_vector(2 downto 0);
      mst_HBURST    : in  std_ulogic_vector(2 downto 0);
      mst_HPROT     : in  std_ulogic_vector(3 downto 0);
      mst_HTRANS    : in  std_ulogic_vector(1 downto 0);
      mst_HMASTLOCK : in  std_ulogic;
      mst_HREADYOUT : out std_ulogic;
      mst_HRESP     : out std_ulogic
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal clk : std_ulogic;
  signal rst : std_ulogic;

  signal noc_in_req_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal noc_in_req_last  : std_ulogic;
  signal noc_in_req_valid : std_ulogic;
  signal noc_in_req_ready : std_ulogic;

  signal noc_in_res_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal noc_in_res_last  : std_ulogic;
  signal noc_in_res_valid : std_ulogic;
  signal noc_in_res_ready : std_ulogic;

  signal noc_out_req_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal noc_out_req_last  : std_ulogic;
  signal noc_out_req_valid : std_ulogic;
  signal noc_out_req_ready : std_ulogic;

  signal noc_out_res_flit  : std_ulogic_vector(PLEN-1 downto 0);
  signal noc_out_res_last  : std_ulogic;
  signal noc_out_res_valid : std_ulogic;
  signal noc_out_res_ready : std_ulogic;

  signal irq : std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

  --AHB master interface
  signal mst_HSEL      : std_ulogic;
  signal mst_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal mst_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal mst_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal mst_HWRITE    : std_ulogic;
  signal mst_HSIZE     : std_ulogic_vector(2 downto 0);
  signal mst_HBURST    : std_ulogic_vector(2 downto 0);
  signal mst_HPROT     : std_ulogic_vector(3 downto 0);
  signal mst_HTRANS    : std_ulogic_vector(1 downto 0);
  signal mst_HMASTLOCK : std_ulogic;
  signal mst_HREADYOUT : std_ulogic;
  signal mst_HRESP     : std_ulogic;

  --AHB slave interface
  signal slv_HSEL      : std_ulogic;
  signal slv_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal slv_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal slv_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal slv_HWRITE    : std_ulogic;
  signal slv_HSIZE     : std_ulogic_vector(2 downto 0);
  signal slv_HBURST    : std_ulogic_vector(2 downto 0);
  signal slv_HPROT     : std_ulogic_vector(3 downto 0);
  signal slv_HTRANS    : std_ulogic_vector(1 downto 0);
  signal slv_HMASTLOCK : std_ulogic;
  signal slv_HREADY    : std_ulogic;
  signal slv_HRESP     : std_ulogic;

  --NoC Interface
  signal noc_mpb_in_flit  : M_CHANNELS_PLEN;
  signal noc_mpb_in_last  : std_ulogic_vector(CHANNELS-1 downto 0);
  signal noc_mpb_in_valid : std_ulogic_vector(CHANNELS-1 downto 0);
  signal noc_mpb_in_ready : std_ulogic_vector(CHANNELS-1 downto 0);

  signal noc_mpb_out_flit  : M_CHANNELS_PLEN;
  signal noc_mpb_out_last  : std_ulogic_vector(CHANNELS-1 downto 0);
  signal noc_mpb_out_valid : std_ulogic_vector(CHANNELS-1 downto 0);
  signal noc_mpb_out_ready : std_ulogic_vector(CHANNELS-1 downto 0);

  --AHB MPB master interface
  signal mst_mpb_HSEL      : std_ulogic;
  signal mst_mpb_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal mst_mpb_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal mst_mpb_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal mst_mpb_HWRITE    : std_ulogic;
  signal mst_mpb_HSIZE     : std_ulogic_vector(2 downto 0);
  signal mst_mpb_HBURST    : std_ulogic_vector(2 downto 0);
  signal mst_mpb_HPROT     : std_ulogic_vector(3 downto 0);
  signal mst_mpb_HTRANS    : std_ulogic_vector(1 downto 0);
  signal mst_mpb_HMASTLOCK : std_ulogic;
  signal mst_mpb_HREADYOUT : std_ulogic;
  signal mst_mpb_HRESP     : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --DUT
  dma : riscv_dma
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      NOC_PACKET_SIZE => NOC_PACKET_SIZE,

      TABLE_ENTRIES           => TABLE_ENTRIES,
      DMA_REQMASK_WIDTH       => DMA_REQMASK_WIDTH,
      DMA_REQUEST_WIDTH       => DMA_REQUEST_WIDTH,
      DMA_REQFIELD_SIZE_WIDTH => DMA_REQFIELD_SIZE_WIDTH,
      TABLE_ENTRIES_PTRWIDTH  => TABLE_ENTRIES_PTRWIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      noc_in_req_flit  => noc_in_req_flit,
      noc_in_req_last  => noc_in_req_last,
      noc_in_req_valid => noc_in_req_valid,
      noc_in_req_ready => noc_in_req_ready,

      noc_in_res_flit  => noc_in_res_flit,
      noc_in_res_last  => noc_in_res_last,
      noc_in_res_valid => noc_in_res_valid,
      noc_in_res_ready => noc_in_res_ready,

      noc_out_req_flit  => noc_out_req_flit,
      noc_out_req_last  => noc_out_req_last,
      noc_out_req_valid => noc_out_req_valid,
      noc_out_req_ready => noc_out_req_ready,

      noc_out_res_flit  => noc_out_res_flit,
      noc_out_res_last  => noc_out_res_last,
      noc_out_res_valid => noc_out_res_valid,
      noc_out_res_ready => noc_out_res_ready,

      irq => irq,

      --AHB master interface
      mst_HSEL      => mst_HSEL,
      mst_HADDR     => mst_HADDR,
      mst_HWDATA    => mst_HWDATA,
      mst_HRDATA    => mst_HRDATA,
      mst_HWRITE    => mst_HWRITE,
      mst_HSIZE     => mst_HSIZE,
      mst_HBURST    => mst_HBURST,
      mst_HPROT     => mst_HPROT,
      mst_HTRANS    => mst_HTRANS,
      mst_HMASTLOCK => mst_HMASTLOCK,
      mst_HREADYOUT => mst_HREADYOUT,
      mst_HRESP     => mst_HRESP,

      --AHB slave interface
      slv_HSEL      => slv_HSEL,
      slv_HADDR     => slv_HADDR,
      slv_HWDATA    => slv_HWDATA,
      slv_HRDATA    => slv_HRDATA,
      slv_HWRITE    => slv_HWRITE,
      slv_HSIZE     => slv_HSIZE,
      slv_HBURST    => slv_HBURST,
      slv_HPROT     => slv_HPROT,
      slv_HTRANS    => slv_HTRANS,
      slv_HMASTLOCK => slv_HMASTLOCK,
      slv_HREADY    => slv_HREADY,
      slv_HRESP     => slv_HRESP
    );

  --Instantiate RISC-V Message Passing Buffer End-Point
  mpb : riscv_mpb
    generic map (
      PLEN     => PLEN,
      XLEN     => XLEN,
      CHANNELS => CHANNELS,
      SIZE     => 2
    )
    port map (
      --Common signals
      HRESETn => rst,
      HCLK    => clk,

      --NoC Interface
      noc_in_flit  => noc_mpb_in_flit,
      noc_in_last  => noc_mpb_in_last,
      noc_in_valid => noc_mpb_in_valid,
      noc_in_ready => noc_mpb_in_ready,

      noc_out_flit  => noc_mpb_out_flit,
      noc_out_last  => noc_mpb_out_last,
      noc_out_valid => noc_mpb_out_valid,
      noc_out_ready => noc_mpb_out_ready,

      --AHB input interface
      mst_HSEL      => mst_mpb_HSEL,
      mst_HADDR     => mst_mpb_HADDR,
      mst_HWDATA    => mst_mpb_HWDATA,
      mst_HRDATA    => mst_mpb_HRDATA,
      mst_HWRITE    => mst_mpb_HWRITE,
      mst_HSIZE     => mst_mpb_HSIZE,
      mst_HBURST    => mst_mpb_HBURST,
      mst_HPROT     => mst_mpb_HPROT,
      mst_HTRANS    => mst_mpb_HTRANS,
      mst_HMASTLOCK => mst_mpb_HMASTLOCK,
      mst_HREADYOUT => mst_mpb_HREADYOUT,
      mst_HRESP     => mst_mpb_HRESP
    );
end RTL;
