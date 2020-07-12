-- Converted from rtl/verilog/wb/mpsoc_dma_wb_interface.sv
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
-- *   Stefan Wallentowitz <stefan@wallentowitz.de>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_wb_interface is
  generic (
    ADDR_WIDTH             : integer := 64;
    DATA_WIDTH             : integer := 64;
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
end mpsoc_dma_wb_interface;

architecture RTL of mpsoc_dma_wb_interface is

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  if_write_req <= ('0' & wb_if_dat_i(DMA_REQFIELD_LADDR_WIDTH-1 downto 0) &
                   wb_if_dat_i(DMA_REQFIELD_SIZE_WIDTH-1 downto 0) &
                   wb_if_dat_i(DMA_REQFIELD_RTILE_WIDTH-1 downto 0) &
                   wb_if_dat_i(DMA_REQFIELD_RADDR_WIDTH-1 downto 0) & wb_if_dat_i(0));

  if_write_pos <= wb_if_addr_i(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_write_en  <= wb_if_cyc_i and wb_if_stb_i and wb_if_we_i;

  if_valid_pos  <= wb_if_addr_i(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_valid_en   <= wb_if_cyc_i and wb_if_stb_i and to_stdlogic(wb_if_addr_i(4 downto 0) = "10100") and wb_if_we_i;
  if_validrd_en <= wb_if_cyc_i and wb_if_stb_i and to_stdlogic(wb_if_addr_i(4 downto 0) = "10100") and not wb_if_we_i;
  if_valid_set  <= wb_if_we_i or (not wb_if_we_i and not done(to_integer(unsigned(wb_if_addr_i(TABLE_ENTRIES_PTRWIDTH+4 downto 5)))));

  wb_if_ack_o <= wb_if_cyc_i and wb_if_stb_i;

  processing_0 : process (done, wb_if_addr_i)
  begin
    if (wb_if_addr_i(4 downto 0) = "10100") then
      wb_if_dat_o <= ((DATA_WIDTH-1 downto 0 => '0') & done(to_integer(unsigned(wb_if_addr_i(TABLE_ENTRIES_PTRWIDTH+4 downto 5)))));
    end if;
  end process;

  -- This assumes, that mask and address match
  generating_0 : for i in 0 to DMA_REQMASK_WIDTH - 1 generate
    if_write_select(i) <= to_stdlogic(unsigned(wb_if_addr_i(4 downto 2)) = to_unsigned(i, 3));
  end generate;
end RTL;
