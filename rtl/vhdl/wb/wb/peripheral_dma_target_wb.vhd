-- Converted from rtl/verilog/wb/mpsoc_dma_wb_target.sv
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

entity mpsoc_dma_wb_target is
  generic (
    ADDR_WIDTH  : integer := 64;
    DATA_WIDTH  : integer := 64;
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
end mpsoc_dma_wb_target;

architecture RTL of mpsoc_dma_wb_target is
  component mpsoc_dma_packet_buffer
    generic (
      DATA_WIDTH : integer   := 32;
      FLIT_WIDTH : integer   := 34;
      FIFO_DEPTH : integer   := 16;
      SIZE_WIDTH : integer   := integer(log2(real(17)));
      READY      : std_logic := '0';
      BUSY       : std_logic := '1'
      );
    port (
      --inputs
      clk : in std_logic;
      rst : in std_logic;

      in_flit  : in  std_logic_vector(FLIT_WIDTH-1 downto 0);
      in_valid : in  std_logic;
      in_ready : out std_logic;

      out_flit  : out std_logic_vector(FLIT_WIDTH-1 downto 0);
      out_valid : out std_logic;
      out_ready : in  std_logic;

      out_size : out std_logic_vector(SIZE_WIDTH-1 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Types
  --
  type M_2_DATA_WIDTH is array (2 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- There is a buffer between the NoC input and the wishbone
  -- handling by the state machine. Those are the connection signals
  -- from buffer to wishbone
  signal buf_flit  : std_logic_vector(FLIT_WIDTH-1 downto 0);
  signal buf_valid : std_logic;
  signal buf_ready : std_logic;

  -- One FSM that handles the flow from the input
  -- buffer to the wishbone interface

  -- FSM state
  signal state     : std_logic_vector(3 downto 0);
  signal nxt_state : std_logic_vector(STATE_WIDTH-1 downto 0);

  --FSM hidden state
  signal wb_waiting     : std_logic;
  signal nxt_wb_waiting : std_logic;

  -- Store request parameters: address, last packet and source
  signal src_address        : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal nxt_src_address    : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal address            : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal nxt_address        : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal end_of_request     : std_logic;
  signal nxt_end_of_request : std_logic;
  signal src_tile           : std_logic_vector(SOURCE_WIDTH-1 downto 0);
  signal nxt_src_tile       : std_logic_vector(SOURCE_WIDTH-1 downto 0);
  signal packet_id          : std_logic_vector(PACKET_ID_WIDTH-1 downto 0);
  signal nxt_packet_id      : std_logic_vector(PACKET_ID_WIDTH-1 downto 0);

  -- Counter for flits/words in request
  signal noc_resp_wcounter     : std_logic_vector(SIZE_WIDTH-1 downto 0);
  signal nxt_noc_resp_wcounter : std_logic_vector(SIZE_WIDTH-1 downto 0);

  -- Current packet flit/word counter
  signal noc_resp_packet_wcount     : std_logic_vector(4 downto 0);
  signal nxt_noc_resp_packet_wcount : std_logic_vector(4 downto 0);

  -- Current packet total number of flits/words
  signal noc_resp_packet_wsize     : std_logic_vector(4 downto 0);
  signal nxt_noc_resp_packet_wsize : std_logic_vector(4 downto 0);

  -- TODO: correct define!
  signal resp_wsize        : std_logic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);
  signal nxt_resp_wsize    : std_logic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);
  signal wb_resp_count     : std_logic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);
  signal nxt_wb_resp_count : std_logic_vector(DMA_RESPFIELD_SIZE_WIDTH-3 downto 0);

  --FIFO-Stuff

  signal data_fifo_valid : std_logic;
  signal data_fifo       : M_2_DATA_WIDTH;  -- data storage
  signal data_fifo_pop   : std_logic;       -- NOC pushes
  signal data_fifo_push  : std_logic;       -- WB pops

  signal data_fifo_out : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Current first element
  signal data_fifo_in  : std_logic_vector(DATA_WIDTH-1 downto 0);  -- Push element
  -- Shift register for current position (4th bit is full mark)
  signal data_fifo_pos : std_logic_vector(3 downto 0);

  signal data_fifo_empty : std_logic;   -- FIFO empty
  signal data_fifo_ready : std_logic;   -- FIFO accepts new elements

  signal buf_last_flit : std_logic;

  signal noc_sgn_valid : std_logic;

  --//////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function reduce_nor (
    reduce_nor_in : std_logic_vector
  ) return std_logic is
    variable reduce_nor_out : std_logic := '0';
  begin
    for i in reduce_nor_in'range loop
      reduce_nor_out := reduce_nor_out nor reduce_nor_in(i);
    end loop;
    return reduce_nor_out;
  end reduce_nor;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Input buffer that stores flits until we have one complete packet
  packet_buffer : mpsoc_dma_packet_buffer
    generic map (
      FIFO_DEPTH => NOC_PACKET_SIZE
      )
    port map (
      -- Outputs
      in_ready  => noc_in_ready,                        -- Templated
      out_flit  => buf_flit(FLIT_WIDTH-1 downto 0),     -- Templated
      out_valid => buf_valid,                           -- Templated
      out_size  => open,
      -- Templated
      -- Inputs
      clk       => clk,
      rst       => rst,
      in_flit   => noc_in_flit(FLIT_WIDTH-1 downto 0),  -- Templated
      in_valid  => noc_in_valid,                        -- Templated
      out_ready => buf_ready                            -- Templated
      );

  -- Is this the last flit of a packet?
  buf_last_flit <= to_stdlogic(buf_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) = FLIT_TYPE_LAST) or
                   to_stdlogic(buf_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) = FLIT_TYPE_SINGLE);

  -- The intermediate store a FIFO of three elements
  --
  -- There should be no combinatorial path from input to output, so
  -- that it takes one cycle before the wishbone interface knows
  -- about back pressure from the NoC. Additionally, the wishbone
  -- interface needs one extra cycle for burst termination. The data
  -- should be stored and not discarded. Finally, there is one
  -- element in the FIFO that is the normal timing decoupling.

  -- Connect the fifo signals to the ports
  -- assign data_fifo_pop = resp_data_ready;
  data_fifo_valid <= not data_fifo_empty;
  data_fifo_empty <= data_fifo_pos(0);  -- Empty when pushing to first one
  data_fifo_ready <= reduce_nor(data_fifo_pos(3 downto 2));  --equal to not full
  data_fifo_in    <= wb_dat_i;
  data_fifo_out   <= data_fifo(0);      -- First element is out

  -- FIFO position pointer logic
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        data_fifo_pos <= "0001";
      elsif (data_fifo_push = '1' and data_fifo_pop = '0') then
        -- push and no pop
        data_fifo_pos <= std_logic_vector(unsigned(data_fifo_pos) sll 1);
      elsif (data_fifo_push = '0' and data_fifo_pop = '1') then
        -- pop and no push
        data_fifo_pos <= std_logic_vector(unsigned(data_fifo_pos) srl 1);
      else                              -- * no push or pop or
        -- * both push and pop
        data_fifo_pos <= data_fifo_pos;
      end if;
    end if;
  end process;

  -- FIFO data shifting logic
  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      -- Iterate all fifo elements, starting from lowest
      for i in 0 to 3 - 1 loop
        if (data_fifo_pop = '1') then
          -- when popping data..
          if (data_fifo_push = '1' and data_fifo_pos(i+1) = '1') then
            -- .. and we also push this cycle, we need to check
            -- whether the pointer was on the next one
            data_fifo(i) <= data_fifo_in;
          elsif (i < 2) then
            -- .. otherwise shift if not last
            data_fifo(i) <= data_fifo(i+1);
          else                          -- the last stays static
            data_fifo(i) <= data_fifo(i);
          end if;
        elsif (data_fifo_push = '1' and data_fifo_pos(i) = '1') then
          -- when pushing only and this is the current write
          -- position
          data_fifo(i) <= data_fifo_in;
        else                            -- else just keep
          data_fifo(i) <= data_fifo(i);
        end if;
      end loop;
    end if;
  end process;

  -- Wishbone signal generation

  -- We only do word transfers
  wb_sel_o <= X"f";

  -- The data of the payload flits
  wb_dat_o <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);

  -- Assign stored (and incremented) address to wishbone interface
  wb_adr_o <= address;

  --FSM

  -- Next state, counting, control signals
  processing_2 : process (state)
  begin
    -- Default values are old values
    nxt_address                <= address;
    nxt_resp_wsize             <= resp_wsize;
    nxt_end_of_request         <= end_of_request;
    nxt_src_address            <= src_address;
    nxt_src_tile               <= src_tile;
    nxt_end_of_request         <= end_of_request;
    nxt_packet_id              <= packet_id;
    nxt_wb_resp_count          <= wb_resp_count;
    nxt_noc_resp_packet_wcount <= noc_resp_packet_wcount;
    nxt_noc_resp_packet_wsize  <= noc_resp_packet_wsize;
    nxt_wb_waiting             <= wb_waiting;
    nxt_noc_resp_wcounter      <= noc_resp_wcounter;
    -- Default control signals
    wb_cyc_o                   <= '0';
    wb_stb_o                   <= '0';
    wb_we_o                    <= '0';
    wb_bte_o                   <= "00";
    wb_cti_o                   <= "000";
    noc_sgn_valid              <= '0';
    noc_out_flit               <= (others => '0');
    data_fifo_push             <= '0';
    data_fifo_pop              <= '0';
    buf_ready                  <= '0';
    case (state) is
      when "0000" =>
        buf_ready             <= '1';
        nxt_end_of_request    <= buf_flit(PACKET_REQ_LAST);
        nxt_src_tile          <= buf_flit(SOURCE_MSB downto SOURCE_LSB);
        nxt_resp_wsize        <= buf_flit(SIZE_MSB-20 downto SIZE_LSB);
        nxt_packet_id         <= buf_flit(PACKET_ID_MSB downto PACKET_ID_LSB);
        nxt_noc_resp_wcounter <= (others => '0');
        nxt_wb_resp_count     <= std_logic_vector(to_unsigned(1, DMA_RESPFIELD_SIZE_WIDTH-2));
        if (buf_valid = '1') then
          if (buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB) = PACKET_TYPE_L2R_REQ) then
            nxt_state <= STATE_L2R_GETADDR;
          elsif (buf_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB) = PACKET_TYPE_R2L_REQ) then
            nxt_state <= STATE_R2L_GETLADDR;
          else                          -- now we have a problem...
            -- must not happen
            nxt_state <= STATE_IDLE;
          end if;
        else
          nxt_state <= STATE_IDLE;
        end if;
      -- case: STATE_IDLE
      --L2R-handling
      when "0001" =>
        buf_ready   <= '1';
        nxt_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_L2R_DATA;
        else
          nxt_state <= STATE_L2R_GETADDR;
        end if;
      when "0010" =>
        if (buf_last_flit = '1') then
          wb_cti_o <= "111";
        else
          wb_cti_o <= "010";
        end if;
        wb_cyc_o <= '1';
        wb_stb_o <= '1';
        wb_we_o  <= '1';
        if (wb_ack_i = '1') then
          nxt_address <= std_logic_vector(unsigned(address)+to_unsigned(4, ADDR_WIDTH));
          buf_ready   <= '1';
          if (buf_last_flit = '1') then
            if (end_of_request = '1') then
              nxt_state <= STATE_L2R_SENDRESP;
            else
              nxt_state <= STATE_IDLE;
            end if;
          else
            nxt_state <= STATE_L2R_DATA;
          end if;
        else
          buf_ready <= '0';
          nxt_state <= STATE_L2R_DATA;
        end if;
      -- case: STATE_L2R_DATA
      when "0011" =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_SINGLE;
        noc_out_flit(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= src_tile;
        noc_out_flit(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit(PACKET_ID_MSB downto PACKET_ID_LSB)       <= packet_id;
        noc_out_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= PACKET_TYPE_L2R_RESP;
        if (noc_out_ready = '1') then
          nxt_state <= STATE_IDLE;
        else
          nxt_state <= STATE_L2R_SENDRESP;
        end if;
      -- case: STATE_L2R_SENDRESP
      --R2L handling
      when "0100" =>
        buf_ready   <= '1';
        nxt_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_R2L_GETRADDR;
        else
          nxt_state <= STATE_R2L_GETLADDR;
        end if;
      when "0101" =>
        buf_ready       <= '1';
        nxt_src_address <= buf_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB);
        if (buf_valid = '1') then
          nxt_state <= STATE_R2L_GENHDR;
        else
          nxt_state <= STATE_R2L_GETRADDR;
        end if;
      when "0110" =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_HEADER;
        noc_out_flit(FLIT_DEST_MSB downto FLIT_DEST_LSB)       <= src_tile;
        noc_out_flit(PACKET_CLASS_MSB downto PACKET_CLASS_LSB) <= PACKET_CLASS_DMA;
        noc_out_flit(PACKET_ID_MSB downto PACKET_ID_LSB)       <= packet_id;
        noc_out_flit(SOURCE_MSB downto SOURCE_LSB)             <= std_logic_vector(to_unsigned(TILEID, SOURCE_MSB-SOURCE_LSB+1));
        noc_out_flit(PACKET_TYPE_MSB downto PACKET_TYPE_LSB)   <= PACKET_TYPE_R2L_RESP;

        if ((unsigned(noc_resp_wcounter)+to_unsigned(NOC_PACKET_SIZE-2, SIZE_WIDTH)) < unsigned(resp_wsize)) then
          -- This is not the last packet in the respuest ((NOC_PACKET_SIZE -2) words*4 bytes=120)
          -- Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
          -- because we need a header-flit and an address-flit, too.
          noc_out_flit(SIZE_MSB downto SIZE_LSB) <= std_logic_vector(to_unsigned(120, SIZE_MSB-SIZE_LSB+1));
          noc_out_flit(PACKET_RESP_LAST)         <= '0';
          nxt_noc_resp_packet_wsize              <= std_logic_vector(to_unsigned(NOC_PACKET_SIZE-2, 5));
          -- count is the current transfer number
          nxt_noc_resp_packet_wcount             <= std_logic_vector(to_unsigned(1, 5));
        else  -- This is the last packet in the respuest
          noc_out_flit(SIZE_MSB downto SIZE_LSB) <= std_logic_vector(unsigned(resp_wsize)-unsigned(noc_resp_wcounter));
          noc_out_flit(PACKET_RESP_LAST)         <= '1';
          nxt_noc_resp_packet_wsize              <= std_logic_vector(unsigned(resp_wsize(4 downto 0))-unsigned(noc_resp_wcounter(4 downto 0)));
          -- count is the current transfer number
          nxt_noc_resp_packet_wcount             <= std_logic_vector(to_unsigned(1, 5));
        end if;
        -- else: !if((noc_resp_wcounter + (NOC_PACKET_SIZE -2)) < resp_wsize)
        -- change to next state if successful
        if (noc_out_ready = '1') then
          nxt_state <= STATE_R2L_GENADDR;
        else
          nxt_state <= STATE_R2L_GENHDR;
        end if;
      -- case: STATE_R2L_GENHDR
      when "0111" =>
        noc_sgn_valid                                          <= '1';
        noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB)       <= FLIT_TYPE_PAYLOAD;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= std_logic_vector(unsigned(src_address)+(unsigned(noc_resp_wcounter) sll 2));
        if (noc_out_ready = '1') then
          nxt_state <= STATE_R2L_DATA;
        else
          nxt_state <= STATE_R2L_GENADDR;
        end if;
      -- case: `NOC_RESP_R2L_GENADDR
      when "1000" =>
        -- NOC-handling
        -- transfer data to noc if available
        noc_sgn_valid                                          <= data_fifo_valid;
        noc_out_flit(FLIT_CONTENT_MSB downto FLIT_CONTENT_LSB) <= data_fifo_out;
        --TODO: Rearange ifs
        if (noc_resp_packet_wcount = noc_resp_packet_wsize) then
          noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= FLIT_TYPE_LAST;
          if (noc_sgn_valid = '1' and noc_out_ready = '1') then
            data_fifo_pop <= '1';
            if ((unsigned(noc_resp_wcounter)+to_unsigned(NOC_PACKET_SIZE-2, SIZE_WIDTH)) < unsigned(resp_wsize)) then
              -- Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
              -- because we need a header-flit and an address-flit, too.

              --this was not the last packet of the response
              nxt_state             <= STATE_R2L_GENHDR;
              nxt_noc_resp_wcounter <= std_logic_vector(unsigned(noc_resp_wcounter)+unsigned(noc_resp_packet_wcount));
            else              --this is the last packet of the response
              nxt_state <= STATE_IDLE;
            end if;
          else
            nxt_state <= STATE_R2L_DATA;
          end if;
        else                            --not LAST
          noc_out_flit(FLIT_TYPE_MSB downto FLIT_TYPE_LSB) <= FLIT_TYPE_PAYLOAD;
          if (noc_sgn_valid = '1' and noc_out_ready = '1') then
            data_fifo_pop              <= '1';
            nxt_noc_resp_packet_wcount <= std_logic_vector(unsigned(noc_resp_packet_wcount)+to_unsigned(1, 5));
          end if;
          nxt_state <= STATE_R2L_DATA;
        end if;
        --FIFO-handling
        if (wb_waiting = '1') then            --hidden state
          --don't get data from the bus
          wb_stb_o       <= '0';
          wb_cyc_o       <= '0';
          data_fifo_push <= '0';
          if (data_fifo_ready = '1') then
            nxt_wb_waiting <= '0';
          else
            nxt_wb_waiting <= '1';
          end if;
        --not wb_waiting
        -- Signal cycle and strobe. We do bursts, but don't insert
        -- wait states, so both of them are always equal.
        elsif ((noc_resp_packet_wcount = noc_resp_packet_wsize) and noc_sgn_valid = '1' and noc_out_ready = '1') then
          wb_stb_o <= '0';
          wb_cyc_o <= '0';
        else
          wb_stb_o <= '1';
          wb_cyc_o <= '1';
          -- TODO: why not generate address from the base address + counter<<2?
          if ((data_fifo_ready = '0') or (wb_resp_count = resp_wsize)) then
            wb_cti_o <= "111";
          else
            wb_cti_o <= "111";
          end if;
          if (wb_ack_i = '1') then
            -- When this was successfull..
            if ((data_fifo_ready = '0') or (wb_resp_count = resp_wsize)) then
              nxt_wb_waiting <= '1';
            else
              nxt_wb_waiting <= '0';
            end if;
            nxt_wb_resp_count <= std_logic_vector(unsigned(wb_resp_count)+to_unsigned(1, DMA_RESPFIELD_SIZE_WIDTH-2));
            nxt_address       <= std_logic_vector(unsigned(address)+to_unsigned(4, ADDR_WIDTH));
            data_fifo_push    <= '1';
          else  -- ..otherwise we still wait for the acknowledgement
            nxt_wb_resp_count <= wb_resp_count;
            nxt_address       <= address;
            data_fifo_push    <= '0';
            nxt_wb_waiting    <= '0';
          end if;
        end if;
      -- else: !if(wb_waiting)
      -- case: STATE_R2L_DATA
      when others =>
        nxt_state <= STATE_IDLE;
    end case;
  end process;

  noc_out_valid <= noc_sgn_valid;

  processing_3 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state                  <= STATE_IDLE;
        address                <= (others => '0');
        end_of_request         <= '0';
        src_tile               <= (others => '0');
        resp_wsize             <= (others => '0');
        packet_id              <= (others => '0');
        src_address            <= (others => '0');
        noc_resp_wcounter      <= (others => '0');
        noc_resp_packet_wsize  <= (others => '0');
        noc_resp_packet_wcount <= (others => '0');
        noc_resp_packet_wcount <= (others => '0');
        wb_resp_count          <= (others => '0');
        wb_waiting             <= '0';
      else
        state                  <= nxt_state;
        address                <= nxt_address;
        end_of_request         <= nxt_end_of_request;
        src_tile               <= nxt_src_tile;
        resp_wsize             <= nxt_resp_wsize;
        packet_id              <= nxt_packet_id;
        src_address            <= nxt_src_address;
        noc_resp_wcounter      <= nxt_noc_resp_wcounter;
        noc_resp_packet_wsize  <= nxt_noc_resp_packet_wsize;
        noc_resp_packet_wcount <= nxt_noc_resp_packet_wcount;
        wb_resp_count          <= nxt_wb_resp_count;
        wb_waiting             <= nxt_wb_waiting;
      end if;
    end if;
  end process;
end RTL;
