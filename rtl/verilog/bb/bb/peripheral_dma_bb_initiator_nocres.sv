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
//              Blackbone Bus Interface                                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2018-2019 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 * Author(s):
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_bb_initiator_nocres #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter FLIT_WIDTH = `FLIT_WIDTH,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),

  parameter NOC_PACKET_SIZE = 16,

  parameter STATE_WIDTH    = 2,
  parameter STATE_IDLE     = 2'b00,
  parameter STATE_GET_ADDR = 2'b01,
  parameter STATE_DATA     = 2'b10,
  parameter STATE_GET_SIZE = 2'b11
)
  (
    input clk,
    input rst,

    input [`FLIT_WIDTH-1:0]                 noc_in_flit,
    input                                   noc_in_valid,
    output                                  noc_in_ready,

    // Blackbone interface for L2R data fetch
    output     [ADDR_WIDTH-1:0]             bb_addr_o,
    output     [ADDR_WIDTH-1:0]             bb_din_o,
    output reg                              bb_en_o,
    output reg                              bb_we_o,
    input      [ADDR_WIDTH-1:0]             bb_dout_i,

    output reg [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
    output reg                              ctrl_done_en
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // State registers and next state logic
  reg [STATE_WIDTH-1:0]                   state;
  reg [STATE_WIDTH-1:0]                   nxt_state;
  reg [ADDR_WIDTH -1:0]                   resp_address;
  reg [ADDR_WIDTH -1:0]                   nxt_resp_address;
  reg                                     last_packet_of_response;
  reg                                     nxt_last_packet_of_response;
  reg [TABLE_ENTRIES_PTRWIDTH-1:0]        resp_id;
  reg [TABLE_ENTRIES_PTRWIDTH-1:0]        nxt_resp_id;

  // There is a buffer between the NoC input and the wishbone
  // handling by the state machine. Those are the connection signals
  // from buffer to wishbone
  wire [`FLIT_WIDTH-1:0]                  buf_flit;
  wire                                    buf_valid;
  reg                                     buf_ready;

  wire buf_last_flit;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  mpsoc_dma_packet_buffer #(
    .FIFO_DEPTH (NOC_PACKET_SIZE)
  )
  packet_buffer (
    .clk                           (clk),
    .rst                           (rst),

    // Inputs
    .in_flit                       (noc_in_flit[FLIT_WIDTH-1:0]),
    .in_valid                      (noc_in_valid),
    .in_ready                      (noc_in_ready),

    // Outputs
    .out_flit                      (buf_flit[FLIT_WIDTH-1:0]),
    .out_valid                     (buf_valid),
    .out_ready                     (buf_ready),

    .out_size                      ()
  );

  // Is this the last flit of a packet?
  assign buf_last_flit = (buf_flit[`FLIT_TYPE_MSB:`FLIT_TYPE_LSB]==`FLIT_TYPE_LAST) |
                         (buf_flit[`FLIT_TYPE_MSB:`FLIT_TYPE_LSB]==`FLIT_TYPE_SINGLE);

  assign bb_addr_o = resp_address; //alias

  assign bb_din_o = buf_flit[`FLIT_CONTENT_MSB:`FLIT_CONTENT_LSB];

  // Next state, wishbone combinatorial signals and counting
  always @(*) begin
    // Signal defaults
    bb_en_o = 1'b0;
    bb_we_o = 1'b0;

    ctrl_done_en  = 1'b0;
    ctrl_done_pos = 0;

    // Default values are old values
    nxt_resp_id = resp_id;
    nxt_resp_address = resp_address;
    nxt_last_packet_of_response = last_packet_of_response;

    buf_ready = 1'b0;

    case (state)
      STATE_IDLE: begin
        buf_ready = 1'b1;
        if (buf_valid) begin
          nxt_resp_id = buf_flit[`PACKET_ID_MSB:`PACKET_ID_LSB];
          nxt_last_packet_of_response = buf_flit[`PACKET_RESP_LAST];
          if (buf_flit[`PACKET_TYPE_MSB:`PACKET_TYPE_LSB] == `PACKET_TYPE_L2R_RESP) begin
            nxt_state = STATE_IDLE;
            ctrl_done_en = 1'b1;
            ctrl_done_pos = nxt_resp_id;
          end
          else if(buf_flit[`PACKET_TYPE_MSB:`PACKET_TYPE_LSB] == `PACKET_TYPE_R2L_RESP) begin
            nxt_state = STATE_GET_SIZE;
          end
          else begin
            // now we have a problem...
            // must not happen
            nxt_state = STATE_IDLE;
          end
        end
        else begin // if (buf_valid)
          nxt_state = STATE_IDLE;
        end
      end
      STATE_GET_SIZE: begin
        buf_ready = 1'b1;
        nxt_state = STATE_GET_ADDR;
      end
      STATE_GET_ADDR: begin
        buf_ready = 1'b1;
        nxt_resp_address = buf_flit[`FLIT_CONTENT_MSB:`FLIT_CONTENT_LSB];
        nxt_state = STATE_DATA;
      end
      STATE_DATA: begin
        bb_en_o = 1'b1;
        bb_we_o = 1'b1;

        buf_ready = 1'b0;
        nxt_state = STATE_DATA;
      end
      default: begin
        nxt_state = STATE_IDLE;
      end
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      state <= STATE_IDLE;
      resp_address <= 0;
      last_packet_of_response <= 0;
      resp_id <= 0;
    end
    else begin
      state <= nxt_state;
      resp_address <= nxt_resp_address;
      last_packet_of_response <= nxt_last_packet_of_response;
      resp_id <= nxt_resp_id;
    end
  end
endmodule
