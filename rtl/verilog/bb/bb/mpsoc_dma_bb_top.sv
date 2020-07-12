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
 *   Michael Tempelmeier <michael.tempelmeier@tum.de>
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_bb_top #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID                 = 0,
  parameter NOC_PACKET_SIZE        = 16,
  parameter GENERATE_INTERRUPT     = 1
)
  (
    input clk,
    input rst,

    input [`FLIT_WIDTH-1:0] noc_in_req_flit,
    input                   noc_in_req_valid,
    output                  noc_in_req_ready,

    input [`FLIT_WIDTH-1:0] noc_in_res_flit,
    input                   noc_in_res_valid,
    output                  noc_in_res_ready,

    output [`FLIT_WIDTH-1:0] noc_out_req_flit,
    output                   noc_out_req_valid,
    input                    noc_out_req_ready,

    output [`FLIT_WIDTH-1:0] noc_out_res_flit,
    output                   noc_out_res_valid,
    input                    noc_out_res_ready,

    input  [ADDR_WIDTH-1:0]  bb_if_addr_i,
    input  [DATA_WIDTH-1:0]  bb_if_din_i,
    input                    bb_if_en_i,
    input                    bb_if_we_i,
    output [DATA_WIDTH-1:0]  bb_if_dout_o,

    output reg [ADDR_WIDTH-1:0] bb_addr_o,
    output reg [DATA_WIDTH-1:0] bb_din_o,
    output reg                  bb_en_o,
    output reg                  bb_we_o,
    input      [DATA_WIDTH-1:0] bb_dout_i,

    output [TABLE_ENTRIES-1:0] irq
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam bb_arb_req    = 2'b00;
  localparam bb_arb_resp   = 2'b01;
  localparam bb_arb_target = 2'b10;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  wire [ADDR_WIDTH-1:0]    bb_req_addr_o;
  wire [DATA_WIDTH-1:0]    bb_req_din_o;
  wire                     bb_req_en_o;
  wire                     bb_req_we_o;
  reg  [DATA_WIDTH-1:0]    bb_req_dout_i;

  wire [ADDR_WIDTH-1:0]    bb_res_addr_o;
  wire [DATA_WIDTH-1:0]    bb_res_din_o;
  wire                     bb_res_en_o;
  wire                     bb_res_we_o;
  reg  [DATA_WIDTH-1:0]    bb_res_dout_i;

  wire [ADDR_WIDTH-1:0]    bb_target_addr_o;
  wire [DATA_WIDTH-1:0]    bb_target_din_o;
  wire                     bb_target_en_o;
  wire                     bb_target_we_o;
  reg  [DATA_WIDTH-1:0]    bb_target_dout_i;

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                              ctrl_done_en;     // From initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos;    // From initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos;    // From initiator
  wire [`DMA_REQUEST_WIDTH    -1:0] ctrl_read_req;    // From request_table
  wire [TABLE_ENTRIES         -1:0] done;             // From request_table
  wire                              if_valid_en;      // From bb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos;     // From bb interface
  wire                              if_valid_set;     // From bb interface
  wire                              if_validrd_en;    // From bb interface
  wire                              if_write_en;      // From bb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos;     // From bb interface
  wire [`DMA_REQUEST_WIDTH    -1:0] if_write_req;     // From bb interface
  wire [`DMA_REQMASK_WIDTH    -1:0] if_write_select;  // From bb interface
  wire [TABLE_ENTRIES         -1:0] valid;            // From request_table
  wire [                       3:0] bb_target_sel_o;  // From target
  // End of automatics

  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_out_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_in_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_write_pos;

  reg [           1:0]              bb_arb;
  reg [           1:0]              nxt_bb_arb;

  wire bb_arb_active;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign bb_if_err_o = 1'b0;
  assign bb_if_rty_o = 1'b0;

  assign ctrl_out_read_pos = 0;
  assign ctrl_in_read_pos  = 0;
  assign ctrl_write_pos    = 0;

  mpsoc_dma_bb_interface #(
    .TILEID(TILEID)
  )
  bb_interface (
    .clk                     (clk),
    .rst                     (rst),

    .bb_if_addr_i            (bb_if_addr_i[ADDR_WIDTH-1:0]),
    .bb_if_din_i             (bb_if_din_i[DATA_WIDTH-1:0]),
    .bb_if_en_i              (bb_if_en_i),
    .bb_if_we_i              (bb_if_we_i),
    .bb_if_dout_o            (bb_if_dout_o[DATA_WIDTH-1:0]),

    .if_write_req            (if_write_req[`DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos            (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select         (if_write_select[`DMA_REQMASK_WIDTH-1:0]),
    .if_write_en             (if_write_en),

    .if_valid_pos            (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set            (if_valid_set),
    .if_valid_en             (if_valid_en),
    .if_validrd_en           (if_validrd_en),

    .done                    (done[TABLE_ENTRIES-1:0])
  );

  mpsoc_dma_request_table #(
    .GENERATE_INTERRUPT(GENERATE_INTERRUPT)
  )
  request_table (
    .clk                   (clk),
    .rst                   (rst),

    .if_write_req          (if_write_req[`DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos          (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select       (if_write_select[`DMA_REQMASK_WIDTH-1:0]),
    .if_write_en           (if_write_en),

    .if_valid_pos          (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set          (if_valid_set),
    .if_valid_en           (if_valid_en),
    .if_validrd_en         (if_validrd_en),

    .ctrl_read_req         (ctrl_read_req[`DMA_REQUEST_WIDTH-1:0]),
    .ctrl_read_pos         (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),

    .ctrl_done_pos         (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en          (ctrl_done_en),

    .valid                 (valid[TABLE_ENTRIES-1:0]),
    .done                  (done[TABLE_ENTRIES-1:0]),

    .irq                   (irq[TABLE_ENTRIES-1:0])
  );

  mpsoc_dma_bb_initiator #(
    .TILEID (TILEID)
  )
  bb_initiator (
    .clk                  (clk),
    .rst                  (rst),

    .ctrl_read_pos        (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_read_req        (ctrl_read_req[`DMA_REQUEST_WIDTH-1:0]),

    .ctrl_done_pos        (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en         (ctrl_done_en),

    .valid                (valid[TABLE_ENTRIES-1:0]),

    .noc_out_flit         (noc_out_req_flit[`FLIT_WIDTH-1:0]),
    .noc_out_valid        (noc_out_req_valid),
    .noc_out_ready        (noc_out_req_ready),

    .noc_in_flit          (noc_in_res_flit[`FLIT_WIDTH-1:0]),
    .noc_in_valid         (noc_in_res_valid),
    .noc_in_ready         (noc_in_res_ready),

    .bb_res_addr_o        (bb_res_addr_o[ADDR_WIDTH-1:0]),
    .bb_res_din_o         (bb_res_din_o[DATA_WIDTH-1:0]),
    .bb_res_en_o          (bb_res_en_o),
    .bb_res_we_o          (bb_res_we_o),
    .bb_req_dout_i        (bb_req_dout_i[DATA_WIDTH-1:0]),

    .bb_req_addr_o        (bb_req_addr_o[ADDR_WIDTH-1:0]),
    .bb_req_din_o         (bb_req_din_o[DATA_WIDTH-1:0]),
    .bb_req_en_o          (bb_req_en_o),
    .bb_req_we_o          (bb_req_we_o),
    .bb_res_dout_i        (bb_res_dout_i[DATA_WIDTH-1:0])
  );

  mpsoc_dma_bb_target #(
    .TILEID(TILEID),
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  )
  bb_target (
    // Outputs
    .clk                          (clk),
    .rst                          (rst),

    .noc_out_flit                 (noc_out_res_flit[`FLIT_WIDTH-1:0]),
    .noc_out_valid                (noc_out_res_valid),
    .noc_out_ready                (noc_out_res_ready),

    .noc_in_flit                  (noc_in_req_flit[`FLIT_WIDTH-1:0]),
    .noc_in_valid                 (noc_in_req_valid),
    .noc_in_ready                 (noc_in_req_ready),

    .bb_addr_o                    (bb_target_addr_o[ADDR_WIDTH-1:0]),
    .bb_din_o                     (bb_target_din_o[DATA_WIDTH-1:0]),
    .bb_en_o                      (bb_target_en_o),
    .bb_we_o                      (bb_target_we_o),
    .bb_dout_i                    (bb_target_dout_i[DATA_WIDTH-1:0])
  );

  always @(posedge clk) begin
    if (rst) begin
      bb_arb <= bb_arb_target;
    end
    else begin
      bb_arb <= nxt_bb_arb;
    end
  end

  assign bb_arb_active = ((bb_arb == bb_arb_req)    & bb_req_en_o) |
                         ((bb_arb == bb_arb_resp)   & bb_res_en_o) |
                         ((bb_arb == bb_arb_target) & bb_target_en_o);

  always @(*) begin
    if (bb_arb_active) begin
      nxt_bb_arb = bb_arb;
    end
    else begin
      if (bb_target_en_o) begin
        nxt_bb_arb = bb_arb_target;
      end
      else if (bb_res_en_o) begin
        nxt_bb_arb = bb_arb_resp;
      end
      else if (bb_req_en_o) begin
        nxt_bb_arb = bb_arb_req;
      end
      else begin
        nxt_bb_arb = bb_arb_target;
      end
    end
  end

  assign bb_cab_o = 1'b0;
  always @(*) begin
    if (bb_arb == bb_arb_target) begin
      bb_addr_o = bb_target_addr_o;
      bb_din_o = bb_target_din_o;
      bb_en_o = bb_target_en_o;
      bb_we_o = bb_target_we_o;
      bb_target_dout_i = bb_dout_i;
      bb_req_dout_i = 32'hx;
      bb_res_dout_i = 32'hx;
    end
    else if (bb_arb == bb_arb_resp) begin
      bb_addr_o = bb_res_addr_o;
      bb_din_o = bb_res_din_o;
      bb_en_o = bb_res_en_o;
      bb_we_o = bb_res_we_o;
      bb_res_dout_i = bb_dout_i;
      bb_req_dout_i = 32'hx;
      bb_target_dout_i = 32'hx;
    end
    else if (bb_arb == bb_arb_req) begin
      bb_addr_o = bb_req_addr_o;
      bb_din_o = bb_req_din_o;
      bb_en_o = bb_req_en_o;
      bb_we_o = bb_req_we_o;
      bb_req_dout_i = bb_dout_i;
      bb_res_dout_i = 32'hx;
      bb_target_dout_i = 32'hx;
    end
    else begin
      bb_addr_o = 32'h0;
      bb_din_o = 32'h0;
      bb_en_o = 1'b0;
      bb_we_o = 1'b0;
      bb_req_dout_i = 32'hx;
      bb_res_dout_i = 32'hx;
      bb_target_dout_i = 32'hx;
    end
  end
endmodule
