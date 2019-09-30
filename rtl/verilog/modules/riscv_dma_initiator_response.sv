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
//              Network on Chip Direct Memory Access                          //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              Mesh Topology                                                 //
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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

`include "riscv_dma_pkg.sv"

module riscv_dma_initiator_response #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter NOC_PACKET_SIZE = 16,

  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4)
)
  (
    input                                   clk,
    input                                   rst,

    input      [PLEN                  -1:0] noc_in_flit,
    input                                   noc_in_last,
    input                                   noc_in_valid,
    output                                  noc_in_ready,

    // AHB interface for L2R data fetch
    output reg                              HSEL,
    output     [PLEN                  -1:0] HADDR,
    output     [XLEN                  -1:0] HWDATA,
    input      [XLEN                  -1:0] HRDATA,
    output reg                              HWRITE,
    output reg [                       2:0] HSIZE,
    output reg [                       2:0] HBURST,
    output     [                       3:0] HPROT,
    output reg [                       1:0] HTRANS,
    output reg                              HMASTLOCK,
    input                                   HREADY,
    input                                   HRESP,

    output reg [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
    output reg                              ctrl_done_en
  );

  localparam STATE_WIDTH    = 2;
  localparam STATE_IDLE     = 2'b00;
  localparam STATE_GET_ADDR = 2'b01;
  localparam STATE_DATA     = 2'b10;
  localparam STATE_GET_SIZE = 2'b11;

  // State registers and next state logic
  reg [STATE_WIDTH-1:0]                   state;
  reg [STATE_WIDTH-1:0]                   nxt_state;
  reg [PLEN       -1:0]                   res_address;
  reg [PLEN       -1:0]                   nxt_res_address;
  reg                                     last_packet_of_response;
  reg                                     nxt_last_packet_of_response;
  reg [TABLE_ENTRIES_PTRWIDTH-1:0]        res_id;
  reg [TABLE_ENTRIES_PTRWIDTH-1:0]        nxt_res_id;


  // There is a buffer between the NoC input and the wishbone
  // handling by the state machine. Those are the connection signals
  // from buffer to wishbone
  wire [PLEN      -1:0]                  buf_flit;
  wire                                   buf_valid;
  reg                                    buf_ready;

  riscv_dma_buffer #(
    .HADDR_SIZE   (PLEN),
    .BUFFER_DEPTH (NOC_PACKET_SIZE),
    .FULLPACKET   (0)
  )
  dma_buffer (
    .clk                           (clk),
    .rst                           (rst),

    .in_flit                       (noc_in_flit[PLEN-1:0]),
    .in_last                       (noc_in_last),
    .in_valid                      (noc_in_valid),
    .in_ready                      (noc_in_ready),

    .out_flit                      (buf_flit[PLEN-1:0]),
    .out_last                      (buf_last),
    .out_valid                     (buf_valid),
    .out_ready                     (buf_ready),

    .packet_size                   ()
  );

  assign HADDR = res_address; //alias

  assign HWDATA = buf_flit[`FLIT_CONTENT_MSB:`FLIT_CONTENT_LSB];

  // We only do word transfers
  assign HPROT = 4'hf;

  // Next state, wishbone combinatorial signals and counting
  always @(*) begin
    // Signal defaults
    HSEL      = 1'b0;
    HMASTLOCK = 1'b0;
    HWRITE    = 1'b0;
    HTRANS    = 2'b00;
    HBURST    = 3'b000;

    ctrl_done_en  = 1'b0;
    ctrl_done_pos = 0;

    // Default values are old values
    nxt_res_id = res_id;
    nxt_res_address = res_address;
    nxt_last_packet_of_response = last_packet_of_response;

    buf_ready = 1'b0;

    case (state)
      STATE_IDLE: begin
        buf_ready = 1'b1;

        if (buf_valid) begin
          nxt_res_id = buf_flit[`PACKET_ID_MSB:`PACKET_ID_LSB];
          nxt_last_packet_of_response = buf_flit[`PACKET_RES_LAST];

          if (buf_flit[`PACKET_TYPE_MSB:`PACKET_TYPE_LSB] == `PACKET_TYPE_L2R_RESP) begin
            nxt_state = STATE_IDLE;
            ctrl_done_en = 1'b1;
            ctrl_done_pos = nxt_res_id;
          end
          else if (buf_flit[`PACKET_TYPE_MSB:`PACKET_TYPE_LSB] == `PACKET_TYPE_R2L_RESP) begin
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
        nxt_res_address = buf_flit[`FLIT_CONTENT_MSB:`FLIT_CONTENT_LSB];
        nxt_state = STATE_DATA;
      end

      STATE_DATA: begin
        if (buf_last) begin
          HBURST = 3'b111;
        end
        else begin
          HBURST = 3'b010;
        end

        HTRANS = 2'b00;
        HMASTLOCK = 1'b1;
        HSEL = 1'b1;
        HWRITE = 1'b1;

        if (HREADY) begin
          nxt_res_address = res_address + 4;
          buf_ready = 1'b1;
          if (buf_last) begin
            nxt_state = STATE_IDLE;
            if (last_packet_of_response) begin
              ctrl_done_en = 1'b1;
              ctrl_done_pos = res_id;
            end
          end
          else begin
            nxt_state = STATE_DATA;
          end
        end
        else begin
          buf_ready = 1'b0;
          nxt_state = STATE_DATA;
        end
      end
      default: begin
        nxt_state = STATE_IDLE;
      end
    endcase // case (state)
  end // always @ (*)

  always @(posedge clk) begin
    if (rst) begin
      state <= STATE_IDLE;
      res_address <= 0;
      last_packet_of_response <= 0;
      res_id <= 0;
    end
    else begin
      state <= nxt_state;
      res_address <= nxt_res_address;
      last_packet_of_response <= nxt_last_packet_of_response;
      res_id <= nxt_res_id;
    end
  end
endmodule
