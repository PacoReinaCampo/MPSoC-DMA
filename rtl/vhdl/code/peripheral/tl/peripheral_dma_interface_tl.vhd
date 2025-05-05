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

use work.vhdl_pkg.all;
use work.peripheral_dma_pkg.all;

entity peripheral_dma_interface_tl is
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
end peripheral_dma_interface_tl;

architecture rtl of peripheral_dma_interface_tl is

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal if_valid_pos_sgn : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------
  if_write_req <= ('0' & biu_if_hrdata(DMA_REQFIELD_LADDR_WIDTH-1 downto 0) &
                   biu_if_hrdata(DMA_REQFIELD_SIZE_WIDTH-1 downto 0) &
                   biu_if_hrdata(DMA_REQFIELD_RTILE_WIDTH-1 downto 0) &
                   biu_if_hrdata(DMA_REQFIELD_RADDR_WIDTH-1 downto 0) & biu_if_hrdata(0));

  if_write_pos <= biu_if_haddr(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_write_en  <= biu_if_hmastlock and biu_if_hsel and biu_if_hwrite;

  if_valid_pos_sgn <= biu_if_haddr(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_valid_en      <= biu_if_hmastlock and biu_if_hsel and to_stdlogic(biu_if_haddr(4 downto 0) = "10100") and biu_if_hwrite;
  if_validrd_en    <= biu_if_hmastlock and biu_if_hsel and to_stdlogic(biu_if_haddr(4 downto 0) = "10100") and not biu_if_hwrite;
  if_valid_set     <= biu_if_hwrite or (not biu_if_hwrite and not done(to_integer(unsigned(if_valid_pos_sgn))));
  if_valid_pos     <= if_valid_pos_sgn;

  biu_if_hready <= biu_if_hmastlock and biu_if_hsel;

  processing_0 : process (done, if_valid_pos_sgn)
  begin
    if (biu_if_haddr(4 downto 0) = "10100") then
      biu_if_hwdata <= ((DATA_WIDTH-1 downto 0 => '0') & done(to_integer(unsigned(if_valid_pos_sgn))));
    end if;
  end process;

  -- This assumes, that mask and address match
  generating_0 : for i in 0 to DMA_REQMASK_WIDTH - 1 generate
    if_write_select(i) <= to_stdlogic(unsigned(biu_if_haddr(4 downto 2)) = to_unsigned(i, 3));
  end generate;
end rtl;
