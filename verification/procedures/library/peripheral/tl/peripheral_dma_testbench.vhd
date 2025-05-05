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
--              AMBA4 AHB-Lite Bus Interface                                  --
--              WishBone Bus Interface                                        --
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
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.peripheral_dma_pkg.all;

entity peripheral_dma_testbench is
end peripheral_dma_testbench;

architecture rtl of peripheral_dma_testbench is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dma_top_tl
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

      tl_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      tl_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      tl_if_hmastlock : in  std_logic;
      tl_if_hsel      : in  std_logic;
      tl_if_hwrite    : in  std_logic;
      tl_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      tl_if_hready    : out std_logic;
      tl_if_hresp     : out std_logic;

      tl_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      tl_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      tl_hmastlock : out std_logic;
      tl_hsel      : out std_logic;
      tl_hprot     : out std_logic_vector(3 downto 0);
      tl_hwrite    : out std_logic;
      tl_hsize     : out std_logic_vector(2 downto 0);
      tl_hburst    : out std_logic_vector(2 downto 0);
      tl_htrans    : out std_logic_vector(1 downto 0);
      tl_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      tl_hready    : in  std_logic;

      irq : out std_logic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  ------------------------------------------------------------------------------
  --  Constants
  ------------------------------------------------------------------------------
  constant ADDR_WIDTH : integer := 32;
  constant DATA_WIDTH : integer := 32;

  constant TABLE_ENTRIES          : integer := 4;
  constant TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
  constant TILEID                 : integer := 0;
  constant NOC_PACKET_SIZE        : integer := 16;
  constant GENERATE_INTERRUPT     : integer := 1;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal clk : std_logic;
  signal rst : std_logic;

  -- AHB4
  signal noc_tl_in_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_tl_in_req_valid : std_logic;
  signal noc_tl_in_req_ready : std_logic;

  signal noc_tl_in_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_tl_in_res_valid : std_logic;
  signal noc_tl_in_res_ready : std_logic;

  signal noc_tl_out_req_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_tl_out_req_valid : std_logic;
  signal noc_tl_out_req_ready : std_logic;

  signal noc_tl_out_res_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal noc_tl_out_res_valid : std_logic;
  signal noc_tl_out_res_ready : std_logic;

  signal tl_if_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal tl_if_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal tl_if_hmastlock : std_logic;
  signal tl_if_hsel      : std_logic;
  signal tl_if_hwrite    : std_logic;
  signal tl_if_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal tl_if_hready    : std_logic;
  signal tl_if_hresp     : std_logic;

  signal tl_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal tl_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal tl_hmastlock : std_logic;
  signal tl_hsel      : std_logic;
  signal tl_hprot     : std_logic_vector(3 downto 0);
  signal tl_hwrite    : std_logic;
  signal tl_hsize     : std_logic_vector(2 downto 0);
  signal tl_hburst    : std_logic_vector(2 downto 0);
  signal tl_htrans    : std_logic_vector(1 downto 0);
  signal tl_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal tl_hready    : std_logic;

  signal irq_tl : std_logic_vector(TABLE_ENTRIES-1 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- DUT AHB4
  tl_top : peripheral_dma_top_tl
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

      noc_in_req_flit  => noc_tl_in_req_flit,
      noc_in_req_valid => noc_tl_in_req_valid,
      noc_in_req_ready => noc_tl_in_req_ready,

      noc_in_res_flit  => noc_tl_in_res_flit,
      noc_in_res_valid => noc_tl_in_res_valid,
      noc_in_res_ready => noc_tl_in_res_ready,

      noc_out_req_flit  => noc_tl_out_req_flit,
      noc_out_req_valid => noc_tl_out_req_valid,
      noc_out_req_ready => noc_tl_out_req_ready,

      noc_out_res_flit  => noc_tl_out_res_flit,
      noc_out_res_valid => noc_tl_out_res_valid,
      noc_out_res_ready => noc_tl_out_res_ready,

      tl_if_haddr     => tl_if_haddr,
      tl_if_hrdata    => tl_if_hrdata,
      tl_if_hmastlock => tl_if_hmastlock,
      tl_if_hsel      => tl_if_hsel,
      tl_if_hwrite    => tl_if_hwrite,
      tl_if_hwdata    => tl_if_hwdata,
      tl_if_hready    => tl_if_hready,
      tl_if_hresp     => tl_if_hresp,

      tl_haddr     => tl_haddr,
      tl_hwdata    => tl_hwdata,
      tl_hmastlock => tl_hmastlock,
      tl_hsel      => tl_hsel,
      tl_hprot     => tl_hprot,
      tl_hwrite    => tl_hwrite,
      tl_hsize     => tl_hsize,
      tl_hburst    => tl_hburst,
      tl_htrans    => tl_htrans,
      tl_hrdata    => tl_hrdata,
      tl_hready    => tl_hready,

      irq => irq_tl
      );
end rtl;
