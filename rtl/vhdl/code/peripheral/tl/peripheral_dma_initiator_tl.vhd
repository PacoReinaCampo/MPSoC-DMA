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
--   Stefan Wallentowitz <stefan@wallentowitz.de>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.peripheral_dma_pkg.all;

entity peripheral_dma_initiator_tl is
  generic (
    ADDR_WIDTH             : integer := 64;
    DATA_WIDTH             : integer := 64;
    TABLE_ENTRIES          : integer := 4;
    TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
    TILEID                 : integer := 0;
    NOC_PACKET_SIZE        : integer := 16
    );
  port (
    -- parameters
    clk           : in  std_logic;
    rst           : in  std_logic;
    -- Control read (request) interface
    ctrl_read_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_read_req : in  std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);

    ctrl_done_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_done_en  : out std_logic;

    valid : in std_logic_vector(TABLE_ENTRIES-1 downto 0);

    -- NOC-Interface
    noc_out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
    noc_out_valid : out std_logic;
    noc_out_ready : in  std_logic;

    noc_in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
    noc_in_valid : in  std_logic;
    noc_in_ready : out std_logic;

    -- Wishbone interface for L2R data fetch
    biu_req_hready    : in  std_logic;
    biu_req_hmastlock : out std_logic;
    biu_req_hsel      : out std_logic;
    biu_req_hwrite    : out std_logic;
    biu_req_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_req_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_req_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_req_hburst    : out std_logic_vector(2 downto 0);
    biu_req_htrans    : out std_logic_vector(1 downto 0);
    biu_req_hprot     : out std_logic_vector(3 downto 0);

    -- Wishbone interface for L2R data fetch
    biu_res_hready    : in  std_logic;
    biu_res_hmastlock : out std_logic;
    biu_res_hsel      : out std_logic;
    biu_res_hwrite    : out std_logic;
    biu_res_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_res_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_res_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_res_hburst    : out std_logic_vector(2 downto 0);
    biu_res_htrans    : out std_logic_vector(1 downto 0);
    biu_res_hprot     : out std_logic_vector(3 downto 0)
    );
end peripheral_dma_initiator_tl;

architecture rtl of peripheral_dma_initiator_tl is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dma_initiator_req_tl
    generic (
      ADDR_WIDTH : integer := 32;
      DATA_WIDTH : integer := 32
      );
    port (
      clk : in std_logic;
      rst : in std_logic;

      biu_req_hready    : in  std_logic;
      biu_req_hmastlock : out std_logic;
      biu_req_hsel      : out std_logic;
      biu_req_hwrite    : out std_logic;
      biu_req_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_req_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_req_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_req_hburst    : out std_logic_vector(2 downto 0);
      biu_req_htrans    : out std_logic_vector(1 downto 0);
      biu_req_hprot     : out std_logic_vector(3 downto 0);

      req_start      : in  std_logic;
      req_is_l2r     : in  std_logic;
      req_size       : in  std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
      req_laddr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      req_data_valid : out std_logic;
      req_data       : out std_logic_vector(DATA_WIDTH-1 downto 0);
      req_data_ready : in  std_logic
      );
  end component;

  component peripheral_dma_initiator_nocreq
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      TILEID                 : integer := 0;
      NOC_PACKET_SIZE        : integer := 16
      );
    port (
      -- flits per packet
      clk : in std_logic;
      rst : in std_logic;

      -- NOC-Interface
      noc_out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_out_valid : out std_logic;
      noc_out_ready : in  std_logic;

      -- Control read (request) interface
      ctrl_read_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_read_req : in  std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);

      valid : in std_logic_vector(TABLE_ENTRIES-1 downto 0);

      -- Feedback from response path
      ctrl_done_pos : in std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_done_en  : in std_logic;


      -- Interface to wishbone request
      req_start      : out std_logic;
      req_laddr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      req_data_valid : in  std_logic;
      req_data_ready : out std_logic;
      req_data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      req_is_l2r     : out std_logic;
      req_size       : out std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0)
      );
  end component;

  component peripheral_dma_initiator_tl_nocres
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
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
      biu_hready    : in  std_logic;
      biu_hmastlock : out std_logic;
      biu_hsel      : out std_logic;
      biu_hwrite    : out std_logic;
      biu_hrdata    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_hwdata    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_hburst    : out std_logic_vector(2 downto 0);
      biu_htrans    : out std_logic_vector(1 downto 0);
      biu_hprot     : out std_logic_vector(3 downto 0);

      ctrl_done_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_done_en  : out std_logic
      );
  end component;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal req_data       : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal req_data_ready : std_logic;
  signal req_data_valid : std_logic;
  signal req_is_l2r     : std_logic;
  signal req_laddr      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal req_size       : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  signal req_start      : std_logic;

  signal ctrl_done_pos_sgn : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_done_en_sgn  : std_logic;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  biu_initiator_req : peripheral_dma_initiator_req_tl
    port map (
      -- Outputs
      biu_req_hmastlock => biu_req_hmastlock,
      biu_req_hsel      => biu_req_hsel,
      biu_req_hwrite    => biu_req_hwrite,
      biu_req_hwdata    => biu_req_hwdata(DATA_WIDTH-1 downto 0),
      biu_req_haddr     => biu_req_haddr(ADDR_WIDTH-1 downto 0),
      biu_req_hburst    => biu_req_hburst(2 downto 0),
      biu_req_htrans    => biu_req_htrans(1 downto 0),
      biu_req_hprot     => biu_req_hprot(3 downto 0),
      req_data_valid     => req_data_valid,
      req_data           => req_data(DATA_WIDTH-1 downto 0),
      -- Inputs
      clk                => clk,
      rst                => rst,
      biu_req_hready    => biu_req_hready,
      biu_req_hrdata    => biu_req_hrdata(DATA_WIDTH-1 downto 0),
      req_start          => req_start,
      req_is_l2r         => req_is_l2r,
      req_size           => req_size(DMA_REQFIELD_SIZE_WIDTH-3 downto 0),
      req_laddr          => req_laddr(ADDR_WIDTH-1 downto 0),
      req_data_ready     => req_data_ready
      );

  initiator_nocreq : peripheral_dma_initiator_nocreq
    generic map (
      TILEID          => TILEID,
      NOC_PACKET_SIZE => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      noc_out_flit   => noc_out_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid  => noc_out_valid,
      ctrl_read_pos  => ctrl_read_pos,
      req_start      => req_start,
      req_laddr      => req_laddr(ADDR_WIDTH-1 downto 0),
      req_data_ready => req_data_ready,
      req_is_l2r     => req_is_l2r,
      req_size       => req_size(DMA_REQFIELD_SIZE_WIDTH-3 downto 0),
      -- Inputs
      clk            => clk,
      rst            => rst,
      noc_out_ready  => noc_out_ready,
      ctrl_read_req  => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      valid          => valid(TABLE_ENTRIES-1 downto 0),
      ctrl_done_pos  => ctrl_done_pos_sgn,
      ctrl_done_en   => ctrl_done_en_sgn,
      req_data_valid => req_data_valid,
      req_data       => req_data(DATA_WIDTH-1 downto 0)
      );

  biu_initiator_nocres : peripheral_dma_initiator_tl_nocres
    generic map (
      NOC_PACKET_SIZE => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      noc_in_ready   => noc_in_ready,
      biu_hmastlock => biu_res_hmastlock,                      -- Templated
      biu_hsel      => biu_res_hsel,                           -- Templated
      biu_hwrite    => biu_res_hwrite,                         -- Templated
      biu_hwdata    => biu_res_hwdata(DATA_WIDTH-1 downto 0),  -- Templated
      biu_haddr     => biu_res_haddr(ADDR_WIDTH-1 downto 0),   -- Templated
      biu_hburst    => biu_res_hburst(2 downto 0),             -- Templated
      biu_htrans    => biu_res_htrans(1 downto 0),             -- Templated
      biu_hprot     => biu_res_hprot(3 downto 0),              -- Templated
      ctrl_done_pos  => ctrl_done_pos_sgn,
      ctrl_done_en   => ctrl_done_en_sgn,
      -- Inputs
      clk            => clk,
      rst            => rst,
      noc_in_flit    => noc_in_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid   => noc_in_valid,
      biu_hready    => biu_res_hready,                         -- Templated
      biu_hrdata    => biu_res_hrdata(DATA_WIDTH-1 downto 0)   -- Templated
      );

  ctrl_done_pos <= ctrl_done_pos_sgn;
  ctrl_done_en  <= ctrl_done_en_sgn;
end rtl;
