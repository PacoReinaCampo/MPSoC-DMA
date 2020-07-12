-- Converted from rtl/verilog/core/mpsoc_dma_initiator_nocreq.sv
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
use ieee.math_real.all;

use work.mpsoc_dma_pkg.all;

entity mpsoc_dma_initiator_nocreq is
  generic (
    ADDR_WIDTH             : integer := 64;
    DATA_WIDTH             : integer := 64;
    TABLE_ENTRIES          : integer := 4;
    TABLE_ENTRIES_PTRWIDTH : integer := integer(log2(real(4)));
    TILEID                 : integer := 0;
    NOC_PACKET_SIZE        : integer := 16
    );
  port (
    -- flits per packet
    clk : in std_logic;
    rst : in std_logic;

    -- NOC-Interface
    noc_out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
    noc_out_valid : out std_logic;
    noc_out_ready : in  std_logic;

    -- Control read (request) interface
    ctrl_read_pos : out std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_read_req : in  std_logic_vector(DMA_REQUEST_WIDTH-1 downto 0);

    valid : in std_logic_vector(TABLE_ENTRIES-1 downto 0);

    -- Feedback from response path
    ctrl_done_pos : in std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);
    ctrl_done_en  : in std_logic;


    -- Interface to wishbone request
    req_start      : out std_logic;
    req_laddr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    req_data_valid : in  std_logic;
    req_data_ready : out std_logic;
    req_data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    req_is_l2r     : out std_logic;
    req_size       : out std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0)
    );
end mpsoc_dma_initiator_nocreq;

architecture RTL of mpsoc_dma_initiator_nocreq is
  component arb_rr
    generic (
      N : integer := 2
      );
    port (
      req     : in  std_logic_vector(N-1 downto 0);
      en      : in  std_logic;
      gnt     : in  std_logic_vector(N-1 downto 0);
      nxt_gnt : out std_logic_vector(N-1 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  --  NOC request
  constant NOC_REQ_WIDTH        : integer                      := 4;
  constant NOC_REQ_IDLE         : std_logic_vector(3 downto 0) := "0000";
  constant NOC_REQ_L2R_GENHDR   : std_logic_vector(3 downto 0) := "0001";
  constant NOC_REQ_L2R_GENADDR  : std_logic_vector(3 downto 0) := "0010";
  constant NOC_REQ_L2R_DATA     : std_logic_vector(3 downto 0) := "0011";
  constant NOC_REQ_L2R_WAITDATA : std_logic_vector(3 downto 0) := "0100";
  constant NOC_REQ_R2L_GENHDR   : std_logic_vector(3 downto 0) := "0101";
  constant NOC_REQ_R2L_GENSIZE  : std_logic_vector(3 downto 0) := "1000";

  constant NOC_REQ_R2L_GENRADDR : std_logic_vector(3 downto 0) := "0110";
  constant NOC_REQ_R2L_GENLADDR : std_logic_vector(3 downto 0) := "0111";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- State logic
  signal noc_req_state     : std_logic_vector(NOC_REQ_WIDTH-1 downto 0);
  signal nxt_noc_req_state : std_logic_vector(NOC_REQ_WIDTH-1 downto 0);

  -- Counter for payload flits/words in request
  signal noc_req_counter     : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-1 downto 0);
  signal nxt_noc_req_counter : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-1 downto 0);

  -- Current packet payload flit/word counter
  signal noc_req_packet_count     : std_logic_vector(4 downto 0);
  signal nxt_noc_req_packet_count : std_logic_vector(4 downto 0);

  -- Current packet total number of flits/words
  signal noc_req_packet_size     : std_logic_vector(4 downto 0);
  signal nxt_noc_req_packet_size : std_logic_vector(4 downto 0);

  --Table entry selection logic

  --The request table signals all open requests on the 'valid' bit vector.
  --The selection logic arbitrates among those entries to determine the
  --request to be handled next.

  --The arbitration is not done for all entries marked as valid but only
  --for those, that are additionally not marked in the open_responses
  --bit vector.

  --The selection signals only change after a transfer is started.

  -- Selects the next entry from the table
  signal ini_select : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- current grant of arbiter
  signal nxt_select : std_logic_vector(TABLE_ENTRIES-1 downto 0);  -- next grant of arbiter

  -- Store open responses: table entry valid is not sufficient, as
  -- current requests would be selected
  signal open_responses     : std_logic_vector(TABLE_ENTRIES-1 downto 0);
  signal nxt_open_responses : std_logic_vector(TABLE_ENTRIES-1 downto 0);

  signal requests : std_logic_vector(TABLE_ENTRIES-1 downto 0);

  signal nxt_req_start : std_logic;

  signal req_rtile : std_logic_vector(DMA_REQFIELD_RTILE_WIDTH-1 downto 0);
  signal req_raddr : std_logic_vector(ADDR_WIDTH-1 downto 0);

  signal ctrl_read_pos_sgn : std_logic_vector(TABLE_ENTRIES_PTRWIDTH-1 downto 0);

  signal noc_sgn_valid : std_logic;

  signal req_size_sgn : std_logic_vector(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);

  signal req_start_sgn : std_logic;

  --//////////////////////////////////////////////////////////////
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

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  requests <= valid and not open_responses and (TABLE_ENTRIES-1 downto 0 => to_stdlogic(noc_req_state = NOC_REQ_IDLE));

  -- Round Robin (rr) arbiter
  arbiter_rr : arb_rr
    generic map (
      N => TABLE_ENTRIES
      )
    port map (
      -- Outputs
      nxt_gnt => nxt_select,

      -- Inputs
      req => requests, 
      en  => '1'
      gnt => ini_select
      );

  -- register next select to initial select
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        ini_select <= (others => '0');
      else
        ini_select <= nxt_select;
      end if;
    end if;
  end process;

  -- Convert (one hot) select bit vector to binary
  processing_1 : process (ctrl_read_pos_sgn, ini_select)
  begin
    ctrl_read_pos_sgn <= (others => '0');
    for d in 0 to TABLE_ENTRIES - 1 loop
      if (ini_select(d) = '1') then
        ctrl_read_pos_sgn <= ctrl_read_pos_sgn or std_logic_vector(to_unsigned(d, TABLE_ENTRIES_PTRWIDTH));
      end if;
    end loop;
  end process;

  ctrl_read_pos <= ctrl_read_pos_sgn;

  -- Request generation
  -- This is a pulse that signals the start of a request to the wishbone and noc
  -- part of the request generation.
  -- start when any is valid and not already in progress
  -- and we are not currently generating a request (pulse)
  nxt_req_start <= (reduce_or(valid and not open_responses)) and to_stdlogic(noc_req_state = NOC_REQ_IDLE);

  -- Convenience wires
  req_is_l2r   <= to_stdlogic(ctrl_read_req(DMA_REQFIELD_DIR) = DMA_REQUEST_L2R);
  req_laddr    <= ctrl_read_req(ADDR_WIDTH-1 downto 0);
  req_size_sgn <= ctrl_read_req(DMA_REQFIELD_SIZE_WIDTH-3 downto 0);
  req_rtile    <= ctrl_read_req(DMA_REQFIELD_RTILE_MSB downto DMA_REQFIELD_RTILE_LSB);
  req_raddr    <= ctrl_read_req(DMA_REQFIELD_RADDR_MSB downto DMA_REQFIELD_RADDR_LSB);

  ----req_laddr    <= ctrl_read_req(DMA_REQFIELD_LADDR_MSB downto DMA_REQFIELD_LADDR_LSB);
  ----req_size_sgn <= ctrl_read_req(DMA_REQFIELD_SIZE_MSB-2 downto DMA_REQFIELD_SIZE_LSB);

  req_size <= req_size_sgn;

  -- NoC side request generation

  -- next state logic, counters, control signals
  processing_2 : process (noc_req_state)
  begin
    -- Default is not generating flits
    noc_sgn_valid <= '0';
    noc_out_flit  <= (others => '0');

    -- Only pop when successfull transfer
    req_data_ready <= '0';

    -- Counters stay old value
    nxt_noc_req_counter      <= noc_req_counter;
    nxt_noc_req_packet_count <= noc_req_packet_count;
    nxt_noc_req_packet_size  <= noc_req_packet_size;

    -- Open response only changes when request generated
    nxt_open_responses <= open_responses;

    case (noc_req_state) is
      when NOC_REQ_IDLE =>
        -- Idle'ing
        if (req_start_sgn = '1') then
          -- A valid request exists, that is not open
          if (ctrl_read_req(DMA_REQFIELD_DIR) = DMA_REQUEST_L2R) then
            -- L2R
            nxt_noc_req_state <= NOC_REQ_L2R_GENHDR;
          else                          -- R2L
            nxt_noc_req_state <= NOC_REQ_R2L_GENHDR;
          end if;
        else                            -- wait for request
          nxt_noc_req_state <= NOC_REQ_IDLE;
        end if;
        -- Reset counter
        nxt_noc_req_counter <= (others => '0');
      when NOC_REQ_L2R_GENHDR =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_HEADER;
        noc_out_flit(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= req_rtile;
        noc_out_flit(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit(PACKET_ID_MSB downto PACKET_ID_LSB)       <= ctrl_read_pos_sgn;
        noc_out_flit(SOURCE_MSB downto SOURCE_LSB)             <= std_logic_vector(to_unsigned(TILEID, SOURCE_MSB-SOURCE_LSB+1));
        noc_out_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= PACKET_TYPE_L2R_REQ;
        if ((unsigned(noc_req_counter)+to_unsigned(NOC_PACKET_SIZE-2, DMA_REQFIELD_SIZE_WIDTH)) < unsigned(req_size_sgn)) then
          -- This is not the last packet in the request (NOC_PACKET_SIZE-2)
          noc_out_flit(SIZE_MSB downto SIZE_LSB) <= std_logic_vector(to_unsigned(NOC_PACKET_SIZE-2, SIZE_MSB-SIZE_LSB+1));
          noc_out_flit(PACKET_REQ_LAST)          <= '0';
          nxt_noc_req_packet_size                <= std_logic_vector(to_unsigned(NOC_PACKET_SIZE-2, 5));
          -- count is the current transfer number
          nxt_noc_req_packet_count               <= std_logic_vector(to_unsigned(1, 5));
        else    -- This is the last packet in the request
          noc_out_flit(SIZE_MSB downto SIZE_LSB) <= std_logic_vector(unsigned(req_size_sgn)-unsigned(noc_req_counter));
          noc_out_flit(PACKET_REQ_LAST)          <= '1';
          nxt_noc_req_packet_size                <= std_logic_vector(unsigned(req_size_sgn(4 downto 0))-unsigned(noc_req_counter(4 downto 0)));
          -- count is the current transfer number
          nxt_noc_req_packet_count               <= std_logic_vector(to_unsigned(1, 5));
        end if;
        -- else: !if((noc_req_counter + (NOC_PACKET_SIZE-2)) < req_size_sgn)
        -- change to next state if successful
        if (noc_out_ready = '1') then
          nxt_noc_req_state <= NOC_REQ_L2R_GENADDR;
        else
          nxt_noc_req_state <= NOC_REQ_L2R_GENHDR;
        end if;
      -- case: NOC_REQ_GENHDR
      when NOC_REQ_L2R_GENADDR =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_PAYLOAD;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= std_logic_vector(unsigned(req_raddr)+(unsigned(noc_req_counter) sll 2));
        if (noc_out_ready = '1') then
          nxt_noc_req_state <= NOC_REQ_L2R_DATA;
        else
          nxt_noc_req_state <= NOC_REQ_L2R_GENADDR;
        end if;
      when NOC_REQ_L2R_DATA =>
        -- transfer data to noc if available

        noc_sgn_valid <= req_data_valid;
        -- Signal last flit for this transfer
        if (noc_req_packet_count = noc_req_packet_size) then
          noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= FLIT_TYPE_LAST;
        else
          noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= FLIT_TYPE_PAYLOAD;
        end if;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= req_data;
        if (noc_out_ready = '1' and noc_sgn_valid = '1') then
          -- transfer was successful

          -- signal to data fifo
          req_data_ready <= '1';

          -- increment the counter for this packet
          nxt_noc_req_packet_count <= std_logic_vector(unsigned(noc_req_packet_count)+to_unsigned(1, 5));

          if (noc_req_packet_count = noc_req_packet_size) then
            -- This was the last flit in this packet
            if (unsigned(noc_req_packet_count)+unsigned(noc_req_counter) = unsigned(req_size_sgn)) then
              -- .. and the last flit for the request

              -- keep open_responses and "add" currently selected request to it
              nxt_open_responses <= open_responses or ini_select;
              -- back to IDLE
              nxt_noc_req_state  <= NOC_REQ_IDLE;
            else                        -- .. and other packets to transfer
              -- Start with next header
              nxt_noc_req_state   <= NOC_REQ_L2R_GENHDR;
              -- add the current counter to overall counter
              nxt_noc_req_counter <= std_logic_vector(unsigned(noc_req_counter)+unsigned(noc_req_packet_count));
            end if;
          else  -- if (noc_req_packet_count == noc_req_packet_size)
            -- we transfered a flit inside the packet
            nxt_noc_req_state <= NOC_REQ_L2R_DATA;
          end if;
        else  -- if (noc_out_ready & noc_sgn_valid)
          -- no success
          nxt_noc_req_state <= NOC_REQ_L2R_DATA;
        end if;
      -- case: NOC_REQ_L2R_DATA
      when NOC_REQ_R2L_GENHDR =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_HEADER;
        noc_out_flit(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= req_rtile;
        noc_out_flit(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit(PACKET_ID_MSB downto PACKET_ID_LSB)       <= ctrl_read_pos_sgn;
        noc_out_flit(SOURCE_MSB downto SOURCE_LSB)             <= std_logic_vector(to_unsigned(TILEID, SOURCE_MSB-SOURCE_LSB+1));
        noc_out_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= PACKET_TYPE_R2L_REQ;
        noc_out_flit(11 downto 0)                              <= (others => '0');

        -- There's only one packet needed for the request
        noc_out_flit(PACKET_REQ_LAST) <= '1';

        -- change to next state if successful
        if (noc_out_ready = '1') then
          nxt_noc_req_state <= NOC_REQ_R2L_GENSIZE;
        else
          nxt_noc_req_state <= NOC_REQ_R2L_GENHDR;
        end if;
      -- case: NOC_REQ_GENHDR
      when NOC_REQ_R2L_GENSIZE =>
        noc_sgn_valid                            <= '1';
        noc_out_flit(SIZE_MSB-2 downto SIZE_LSB) <= req_size_sgn;

        -- change to next state if successful
        if (noc_out_ready = '1') then
          nxt_noc_req_state <= NOC_REQ_R2L_GENRADDR;
        else
          nxt_noc_req_state <= NOC_REQ_R2L_GENSIZE;
        end if;
        -- case: NOC_REQ_R2L_GENSIZE

      when NOC_REQ_R2L_GENRADDR =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_PAYLOAD;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= ctrl_read_req(DMA_REQFIELD_RADDR_MSB downto DMA_REQFIELD_RADDR_LSB);
        if (noc_out_ready = '1') then
          -- keep open_responses and "add" currently selected request to it
          nxt_noc_req_state <= NOC_REQ_R2L_GENLADDR;
        else
          nxt_noc_req_state <= NOC_REQ_R2L_GENRADDR;
        end if;
      -- case: NOC_REQ_R2L_GENRADDR
      when NOC_REQ_R2L_GENLADDR =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_LAST;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= ctrl_read_req(DMA_REQFIELD_LADDR_MSB-1 downto DMA_REQFIELD_LADDR_LSB);
        if (noc_out_ready = '1') then
          -- keep open_responses and "add" currently selected request to it
          nxt_open_responses <= open_responses or ini_select;
          nxt_noc_req_state  <= NOC_REQ_IDLE;
        else
          nxt_noc_req_state <= NOC_REQ_R2L_GENLADDR;
        end if;
      -- case: NOC_REQ_R2L_GENLADDR
      when others =>
        nxt_noc_req_state <= NOC_REQ_IDLE;
    end case;
    -- case (noc_req_state)
    -- Process done information from response
    if (ctrl_done_en = '1') then
      nxt_open_responses(to_integer(unsigned(ctrl_done_pos))) <= '0';
    end if;
  end process;

  noc_out_valid <= noc_sgn_valid;

  -- sequential part of NoC interface
  processing_3 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        noc_req_state        <= NOC_REQ_IDLE;
        noc_req_counter      <= (others => '0');
        noc_req_packet_size  <= (others => '0');
        noc_req_packet_count <= (others => '0');
        open_responses       <= (others => '0');
        req_start_sgn        <= '0';
      else
        noc_req_counter      <= nxt_noc_req_counter;
        noc_req_packet_size  <= nxt_noc_req_packet_size;
        noc_req_packet_count <= nxt_noc_req_packet_count;
        noc_req_state        <= nxt_noc_req_state;
        open_responses       <= nxt_open_responses;
        req_start_sgn        <= nxt_req_start;
      end if;
    end if;
  end process;

  req_start <= req_start_sgn;
end RTL;
