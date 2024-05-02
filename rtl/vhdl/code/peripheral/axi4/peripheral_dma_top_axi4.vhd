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

entity peripheral_dma_top_axi4 is
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

    axi4_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    axi4_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    axi4_if_hmastlock : in  std_logic;
    axi4_if_hsel      : in  std_logic;
    axi4_if_hwrite    : in  std_logic;
    axi4_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    axi4_if_hready    : out std_logic;
    axi4_if_hresp     : out std_logic;

    axi4_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    axi4_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    axi4_hmastlock : out std_logic;
    axi4_hsel      : out std_logic;
    axi4_hprot     : out std_logic_vector(3 downto 0);
    axi4_hwrite    : out std_logic;
    axi4_hsize     : out std_logic_vector(2 downto 0);
    axi4_hburst    : out std_logic_vector(2 downto 0);
    axi4_htrans    : out std_logic_vector(1 downto 0);
    axi4_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    axi4_hready    : in  std_logic;

    irq : out std_logic_vector(TABLE_ENTRIES-1 downto 0)
    );
end peripheral_dma_top_axi4;

architecture rtl of peripheral_dma_top_axi4 is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dma_interface_axi4
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

      axi4_if_haddr     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_if_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_if_hmastlock : in  std_logic;
      axi4_if_hsel      : in  std_logic;
      axi4_if_hwrite    : in  std_logic;
      axi4_if_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_if_hready    : out std_logic;

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

  component peripheral_dma_initiator_axi4
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
      axi4_req_hready    : in  std_logic;
      axi4_req_hmastlock : out std_logic;
      axi4_req_hsel      : out std_logic;
      axi4_req_hwrite    : out std_logic;
      axi4_req_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_req_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_req_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_req_hburst    : out std_logic_vector(2 downto 0);
      axi4_req_htrans    : out std_logic_vector(1 downto 0);
      axi4_req_hprot     : out std_logic_vector(3 downto 0);

      -- Wishbone interface for L2R data fetch
      axi4_res_hready    : in  std_logic;
      axi4_res_hmastlock : out std_logic;
      axi4_res_hsel      : out std_logic;
      axi4_res_hwrite    : out std_logic;
      axi4_res_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_res_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_res_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_res_hburst    : out std_logic_vector(2 downto 0);
      axi4_res_htrans    : out std_logic_vector(1 downto 0);
      axi4_res_hprot     : out std_logic_vector(3 downto 0)
      );
  end component;

  component peripheral_dma_target_axi4
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
      axi4_hready    : in  std_logic;
      axi4_hmastlock : out std_logic;
      axi4_hsel      : out std_logic;
      axi4_hwrite    : out std_logic;
      axi4_hrdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_hwdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_haddr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_hprot     : out std_logic_vector(3 downto 0);
      axi4_hburst    : out std_logic_vector(2 downto 0);
      axi4_htrans    : out std_logic_vector(1 downto 0)
      );
  end component;

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  constant axi4_arb_req    : std_logic_vector(1 downto 0) := "00";
  constant axi4_arb_res    : std_logic_vector(1 downto 0) := "01";
  constant axi4_arb_target : std_logic_vector(1 downto 0) := "10";

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal axi4_req_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal axi4_req_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_req_hmastlock : std_logic;
  signal axi4_req_hsel      : std_logic;
  signal axi4_req_hwrite    : std_logic;
  signal axi4_req_hprot     : std_logic_vector(3 downto 0);
  signal axi4_req_hburst    : std_logic_vector(2 downto 0);
  signal axi4_req_htrans    : std_logic_vector(1 downto 0);
  signal axi4_req_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_req_hready    : std_logic;

  signal axi4_res_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal axi4_res_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_res_hmastlock : std_logic;
  signal axi4_res_hsel      : std_logic;
  signal axi4_res_hwrite    : std_logic;
  signal axi4_res_hprot     : std_logic_vector(3 downto 0);
  signal axi4_res_hburst    : std_logic_vector(2 downto 0);
  signal axi4_res_htrans    : std_logic_vector(1 downto 0);
  signal axi4_res_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_res_hready    : std_logic;

  signal axi4_target_haddr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal axi4_target_hwdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_target_hmastlock : std_logic;
  signal axi4_target_hsel      : std_logic;
  signal axi4_target_hwrite    : std_logic;
  signal axi4_target_hburst    : std_logic_vector(2 downto 0);
  signal axi4_target_htrans    : std_logic_vector(1 downto 0);
  signal axi4_target_hrdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_target_hready    : std_logic;

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal ctrl_done_en      : std_logic;  -- From ctrl_initiator
  signal ctrl_done_pos     : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_pos     : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_req     : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From request_table
  signal done              : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal if_valid_en       : std_logic;  -- From axi4 interface
  signal if_valid_pos      : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From axi4 interface
  signal if_valid_set      : std_logic;  -- From axi4 interface
  signal if_validrd_en     : std_logic;  -- From axi4 interface
  signal if_write_en       : std_logic;  -- From axi4 interface
  signal if_write_pos      : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From axi4 interface
  signal if_write_req      : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From axi4 interface
  signal if_write_select   : std_logic_vector(DMA_REQMASK_WIDTH-1 downto 0);  -- From axi4 interface
  signal valid             : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal axi4_target_hprot : std_logic_vector(3 downto 0);  -- From target
  -- End of automatics

  signal ctrl_out_read_pos : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_in_read_pos  : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_write_pos    : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  signal axi4_arb     : std_logic_vector(1 downto 0);
  signal nxt_axi4_arb : std_logic_vector(1 downto 0);

  signal axi4_arb_active : std_logic;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------
  axi4_if_hresp <= '0';

  ctrl_out_read_pos <= (others => '0');
  ctrl_in_read_pos  <= (others => '0');
  ctrl_write_pos    <= (others => '0');

  axi4_interface : peripheral_dma_interface_axi4
    generic map (
      TILEID => TILEID
      )
    port map (
      -- Outputs
      axi4_if_hwdata    => axi4_if_hwdata(DATA_WIDTH-1 downto 0),
      axi4_if_hready    => axi4_if_hready,
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
      axi4_if_haddr     => axi4_if_haddr(ADDR_WIDTH-1 downto 0),
      axi4_if_hrdata    => axi4_if_hrdata(DATA_WIDTH-1 downto 0),
      axi4_if_hmastlock => axi4_if_hmastlock,
      axi4_if_hsel      => axi4_if_hsel,
      axi4_if_hwrite    => axi4_if_hwrite,
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

  axi4_initiator : peripheral_dma_initiator_axi4
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
      axi4_req_hmastlock => axi4_req_hmastlock,
      axi4_req_hsel      => axi4_req_hsel,
      axi4_req_hwrite    => axi4_req_hwrite,
      axi4_req_hwdata    => axi4_req_hwdata(DATA_WIDTH-1 downto 0),
      axi4_req_haddr     => axi4_req_haddr(ADDR_WIDTH-1 downto 0),
      axi4_req_hburst    => axi4_req_hburst(2 downto 0),
      axi4_req_htrans    => axi4_req_htrans(1 downto 0),
      axi4_req_hprot     => axi4_req_hprot(3 downto 0),
      axi4_res_hmastlock => axi4_res_hmastlock,
      axi4_res_hsel      => axi4_res_hsel,
      axi4_res_hwrite    => axi4_res_hwrite,
      axi4_res_hwdata    => axi4_res_hwdata(DATA_WIDTH-1 downto 0),
      axi4_res_haddr     => axi4_res_haddr(ADDR_WIDTH-1 downto 0),
      axi4_res_hburst    => axi4_res_hburst(2 downto 0),
      axi4_res_htrans    => axi4_res_htrans(1 downto 0),
      axi4_res_hprot     => axi4_res_hprot(3 downto 0),
      -- Inputs
      clk                => clk,
      rst                => rst,
      ctrl_read_req      => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      valid              => valid(TABLE_ENTRIES-1 downto 0),
      noc_out_ready      => noc_out_req_ready,
      noc_in_flit        => noc_in_res_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid       => noc_in_res_valid,
      axi4_req_hready    => axi4_req_hready,
      axi4_req_hrdata    => axi4_req_hrdata(DATA_WIDTH-1 downto 0),
      axi4_res_hready    => axi4_res_hready,
      axi4_res_hrdata    => axi4_res_hrdata(DATA_WIDTH-1 downto 0)
      );

  axi4_target : peripheral_dma_target_axi4
    generic map (
      TILEID          => TILEID,
      NOC_PACKET_SIZE => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      noc_out_flit   => noc_out_res_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid  => noc_out_res_valid,
      noc_in_ready   => noc_in_req_ready,
      axi4_hmastlock => axi4_target_hmastlock,
      axi4_hsel      => axi4_target_hsel,
      axi4_hwrite    => axi4_target_hwrite,
      axi4_hwdata    => axi4_target_hwdata(DATA_WIDTH-1 downto 0),
      axi4_haddr     => axi4_target_haddr(ADDR_WIDTH-1 downto 0),
      axi4_hprot     => axi4_target_hprot(3 downto 0),
      axi4_hburst    => axi4_target_hburst(2 downto 0),
      axi4_htrans    => axi4_target_htrans(1 downto 0),
      -- Inputs
      clk            => clk,
      rst            => rst,
      noc_out_ready  => noc_out_res_ready,
      noc_in_flit    => noc_in_req_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid   => noc_in_req_valid,
      axi4_hready    => axi4_target_hready,
      axi4_hrdata    => axi4_target_hrdata(DATA_WIDTH-1 downto 0)
      );

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        axi4_arb <= axi4_arb_target;
      else
        axi4_arb <= nxt_axi4_arb;
      end if;
    end if;
  end process;

  axi4_arb_active <= (to_stdlogic(axi4_arb = axi4_arb_req) and axi4_req_hmastlock) or
                     (to_stdlogic(axi4_arb = axi4_arb_res) and axi4_res_hmastlock) or
                     (to_stdlogic(axi4_arb = axi4_arb_target) and axi4_target_hmastlock);

  processing_1 : process (axi4_arb_active)
  begin
    if (axi4_arb_active = '1') then
      nxt_axi4_arb <= axi4_arb;
    elsif (axi4_target_hmastlock = '1') then
      nxt_axi4_arb <= axi4_arb_target;
    elsif (axi4_res_hmastlock = '1') then
      nxt_axi4_arb <= axi4_arb_res;
    elsif (axi4_req_hmastlock = '1') then
      nxt_axi4_arb <= axi4_arb_req;
    else
      nxt_axi4_arb <= axi4_arb_target;
    end if;
  end process;

  axi4_hsize <= (others => '0');

  processing_2 : process (axi4_arb)
  begin
    if (axi4_arb = axi4_arb_target) then
      axi4_haddr         <= axi4_target_haddr;
      axi4_hwdata        <= axi4_target_hwdata;
      axi4_hmastlock     <= axi4_target_hmastlock;
      axi4_hsel          <= axi4_target_hsel;
      axi4_hprot         <= axi4_target_hprot;
      axi4_hwrite        <= axi4_target_hwrite;
      axi4_htrans        <= axi4_target_htrans;
      axi4_hburst        <= axi4_target_hburst;
      axi4_target_hready <= axi4_hready;
      axi4_target_hrdata <= axi4_hrdata;
      axi4_req_hready    <= '0';
      axi4_req_hrdata    <= (others => 'X');
      axi4_res_hready    <= '0';
      axi4_res_hrdata    <= (others => 'X');
    elsif (axi4_arb = axi4_arb_res) then
      axi4_haddr         <= axi4_res_haddr;
      axi4_hwdata        <= axi4_res_hwdata;
      axi4_hmastlock     <= axi4_res_hmastlock;
      axi4_hsel          <= axi4_res_hsel;
      axi4_hprot         <= axi4_res_hprot;
      axi4_hwrite        <= axi4_res_hwrite;
      axi4_htrans        <= axi4_res_htrans;
      axi4_hburst        <= axi4_res_hburst;
      axi4_res_hready    <= axi4_hready;
      axi4_res_hrdata    <= axi4_hrdata;
      axi4_req_hready    <= '0';
      axi4_req_hrdata    <= (others => 'X');
      axi4_target_hready <= '0';
      axi4_target_hrdata <= (others => 'X');
    elsif (axi4_arb = axi4_arb_req) then
      axi4_haddr         <= axi4_req_haddr;
      axi4_hwdata        <= axi4_req_hwdata;
      axi4_hmastlock     <= axi4_req_hmastlock;
      axi4_hsel          <= axi4_req_hsel;
      axi4_hprot         <= axi4_req_hprot;
      axi4_hwrite        <= axi4_req_hwrite;
      axi4_htrans        <= axi4_req_htrans;
      axi4_hburst        <= axi4_req_hburst;
      axi4_req_hready    <= axi4_hready;
      axi4_req_hrdata    <= axi4_hrdata;
      axi4_res_hready    <= '0';
      axi4_res_hrdata    <= (others => 'X');
      axi4_target_hready <= '0';
      axi4_target_hrdata <= (others => 'X');
    else
      axi4_haddr         <= (others => 'X');
      axi4_hwdata        <= (others => 'X');
      axi4_hmastlock     <= '0';
      axi4_hsel          <= '0';
      axi4_hprot         <= (others => 'X');
      axi4_hwrite        <= '0';
      axi4_htrans        <= "00";
      axi4_hburst        <= "000";
      axi4_req_hready    <= '0';
      axi4_req_hrdata    <= (others => 'X');
      axi4_res_hready    <= '0';
      axi4_res_hrdata    <= (others => 'X');
      axi4_target_hready <= '0';
      axi4_target_hrdata <= (others => 'X');
    end if;
  end process;
end rtl;
