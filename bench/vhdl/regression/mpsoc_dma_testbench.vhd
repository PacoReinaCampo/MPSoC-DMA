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
-- *   Francisco Javier Reina Campo <frareicam@gmail.com>
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

  component mpsoc_mpi_ahb
    generic (
      NoC_DATA_WIDTH : integer := 32;
      NoC_TYPE_WIDTH : integer := 2;
      FIFO_DEPTH     : integer := 16;
      NoC_FLIT_WIDTH : integer := 34;
      SIZE_WIDTH     : integer := 5
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

      HADDR     : in  std_logic_vector(5 downto 0);
      HWRITE    : in  std_logic;
      HMASTLOCK : in  std_logic;
      HSEL      : in  std_logic;
      HRDATA    : in  std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
      HWDATA    : out std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
      HREADY    : out std_logic;

      irq : out std_logic
      );
  end component;

  component mpsoc_mpi_wb
    generic (
      NoC_DATA_WIDTH : integer := 32;
      NoC_TYPE_WIDTH : integer := 2;
      FIFO_DEPTH     : integer := 16;
      NoC_FLIT_WIDTH : integer := 34;
      SIZE_WIDTH     : integer := 5
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

      wb_addr_i : in  std_logic_vector(5 downto 0);
      wb_we_i   : in  std_logic;
      wb_cyc_i  : in  std_logic;
      wb_stb_i  : in  std_logic;
      wb_dat_i  : in  std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
      wb_dat_o  : out std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
      wb_ack_o  : out std_logic;

      irq : out std_logic
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

  constant NoC_DATA_WIDTH : integer := 32;
  constant NoC_TYPE_WIDTH : integer := 2;
  constant FIFO_DEPTH     : integer := 16;
  constant NoC_FLIT_WIDTH : integer := 34;
  constant SIZE_WIDTH     : integer := 5;

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

  -- AHB
  signal ahb_noc_out_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal ahb_noc_out_valid : std_logic;
  signal ahb_noc_out_ready : std_logic;

  signal ahb_noc_in_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal ahb_noc_in_valid : std_logic;
  signal ahb_noc_in_ready : std_logic;

  signal HADDR     : std_logic_vector(5 downto 0);
  signal HWRITE    : std_logic;
  signal HMASTLOCK : std_logic;
  signal HSEL      : std_logic;
  signal HRDATA    : std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
  signal HWDATA    : std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
  signal HREADY    : std_logic;

  signal ahb_irq : std_logic;

  -- WB
  signal wb_noc_out_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal wb_noc_out_valid : std_logic;
  signal wb_noc_out_ready : std_logic;

  signal wb_noc_in_flit  : std_logic_vector(NoC_FLIT_WIDTH-1 downto 0);
  signal wb_noc_in_valid : std_logic;
  signal wb_noc_in_ready : std_logic;

  signal wb_mpi_addr_i : std_logic_vector(5 downto 0);
  signal wb_mpi_we_i   : std_logic;
  signal wb_mpi_cyc_i  : std_logic;
  signal wb_mpi_stb_i  : std_logic;
  signal wb_mpi_dat_i  : std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
  signal wb_mpi_dat_o  : std_logic_vector(NoC_DATA_WIDTH-1 downto 0);
  signal wb_mpi_ack_o  : std_logic;

  signal wb_irq : std_logic;

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

      irq => irq_wb
      );

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

      irq => irq_ahb3
      );

  mpi_ahb : mpsoc_mpi_ahb
    generic map (
      NoC_DATA_WIDTH => NoC_DATA_WIDTH,
      NoC_TYPE_WIDTH => NoC_TYPE_WIDTH,
      FIFO_DEPTH     => FIFO_DEPTH,
      NoC_FLIT_WIDTH => NoC_FLIT_WIDTH,
      SIZE_WIDTH     => SIZE_WIDTH
      )
    port map (
      clk => clk,
      rst => rst,

      -- NoC interface
      noc_out_flit  => ahb_noc_out_flit,
      noc_out_valid => ahb_noc_out_valid,
      noc_out_ready => ahb_noc_out_ready,

      noc_in_flit  => ahb_noc_in_flit,
      noc_in_valid => ahb_noc_in_valid,
      noc_in_ready => ahb_noc_in_ready,

      HADDR     => HADDR,
      HWRITE    => HWRITE,
      HMASTLOCK => HMASTLOCK,
      HSEL      => HSEL,
      HRDATA    => HRDATA,
      HWDATA    => HWDATA,
      HREADY    => HREADY,

      irq => ahb_irq
      );

  mpi_wb : mpsoc_mpi_wb
    generic map (
      NoC_DATA_WIDTH => NoC_DATA_WIDTH,
      NoC_TYPE_WIDTH => NoC_TYPE_WIDTH,
      FIFO_DEPTH     => FIFO_DEPTH,
      NoC_FLIT_WIDTH => NoC_FLIT_WIDTH,
      SIZE_WIDTH     => SIZE_WIDTH
      )
    port map (
      clk => clk,
      rst => rst,

      -- NoC interface
      noc_out_flit  => wb_noc_out_flit,
      noc_out_valid => wb_noc_out_valid,
      noc_out_ready => wb_noc_out_ready,

      noc_in_flit  => wb_noc_in_flit,
      noc_in_valid => wb_noc_in_valid,
      noc_in_ready => wb_noc_in_ready,

      wb_addr_i => wb_mpi_addr_i,
      wb_we_i   => wb_mpi_we_i,
      wb_cyc_i  => wb_mpi_cyc_i,
      wb_stb_i  => wb_mpi_stb_i,
      wb_dat_i  => wb_mpi_dat_i,
      wb_dat_o  => wb_mpi_dat_o,
      wb_ack_o  => wb_mpi_ack_o,

      irq => wb_irq
      );
end RTL;
