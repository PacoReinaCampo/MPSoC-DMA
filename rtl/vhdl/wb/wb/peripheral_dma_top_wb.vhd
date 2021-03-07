-- Converted from rtl/verilog/wb/mpsoc_dma_wb_top.sv
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
-- *   Michael Tempelmeier <michael.tempelmeier@tum.de>
-- *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_wb_top is
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

    wb_if_addr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_if_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_if_cyc_i : in  std_logic;
    wb_if_stb_i : in  std_logic;
    wb_if_we_i  : in  std_logic;
    wb_if_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_if_ack_o : out std_logic;
    wb_if_err_o : out std_logic;
    wb_if_rty_o : out std_logic;

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
end mpsoc_dma_wb_top;

architecture RTL of mpsoc_dma_wb_top is
  component mpsoc_dma_wb_interface
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

      wb_if_addr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_if_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_if_cyc_i : in  std_logic;
      wb_if_stb_i : in  std_logic;
      wb_if_we_i  : in  std_logic;
      wb_if_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_if_ack_o : out std_logic;

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

  component mpsoc_dma_request_table
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

  component mpsoc_dma_wb_initiator
    generic (
      ADDR_WIDTH             : integer := 32;
      DATA_WIDTH             : integer := 32;
      TABLE_ENTRIES          : integer := 4;
      TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
      TILEID                 : integer := 0;
      NOC_PACKET_SIZE        : integer := 16
      );
    port (
      --parameters
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
      wb_req_ack_i : in  std_logic;
      wb_req_cyc_o : out std_logic;
      wb_req_stb_o : out std_logic;
      wb_req_we_o  : out std_logic;
      wb_req_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_req_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_req_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_req_cti_o : out std_logic_vector(2 downto 0);
      wb_req_bte_o : out std_logic_vector(1 downto 0);
      wb_req_sel_o : out std_logic_vector(3 downto 0);

      -- Wishbone interface for L2R data fetch
      wb_res_ack_i : in  std_logic;
      wb_res_cyc_o : out std_logic;
      wb_res_stb_o : out std_logic;
      wb_res_we_o  : out std_logic;
      wb_res_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_res_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_res_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_res_cti_o : out std_logic_vector(2 downto 0);
      wb_res_bte_o : out std_logic_vector(1 downto 0);
      wb_res_sel_o : out std_logic_vector(3 downto 0)
      );
  end component;

  component mpsoc_dma_wb_target
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
      wb_ack_i : in  std_logic;
      wb_cyc_o : out std_logic;
      wb_stb_o : out std_logic;
      wb_we_o  : out std_logic;
      wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_sel_o : out std_logic_vector(3 downto 0);
      wb_cti_o : out std_logic_vector(2 downto 0);
      wb_bte_o : out std_logic_vector(1 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant wb_arb_req    : std_logic_vector(1 downto 0) := "00";
  constant wb_arb_resp   : std_logic_vector(1 downto 0) := "01";
  constant wb_arb_target : std_logic_vector(1 downto 0) := "10";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal wb_req_adr_o : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_req_dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_req_cyc_o : std_logic;
  signal wb_req_stb_o : std_logic;
  signal wb_req_we_o  : std_logic;
  signal wb_req_sel_o : std_logic_vector(3 downto 0);
  signal wb_req_cti_o : std_logic_vector(2 downto 0);
  signal wb_req_bte_o : std_logic_vector(1 downto 0);
  signal wb_req_dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_req_ack_i : std_logic;

  signal wb_res_adr_o : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_res_dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_res_cyc_o : std_logic;
  signal wb_res_stb_o : std_logic;
  signal wb_res_we_o  : std_logic;
  signal wb_res_sel_o : std_logic_vector(3 downto 0);
  signal wb_res_cti_o : std_logic_vector(2 downto 0);
  signal wb_res_bte_o : std_logic_vector(1 downto 0);
  signal wb_res_dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_res_ack_i : std_logic;

  signal wb_target_adr_o : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_target_dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_target_cyc_o : std_logic;
  signal wb_target_stb_o : std_logic;
  signal wb_target_we_o  : std_logic;
  signal wb_target_cti_o : std_logic_vector(2 downto 0);
  signal wb_target_bte_o : std_logic_vector(1 downto 0);
  signal wb_target_dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_target_ack_i : std_logic;

  -- Beginning of automatic wires (for undeclared instantiated-module outputs)
  signal ctrl_done_en    : std_logic;  -- From ctrl_initiator
  signal ctrl_done_pos   : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_pos   : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From ctrl_initiator
  signal ctrl_read_req   : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From request_table
  signal done            : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal if_valid_en     : std_logic;  -- From wb interface
  signal if_valid_pos    : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From wb interface
  signal if_valid_set    : std_logic;  -- From wb interface
  signal if_validrd_en   : std_logic;  -- From wb interface
  signal if_write_en     : std_logic;  -- From wb interface
  signal if_write_pos    : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);  -- From wb interface
  signal if_write_req    : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);  -- From wb interface
  signal if_write_select : std_logic_vector(DMA_REQMASK_WIDTH-1 downto 0);  -- From wb interface
  signal valid           : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- From request_table
  signal wb_target_sel_o : std_logic_vector(3 downto 0);  -- From target
  -- End of automatics

  signal ctrl_out_read_pos : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_in_read_pos  : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
  signal ctrl_write_pos    : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  signal wb_arb     : std_logic_vector(1 downto 0);
  signal nxt_wb_arb : std_logic_vector(1 downto 0);

  signal wb_arb_active : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --
  wb_if_err_o <= '0';
  wb_if_rty_o <= '0';

  ctrl_out_read_pos <= (others => '0');
  ctrl_in_read_pos  <= (others => '0');
  ctrl_write_pos    <= (others => '0');

  wb_interface : mpsoc_dma_wb_interface
    generic map (
      TILEID => TILEID
      )
    port map (
      -- Outputs
      wb_if_dat_o     => wb_if_dat_o(DATA_WIDTH-1 downto 0),
      wb_if_ack_o     => wb_if_ack_o,
      if_write_req    => if_write_req(DMA_REQUEST_WIDTH-1 downto 0),
      if_write_pos    => if_write_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_write_select => if_write_select(DMA_REQMASK_WIDTH-1 downto 0),
      if_write_en     => if_write_en,
      if_valid_pos    => if_valid_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      if_valid_set    => if_valid_set,
      if_valid_en     => if_valid_en,
      if_validrd_en   => if_validrd_en,
      -- Inputs
      clk             => clk,
      rst             => rst,
      wb_if_addr_i     => wb_if_addr_i(ADDR_WIDTH-1 downto 0),
      wb_if_dat_i     => wb_if_dat_i(DATA_WIDTH-1 downto 0),
      wb_if_cyc_i     => wb_if_cyc_i,
      wb_if_stb_i     => wb_if_stb_i,
      wb_if_we_i      => wb_if_we_i,
      done            => done(TABLE_ENTRIES-1 downto 0)
      );

  request_table : mpsoc_dma_request_table
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

  wb_initiator : mpsoc_dma_wb_initiator
    generic map (
      TILEID => TILEID
      )
    port map (
      -- Outputs
      ctrl_read_pos => ctrl_read_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_pos => ctrl_done_pos(TABLE_ENTRIES_PTRWIDTH-1 downto 0),
      ctrl_done_en  => ctrl_done_en,
      noc_out_flit  => noc_out_req_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid => noc_out_req_valid,
      noc_in_ready  => noc_in_res_ready,
      wb_req_cyc_o  => wb_req_cyc_o,
      wb_req_stb_o  => wb_req_stb_o,
      wb_req_we_o   => wb_req_we_o,
      wb_req_dat_o  => wb_req_dat_o(DATA_WIDTH-1 downto 0),
      wb_req_adr_o  => wb_req_adr_o(ADDR_WIDTH-1 downto 0),
      wb_req_cti_o  => wb_req_cti_o(2 downto 0),
      wb_req_bte_o  => wb_req_bte_o(1 downto 0),
      wb_req_sel_o  => wb_req_sel_o(3 downto 0),
      wb_res_cyc_o  => wb_res_cyc_o,
      wb_res_stb_o  => wb_res_stb_o,
      wb_res_we_o   => wb_res_we_o,
      wb_res_dat_o  => wb_res_dat_o(DATA_WIDTH-1 downto 0),
      wb_res_adr_o  => wb_res_adr_o(ADDR_WIDTH-1 downto 0),
      wb_res_cti_o  => wb_res_cti_o(2 downto 0),
      wb_res_bte_o  => wb_res_bte_o(1 downto 0),
      wb_res_sel_o  => wb_res_sel_o(3 downto 0),
      -- Inputs
      clk           => clk,
      rst           => rst,
      ctrl_read_req => ctrl_read_req(DMA_REQUEST_WIDTH-1 downto 0),
      valid         => valid(TABLE_ENTRIES-1 downto 0),
      noc_out_ready => noc_out_req_ready,
      noc_in_flit   => noc_in_res_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid  => noc_in_res_valid,
      wb_req_ack_i  => wb_req_ack_i,
      wb_req_dat_i  => wb_req_dat_i(DATA_WIDTH-1 downto 0),
      wb_res_ack_i  => wb_res_ack_i,
      wb_res_dat_i  => wb_res_dat_i(DATA_WIDTH-1 downto 0)
      );

  wb_target : mpsoc_dma_wb_target
    generic map (
      TILEID          => TILEID,
      NOC_PACKET_SIZE => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      noc_out_flit  => noc_out_res_flit(FLIT_WIDTH-1 downto 0),
      noc_out_valid => noc_out_res_valid,
      noc_in_ready  => noc_in_req_ready,
      wb_cyc_o      => wb_target_cyc_o,
      wb_stb_o      => wb_target_stb_o,
      wb_we_o       => wb_target_we_o,
      wb_dat_o      => wb_target_dat_o(DATA_WIDTH-1 downto 0),
      wb_adr_o      => wb_target_adr_o(ADDR_WIDTH-1 downto 0),
      wb_sel_o      => wb_target_sel_o(3 downto 0),
      wb_cti_o      => wb_target_cti_o(2 downto 0),
      wb_bte_o      => wb_target_bte_o(1 downto 0),
      -- Inputs
      clk           => clk,
      rst           => rst,
      noc_out_ready => noc_out_res_ready,
      noc_in_flit   => noc_in_req_flit(FLIT_WIDTH-1 downto 0),
      noc_in_valid  => noc_in_req_valid,
      wb_ack_i      => wb_target_ack_i,
      wb_dat_i      => wb_target_dat_i(DATA_WIDTH-1 downto 0)
      );

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        wb_arb <= wb_arb_target;
      else
        wb_arb <= nxt_wb_arb;
      end if;
    end if;
  end process;

  wb_arb_active <= (to_stdlogic(wb_arb = wb_arb_req) and wb_req_cyc_o) or
                   (to_stdlogic(wb_arb = wb_arb_resp) and wb_res_cyc_o) or
                   (to_stdlogic(wb_arb = wb_arb_target) and wb_target_cyc_o);

  processing_1 : process (wb_arb_active)
  begin
    if (wb_arb_active = '1') then
      nxt_wb_arb <= wb_arb;
    elsif (wb_target_cyc_o = '1') then
      nxt_wb_arb <= wb_arb_target;
    elsif (wb_res_cyc_o = '1') then
      nxt_wb_arb <= wb_arb_resp;
    elsif (wb_req_cyc_o = '1') then
      nxt_wb_arb <= wb_arb_req;
    else
      nxt_wb_arb <= wb_arb_target;
    end if;
  end process;

  wb_cab_o <= '0';

  processing_2 : process (wb_arb)
  begin
    if (wb_arb = wb_arb_target) then
      wb_adr_o        <= wb_target_adr_o;
      wb_dat_o        <= wb_target_dat_o;
      wb_cyc_o        <= wb_target_cyc_o;
      wb_stb_o        <= wb_target_stb_o;
      wb_sel_o        <= wb_target_sel_o;
      wb_we_o         <= wb_target_we_o;
      wb_bte_o        <= wb_target_bte_o;
      wb_cti_o        <= wb_target_cti_o;
      wb_target_ack_i <= wb_ack_i;
      wb_target_dat_i <= wb_dat_i;
      wb_req_ack_i    <= '0';
      wb_req_dat_i    <= (others => 'X');
      wb_res_ack_i    <= '0';
      wb_res_dat_i    <= (others => 'X');
    elsif (wb_arb = wb_arb_resp) then
      wb_adr_o        <= wb_res_adr_o;
      wb_dat_o        <= wb_res_dat_o;
      wb_cyc_o        <= wb_res_cyc_o;
      wb_stb_o        <= wb_res_stb_o;
      wb_sel_o        <= wb_res_sel_o;
      wb_we_o         <= wb_res_we_o;
      wb_bte_o        <= wb_res_bte_o;
      wb_cti_o        <= wb_res_cti_o;
      wb_res_ack_i    <= wb_ack_i;
      wb_res_dat_i    <= wb_dat_i;
      wb_req_ack_i    <= '0';
      wb_req_dat_i    <= (others => 'X');
      wb_target_ack_i <= '0';
      wb_target_dat_i <= (others => 'X');
    elsif (wb_arb = wb_arb_req) then
      wb_adr_o        <= wb_req_adr_o;
      wb_dat_o        <= wb_req_dat_o;
      wb_cyc_o        <= wb_req_cyc_o;
      wb_stb_o        <= wb_req_stb_o;
      wb_sel_o        <= wb_req_sel_o;
      wb_we_o         <= wb_req_we_o;
      wb_bte_o        <= wb_req_bte_o;
      wb_cti_o        <= wb_req_cti_o;
      wb_req_ack_i    <= wb_ack_i;
      wb_req_dat_i    <= wb_dat_i;
      wb_res_ack_i    <= '0';
      wb_res_dat_i    <= (others => 'X');
      wb_target_ack_i <= '0';
      wb_target_dat_i <= (others => 'X');
    else
      wb_adr_o        <= (others => '0');
      wb_dat_o        <= (others => '0');
      wb_cyc_o        <= '0';
      wb_stb_o        <= '0';
      wb_sel_o        <= (others => '0');
      wb_we_o         <= '0';
      wb_bte_o        <= "00";
      wb_cti_o        <= "000";
      wb_req_ack_i    <= '0';
      wb_req_dat_i    <= (others => 'X');
      wb_res_ack_i    <= '0';
      wb_res_dat_i    <= (others => 'X');
      wb_target_ack_i <= '0';
      wb_target_dat_i <= (others => 'X');
    end if;
  end process;
end RTL;
