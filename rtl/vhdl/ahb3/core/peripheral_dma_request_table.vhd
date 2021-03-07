-- Converted from rtl/verilog/core/mpsoc_dma_request_table.sv
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
--              AMBA3 AHB-Lite Bus Interface                                  //
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
use ieee.math_real.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_request_table is
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
end mpsoc_dma_request_table;

architecture RTL of mpsoc_dma_request_table is
  --////////////////////////////////////////////////////////////////
  --
  -- Types
  --
  type M_TABLE_ENTRIES_DMA_REQUEST_WIDTH is array (TABLE_ENTRIES-1 downto 0) of std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- The storage of the requests ..
  signal transfer_request_table : M_TABLE_ENTRIES_DMA_REQUEST_WIDTH;

  signal transfer_valid : std_logic_vector(TABLE_ENTRIES-1 downto 0);
  signal transfer_done  : std_logic_vector(TABLE_ENTRIES-1 downto 0);

  signal if_write_mask : std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --
  if_write_mask(DMA_REQFIELD_LADDR_MSB downto DMA_REQFIELD_LADDR_LSB) <= (others => if_write_select(DMA_REQMASK_LADDR));
  if_write_mask(DMA_REQFIELD_SIZE_MSB downto DMA_REQFIELD_SIZE_LSB)   <= (others => if_write_select(DMA_REQMASK_SIZE));
  if_write_mask(DMA_REQFIELD_RTILE_MSB downto DMA_REQFIELD_RTILE_LSB) <= (others => if_write_select(DMA_REQMASK_RTILE));
  if_write_mask(DMA_REQFIELD_RADDR_MSB downto DMA_REQFIELD_RADDR_LSB) <= (others => if_write_select(DMA_REQMASK_RADDR));
  if_write_mask(DMA_REQFIELD_DIR)                                     <= if_write_select(DMA_REQMASK_DIR);

  -- Write to the request table
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        --reset
        for i in 0 to TABLE_ENTRIES - 1 loop
          transfer_valid(i) <= '0';
          transfer_done(i)  <= '0';
        end loop;
      --for
      elsif (if_write_en = '1') then
        transfer_request_table(to_integer(unsigned(if_write_pos))) <= (not if_write_mask and transfer_request_table(to_integer(unsigned(if_write_pos)))) or (if_write_mask and if_write_req);
        for i in 0 to TABLE_ENTRIES - 1 loop
          if (if_valid_en = '1' and (unsigned(if_valid_pos) = to_unsigned(i, TABLE_ENTRIES_PTRWIDTH))) then
            -- Start transfer
            transfer_valid(i) <= if_valid_set;
            transfer_done(i)  <= '0';
          elsif (if_validrd_en = '1' and (unsigned(if_valid_pos) = to_unsigned(i, TABLE_ENTRIES_PTRWIDTH)) and (transfer_done(i) = '1')) then
            -- Check transfer and was done
            transfer_done(i)  <= '0';
            transfer_valid(i) <= '0';
          elsif (ctrl_done_en = '1' and (unsigned(ctrl_done_pos) = to_unsigned(i, TABLE_ENTRIES_PTRWIDTH))) then
            -- Transfer is finished
            transfer_done(i) <= '1';
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- Read interface to the request table
  ctrl_read_req <= transfer_request_table(to_integer(unsigned(ctrl_read_pos)));

  -- Combine the valid and done bits to one signal
  generating_0 : for j in 0 to TABLE_ENTRIES - 1 generate
    valid(j) <= transfer_valid(j) and not transfer_done(j);
    done(j)  <= transfer_done(j);
  end generate;

  -- The interrupt is set when any request is valid and done
  irq <= (transfer_valid and transfer_done) and std_logic_vector(to_unsigned(1, TABLE_ENTRIES));
end RTL;
