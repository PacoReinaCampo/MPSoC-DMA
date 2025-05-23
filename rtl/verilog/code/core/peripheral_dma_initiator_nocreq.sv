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
//              Network on Chip                                               //
//              AMBA4 AHB-Lite Bus Interface                                  //
//              Wishbone Bus Interface                                        //
//              Blackbone Bus Interface                                       //
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

module peripheral_dma_initiator_nocreq #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID                 = 0,
  parameter NOC_PACKET_SIZE        = 16          // flits per packet
) (
  input clk,
  input rst,

  // NOC-Interface
  output reg [FLIT_WIDTH-1:0] noc_out_flit,
  output reg                  noc_out_valid,
  input                       noc_out_ready,

  // Control read (request) interface
  output reg [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos,
  input      [DMA_REQUEST_WIDTH     -1:0] ctrl_read_req,

  input [TABLE_ENTRIES         -1:0] valid,

  // Feedback from response path
  input [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
  input                              ctrl_done_en,

  // Interface to wishbone request
  output reg                               req_start,
  output     [ADDR_WIDTH             -1:0] req_laddr,
  input                                    req_data_valid,
  output reg                               req_data_ready,
  input      [DATA_WIDTH             -1:0] req_data,
  output                                   req_is_l2r,
  output     [DMA_REQFIELD_SIZE_WIDTH-3:0] req_size
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  //  NOC request
  localparam NOC_REQ_WIDTH = 4;
  localparam NOC_REQ_IDLE = 4'b0000;
  localparam NOC_REQ_L2R_GENHDR = 4'b0001;
  localparam NOC_REQ_L2R_GENADDR = 4'b0010;
  localparam NOC_REQ_L2R_DATA = 4'b0011;
  localparam NOC_REQ_L2R_WAITDATA = 4'b0100;
  localparam NOC_REQ_R2L_GENHDR = 4'b0101;
  localparam NOC_REQ_R2L_GENSIZE = 4'b1000;

  localparam NOC_REQ_R2L_GENRADDR = 4'b0110;
  localparam NOC_REQ_R2L_GENLADDR = 4'b0111;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // State logic
  reg     [           NOC_REQ_WIDTH-1:0] noc_req_state;
  reg     [           NOC_REQ_WIDTH-1:0] nxt_noc_req_state;

  // Counter for payload flits/words in request
  reg     [ DMA_REQFIELD_SIZE_WIDTH-1:0] noc_req_counter;
  reg     [ DMA_REQFIELD_SIZE_WIDTH-1:0] nxt_noc_req_counter;

  // Current packet payload flit/word counter
  reg     [                         4:0] noc_req_packet_count;
  reg     [                         4:0] nxt_noc_req_packet_count;

  // Current packet total number of flits/words
  reg     [                         4:0] noc_req_packet_size;
  reg     [                         4:0] nxt_noc_req_packet_size;

  // Table entry selection logic
  //
  // The request table signals all open requests on the 'valid' bit vector.
  // The selection logic arbitrates among those entries to determine the
  // request to be handled next.
  //
  // The arbitration is not done for all entries marked as valid but only
  // for those, that are additionally not marked in the open_responses
  // bit vector.
  //
  // The selection signals only change after a transfer is started.

  // Selects the next entry from the table
  reg     [           TABLE_ENTRIES-1:0] select;  // current grant of arbiter
  wire    [           TABLE_ENTRIES-1:0] nxt_select;  // next grant of arbiter

  // Store open responses: table entry valid is not sufficient, as
  // current requests would be selected
  reg     [           TABLE_ENTRIES-1:0] open_responses;
  reg     [           TABLE_ENTRIES-1:0] nxt_open_responses;

  wire    [           TABLE_ENTRIES-1:0] requests;

  wire                                   nxt_req_start;

  wire    [DMA_REQFIELD_RTILE_WIDTH-1:0] req_rtile;
  wire    [ADDR_WIDTH              -1:0] req_raddr;

  integer                                d;

  //////////////////////////////////////////////////////////////////////////////
  // Module body
  //////////////////////////////////////////////////////////////////////////////

  assign requests = valid & ~open_responses & {TABLE_ENTRIES{(noc_req_state == NOC_REQ_IDLE)}};

  // Round Robin (rr) arbiter
  peripheral_arbiter_rr #(
    .N(TABLE_ENTRIES)
  ) arbiter_rr (
    // Outputs
    .nxt_gnt(nxt_select),
    // Inputs
    .req    (requests),
    .en     (1'b1),
    .gnt    (select)
  );

  // register next select to select
  always @(posedge clk) begin
    if (rst) begin
      select <= 0;
    end else begin
      select <= nxt_select;
    end
  end

  // Convert (one hot) select bit vector to binary
  always @(*) begin : readpos_onehottobinary
    ctrl_read_pos = 0;
    for (d = 0; d < TABLE_ENTRIES; d = d + 1) begin
      if (select[d]) begin
        ctrl_read_pos = ctrl_read_pos | d;
      end
    end
  end

  // Request generation
  // This is a pulse that signals the start of a request to the wishbone and noc
  // part of the request generation.
  assign nxt_req_start =  // start when any is valid and not already in progress
 (|(valid & ~open_responses) &  // and we are not currently generating a request (pulse)
 (noc_req_state == NOC_REQ_IDLE));

  // Convenience wires
  assign req_is_l2r    = (ctrl_read_req[DMA_REQFIELD_DIR] == DMA_REQUEST_L2R);
  assign req_laddr     = ctrl_read_req[DMA_REQFIELD_LADDR_MSB:DMA_REQFIELD_LADDR_LSB];
  assign req_size      = ctrl_read_req[DMA_REQFIELD_SIZE_MSB:DMA_REQFIELD_SIZE_LSB];
  assign req_rtile     = ctrl_read_req[DMA_REQFIELD_RTILE_MSB:DMA_REQFIELD_RTILE_LSB];
  assign req_raddr     = ctrl_read_req[DMA_REQFIELD_RADDR_MSB:DMA_REQFIELD_RADDR_LSB];

  // NoC side request generation

  // next state logic, counters, control signals
  always @(*) begin
    // Default is not generating flits
    noc_out_valid            = 1'b0;
    noc_out_flit             = 34'h0;

    // Only pop when successfull transfer
    req_data_ready           = 1'b0;

    // Counters stay old value
    nxt_noc_req_counter      = noc_req_counter;
    nxt_noc_req_packet_count = noc_req_packet_count;
    nxt_noc_req_packet_size  = noc_req_packet_size;

    // Open response only changes when request generated
    nxt_open_responses       = open_responses;

    case (noc_req_state)
      NOC_REQ_IDLE: begin
        // Idle'ing
        if (req_start) begin
          // A valid request exists, that is not open
          if (req_is_l2r) begin
            // L2R
            nxt_noc_req_state = NOC_REQ_L2R_GENHDR;
          end else begin
            // R2L
            nxt_noc_req_state = NOC_REQ_R2L_GENHDR;
          end
        end else begin
          // wait for request
          nxt_noc_req_state = NOC_REQ_IDLE;
        end
        // Reset counter
        nxt_noc_req_counter = 0;
      end
      NOC_REQ_L2R_GENHDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_HEADER;
        noc_out_flit[FLIT_DEST_MSB:FLIT_DEST_LSB]       = req_rtile;
        noc_out_flit[PACKET_CLASS_MSB:PACKET_CLASS_LSB] = PACKET_CLASS_DMA;
        noc_out_flit[PACKET_ID_MSB:PACKET_ID_LSB]       = ctrl_read_pos;
        noc_out_flit[SOURCE_MSB:SOURCE_LSB]             = TILEID;
        noc_out_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB]   = PACKET_TYPE_L2R_REQ;
        if ((noc_req_counter + (NOC_PACKET_SIZE - 2)) < req_size) begin
          // This is not the last packet in the request (NOC_PACKET_SIZE-2)
          noc_out_flit[SIZE_MSB:SIZE_LSB] = NOC_PACKET_SIZE - 2;
          noc_out_flit[PACKET_REQ_LAST]   = 1'b0;
          nxt_noc_req_packet_size         = NOC_PACKET_SIZE - 2;
          // count is the current transfer number
          nxt_noc_req_packet_count        = 5'd1;
        end else begin
          // This is the last packet in the request
          noc_out_flit[SIZE_MSB:SIZE_LSB] = req_size - noc_req_counter;
          noc_out_flit[PACKET_REQ_LAST]   = 1'b1;
          nxt_noc_req_packet_size         = req_size - noc_req_counter;
          // count is the current transfer number
          nxt_noc_req_packet_count        = 5'd1;
        end
        // change to next state if successful
        if (noc_out_ready) begin
          nxt_noc_req_state = NOC_REQ_L2R_GENADDR;
        end else begin
          nxt_noc_req_state = NOC_REQ_L2R_GENHDR;
        end
      end
      NOC_REQ_L2R_GENADDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_PAYLOAD;
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = req_raddr + (noc_req_counter << 2);
        if (noc_out_ready) begin
          nxt_noc_req_state = NOC_REQ_L2R_DATA;
        end else begin
          nxt_noc_req_state = NOC_REQ_L2R_GENADDR;
        end
      end
      NOC_REQ_L2R_DATA: begin
        // transfer data to noc if available
        noc_out_valid = req_data_valid;

        // Signal last flit for this transfer
        if (noc_req_packet_count == noc_req_packet_size) begin
          noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] = FLIT_TYPE_LAST;
        end else begin
          noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB] = FLIT_TYPE_PAYLOAD;
        end
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = req_data;
        if (noc_out_ready & noc_out_valid) begin
          // transfer was successful

          // signal to data fifo
          req_data_ready           = 1'b1;

          // increment the counter for this packet
          nxt_noc_req_packet_count = noc_req_packet_count + 1;

          if (noc_req_packet_count == noc_req_packet_size) begin
            // This was the last flit in this packet
            if (noc_req_packet_count + noc_req_counter == req_size) begin
              // .. and the last flit for the request

              // keep open_responses and "add" currently selected request to it
              nxt_open_responses = open_responses | select;
              // back to IDLE
              nxt_noc_req_state  = NOC_REQ_IDLE;
            end else begin
              // .. and other packets to transfer

              // Start with next header
              nxt_noc_req_state   = NOC_REQ_L2R_GENHDR;

              // add the current counter to overall counter
              nxt_noc_req_counter = noc_req_counter + noc_req_packet_count;
            end
          end else begin
            // we transfered a flit inside the packet
            nxt_noc_req_state = NOC_REQ_L2R_DATA;
          end
        end else begin
          // no success
          nxt_noc_req_state = NOC_REQ_L2R_DATA;
        end
      end
      NOC_REQ_R2L_GENHDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_HEADER;
        noc_out_flit[FLIT_DEST_MSB:FLIT_DEST_LSB]       = req_rtile;
        noc_out_flit[PACKET_CLASS_MSB:PACKET_CLASS_LSB] = PACKET_CLASS_DMA;
        noc_out_flit[PACKET_ID_MSB:PACKET_ID_LSB]       = ctrl_read_pos;
        noc_out_flit[SOURCE_MSB:SOURCE_LSB]             = TILEID;
        noc_out_flit[PACKET_TYPE_MSB:PACKET_TYPE_LSB]   = PACKET_TYPE_R2L_REQ;
        noc_out_flit[11:0]                              = 0;

        // There's only one packet needed for the request
        noc_out_flit[PACKET_REQ_LAST]                   = 1'b1;

        // change to next state if successful
        if (noc_out_ready) begin
          nxt_noc_req_state = NOC_REQ_R2L_GENSIZE;
        end else begin
          nxt_noc_req_state = NOC_REQ_R2L_GENHDR;
        end
      end
      NOC_REQ_R2L_GENSIZE: begin
        noc_out_valid                   = 1'b1;
        noc_out_flit[SIZE_MSB:SIZE_LSB] = req_size;

        // change to next state if successful
        if (noc_out_ready) begin
          nxt_noc_req_state = NOC_REQ_R2L_GENRADDR;
        end else begin
          nxt_noc_req_state = NOC_REQ_R2L_GENSIZE;
        end
      end
      NOC_REQ_R2L_GENRADDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_PAYLOAD;
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = ctrl_read_req[DMA_REQFIELD_RADDR_MSB:DMA_REQFIELD_RADDR_LSB];
        if (noc_out_ready) begin
          // keep open_responses and "add" currently selected request to it
          nxt_noc_req_state = NOC_REQ_R2L_GENLADDR;
        end else begin
          nxt_noc_req_state = NOC_REQ_R2L_GENRADDR;
        end
      end
      NOC_REQ_R2L_GENLADDR: begin
        noc_out_valid                                   = 1'b1;
        noc_out_flit[FLIT_TYPE_MSB:FLIT_TYPE_LSB]       = FLIT_TYPE_LAST;
        noc_out_flit[FLIT_CONTENT_MSB:FLIT_CONTENT_LSB] = ctrl_read_req[DMA_REQFIELD_LADDR_MSB:DMA_REQFIELD_LADDR_LSB];
        if (noc_out_ready) begin
          // keep open_responses and "add" currently selected request to it
          nxt_open_responses = open_responses | select;
          nxt_noc_req_state  = NOC_REQ_IDLE;
        end else begin
          nxt_noc_req_state = NOC_REQ_R2L_GENLADDR;
        end
      end
      default: begin
        nxt_noc_req_state = NOC_REQ_IDLE;
      end
    endcase
    // Process done information from response
    if (ctrl_done_en) begin
      nxt_open_responses[ctrl_done_pos] = 1'b0;
    end
  end

  // sequential part of NoC interface
  always @(posedge clk) begin
    if (rst) begin
      noc_req_state        <= NOC_REQ_IDLE;
      noc_req_counter      <= 0;
      noc_req_packet_size  <= 5'h0;
      noc_req_packet_count <= 5'h0;
      open_responses       <= 0;
      req_start            <= 1'b0;
    end else begin
      noc_req_counter      <= nxt_noc_req_counter;
      noc_req_packet_size  <= nxt_noc_req_packet_size;
      noc_req_packet_count <= nxt_noc_req_packet_count;
      noc_req_state        <= nxt_noc_req_state;
      open_responses       <= nxt_open_responses;
      req_start            <= nxt_req_start;
    end
  end
endmodule
