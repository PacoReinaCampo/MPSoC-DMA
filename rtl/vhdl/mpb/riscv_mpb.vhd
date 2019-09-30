-- Converted from verilog/riscv_mpb/riscv_mpb.sv
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
--              Network on Chip Message Passing Buffer                        //
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

entity riscv_mpb is
  generic (
    PLEN       : integer := 64;
    XLEN       : integer := 64;
    CHANNELS   : integer := 2;
    SIZE       : integer := 16
  );
  port (
    --Common signals
    HRESETn : in std_ulogic;
    HCLK    : in std_ulogic;

    --NoC Interface
    noc_in_flit  : in  M_CHANNELS_PLEN;
    noc_in_last  : in  std_ulogic_vector(CHANNELS-1 downto 0);
    noc_in_valid : in  std_ulogic_vector(CHANNELS-1 downto 0);
    noc_in_ready : out std_ulogic_vector(CHANNELS-1 downto 0);

    noc_out_flit  : out M_CHANNELS_PLEN;
    noc_out_last  : out std_ulogic_vector(CHANNELS-1 downto 0);
    noc_out_valid : out std_ulogic_vector(CHANNELS-1 downto 0);
    noc_out_ready : in  std_ulogic_vector(CHANNELS-1 downto 0);

    --AHB input interface
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
    mst_HRESP     : out std_ulogic
  );
end riscv_mpb;

architecture RTL of riscv_mpb is
  component riscv_mpb_endpoint
    generic (
      PLEN : integer := 32;
      XLEN : integer := 32;
      SIZE : integer := 16
    );
    port (
      --Common signals
      HRESETn : in std_ulogic;
      HCLK    : in std_ulogic;

      --NoC Interface
      noc_in_flit  : in  std_ulogic_vector(PLEN-1 downto 0);
      noc_in_last  : in  std_ulogic;
      noc_in_valid : in  std_ulogic;
      noc_in_ready : out std_ulogic;

      noc_out_flit  : out std_ulogic_vector(PLEN-1 downto 0);
      noc_out_last  : out std_ulogic;
      noc_out_valid : out std_ulogic;
      noc_out_ready : in  std_ulogic;

      --AHB interface
      HSEL      : in  std_ulogic;
      HADDR     : in  std_ulogic_vector(PLEN-1 downto 0);
      HWDATA    : in  std_ulogic_vector(XLEN-1 downto 0);
      HRDATA    : out std_ulogic_vector(XLEN-1 downto 0);
      HWRITE    : in  std_ulogic;
      HSIZE     : in  std_ulogic_vector(2 downto 0);
      HBURST    : in  std_ulogic_vector(2 downto 0);
      HPROT     : in  std_ulogic_vector(3 downto 0);
      HTRANS    : in  std_ulogic_vector(1 downto 0);
      HMASTLOCK : in  std_ulogic;
      HREADYOUT : out std_ulogic;
      HRESP     : out std_ulogic
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  constant CHANNELS_BITS : integer := integer(log2(real(CHANNELS)));

  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function reduce_nor (
    reduce_nor_in : std_ulogic_vector
  ) return std_ulogic is
    variable reduce_nor_out : std_ulogic := '0';
  begin
    for i in reduce_nor_in'range loop
      reduce_nor_out := reduce_nor_out nor reduce_nor_in(i);
    end loop;
    return reduce_nor_out;
  end reduce_nor;

  function reduce_or (
    reduce_or_in : std_ulogic_vector
  ) return std_ulogic is
    variable reduce_or_out : std_ulogic := '0';
  begin
    for i in reduce_or_in'range loop
      reduce_or_out := reduce_or_out or reduce_or_in(i);
    end loop;
    return reduce_or_out;
  end reduce_or;

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

  function onehot2int (
    onehot : std_ulogic_vector(CHANNELS-1 downto 0)
  ) return integer is
    variable onehot2int_return : integer := -1;

    variable onehot_return : std_ulogic_vector(CHANNELS-1 downto 0) := onehot;
  begin
    while (reduce_or(onehot) = '1') loop
      onehot2int_return := onehot2int_return + 1;
      onehot_return     := std_ulogic_vector(unsigned(onehot_return) srl 1);
    end loop;
    return onehot2int_return;
  end onehot2int;  --onehot2int

  function highest_requested_priority (
    hsel : std_ulogic_vector(CHANNELS-1 downto 0)
  ) return std_ulogic_vector is
    variable priorities : M_CHANNELS_2;
    variable highest_requested_priority_return : std_ulogic_vector (2 downto 0);
  begin
    highest_requested_priority_return := (others => '0');
    for n in 0 to CHANNELS - 1 loop
      if (hsel(n) = '1' and unsigned(priorities(n)) > unsigned(highest_requested_priority_return)) then
        highest_requested_priority_return := priorities(n);
      end if;
    end loop;
    return highest_requested_priority_return;
  end highest_requested_priority;  --highest_requested_priority

  function requesters (
    hsel            : std_ulogic_vector(CHANNELS-1 downto 0);
    priority_select : std_ulogic_vector(2 downto 0)
  ) return std_ulogic_vector is
    variable priorities        : M_CHANNELS_2;
    variable requesters_return : std_ulogic_vector (CHANNELS-1 downto 0);
  begin
    for n in 0 to CHANNELS - 1 loop
      requesters_return(n) := to_stdlogic(priorities(n) = priority_select) and hsel(n);
    end loop;
    return requesters_return;
  end requesters;  --requesters

  function nxt_master (
    pending_masters : std_ulogic_vector(CHANNELS-1 downto 0);  --pending masters for the requesed priority level
    last_master     : std_ulogic_vector(CHANNELS-1 downto 0);  --last granted master for the priority level
    current_master  : std_ulogic_vector(CHANNELS-1 downto 0)  --current granted master (indpendent of priority level)
  ) return std_ulogic_vector is
    variable offset            : integer;
    variable sr                : std_ulogic_vector(CHANNELS*2-1 downto 0);
    variable nxt_master_return : std_ulogic_vector (CHANNELS-1 downto 0);
  begin
    --default value, don't switch if not needed
    nxt_master_return := current_master;

    --implement round-robin
    offset := onehot2int(last_master)+1;

    sr := (pending_masters & pending_masters);
    for n in 0 to CHANNELS - 1 loop
      if (sr(n+offset) = '1') then
        return std_ulogic_vector(to_unsigned(2**((n+offset) mod CHANNELS), CHANNELS));
      end if;
    end loop;
    return nxt_master_return;
  end nxt_master;

  --//////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  --AHB interface
  signal bus_HSEL      : std_ulogic_vector(CHANNELS-1 downto 0);
  signal bus_HADDR     : M_CHANNELS_PLEN;
  signal bus_HWDATA    : M_CHANNELS_XLEN;
  signal bus_HRDATA    : M_CHANNELS_XLEN;
  signal bus_HWRITE    : std_ulogic_vector(CHANNELS-1 downto 0);
  signal bus_HSIZE     : M_CHANNELS_2;
  signal bus_HBURST    : M_CHANNELS_2;
  signal bus_HPROT     : M_CHANNELS_3;
  signal bus_HTRANS    : M_CHANNELS_1;
  signal bus_HMASTLOCK : std_ulogic_vector(CHANNELS-1 downto 0);
  signal bus_HREADYOUT : std_ulogic_vector(CHANNELS-1 downto 0);
  signal bus_HRESP     : std_ulogic_vector(CHANNELS-1 downto 0);

  signal requested_priority_lvl : std_ulogic_vector(2 downto 0);  --requested priority level
  signal priority_masters       : std_ulogic_vector(CHANNELS-1 downto 0);  --all masters at this priority level

  signal pending_master      : std_ulogic_vector(CHANNELS-1 downto 0);  --next master waiting to be served
  signal last_granted_master : std_ulogic_vector(CHANNELS-1 downto 0);  --for requested priority level

  signal last_granted_masters : M_2_CHANNELS;  --per priority level, for round-robin

  signal granted_master_idx : std_ulogic_vector(CHANNELS_BITS-1 downto 0);  --granted master as index

  signal granted_master : std_ulogic_vector(CHANNELS-1 downto 0);

begin
  --//////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --get highest priority from selected masters
  requested_priority_lvl <= highest_requested_priority(bus_HSEL);

  --get pending masters for the highest priority requested
  priority_masters <= requesters(bus_HSEL, requested_priority_lvl);

  --get last granted master for the priority requested
  last_granted_master <= last_granted_masters(to_integer(unsigned(requested_priority_lvl)));

  --get next master to serve
  pending_master <= nxt_master(priority_masters, last_granted_master, granted_master);

  --select new master
  processing_0 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      granted_master <= X"1";
    elsif (rising_edge(HCLK)) then
      if (mst_HSEL = '0') then
        granted_master <= pending_master;
      end if;
    end if;
  end process;

  --store current master (for this priority level)
  processing_1 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      last_granted_masters(to_integer(unsigned(requested_priority_lvl))) <= (0 => '1', others => '0');
    elsif (rising_edge(HCLK)) then
      if (mst_HSEL = '0') then
        last_granted_masters(to_integer(unsigned(requested_priority_lvl))) <= pending_master;
      end if;
    end if;
  end process;

  --get signals from current requester
  processing_2 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      granted_master_idx <= X"0";
    elsif (rising_edge(HCLK)) then
      if (mst_HSEL = '0') then
        granted_master_idx <= std_ulogic_vector(to_unsigned(onehot2int(pending_master), CHANNELS_BITS));
      end if;
    end if;
  end process;

  generating_0 : for c in 0 to CHANNELS - 1 generate
    bus_HSEL(c)      <= mst_HSEL;
    bus_HADDR(c)     <= mst_HADDR;
    bus_HWDATA(c)    <= mst_HWDATA;
    bus_HWRITE(c)    <= mst_HWRITE;
    bus_HSIZE(c)     <= mst_HSIZE;
    bus_HBURST(c)    <= mst_HBURST;
    bus_HPROT(c)     <= mst_HPROT;
    bus_HTRANS(c)    <= mst_HTRANS;
    bus_HMASTLOCK(c) <= mst_HMASTLOCK;
  end generate;


  mst_HRDATA    <= bus_HRDATA(to_integer(unsigned(granted_master_idx)));
  mst_HREADYOUT <= bus_HREADYOUT(to_integer(unsigned(granted_master_idx)));
  mst_HRESP     <= bus_HRESP(to_integer(unsigned(granted_master_idx)));

  generating_1 : for c in 0 to CHANNELS - 1 generate
    mpb_endpoint : riscv_mpb_endpoint
      generic map (
        PLEN => PLEN,
        XLEN => XLEN,
        SIZE       => SIZE
      )
      port map (
        --Common signals
        HRESETn => HRESETn,
        HCLK    => HCLK,

        --NoC Interface
        noc_in_flit  => noc_in_flit(c),
        noc_in_last  => noc_in_last(c),
        noc_in_valid => noc_in_valid(c),
        noc_in_ready => noc_in_ready(c),

        noc_out_flit  => noc_out_flit(c),
        noc_out_last  => noc_out_last(c),
        noc_out_valid => noc_out_valid(c),
        noc_out_ready => noc_out_ready(c),

        --AHB master interface
        HSEL      => bus_HSEL(c),
        HADDR     => bus_HADDR(c),
        HWDATA    => bus_HWDATA(c),
        HRDATA    => bus_HRDATA(c),
        HWRITE    => bus_HWRITE(c),
        HSIZE     => bus_HSIZE(c),
        HBURST    => bus_HBURST(c),
        HPROT     => bus_HPROT(c),
        HTRANS    => bus_HTRANS(c),
        HMASTLOCK => bus_HMASTLOCK(c),
        HREADYOUT => bus_HREADYOUT(c),
        HRESP     => bus_HRESP(c)
      );
  end generate;
end RTL;
