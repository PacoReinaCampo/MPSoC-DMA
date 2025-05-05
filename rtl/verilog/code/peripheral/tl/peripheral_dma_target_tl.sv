////////////////////////////////////////////////////////////////////////////////
//                                            __ _      _     _               //
//                                           / _(_)    | |   | |              //
//                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
//               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
//              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
//               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
//                  | |                                                       //
//                  |_|                                                       //
//                                                                            //
//                                                                            //
//              MPSoC-RISCV CPU                                               //
//              Direct Access Memory Interface                                //
//              AMBA4 AHB-Lite Bus Interface                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Stefan Wallentowitz <stefan@wallentowitz.de>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_dma_pkg::*;

module peripheral_dma_target_tl #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter FLIT_WIDTH         = 34,
  parameter STATE_WIDTH        = 4,
  parameter STATE_IDLE         = 4'b0000,
  parameter STATE_L2R_GETADDR  = 4'b0001,
  parameter STATE_L2R_DATA     = 4'b0010,
  parameter STATE_L2R_SENDRESP = 4'b0011,
  parameter STATE_R2L_GETLADDR = 4'b0100,
  parameter STATE_R2L_GETRADDR = 4'b0101,
  parameter STATE_R2L_GENHDR   = 4'b0110,
  parameter STATE_R2L_GENADDR  = 4'b0111,
  parameter STATE_R2L_DATA     = 4'b1000,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID                 = 0,
  parameter NOC_PACKET_SIZE        = 16
) (
  input clk,
  input rst,

  // NOC-Interface
  output reg [FLIT_WIDTH-1:0] noc_out_flit,
  output reg                  noc_out_valid,
  input                       noc_out_ready,

  input  [FLIT_WIDTH-1:0] noc_in_flit,
  input                   noc_in_valid,
  output                  noc_in_ready,

  // Wishbone interface for L2R data store
  output reg                  biu_hsel,
  output     [ADDR_WIDTH-1:0] biu_haddr,
  output     [DATA_WIDTH-1:0] biu_hwdata,
  output reg                  biu_hwrite,
  output reg [           2:0] biu_hburst,
  output     [           3:0] biu_hprot,
  output reg [           1:0] biu_htrans,
  output reg                  biu_hmastlock,

  input [DATA_WIDTH-1:0] biu_hrdata,
  input                  biu_hready
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // There is a buffer between the NoC input and the wishbone
  // handling by the state machine. Those are the connection signals
  // from buffer to wishbone
  wire    [              FLIT_WIDTH-1:0] buf_flit;
  wire                                   buf_valid;
  reg                                    buf_ready;

  // One FSM that handles the flow from the input
  // buffer to the wishbone interface

  // FSM state
  reg     [             STATE_WIDTH-1:0] state;
  reg     [             STATE_WIDTH-1:0] nxt_state;

  // FSM hidden state
  reg                                    biu_waiting;
  reg                                    nxt_tl_waiting;

  // Store request parameters: address, last packet and source
  reg     [              ADDR_WIDTH-1:0] src_address;
  reg     [              ADDR_WIDTH-1:0] nxt_src_address;
  reg     [              ADDR_WIDTH-1:0] address;
  reg     [              ADDR_WIDTH-1:0] nxt_address;
  reg                                    end_of_request;
  reg                                    nxt_end_of_request;
  reg     [         SOURCE_WIDTH   -1:0] src_tile;
  reg     [         SOURCE_WIDTH   -1:0] nxt_src_tile;
  reg     [         PACKET_ID_WIDTH-1:0] packet_id;
  reg     [         PACKET_ID_WIDTH-1:0] nxt_packet_id;

  // Counter for flits/words in request
  reg     [              SIZE_WIDTH-1:0] noc_resp_wcounter;
  reg     [              SIZE_WIDTH-1:0] nxt_noc_resp_wcounter;

  // Current packet flit/word counter
  reg     [                         4:0] noc_resp_packet_wcount;
  reg     [                         4:0] nxt_noc_resp_packet_wcount;

  // Current packet total number of flits/words
  reg     [                         4:0] noc_resp_packet_wsize;
  reg     [                         4:0] nxt_noc_resp_packet_wsize;

  // TO-DO: correct define!
  reg     [DMA_REQFIELD_SIZE_WIDTH -3:0] resp_wsize;
  reg     [DMA_REQFIELD_SIZE_WIDTH -3:0] nxt_resp_wsize;
  reg     [DMA_RESPFIELD_SIZE_WIDTH-3:0] biu_resp_count;
  reg     [DMA_RESPFIELD_SIZE_WIDTH-3:0] nxt_tl_resp_count;

  // FIFO-Stuff

  wire                                   data_fifo_valid;
  reg     [              DATA_WIDTH-1:0] data_fifo                                     [0:2];  // data storage
  reg                                    data_fifo_pop;  // NOC pushes
  reg                                    data_fifo_push;  // AHB4 pops

  wire    [              DATA_WIDTH-1:0] data_fifo_out;  // Current first element
  wire    [              DATA_WIDTH-1:0] data_fifo_in;  // Push element
  // Shift register for current position (4th bit is full mark)
  reg     [                         3:0] data_fifo_pos;

  wire                                   data_fifo_empty;  // FIFO empty
  wire                                   data_fifo_ready;  // FIFO accepts new elements

  wire                                   buf_last_flit;

  integer                                i;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // Input buffer that stores flits until we have one complete packet
  peripheral_dma_packet_buffer #(
    .FIFO_DEPTH(NOC_PACKET_SIZE)
  ) dma_packet_buffer (
    .clk(clk),
    .rst(rst),

    // Out
    .out_flit (buf_flit[FLIT_WIDTH-1:0]),
    .out_valid(buf_valid),
    .out_ready(buf_ready),

    // In
    .in_flit (noc_in_flit[FLIT_WIDTH-1:0]),
    .in_valid(noc_in_valid),
    .in_ready(noc_in_ready),

    .out_size()
  );

  // Is this the last flit of a packet?
  assign buf_last_flit   = (buf_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] == FLIT_TYPE_LAST) | (buf_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] == FLIT_TYPE_SINGLE);

  // The intermediate store a FIFO of three elements
  //
  // There should be no combinatorial path from input to output, so
  // that it takes one cycle before the wishbone interface knows
  // about back pressure from the NoC. Additionally, the wishbone
  // interface needs one extra cycle for burst termination. The data
  // should be stored and not discarded. Finally, there is one
  // element in the FIFO that is the normal timing decoupling.

  // Connect the fifo signals to the ports
  // assign data_fifo_pop = resp_data_ready;
  assign data_fifo_valid = ~data_fifo_empty;
  assign data_fifo_empty = data_fifo_pos[0];  // Empty when pushing to first one
  assign data_fifo_ready = ~|data_fifo_pos[3:2];  // equal to not full
  assign data_fifo_in    = biu_hrdata;
  assign data_fifo_out   = data_fifo[0];  // First element is out

  // FIFO position pointer logic
  always @(posedge clk) begin
    if (rst) begin
      data_fifo_pos <= 4'b001;
    end else begin
      if (data_fifo_push & ~data_fifo_pop) begin
        // push and no pop
        data_fifo_pos <= data_fifo_pos << 1;
      end else if (~data_fifo_push & data_fifo_pop) begin
        // pop and no push
        data_fifo_pos <= data_fifo_pos >> 1;
      end else begin
        // * no push or pop or
        // * both push and pop
        data_fifo_pos <= data_fifo_pos;
      end
    end
  end

  // FIFO data shifting logic
  always @(posedge clk) begin : data_fifo_shift
    // Iterate all fifo elements, starting from lowest
    for (i = 0; i < 3; i = i + 1) begin
      if (data_fifo_pop) begin
        // when popping data..
        if (data_fifo_push & data_fifo_pos[i+1]) begin
          // .. and we also push this cycle, we need to check
          // whether the pointer was on the next one
          data_fifo[i] <= data_fifo_in;
        end else if (i < 2) begin
          // .. otherwise shift if not last
          data_fifo[i] <= data_fifo[i+1];
        end else begin
          // the last stays static
          data_fifo[i] <= data_fifo[i];
        end
      end else if (data_fifo_push & data_fifo_pos[i]) begin
        // when pushing only and this is the current write
        // position
        data_fifo[i] <= data_fifo_in;
      end else begin
        // else just keep
        data_fifo[i] <= data_fifo[i];
      end
    end
  end

  // Wishbone signal generation

  // We only do word transfers
  assign biu_hprot  = 4'hf;

  // The data of the payload flits
  assign biu_hwdata = buf_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB];

  // Assign stored (and incremented) address to wishbone interface
  assign biu_haddr  = address;

  // FSM

  // Next state, counting, control signals
  always @(*) begin
    // Default values are old values
    nxt_address                = address;
    nxt_resp_wsize             = resp_wsize;
    nxt_end_of_request         = end_of_request;
    nxt_src_address            = src_address;
    nxt_src_tile               = src_tile;
    nxt_end_of_request         = end_of_request;
    nxt_packet_id              = packet_id;
    nxt_tl_resp_count        = biu_resp_count;
    nxt_noc_resp_packet_wcount = noc_resp_packet_wcount;
    nxt_noc_resp_packet_wsize  = noc_resp_packet_wsize;
    nxt_tl_waiting           = biu_waiting;
    nxt_noc_resp_wcounter      = noc_resp_wcounter;
    // Default control signals
    biu_hmastlock             = 1'b0;
    biu_hsel                  = 1'b0;
    biu_hwrite                = 1'b0;
    biu_htrans                = 2'b00;
    biu_hburst                = 3'b000;
    noc_out_valid              = 1'b0;
    noc_out_flit               = 34'h0;
    data_fifo_push             = 1'b0;
    data_fifo_pop              = 1'b0;
    buf_ready                  = 1'b0;
    case (state)
      STATE_IDLE: begin
        buf_ready             = 1'b1;
        nxt_end_of_request    = buf_flit[PACKET_REQ_LAST];
        nxt_src_tile          = buf_flit[SOURCE_MSB:SOURCE_LSB];
        nxt_resp_wsize        = buf_flit[SIZE_MSB:SIZE_LSB];
        nxt_packet_id         = buf_flit[PACKET_ID_MSB:PACKET_ID_LSB];
        nxt_noc_resp_wcounter = 0;
        nxt_tl_resp_count   = 1;
        if (buf_valid) begin
          if (buf_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB] == PACKET_TYPE_L2R_REQ) begin
            nxt_state = STATE_L2R_GETADDR;
          end else if (buf_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB] == PACKET_TYPE_R2L_REQ) begin
            nxt_state = STATE_R2L_GETLADDR;
          end else begin
            // now we have a problem...
            // must not happen
            nxt_state = STATE_IDLE;
          end
        end else begin
          nxt_state = STATE_IDLE;
        end
      end
      // L2R-handling
      STATE_L2R_GETADDR: begin
        buf_ready   = 1'b1;
        nxt_address = buf_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB];
        if (buf_valid) begin
          nxt_state = STATE_L2R_DATA;
        end else begin
          nxt_state = STATE_L2R_GETADDR;
        end
      end
      STATE_L2R_DATA: begin
        if (buf_last_flit) begin
          biu_hburst = 3'b111;
        end else begin
          biu_hburst = 3'b010;
        end
        biu_hmastlock = 1'b1;
        biu_hsel      = 1'b1;
        biu_hwrite    = 1'b1;
        if (biu_hready) begin
          nxt_address = address + 4;
          buf_ready   = 1'b1;
          if (buf_last_flit) begin
            if (end_of_request) begin
              nxt_state = STATE_L2R_SENDRESP;
            end else begin
              nxt_state = STATE_IDLE;
            end
          end else begin
            nxt_state = STATE_L2R_DATA;
          end
        end else begin
          buf_ready = 1'b0;
          nxt_state = STATE_L2R_DATA;
        end
      end
      STATE_L2R_SENDRESP: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_SINGLE;
        noc_out_flit[FLIT_DEST_MSB:FLIT_DEST_LSB]       = src_tile;
        noc_out_flit[PACKET_CLASS_MSB:PACKET_CLASS_LSB] = PACKET_CLASS_DMA;
        noc_out_flit[PACKET_ID_MSB:PACKET_ID_LSB]       = packet_id;
        noc_out_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB]   = PACKET_TYPE_L2R_RESP;
        if (noc_out_ready) begin
          nxt_state = STATE_IDLE;
        end else begin
          nxt_state = STATE_L2R_SENDRESP;
        end
      end
      // R2L handling
      STATE_R2L_GETLADDR: begin
        buf_ready   = 1'b1;
        nxt_address = buf_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB];
        if (buf_valid) begin
          nxt_state = STATE_R2L_GETRADDR;
        end else begin
          nxt_state = STATE_R2L_GETLADDR;
        end
      end
      STATE_R2L_GETRADDR: begin
        buf_ready       = 1'b1;
        nxt_src_address = buf_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB];
        if (buf_valid) begin
          nxt_state = STATE_R2L_GENHDR;
        end else begin
          nxt_state = STATE_R2L_GETRADDR;
        end
      end
      STATE_R2L_GENHDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_HEADER;
        noc_out_flit[FLIT_DEST_MSB:FLIT_DEST_LSB]       = src_tile;
        noc_out_flit[PACKET_CLASS_MSB:PACKET_CLASS_LSB] = PACKET_CLASS_DMA;
        noc_out_flit[PACKET_ID_MSB:PACKET_ID_LSB]       = packet_id;
        noc_out_flit[SOURCE_MSB:SOURCE_LSB]             = TILEID;
        noc_out_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB]   = PACKET_TYPE_R2L_RESP;

        if ((noc_resp_wcounter + (NOC_PACKET_SIZE - 2)) < resp_wsize) begin
          // This is not the last packet in the respuest ((NOC_PACKET_SIZE -2) words*4 bytes=120)
          // Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
          // because we need a header-flit and an address-flit, too.
          noc_out_flit[SIZE_MSB:SIZE_LSB] = 7'd120;
          noc_out_flit[PACKET_RESP_LAST]  = 1'b0;
          nxt_noc_resp_packet_wsize       = NOC_PACKET_SIZE - 2;
          // count is the current transfer number
          nxt_noc_resp_packet_wcount      = 5'd1;
        end else begin
          // This is the last packet in the respuest
          noc_out_flit[SIZE_MSB:SIZE_LSB] = resp_wsize - noc_resp_wcounter;
          noc_out_flit[PACKET_RESP_LAST]  = 1'b1;
          nxt_noc_resp_packet_wsize       = resp_wsize - noc_resp_wcounter;
          // count is the current transfer number
          nxt_noc_resp_packet_wcount      = 5'd1;
        end
        // change to next state if successful
        if (noc_out_ready) begin
          nxt_state = STATE_R2L_GENADDR;
        end else begin
          nxt_state = STATE_R2L_GENHDR;
        end
      end
      STATE_R2L_GENADDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_PAYLOAD;
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = src_address + (noc_resp_wcounter << 2);
        if (noc_out_ready) begin
          nxt_state = STATE_R2L_DATA;
        end else begin
          nxt_state = STATE_R2L_GENADDR;
        end
      end
      STATE_R2L_DATA: begin
        // NOC-handling
        // transfer data to noc if available
        noc_out_valid                                   = data_fifo_valid;
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = data_fifo_out;
        // TO-DO: Rearange ifs
        if (noc_resp_packet_wcount == noc_resp_packet_wsize) begin
          noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] = FLIT_TYPE_LAST;
          if (noc_out_valid & noc_out_ready) begin
            data_fifo_pop = 1'b1;
            if ((noc_resp_wcounter + (NOC_PACKET_SIZE - 2)) < resp_wsize) begin
              // Only (NOC_PACKET_SIZE -2) flits are availabel for the payload,
              // because we need a header-flit and an address-flit, too.

              // this was not the last packet of the response
              nxt_state             = STATE_R2L_GENHDR;
              nxt_noc_resp_wcounter = noc_resp_wcounter + noc_resp_packet_wcount;
            end else begin
              // this is the last packet of the response
              nxt_state = STATE_IDLE;
            end
          end else begin
            nxt_state = STATE_R2L_DATA;
          end
        end else begin
          noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] = FLIT_TYPE_PAYLOAD;
          if (noc_out_valid & noc_out_ready) begin
            data_fifo_pop              = 1'b1;
            nxt_noc_resp_packet_wcount = noc_resp_packet_wcount + 1;
          end
          nxt_state = STATE_R2L_DATA;
        end
        // FIFO-handling
        if (biu_waiting) begin
          // don't get data from the bus
          biu_hsel      = 1'b0;
          biu_hmastlock = 1'b0;
          data_fifo_push = 1'b0;
          if (data_fifo_ready) begin
            nxt_tl_waiting = 1'b0;
          end else begin
            nxt_tl_waiting = 1'b1;
          end
        end else begin
          // Signal cycle and strobe. We do bursts, but don't insert
          // wait states, so both of them are always equal.
          if ((noc_resp_packet_wcount == noc_resp_packet_wsize) & noc_out_valid & noc_out_ready) begin
            biu_hsel      = 1'b0;
            biu_hmastlock = 1'b0;
          end else begin
            biu_hsel      = 1'b1;
            biu_hmastlock = 1'b1;
          end
          // TO-DO: why not generate address from the base address + counter<<2?
          if (~data_fifo_ready | (biu_resp_count == resp_wsize)) begin
            biu_hburst = 3'b111;
          end else begin
            biu_hburst = 3'b111;
          end
          if (biu_hready) begin
            // When this was successfull..
            if (~data_fifo_ready | (biu_resp_count == resp_wsize)) begin
              nxt_tl_waiting = 1'b1;
            end else begin
              nxt_tl_waiting = 1'b0;
            end
            nxt_tl_resp_count = biu_resp_count + 1;
            nxt_address         = address + 4;
            data_fifo_push      = 1'b1;
          end else begin
            // ..otherwise we still wait for the acknowledgement
            nxt_tl_resp_count = biu_resp_count;
            nxt_address         = address;
            data_fifo_push      = 1'b0;
            nxt_tl_waiting    = 1'b0;
          end
        end
      end
      default: begin
        nxt_state = STATE_IDLE;
      end
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      state                  <= STATE_IDLE;
      address                <= 32'h0;
      end_of_request         <= 1'b0;
      src_tile               <= 0;
      resp_wsize             <= 0;
      packet_id              <= 0;
      src_address            <= 0;
      noc_resp_wcounter      <= 0;
      noc_resp_packet_wsize  <= 5'h0;
      noc_resp_packet_wcount <= 5'h0;
      noc_resp_packet_wcount <= 0;
      biu_resp_count        <= 0;
      biu_waiting           <= 0;
    end else begin
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
      biu_resp_count        <= nxt_tl_resp_count;
      biu_waiting           <= nxt_tl_waiting;
    end
  end
endmodule
