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
--              AMBA3 AHB-Lite Bus Interface                                  --
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
--   Michael Tempelmeier <michael.tempelmeier@tum.de>
--   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vhdl_pkg.all;
use work.peripheral_dma_pkg.all;

entity peripheral_dma_top_tl is
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

    biu_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_if_hmastlock : in  std_logic;
    biu_if_hsel      : in  std_logic;
    biu_if_hwrite    : in  std_logic;
    biu_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_if_hready    : out std_logic;
    biu_if_hresp     : out std_logic;

    biu_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_hmastlock : out std_logic;
    biu_hsel      : out std_logic;
    biu_hprot     : out std_logic_vector(3 downto 0);
    biu_hwrite    : out std_logic;
    biu_hsize     : out std_logic_vector(2 downto 0);
    biu_hburst    : out std_logic_vector(2 downto 0);
    biu_htrans    : out std_logic_vector(1 downto 0);
    biu_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_hready    : in  std_logic;

    irq : out std_logic_vector(TABLE_ENTRIES-1 downto 0)
    );
end peripheral_dma_top_tl;

architecture rtl of peripheral_dma_top_tl is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dma_interface_tl
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := 2;
      TILEID                 : integer := 0
      );
    port (
      clk : in std_logic;
      rst : in std_logic;

      biu_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_if_hmastlock : in  std_logic;
      biu_if_hsel      : in  std_logic;
      biu_if_hwrite    : in  std_logic;
      biu_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_if_hready    : out std_logic;

      if_write_req    : out std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      if_write_pos    : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_write_select : out std_logic_vector(DMA_REQMASK_WIDTH-1 downto 0);
      if_write_en     : out std_logic;

      -- Interface read (status) interface
      if_valid_pos  : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_valid_set  : out std_logic;
      if_valid_en   : out std_logic;
      if_validrd_en : out std_logic;

      done : in std_logic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  component peripheral_dma_request_table
    generic (
      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      GENERATE_INTERRUPT     : integer := 1
      );
    port (
      clk : in std_logic;
      rst : in std_logic;

      -- Interface write (request) interface
      if_write_req    : in std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      if_write_pos    : in std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_write_select : in std_logic_vector(DMA_REQMASK_WIDTH-1 downto 0);
      if_write_en     : in std_logic;

      if_valid_pos  : in std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      if_valid_set  : in std_logic;
      if_valid_en   : in std_logic;
      if_validrd_en : in std_logic;

      -- Control read (request) interface
      ctrl_read_req : out std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);
      ctrl_read_pos : in  std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

      -- Control write (status) interface
      ctrl_done_pos : in std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
      ctrl_done_en  : in std_logic;

      -- All valid bits of the entries
      valid : out std_logic_vector(TABLE_ENTRIES-1 downto 0);
      done  : out std_logic_vector(TABLE_ENTRIES-1 downto 0);

      irq : out std_logic_vector(TABLE_ENTRIES-1 downto 0)
      );
  end component;

  component peripheral_dma_initiator_tl
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
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
  end component;

  component peripheral_dma_target_tl
    generic (
      ADDR_WIDTH  : integer := 32;
      DATA_WIDTH  : integer := 32;
      FLIT_WIDTH  : integer := FLIT_WIDTH;
      STATE_WIDTH : integer := 4;

      STATE_IDLE         : std_logic_vector(3 downto 0) := "0000";
      STATE_L2R_GETADDR  : std_logic_vector(3 downto 0) := "0001";
      STATE_L2R_DATA     : std_logic_vector(3 downto 0) := "0010";
      STATE_L2R_SENDRESP : std_logic_vector(3 downto 0) := "0011";
      STATE_R2L_GETLADDR : std_logic_vector(3 downto 0) := "0100";
      STATE_R2L_GETRADDR : std_logic_vector(3 downto 0) := "0101";
      STATE_R2L_GENHDR   : std_logic_vector(3 downto 0) := "0110";
      STATE_R2L_GENADDR  : std_logic_vector(3 downto 0) := "0111";
      STATE_R2L_DATA     : std_logic_vector(3 downto 0) := "1000";

      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      TILEID                 : integer := 0;
      NOC_PACKET_SIZE        : integer := 16
      );
    port (
      clk : in std_logic;
      rst : in std_logic;

      -- NOC-Interface
      noc_out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_out_valid : out std_logic;
      noc_out_ready : in  std_logic;

      noc_in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      noc_in_valid : in  std_logic;
      noc_in_ready : out std_logic;

      -- Wishbone interface for L2R data store
      biu_hready    : in  std_logic;
      biu_hmastlock : out std_logic;
      biu_hsel      : out std_logic;
      biu_hwrite    : out std_logic;
      biu_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_hprot     : out std_logic_vector(3 downto 0);
      biu_hburst    : out std_logic_vector(2 downto 0);
      biu_htrans    : out std_logic_vector(1 downto 0)
      );
  end component;

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  constant biu_arb_req    : std_logic_vector(1 downto 0) := "00";
  constant biu_arb_res    : std_logic_vector(1 downto 0) := "01";
  constant biu_arb_target : std_logic_vector(1 downto 0) := "10";

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal biu_req_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal biu_req_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_req_hmastlock : std_logic;
  signal biu_req_hsel      : std_logic;
  signal biu_req_hwrite    : std_logic;
  signal biu_req_hprot     : std_logic_vector(3 downto 0);
  signal biu_req_hburst    : std_logic_vector(2 downto 0);
  signal biu_req_htrans    : std_logic_vector(1 downto 0);
  signal biu_req_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_req_hready    : std_logic;

  signal biu_res_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal biu_res_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_res_hmastlock : std_logic;
  signal biu_res_hsel      : std_logic;
  signal biu_res_hwrite    : std_logic;
  signal biu_res_hprot     : std_logic_vector(3 downto 0);
  signal biu_res_hburst    : std_logic_vector(2 downto 0);
  signal biu_res_htrans    : std_logic_vector(1 downto 0);
  signal biu_res_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_res_hready    : std_logic;

  signal biu_target_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal biu_target_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_target_hmastlock : std_logic;
  signal biu_target_hsel      : std_logic;
  signal biu_target_hwrite    : std_logic;
  signal biu_target_hburst    : std_logic_vector(2 downto 0);
  signal biu_target_htrans    : std_logic_vector(1 downto 0);
  signal biu_target_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_target_hready    : std_logic;

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal ctrl_done_en      : std_logic;  -- From ctrl_initiator
  signal ctrl_done_pos     : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_pos     : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_req     : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From request_table
  signal done              : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal if_valid_en       : std_logic;  -- From wb interface
  signal if_valid_pos      : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From wb interface
  signal if_valid_set      : std_logic;  -- From wb interface
  signal if_validrd_en     : std_logic;  -- From wb interface
  signal if_write_en       : std_logic;  -- From wb interface
  signal if_write_pos      : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From wb interface
  signal if_write_req      : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From wb interface
  signal if_write_select   : std_logic_vector(DMA_REQMASK_WIDTH-1 downto 0);  -- From wb interface
  signal valid             : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal biu_target_hprot : std_logic_vector(3 downto 0);  -- From target
  -- End of automatics

  signal ctrl_out_read_pos : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_in_read_pos  : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_write_pos    : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  signal biu_arb     : std_logic_vector(1 downto 0);
  signal nxt_tl_arb : std_logic_vector(1 downto 0);

  signal biu_arb_active : std_logic;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------
  biu_if_hresp <= '0';

  ctrl_out_read_pos <= (others => '0');
  ctrl_in_read_pos  <= (others => '0');
  ctrl_write_pos    <= (others => '0');

  biu_interface : peripheral_dma_interface_tl
    generic map (
      TILEID => TILEID
      )
    port map (
      -- Outputs
      biu_if_hwdata    => biu_if_hwdata(DATA_WIDTH-1 downto 0),
      biu_if_hready    => biu_if_hready,
      if_write_req      => if_write_req(DMA_REQUEST_WIDTH-1 downto 0),
      if_write_pos      => if_write_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_write_select   => if_write_select(DMA_REQMASK_WIDTH-1 downto 0),
      if_write_en       => if_write_en,
      if_valid_pos      => if_valid_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_valid_set      => if_valid_set,
      if_valid_en       => if_valid_en,
      if_validrd_en     => if_validrd_en,
      -- Inputs
      clk               => clk,
      rst               => rst,
      biu_if_haddr     => biu_if_haddr(ADDR_WIDTH-1 downto 0),
      biu_if_hrdata    => biu_if_hrdata(DATA_WIDTH-1 downto 0),
      biu_if_hmastlock => biu_if_hmastlock,
      biu_if_hsel      => biu_if_hsel,
      biu_if_hwrite    => biu_if_hwrite,
      done              => done(TABLE_ENTRIES-1 downto 0)
      );

  request_table : peripheral_dma_request_table
    generic map (
      GENERATE_INTERRUPT => GENERATE_INTERRUPT
      )
    port map (
      -- Outputs
      ctrl_read_req   => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      valid           => valid(TABLE_ENTRIES-1 downto 0),
      done            => done(TABLE_ENTRIES-1 downto 0),
      irq             => irq(TABLE_ENTRIES-1 downto 0),
      -- Inputs
      clk             => clk,
      rst             => rst,
      if_write_req    => if_write_req(DMA_REQUEST_WIDTH-1 downto 0),
      if_write_pos    => if_write_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_write_select => if_write_select(DMA_REQMASK_WIDTH-1 downto 0),
      if_write_en     => if_write_en,
      if_valid_pos    => if_valid_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_valid_set    => if_valid_set,
      if_valid_en     => if_valid_en,
      if_validrd_en   => if_validrd_en,
      ctrl_read_pos   => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_pos   => ctrl_done_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en    => ctrl_done_en
      );

  biu_initiator : peripheral_dma_initiator_tl
    generic map (
      TILEID => TILEID
      )
    port map (
      -- Outputs
      ctrl_read_pos      => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_pos      => ctrl_done_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en       => ctrl_done_en,
      noc_out_flit       => noc_out_req_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid      => noc_out_req_valid,
      noc_in_ready       => noc_in_res_ready,
      biu_req_hmastlock => biu_req_hmastlock,
      biu_req_hsel      => biu_req_hsel,
      biu_req_hwrite    => biu_req_hwrite,
      biu_req_hwdata    => biu_req_hwdata(DATA_WIDTH-1 downto 0),
      biu_req_haddr     => biu_req_haddr(ADDR_WIDTH-1 downto 0),
      biu_req_hburst    => biu_req_hburst(2 downto 0),
      biu_req_htrans    => biu_req_htrans(1 downto 0),
      biu_req_hprot     => biu_req_hprot(3 downto 0),
      biu_res_hmastlock => biu_res_hmastlock,
      biu_res_hsel      => biu_res_hsel,
      biu_res_hwrite    => biu_res_hwrite,
      biu_res_hwdata    => biu_res_hwdata(DATA_WIDTH-1 downto 0),
      biu_res_haddr     => biu_res_haddr(ADDR_WIDTH-1 downto 0),
      biu_res_hburst    => biu_res_hburst(2 downto 0),
      biu_res_htrans    => biu_res_htrans(1 downto 0),
      biu_res_hprot     => biu_res_hprot(3 downto 0),
      -- Inputs
      clk                => clk,
      rst                => rst,
      ctrl_read_req      => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      valid              => valid(TABLE_ENTRIES-1 downto 0),
      noc_out_ready      => noc_out_req_ready,
      noc_in_flit        => noc_in_res_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid       => noc_in_res_valid,
      biu_req_hready    => biu_req_hready,
      biu_req_hrdata    => biu_req_hrdata(DATA_WIDTH-1 downto 0),
      biu_res_hready    => biu_res_hready,
      biu_res_hrdata    => biu_res_hrdata(DATA_WIDTH-1 downto 0)
      );

  biu_target : peripheral_dma_target_tl
    generic map (
      TILEID          => TILEID,
      NOC_PACKET_SIZE => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      noc_out_flit   => noc_out_res_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid  => noc_out_res_valid,
      noc_in_ready   => noc_in_req_ready,
      biu_hmastlock => biu_target_hmastlock,
      biu_hsel      => biu_target_hsel,
      biu_hwrite    => biu_target_hwrite,
      biu_hwdata    => biu_target_hwdata(DATA_WIDTH-1 downto 0),
      biu_haddr     => biu_target_haddr(ADDR_WIDTH-1 downto 0),
      biu_hprot     => biu_target_hprot(3 downto 0),
      biu_hburst    => biu_target_hburst(2 downto 0),
      biu_htrans    => biu_target_htrans(1 downto 0),
      -- Inputs
      clk            => clk,
      rst            => rst,
      noc_out_ready  => noc_out_res_ready,
      noc_in_flit    => noc_in_req_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid   => noc_in_req_valid,
      biu_hready    => biu_target_hready,
      biu_hrdata    => biu_target_hrdata(DATA_WIDTH-1 downto 0)
      );

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        biu_arb <= biu_arb_target;
      else
        biu_arb <= nxt_tl_arb;
      end if;
    end if;
  end process;

  biu_arb_active <= (to_stdlogic(biu_arb = biu_arb_req) and biu_req_hmastlock) or
                     (to_stdlogic(biu_arb = biu_arb_res) and biu_res_hmastlock) or
                     (to_stdlogic(biu_arb = biu_arb_target) and biu_target_hmastlock);

  processing_1 : process (biu_arb_active)
  begin
    if (biu_arb_active = '1') then
      nxt_tl_arb <= biu_arb;
    elsif (biu_target_hmastlock = '1') then
      nxt_tl_arb <= biu_arb_target;
    elsif (biu_res_hmastlock = '1') then
      nxt_tl_arb <= biu_arb_res;
    elsif (biu_req_hmastlock = '1') then
      nxt_tl_arb <= biu_arb_req;
    else
      nxt_tl_arb <= biu_arb_target;
    end if;
  end process;

  biu_hsize <= (others => '0');

  processing_2 : process (biu_arb)
  begin
    if (biu_arb = biu_arb_target) then
      biu_haddr         <= biu_target_haddr;
      biu_hwdata        <= biu_target_hwdata;
      biu_hmastlock     <= biu_target_hmastlock;
      biu_hsel          <= biu_target_hsel;
      biu_hprot         <= biu_target_hprot;
      biu_hwrite        <= biu_target_hwrite;
      biu_htrans        <= biu_target_htrans;
      biu_hburst        <= biu_target_hburst;
      biu_target_hready <= biu_hready;
      biu_target_hrdata <= biu_hrdata;
      biu_req_hready    <= '0';
      biu_req_hrdata    <= (others => 'X');
      biu_res_hready    <= '0';
      biu_res_hrdata    <= (others => 'X');
    elsif (biu_arb = biu_arb_res) then
      biu_haddr         <= biu_res_haddr;
      biu_hwdata        <= biu_res_hwdata;
      biu_hmastlock     <= biu_res_hmastlock;
      biu_hsel          <= biu_res_hsel;
      biu_hprot         <= biu_res_hprot;
      biu_hwrite        <= biu_res_hwrite;
      biu_htrans        <= biu_res_htrans;
      biu_hburst        <= biu_res_hburst;
      biu_res_hready    <= biu_hready;
      biu_res_hrdata    <= biu_hrdata;
      biu_req_hready    <= '0';
      biu_req_hrdata    <= (others => 'X');
      biu_target_hready <= '0';
      biu_target_hrdata <= (others => 'X');
    elsif (biu_arb = biu_arb_req) then
      biu_haddr         <= biu_req_haddr;
      biu_hwdata        <= biu_req_hwdata;
      biu_hmastlock     <= biu_req_hmastlock;
      biu_hsel          <= biu_req_hsel;
      biu_hprot         <= biu_req_hprot;
      biu_hwrite        <= biu_req_hwrite;
      biu_htrans        <= biu_req_htrans;
      biu_hburst        <= biu_req_hburst;
      biu_req_hready    <= biu_hready;
      biu_req_hrdata    <= biu_hrdata;
      biu_res_hready    <= '0';
      biu_res_hrdata    <= (others => 'X');
      biu_target_hready <= '0';
      biu_target_hrdata <= (others => 'X');
    else
      biu_haddr         <= (others => 'X');
      biu_hwdata        <= (others => 'X');
      biu_hmastlock     <= '0';
      biu_hsel          <= '0';
      biu_hprot         <= (others => 'X');
      biu_hwrite        <= '0';
      biu_htrans        <= "00";
      biu_hburst        <= "000";
      biu_req_hready    <= '0';
      biu_req_hrdata    <= (others => 'X');
      biu_res_hready    <= '0';
      biu_res_hrdata    <= (others => 'X');
      biu_target_hready <= '0';
      biu_target_hrdata <= (others => 'X');
    end if;
  end process;
end rtl;
