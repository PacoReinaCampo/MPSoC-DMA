-- Converted from rtl/verilog/modules/riscv_dma_interface.sv
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

entity riscv_dma_interface is
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
end riscv_dma_interface;

architecture RTL of riscv_dma_interface is
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

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  if_write_req <= (if_HWDATA(DMA_REQFIELD_LADDR_WIDTH-1 downto 0) &
                   if_HWDATA(DMA_REQFIELD_SIZE_WIDTH-1 downto 0)  &
                   if_HWDATA(DMA_REQFIELD_RTILE_WIDTH-1 downto 0) &
                   if_HWDATA(DMA_REQFIELD_RADDR_WIDTH-1 downto 0) & if_HWDATA(0) & '0');

  if_write_pos <= if_HADDR(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_write_en  <= if_HMASTLOCK and if_HSEL and if_HWRITE;

  if_valid_pos  <= if_HADDR(TABLE_ENTRIES_PTRWIDTH+4 downto 5);  -- ptrwidth MUST be <= 7 (=128 entries)
  if_valid_en   <= if_HMASTLOCK and if_HSEL and to_stdlogic(if_HADDR(4 downto 0) = "10100") and if_HWRITE;
  if_validrd_en <= if_HMASTLOCK and if_HSEL and to_stdlogic(if_HADDR(4 downto 0) = "10100") and not if_HWRITE;
  if_valid_set  <= if_HWRITE or (not if_HWRITE and not done(to_integer(unsigned(if_HADDR(TABLE_ENTRIES_PTRWIDTH+4 downto 5)))));

  if_HREADYOUT <= if_HMASTLOCK and if_HSEL;

  processing_0 : process (done, if_HADDR)
  begin
    if (if_HADDR(4 downto 0) = "10100") then
      if_HRDATA <= ((XLEN-1 downto 1 => '0') & done(to_integer(unsigned(if_HADDR(TABLE_ENTRIES_PTRWIDTH+4 downto 5)))));
    end if;
  end process;

  -- This assumes, that mask and address match
  generating_0 : for i in 0 to DMA_REQMASK_WIDTH - 1 generate
    if_write_select(i) <= to_stdlogic(unsigned(if_HADDR(4 downto 2)) = to_unsigned(i, 3));
  end generate;
  
  if_HRESP <= '0';
end RTL;
