-- Converted from mpsoc_packet_buffer.sv
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
--              Message Passing Interface                                     //
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

entity mpsoc_packet_buffer is
  generic (
    DATA_WIDTH : integer   := 32;
    FIFO_DEPTH : integer   := 16;
    FLIT_WIDTH : integer   := 34;
    SIZE_WIDTH : integer   := 5;

    READY : std_logic := '0';
    BUSY  : std_logic := '1'
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    --inputs
    in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
    in_valid : in  std_logic;
    in_ready : out std_logic;

    --outputs
    out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
    out_valid : out std_logic;
    out_ready : in  std_logic;

    out_size : out std_logic_vector(SIZE_WIDTH-1 downto 0)
  );
end mpsoc_packet_buffer;

architecture RTL of mpsoc_packet_buffer is
  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function reduce_or (
    reduce_or_in : std_logic_vector
  ) return std_logic is
    variable reduce_or_out : std_logic := '0';
  begin
    for i in reduce_or_in'range loop
      reduce_or_out := reduce_or_out or reduce_or_in(i);
    end loop;
    return reduce_or_out;
  end reduce_or;

  function to_stdlogic (
    input : boolean
    ) return std_logic is
  begin
    if input then
      return('1');
    else
      return('0');
    end if;
  end function to_stdlogic;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  constant FLIT_TYPE_LAST   : std_logic_vector(1 downto 0) := "10";
  constant FLIT_TYPE_SINGLE : std_logic_vector(1 downto 0) := "11";

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  type M_FIFO_DEPTH1_FLIT_WIDTH is array (FIFO_DEPTH downto 0) of std_logic_vector(FLIT_WIDTH-1 downto 0);

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Signals for fifo
  signal fifo_data      : M_FIFO_DEPTH1_FLIT_WIDTH;  --actual fifo
  signal fifo_write_ptr : std_logic_vector(FIFO_DEPTH downto 0);

  signal last_flits : std_logic_vector(FIFO_DEPTH downto 0);

  signal full_packet : std_logic;
  signal pop         : std_logic;
  signal push        : std_logic;

  signal in_flit_type : std_logic_vector(1 downto 0);
  signal in_is_last   : std_logic;
  signal valid_flits  : std_logic_vector(FIFO_DEPTH-1 downto 0);

  signal i     : std_logic_vector(SIZE_WIDTH-1 downto 0);
  signal s     : std_logic_vector(SIZE_WIDTH-1 downto 0);
  signal found : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  in_flit_type <= in_flit(FLIT_WIDTH-1 downto FLIT_WIDTH-2);
  in_is_last   <= to_stdlogic(in_flit_type = FLIT_TYPE_LAST) or to_stdlogic(in_flit_type = FLIT_TYPE_SINGLE);

  processing_0 : process (fifo_write_ptr, valid_flits)
  begin
    -- Set first element
    valid_flits(FIFO_DEPTH-1) <= fifo_write_ptr(FIFO_DEPTH);
    for j in FIFO_DEPTH-2 downto 0 loop
      valid_flits(j) <= fifo_write_ptr(j+1) or valid_flits(j+1);
    end loop;
  end process;

  full_packet <= reduce_or(last_flits(FIFO_DEPTH-1 downto 0) and valid_flits);

  pop  <= full_packet and out_ready;
  push <= in_valid and not fifo_write_ptr(FIFO_DEPTH);

  out_flit  <= fifo_data(0);
  out_valid <= full_packet;

  in_ready <= not fifo_write_ptr(FIFO_DEPTH);

  processing_1 : process (last_flits, found)
  begin
    s     <= std_logic_vector(to_unsigned(0, SIZE_WIDTH));
    found <= '0';

    for i in 0 to FIFO_DEPTH - 1 loop
      if (last_flits(i) = '1' and found = '0') then
        s     <= std_logic_vector(to_unsigned(i+1, SIZE_WIDTH));
        found <= '1';
      end if;
    end loop;
    out_size <= s;
  end process;

  processing_2 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        fifo_write_ptr <= std_logic_vector(to_unsigned(1, FIFO_DEPTH+1));
      elsif (push = '1' and pop = '0') then
        fifo_write_ptr <= std_logic_vector(unsigned(fifo_write_ptr) sll 1);
      elsif (push = '0' and pop = '1') then
        fifo_write_ptr <= std_logic_vector(unsigned(fifo_write_ptr) srl 1);
      end if;
    end if;
  end process;

  processing_3 : process (clk)
    variable last_k : integer;
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        last_flits <= (others => '0');
      else
        for k in 0 to FIFO_DEPTH-2 loop
          if (pop = '1') then
            if (push = '1' and fifo_write_ptr(k+1) = '1') then
              fifo_data  (k) <= in_flit;
              last_flits (k) <= in_is_last;
            else
              fifo_data  (k) <= fifo_data  (k+1);
              last_flits (k) <= last_flits (k+1);
            end if;
          elsif (push = '1' and fifo_write_ptr(k) = '1') then
            fifo_data  (k) <= in_flit;
            last_flits (k) <= in_is_last;
          end if;
          last_k := k;
        end loop;
        -- Handle last element
        if (pop = '1' and push = '1' and fifo_write_ptr(last_k+1) = '1') then
          fifo_data  (last_k) <= in_flit;
          last_flits (last_k) <= in_is_last;
        elsif (push = '1' and fifo_write_ptr(last_k) = '1') then
          fifo_data  (last_k) <= in_flit;
          last_flits (last_k) <= in_is_last;
        end if;
      end if;
    end if;
  end process;
end RTL;
