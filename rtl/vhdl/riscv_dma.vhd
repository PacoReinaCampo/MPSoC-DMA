-- Converted from rtl/verilog/riscv_dma.sv
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

entity riscv_dma is
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
end riscv_dma;

architecture RTL of riscv_dma is
  component riscv_dma_interface
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      TABLE_ENTRIES : integer := 4;
      DMA_REQMASK_WIDTH : integer := 5;
      DMA_REQUEST_WIDTH : integer := 199;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)))
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      if_HSEL      : in  std_ulogic;
      if_HADDR     : in  std_ulogic_vector(PLEN-1 downto 0);
      if_HWDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      if_HRDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      if_HWRITE    : in  std_ulogic;
      if_HSIZE     : in  std_ulogic_vector(2 downto 0);
      if_HBURST    : in  std_ulogic_vector(2 downto 0);
      if_HPROT     : in  std_ulogic_vector(3 downto 0);
      if_HTRANS    : in  std_ulogic_vector(1 downto 0);
      if_HMASTLOCK : in  std_ulogic;
      if_HREADYOUT : out std_ulogic;
      if_HRESP     : out std_ulogic;

      if_write_req    : out std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      if_write_pos    : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_write_select : out std_ulogic_vector(DMA_REQMASK_WIDTH-1 downto 0);
      if_write_en     : out std_ulogic;

      -- Interface read (status) interface
      if_valid_pos  : out std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_valid_set  : out std_ulogic;
      if_valid_en   : out std_ulogic;
      if_validrd_en : out std_ulogic;

      done : in std_ulogic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  component riscv_dma_transfer_table
    generic (
      DMA_REQUEST_WIDTH : integer := 199;
      TABLE_ENTRIES : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      DMA_REQMASK_WIDTH : integer := 5
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      -- Interface write (request) interface
      if_write_req    : in std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      if_write_pos    : in std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_write_select : in std_ulogic_vector(DMA_REQMASK_WIDTH-1 downto 0);
      if_write_en     : in std_ulogic;

      if_valid_pos  : in std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_valid_set  : in std_ulogic;
      if_valid_en   : in std_ulogic;
      if_validrd_en : in std_ulogic;

      -- Control read (request) interface
      ctrl_read_req : out std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      ctrl_read_pos : in  std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

      -- Control write (status) interface
      ctrl_done_pos : in std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_done_en  : in std_ulogic;

      -- All valid bits of the entries
      valid : out std_ulogic_vector(TABLE_ENTRIES-1 downto 0);
      done  : out std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

      irq : out std_ulogic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  component riscv_dma_initiator
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
  end component;

  component riscv_dma_transfer_target
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      NOC_PACKET_SIZE : integer := 16
    );
    port (
      clk : in std_ulogic;
      rst : in std_ulogic;

      -- NOC-Interface
      noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
      noc_out_last  : out std_ulogic;
      noc_out_valid : out std_ulogic;
      noc_out_ready : in  std_ulogic;

      noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
      noc_in_last  : in  std_ulogic;
      noc_in_valid : in  std_ulogic;
      noc_in_ready : out std_ulogic;

      -- AHB interface for L2R data store
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
      HRESP     : in  std_ulogic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant ahb_arb_req    : std_ulogic_vector(1 downto 0) := "00";
  constant ahb_arb_res    : std_ulogic_vector(1 downto 0) := "01";
  constant ahb_arb_target : std_ulogic_vector(1 downto 0) := "10";

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
  signal req_HSEL      : std_ulogic;
  signal req_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal req_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal req_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal req_HWRITE    : std_ulogic;
  signal req_HPROT     : std_ulogic_vector(3 downto 0);
  signal req_HSIZE     : std_ulogic_vector(2 downto 0);
  signal req_HBURST    : std_ulogic_vector(2 downto 0);
  signal req_HTRANS    : std_ulogic_vector(1 downto 0);
  signal req_HMASTLOCK : std_ulogic;
  signal req_HREADY    : std_ulogic;
  signal req_HRESP     : std_ulogic;

  signal res_HSEL      : std_ulogic;
  signal res_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal res_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal res_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal res_HWRITE    : std_ulogic;
  signal res_HPROT     : std_ulogic_vector(3 downto 0);
  signal res_HSIZE     : std_ulogic_vector(2 downto 0);
  signal res_HBURST    : std_ulogic_vector(2 downto 0);
  signal res_HTRANS    : std_ulogic_vector(1 downto 0);
  signal res_HMASTLOCK : std_ulogic;
  signal res_HREADY    : std_ulogic;
  signal res_HRESP     : std_ulogic;

  signal target_HSEL      : std_ulogic;
  signal target_HADDR     : std_ulogic_vector(PLEN-1 downto 0);
  signal target_HWDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal target_HRDATA    : std_ulogic_vector(XLEN-1 downto 0);
  signal target_HWRITE    : std_ulogic;
  signal target_HPROT     : std_ulogic_vector(3 downto 0);
  signal target_HSIZE     : std_ulogic_vector(2 downto 0);
  signal target_HBURST    : std_ulogic_vector(2 downto 0);
  signal target_HTRANS    : std_ulogic_vector(1 downto 0);
  signal target_HMASTLOCK : std_ulogic;
  signal target_HREADY    : std_ulogic;
  signal target_HRESP     : std_ulogic;

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal ctrl_done_en    : std_ulogic;
  signal ctrl_done_pos   : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_read_pos   : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_read_req   : std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);
  signal done            : std_ulogic_vector(TABLE_ENTRIES-1 downto 0);
  signal if_valid_en     : std_ulogic;
  signal if_valid_pos    : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal if_valid_set    : std_ulogic;
  signal if_validrd_en   : std_ulogic;
  signal if_write_en     : std_ulogic;
  signal if_write_pos    : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal if_write_req    : std_ulogic_vector(DMA_REQUEST_WIDTH-1 downto 0);
  signal if_write_select : std_ulogic_vector(DMA_REQMASK_WIDTH-1 downto 0);
  signal valid           : std_ulogic_vector(TABLE_ENTRIES-1 downto 0);

  -- End of automatics
  signal ctrl_out_read_pos : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_in_read_pos  : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_write_pos    : std_ulogic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  signal ahb_arb     : std_ulogic_vector(1 downto 0);
  signal nxt_ahb_arb : std_ulogic_vector(1 downto 0);

  signal ahb_arb_active : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  ctrl_out_read_pos <= (others => '0');
  ctrl_in_read_pos  <= (others => '0');
  ctrl_write_pos    <= (others => '0');

  dma_wbinterface : riscv_dma_interface
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      TABLE_ENTRIES => TABLE_ENTRIES,
      DMA_REQMASK_WIDTH => DMA_REQMASK_WIDTH,
      DMA_REQUEST_WIDTH => DMA_REQUEST_WIDTH,
      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      if_HSEL      => mst_HSEL,
      if_HADDR     => mst_HADDR(PLEN-1 downto 0),
      if_HWDATA    => mst_HWDATA(XLEN-1 downto 0),
      if_HRDATA    => mst_HRDATA(XLEN-1 downto 0),
      if_HWRITE    => mst_HWRITE,
      if_HSIZE     => mst_HSIZE(2 downto 0),
      if_HBURST    => mst_HBURST(2 downto 0),
      if_HPROT     => mst_HPROT(3 downto 0),
      if_HTRANS    => mst_HTRANS(1 downto 0),
      if_HMASTLOCK => mst_HMASTLOCK,
      if_HREADYOUT => mst_HREADYOUT,
      if_HRESP     => mst_HRESP,

      if_write_req    => if_write_req(DMA_REQUEST_WIDTH-1 downto 0),
      if_write_pos    => if_write_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_write_select => if_write_select(DMA_REQMASK_WIDTH-1 downto 0),
      if_write_en     => if_write_en,

      if_valid_pos  => if_valid_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_valid_set  => if_valid_set,
      if_valid_en   => if_valid_en,
      if_validrd_en => if_validrd_en,

      done => done(TABLE_ENTRIES-1 downto 0)
      );

  dma_transfer_table : riscv_dma_transfer_table
    generic map (
      DMA_REQUEST_WIDTH => DMA_REQUEST_WIDTH,
      TABLE_ENTRIES => TABLE_ENTRIES,
      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH,
      DMA_REQMASK_WIDTH => DMA_REQMASK_WIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      if_write_req    => if_write_req(DMA_REQUEST_WIDTH-1 downto 0),
      if_write_pos    => if_write_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_write_select => if_write_select(DMA_REQMASK_WIDTH-1 downto 0),
      if_write_en     => if_write_en,

      if_valid_pos  => if_valid_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_valid_set  => if_valid_set,
      if_valid_en   => if_valid_en,
      if_validrd_en => if_validrd_en,

      ctrl_read_req => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      ctrl_read_pos => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),

      ctrl_done_pos => ctrl_done_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en  => ctrl_done_en,

      valid => valid(TABLE_ENTRIES-1 downto 0),
      done  => done(TABLE_ENTRIES-1 downto 0),

      irq => irq(TABLE_ENTRIES-1 downto 0)
      );

  dma_initiator : riscv_dma_initiator
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      NOC_PACKET_SIZE => NOC_PACKET_SIZE,

      TABLE_ENTRIES => TABLE_ENTRIES,
      DMA_REQUEST_WIDTH => DMA_REQUEST_WIDTH,
      DMA_REQFIELD_SIZE_WIDTH => DMA_REQFIELD_SIZE_WIDTH,
      TABLE_ENTRIES_PTRWIDTH => TABLE_ENTRIES_PTRWIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      ctrl_read_pos => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_read_req => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),

      ctrl_done_pos => ctrl_done_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en  => ctrl_done_en,

      valid => valid(TABLE_ENTRIES-1 downto 0),

      noc_out_flit  => noc_out_req_flit(PLEN-1 downto 0),
      noc_out_last  => noc_out_req_last,
      noc_out_valid => noc_out_req_valid,
      noc_out_ready => noc_out_req_ready,

      noc_in_flit  => noc_in_res_flit(PLEN-1 downto 0),
      noc_in_last  => noc_in_res_last,
      noc_in_valid => noc_in_res_valid,
      noc_in_ready => noc_in_res_ready,

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

      res_HSEL      => res_HSEL,
      res_HADDR     => res_HADDR(PLEN-1 downto 0),
      res_HWDATA    => res_HWDATA(XLEN-1 downto 0),
      res_HRDATA    => res_HRDATA(XLEN-1 downto 0),
      res_HWRITE    => res_HWRITE,
      res_HSIZE     => res_HSIZE(2 downto 0),
      res_HBURST    => res_HBURST(2 downto 0),
      res_HPROT     => res_HPROT(3 downto 0),
      res_HTRANS    => res_HTRANS(1 downto 0),
      res_HMASTLOCK => res_HMASTLOCK,
      res_HREADY    => res_HREADY,
      res_HRESP     => res_HRESP
      );

  transfer_target : riscv_dma_transfer_target
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      NOC_PACKET_SIZE => NOC_PACKET_SIZE
    )
    port map (
      clk => clk,
      rst => rst,

      noc_out_flit  => noc_out_res_flit(PLEN-1 downto 0),
      noc_out_last  => noc_out_res_last,
      noc_out_valid => noc_out_res_valid,
      noc_out_ready => noc_out_res_ready,

      noc_in_flit  => noc_in_req_flit(PLEN-1 downto 0),
      noc_in_last  => noc_in_req_last,
      noc_in_valid => noc_in_req_valid,
      noc_in_ready => noc_in_req_ready,

      HSEL      => target_HSEL,
      HADDR     => target_HADDR(PLEN-1 downto 0),
      HWDATA    => target_HWDATA(XLEN-1 downto 0),
      HRDATA    => target_HRDATA(XLEN-1 downto 0),
      HWRITE    => target_HWRITE,
      HSIZE     => target_HSIZE(2 downto 0),
      HBURST    => target_HBURST(2 downto 0),
      HPROT     => target_HPROT(3 downto 0),
      HTRANS    => target_HTRANS(1 downto 0),
      HMASTLOCK => target_HMASTLOCK,
      HREADY    => target_HREADY,
      HRESP     => target_HRESP
      );

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        ahb_arb <= ahb_arb_target;
      else
        ahb_arb <= nxt_ahb_arb;
      end if;
    end if;
  end process;

  ahb_arb_active <= (to_stdlogic(ahb_arb = ahb_arb_req) and req_HMASTLOCK) or (to_stdlogic(ahb_arb = ahb_arb_res) and res_HMASTLOCK) or (to_stdlogic(ahb_arb = ahb_arb_target) and target_HMASTLOCK);

  processing_1 : process (ahb_arb, ahb_arb_active, req_HMASTLOCK, res_HMASTLOCK, target_HMASTLOCK)
  begin
    if (ahb_arb_active = '1') then
      nxt_ahb_arb <= ahb_arb;
    elsif (target_HMASTLOCK = '1') then
      nxt_ahb_arb <= ahb_arb_target;
    elsif (res_HMASTLOCK = '1') then
      nxt_ahb_arb <= ahb_arb_res;
    elsif (req_HMASTLOCK = '1') then
      nxt_ahb_arb <= ahb_arb_req;
    else
      nxt_ahb_arb <= ahb_arb_target;
    end if;
  end process;

  processing_2 : process (ahb_arb, req_HADDR, req_HBURST, req_HMASTLOCK, req_HPROT, req_HSEL, req_HTRANS, req_HWDATA, req_HWRITE, res_HADDR, res_HBURST, res_HMASTLOCK, res_HPROT, res_HSEL, res_HTRANS, res_HWDATA, res_HWRITE, slv_HRDATA, slv_HREADY, target_HADDR, target_HBURST, target_HMASTLOCK, target_HPROT, target_HSEL, target_HTRANS, target_HWDATA, target_HWRITE)
  begin
    if (ahb_arb = ahb_arb_target) then
      slv_HSEL      <= target_HSEL;
      slv_HADDR     <= target_HADDR;
      slv_HWDATA    <= target_HWDATA;
      slv_HWRITE    <= target_HWRITE;
      slv_HBURST    <= target_HBURST;
      slv_HPROT     <= target_HPROT;
      slv_HTRANS    <= target_HTRANS;
      slv_HMASTLOCK <= target_HMASTLOCK;
      target_HREADY <= slv_HREADY;
      target_HRDATA <= slv_HRDATA;
      req_HRDATA    <= (others => 'X');
      req_HREADY    <= '0';
      res_HRDATA    <= (others => 'X');
      res_HREADY    <= '0';
    elsif (ahb_arb = ahb_arb_res) then
      slv_HSEL      <= res_HSEL;
      slv_HADDR     <= res_HADDR;
      slv_HWDATA    <= res_HWDATA;
      slv_HWRITE    <= res_HWRITE;
      slv_HBURST    <= res_HBURST;
      slv_HPROT     <= res_HPROT;
      slv_HTRANS    <= res_HTRANS;
      slv_HMASTLOCK <= res_HMASTLOCK;
      res_HREADY    <= slv_HREADY;
      res_HRDATA    <= slv_HRDATA;
      req_HRDATA    <= (others => 'X');
      req_HREADY    <= '0';
      target_HRDATA <= (others => 'X');
      target_HREADY <= '0';
    elsif (ahb_arb = ahb_arb_req) then
      slv_HSEL      <= req_HSEL;
      slv_HADDR     <= req_HADDR;
      slv_HWDATA    <= req_HWDATA;
      slv_HWRITE    <= req_HWRITE;
      slv_HBURST    <= req_HBURST;
      slv_HPROT     <= req_HPROT;
      slv_HTRANS    <= req_HTRANS;
      slv_HMASTLOCK <= req_HMASTLOCK;
      req_HREADY    <= slv_HREADY;
      req_HRDATA    <= slv_HRDATA;
      res_HRDATA    <= (others => 'X');
      res_HREADY    <= '0';
      target_HRDATA <= (others => 'X');
      target_HREADY <= '0';
    else                                -- if (ahb_arb == ahb_arb_req)
      slv_HSEL      <= '0';
      slv_HADDR     <= (others => '0');
      slv_HWDATA    <= (others => '0');
      slv_HWRITE    <= '0';
      slv_HBURST    <= (others => '0');
      slv_HPROT     <= (others => '0');
      slv_HTRANS    <= (others => '0');
      slv_HMASTLOCK <= '0';
      req_HRDATA    <= (others => 'X');
      req_HREADY    <= '0';
      res_HRDATA    <= (others => 'X');
      res_HREADY    <= '0';
      target_HRDATA <= (others => 'X');
      target_HREADY <= '0';
    end if;
  end process;

  slv_HSIZE <= "000";
end RTL;
