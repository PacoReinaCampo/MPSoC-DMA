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
//              Wishbone Bus Interface                                        //
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

module mpsoc_dma_wb_top #(
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

    input  [ADDR_WIDTH-1:0]  wb_if_addr_i,
    input  [DATA_WIDTH-1:0]  wb_if_dat_i,
    input                    wb_if_cyc_i,
    input                    wb_if_stb_i,
    input                    wb_if_we_i,
    output [DATA_WIDTH-1:0]  wb_if_dat_o,
    output                   wb_if_ack_o,
    output                   wb_if_err_o,
    output                   wb_if_rty_o,

    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    output reg                  wb_cyc_o,
    output reg                  wb_stb_o,
    output reg [           3:0] wb_sel_o,
    output reg                  wb_we_o,
    output                      wb_cab_o,
    output reg [           2:0] wb_cti_o,
    output reg [           1:0] wb_bte_o,
    input      [DATA_WIDTH-1:0] wb_dat_i,
    input                       wb_ack_i,

    output [TABLE_ENTRIES-1:0] irq
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam wb_arb_req    = 2'b00;
  localparam wb_arb_resp   = 2'b01;
  localparam wb_arb_target = 2'b10;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  wire [ADDR_WIDTH-1:0]    wb_req_adr_o;
  wire [DATA_WIDTH-1:0]    wb_req_dat_o;
  wire                     wb_req_cyc_o;
  wire                     wb_req_stb_o;
  wire                     wb_req_we_o;
  wire [           3:0]    wb_req_sel_o;
  wire [           2:0]    wb_req_cti_o;
  wire [           1:0]    wb_req_bte_o;
  reg  [DATA_WIDTH-1:0]    wb_req_dat_i;
  reg                      wb_req_ack_i;

  wire [ADDR_WIDTH-1:0]    wb_res_adr_o;
  wire [DATA_WIDTH-1:0]    wb_res_dat_o;
  wire                     wb_res_cyc_o;
  wire                     wb_res_stb_o;
  wire                     wb_res_we_o;
  wire [           3:0]    wb_res_sel_o;
  wire [           2:0]    wb_res_cti_o;
  wire [           1:0]    wb_res_bte_o;
  reg  [DATA_WIDTH-1:0]    wb_res_dat_i;
  reg                      wb_res_ack_i;

  wire [ADDR_WIDTH-1:0]    wb_target_adr_o;
  wire [DATA_WIDTH-1:0]    wb_target_dat_o;
  wire                     wb_target_cyc_o;
  wire                     wb_target_stb_o;
  wire                     wb_target_we_o;
  wire [           2:0]    wb_target_cti_o;
  wire [           1:0]    wb_target_bte_o;
  reg  [DATA_WIDTH-1:0]    wb_target_dat_i;
  reg                      wb_target_ack_i;

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                              ctrl_done_en;     // From initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos;    // From initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos;    // From initiator
  wire [`DMA_REQUEST_WIDTH    -1:0] ctrl_read_req;    // From request_table
  wire [TABLE_ENTRIES         -1:0] done;             // From request_table
  wire                              if_valid_en;      // From wb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos;     // From wb interface
  wire                              if_valid_set;     // From wb interface
  wire                              if_validrd_en;    // From wb interface
  wire                              if_write_en;      // From wb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos;     // From wb interface
  wire [`DMA_REQUEST_WIDTH    -1:0] if_write_req;     // From wb interface
  wire [`DMA_REQMASK_WIDTH    -1:0] if_write_select;  // From wb interface
  wire [TABLE_ENTRIES         -1:0] valid;            // From request_table
  wire [                       3:0] wb_target_sel_o;  // From target
  // End of automatics

  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_out_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_in_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_write_pos;

  reg [           1:0]              wb_arb;
  reg [           1:0]              nxt_wb_arb;

  wire wb_arb_active;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign wb_if_err_o = 1'b0;
  assign wb_if_rty_o = 1'b0;

  assign ctrl_out_read_pos = 0;
  assign ctrl_in_read_pos  = 0;
  assign ctrl_write_pos    = 0;

  mpsoc_dma_wb_interface #(
    .TILEID(TILEID)
  )
  wb_interface (
    .clk                     (clk),
    .rst                     (rst),

    .wb_if_addr_i            (wb_if_addr_i[ADDR_WIDTH-1:0]),
    .wb_if_dat_i             (wb_if_dat_i[DATA_WIDTH-1:0]),
    .wb_if_we_i              (wb_if_we_i),
    .wb_if_cyc_i             (wb_if_cyc_i),
    .wb_if_stb_i             (wb_if_stb_i),
    .wb_if_dat_o             (wb_if_dat_o[DATA_WIDTH-1:0]),
    .wb_if_ack_o             (wb_if_ack_o),

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

  mpsoc_dma_wb_initiator #(
    .TILEID (TILEID)
  )
  wb_initiator (
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

    .wb_res_adr_o         (wb_res_adr_o[ADDR_WIDTH-1:0]),
    .wb_res_dat_o         (wb_res_dat_o[DATA_WIDTH-1:0]),
    .wb_res_sel_o         (wb_res_sel_o[3:0]),
    .wb_res_we_o          (wb_res_we_o),
    .wb_res_cyc_o         (wb_res_cyc_o),
    .wb_res_stb_o         (wb_res_stb_o),
    .wb_res_cti_o         (wb_res_cti_o[2:0]),
    .wb_res_bte_o         (wb_res_bte_o[1:0]),
    .wb_req_dat_i         (wb_req_dat_i[DATA_WIDTH-1:0]),
    .wb_req_ack_i         (wb_req_ack_i),

    .wb_req_adr_o         (wb_req_adr_o[ADDR_WIDTH-1:0]),
    .wb_req_dat_o         (wb_req_dat_o[DATA_WIDTH-1:0]),
    .wb_req_sel_o         (wb_req_sel_o[3:0]),
    .wb_req_we_o          (wb_req_we_o),
    .wb_req_cyc_o         (wb_req_cyc_o),
    .wb_req_stb_o         (wb_req_stb_o),
    .wb_req_cti_o         (wb_req_cti_o[2:0]),
    .wb_req_bte_o         (wb_req_bte_o[1:0]),
    .wb_res_dat_i         (wb_res_dat_i[DATA_WIDTH-1:0]),
    .wb_res_ack_i         (wb_res_ack_i)
  );

  mpsoc_dma_wb_target #(
    .TILEID(TILEID),
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  )
  wb_target (
    // Outputs
    .clk                          (clk),
    .rst                          (rst),

    .noc_out_flit                 (noc_out_res_flit[`FLIT_WIDTH-1:0]),
    .noc_out_valid                (noc_out_res_valid),
    .noc_out_ready                (noc_out_res_ready),

    .noc_in_flit                  (noc_in_req_flit[`FLIT_WIDTH-1:0]),
    .noc_in_valid                 (noc_in_req_valid),
    .noc_in_ready                 (noc_in_req_ready),

    .wb_adr_o                     (wb_target_adr_o[ADDR_WIDTH-1:0]),
    .wb_dat_o                     (wb_target_dat_o[DATA_WIDTH-1:0]),
    .wb_sel_o                     (wb_target_sel_o[3:0]),
    .wb_we_o                      (wb_target_we_o),
    .wb_cyc_o                     (wb_target_cyc_o),
    .wb_stb_o                     (wb_target_stb_o),
    .wb_cti_o                     (wb_target_cti_o[2:0]),
    .wb_bte_o                     (wb_target_bte_o[1:0]),
    .wb_dat_i                     (wb_target_dat_i[DATA_WIDTH-1:0]),
    .wb_ack_i                     (wb_target_ack_i)
  );

  always @(posedge clk) begin
    if (rst) begin
      wb_arb <= wb_arb_target;
    end
    else begin
      wb_arb <= nxt_wb_arb;
    end
  end

  assign wb_arb_active = ((wb_arb == wb_arb_req)    & wb_req_cyc_o) |
                         ((wb_arb == wb_arb_resp)   & wb_res_cyc_o) |
                         ((wb_arb == wb_arb_target) & wb_target_cyc_o);

  always @(*) begin
    if (wb_arb_active) begin
      nxt_wb_arb = wb_arb;
    end
    else begin
      if (wb_target_cyc_o) begin
        nxt_wb_arb = wb_arb_target;
      end
      else if (wb_res_cyc_o) begin
        nxt_wb_arb = wb_arb_resp;
      end
      else if (wb_req_cyc_o) begin
        nxt_wb_arb = wb_arb_req;
      end
      else begin
        nxt_wb_arb = wb_arb_target;
      end
    end
  end

  assign wb_cab_o = 1'b0;
  always @(*) begin
    if (wb_arb == wb_arb_target) begin
      wb_adr_o = wb_target_adr_o;
      wb_dat_o = wb_target_dat_o;
      wb_cyc_o = wb_target_cyc_o;
      wb_stb_o = wb_target_stb_o;
      wb_sel_o = wb_target_sel_o;
      wb_we_o = wb_target_we_o;
      wb_bte_o = wb_target_bte_o;
      wb_cti_o = wb_target_cti_o;
      wb_target_ack_i = wb_ack_i;
      wb_target_dat_i = wb_dat_i;
      wb_req_ack_i = 1'b0;
      wb_req_dat_i = 32'hx;
      wb_res_ack_i = 1'b0;
      wb_res_dat_i = 32'hx;
    end
    else if (wb_arb == wb_arb_resp) begin
      wb_adr_o = wb_res_adr_o;
      wb_dat_o = wb_res_dat_o;
      wb_cyc_o = wb_res_cyc_o;
      wb_stb_o = wb_res_stb_o;
      wb_sel_o = wb_res_sel_o;
      wb_we_o = wb_res_we_o;
      wb_bte_o = wb_res_bte_o;
      wb_cti_o = wb_res_cti_o;
      wb_res_ack_i = wb_ack_i;
      wb_res_dat_i = wb_dat_i;
      wb_req_ack_i = 1'b0;
      wb_req_dat_i = 32'hx;
      wb_target_ack_i = 1'b0;
      wb_target_dat_i = 32'hx;
    end
    else if (wb_arb == wb_arb_req) begin
      wb_adr_o = wb_req_adr_o;
      wb_dat_o = wb_req_dat_o;
      wb_cyc_o = wb_req_cyc_o;
      wb_stb_o = wb_req_stb_o;
      wb_sel_o = wb_req_sel_o;
      wb_we_o = wb_req_we_o;
      wb_bte_o = wb_req_bte_o;
      wb_cti_o = wb_req_cti_o;
      wb_req_ack_i = wb_ack_i;
      wb_req_dat_i = wb_dat_i;
      wb_res_ack_i = 1'b0;
      wb_res_dat_i = 32'hx;
      wb_target_ack_i = 1'b0;
      wb_target_dat_i = 32'hx;
    end
    else begin
      wb_adr_o = 32'h0;
      wb_dat_o = 32'h0;
      wb_cyc_o = 1'b0;
      wb_stb_o = 1'b0;
      wb_sel_o = 4'h0;
      wb_we_o = 1'b0;
      wb_bte_o = 2'b00;
      wb_cti_o = 3'b000;
      wb_req_ack_i = 1'b0;
      wb_req_dat_i = 32'hx;
      wb_res_ack_i = 1'b0;
      wb_res_dat_i = 32'hx;
      wb_target_ack_i = 1'b0;
      wb_target_dat_i = 32'hx;
    end
  end
endmodule
