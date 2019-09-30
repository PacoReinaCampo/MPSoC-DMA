-- Converted from rtl/verilog/modules/riscv_dma_initiator.sv
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

entity riscv_dma_initiator is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    NOC_PACKET_SIZE : integer := 16;

    TABLE_ENTRIES : integer := 4;
    DMA_REQUEST_WIDTH : integer := 199;
    DMA_REQFIELD_SIZE_WIDTH : integer := 64;
    TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)))
  );
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    -- Control read (request) interface
    ctrl_read_pos : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_read_req : in  std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);

    ctrl_done_pos : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_done_en  : out std_ulogic;

    valid : in std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

    -- NOC-Interface
    noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
    noc_out_last  : out std_ulogic;
    noc_out_valid : out std_ulogic;
    noc_out_ready : in  std_ulogic;

    noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
    noc_in_last  : in  std_ulogic;
    noc_in_valid : in  std_ulogic;
    noc_in_ready : out std_ulogic;

    -- AHB interface for L2R data fetch
    req_HSEL      : out std_ulogic;
    req_HADDR     : out std_ulogic_vector(PLEN-1 downto 0);
    req_HWDATA    : out std_ulogic_vector(XLEN-1 downto 0);
    req_HRDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
    req_HWRITE    : out std_ulogic;
    req_HSIZE     : out std_ulogic_vector(2 downto 0);
    req_HBURST    : out std_ulogic_vector(2 downto 0);
    req_HPROT     : out std_ulogic_vector(3 downto 0);
    req_HTRANS    : out std_ulogic_vector(1 downto 0);
    req_HMASTLOCK : out std_ulogic;
    req_HREADY    : in  std_ulogic;
    req_HRESP     : in  std_ulogic;

    -- AHB interface for L2R data fetch
    res_HSEL      : out std_ulogic;
    res_HADDR     : out std_ulogic_vector(PLEN-1 downto 0);
    res_HWDATA    : out std_ulogic_vector(XLEN-1 downto 0);
    res_HRDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
    res_HWRITE    : out std_ulogic;
    res_HSIZE     : out std_ulogic_vector(2 downto 0);
    res_HBURST    : out std_ulogic_vector(2 downto 0);
    res_HPROT     : out std_ulogic_vector(3 downto 0);
    res_HTRANS    : out std_ulogic_vector(1 downto 0);
    res_HMASTLOCK : out std_ulogic;
    res_HREADY    : in  std_ulogic;
    res_HRESP     : in  std_ulogic
  );
end riscv_dma_initiator;

architecture RTL of riscv_dma_initiator is
  component riscv_dma_initiator_interface
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      DMA_REQFIELD_SIZE_WIDTH : integer := 64
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      req_HSEL      : out std_ulogic;
      req_HADDR     : out std_ulogic_vector(PLEN-1 downto 0);
      req_HWDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      req_HRDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      req_HWRITE    : out std_ulogic;
      req_HSIZE     : out std_ulogic_vector(2 downto 0);
      req_HBURST    : out std_ulogic_vector(2 downto 0);
      req_HPROT     : out std_ulogic_vector(3 downto 0);
      req_HTRANS    : out std_ulogic_vector(1 downto 0);
      req_HMASTLOCK : out std_ulogic;
      req_HREADY    : in  std_ulogic;
      req_HRESP     : in  std_ulogic;

      req_start      : in  std_ulogic;
      req_is_l2r     : in  std_ulogic;
      req_size       : in  std_ulogic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
      req_laddr      : in  std_ulogic_vector(PLEN-1 downto 0);
      req_data_valid : out std_ulogic;
      req_data       : out std_ulogic_vector(XLEN-1 downto 0);
      req_data_ready : in  std_ulogic
    );
  end component;

  component riscv_dma_initiator_request
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      TABLE_ENTRIES : integer := 4;
      DMA_REQUEST_WIDTH : integer := 199;
      DMA_REQFIELD_SIZE_WIDTH : integer := 64;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)))
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      -- NOC-Interface
      noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
      noc_out_last  : out std_ulogic;
      noc_out_valid : out std_ulogic;
      noc_out_ready : in  std_ulogic;

      -- Control read (request) interface
      ctrl_read_pos : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_read_req : in  std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);

      valid : in std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

      -- Feedback from response path
      ctrl_done_pos : in std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_done_en  : in std_ulogic;

      -- Interface to wishbone request
      req_start      : out std_ulogic;
      req_laddr      : out std_ulogic_vector(PLEN-1 downto 0);
      req_data_valid : in  std_ulogic;
      req_data_ready : out std_ulogic;
      req_data       : in  std_ulogic_vector(XLEN-1 downto 0);
      req_is_l2r     : out std_ulogic;
      req_size       : out std_ulogic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0)
    );
  end component;

  component riscv_dma_initiator_response
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal req_data       : std_ulogic_vector(XLEN-1 downto 0);
  signal req_data_ready : std_ulogic;
  signal req_data_valid : std_ulogic;
  signal req_is_l2r     : std_ulogic;
  signal req_laddr      : std_ulogic_vector(XLEN-1 downto 0);
  signal req_size       : std_ulogic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  signal req_start      : std_ulogic;
  -- End of automatics

  signal ctrl_done_pos_sgn : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_done_en_sgn  : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  dma_initiator_interface : riscv_dma_initiator_interface
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      DMA_REQFIELD_SIZE_WIDTH => DMA_REQFIELD_SIZE_WIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      req_HSEL      => req_HSEL,
      req_HADDR     => req_HADDR(PLEN-1 downto 0),
      req_HWDATA    => req_HWDATA(XLEN-1 downto 0),
      req_HRDATA    => req_HRDATA(XLEN-1 downto 0),
      req_HWRITE    => req_HWRITE,
      req_HSIZE     => req_HSIZE(2 downto 0),
      req_HBURST    => req_HBURST(2 downto 0),
      req_HPROT     => req_HPROT(3 downto 0),
      req_HTRANS    => req_HTRANS(1 downto 0),
      req_HMASTLOCK => req_HMASTLOCK,
      req_HREADY    => req_HREADY,
      req_HRESP     => req_HRESP,

      req_start      => req_start,
      req_is_l2r     => req_is_l2r,
      req_size       => req_size(DMA_REQFIELD_SIZE_WIDTH-3 downto 0),
      req_laddr      => req_laddr(XLEN-1 downto 0),
      req_data_valid => req_data_valid,
      req_data       => req_data(XLEN-1 downto 0),
      req_data_ready => req_data_ready
    );

  dma_initiator_request : riscv_dma_initiator_request
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      TABLE_ENTRIES => TABLE_ENTRIES,
      DMA_REQUEST_WIDTH => DMA_REQUEST_WIDTH,
      DMA_REQFIELD_SIZE_WIDTH => DMA_REQFIELD_SIZE_WIDTH,
      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      noc_out_flit  => noc_out_flit(PLEN-1 downto 0),
      noc_out_last  => noc_out_last,
      noc_out_valid => noc_out_valid,
      noc_out_ready => noc_out_ready,

      ctrl_read_pos => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_read_req => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),

      valid => valid(TABLE_ENTRIES-1 downto 0),

      ctrl_done_pos => ctrl_done_pos_sgn(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en  => ctrl_done_en_sgn,

      req_start      => req_start,
      req_laddr      => req_laddr(XLEN-1 downto 0),
      req_data_valid => req_data_valid,
      req_data_ready => req_data_ready,
      req_data       => req_data(XLEN-1 downto 0),
      req_is_l2r     => req_is_l2r,
      req_size       => req_size(DMA_REQFIELD_SIZE_WIDTH-3 downto 0)
    );

  dma_initiator_response : riscv_dma_initiator_response
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      NOC_PACKET_SIZE => NOC_PACKET_SIZE,

      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      noc_in_flit  => noc_in_flit(PLEN-1 downto 0),
      noc_in_last  => noc_in_last,
      noc_in_valid => noc_in_valid,
      noc_in_ready => noc_in_ready,

      HSEL      => res_HSEL,
      HADDR     => res_HADDR(PLEN-1 downto 0),
      HWDATA    => res_HWDATA(XLEN-1 downto 0),
      HRDATA    => res_HRDATA(XLEN-1 downto 0),
      HWRITE    => res_HWRITE,
      HSIZE     => res_HSIZE(2 downto 0),
      HBURST    => res_HBURST(2 downto 0),
      HPROT     => res_HPROT(3 downto 0),
      HTRANS    => res_HTRANS(1 downto 0),
      HMASTLOCK => res_HMASTLOCK,
      HREADY    => res_HREADY,
      HRESP     => res_HRESP,

      ctrl_done_pos => ctrl_done_pos_sgn(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en  => ctrl_done_en_sgn
    );

  ctrl_done_pos <= ctrl_done_pos_sgn;
  ctrl_done_en  <= ctrl_done_en_sgn;
end RTL;
