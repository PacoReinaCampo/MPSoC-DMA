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
//              AMBA3 AHB-Lite Bus Interface                                  //
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
//   Michael Tempelmeier <michael.tempelmeier@tum.de>
//   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_dma_pkg::*;

module peripheral_dma_top_apb4 #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID                 = 0,
  parameter NOC_PACKET_SIZE        = 16,
  parameter GENERATE_INTERRUPT     = 1
) (
  input clk,
  input rst,

  input  [FLIT_WIDTH-1:0] noc_in_req_flit,
  input                   noc_in_req_valid,
  output                  noc_in_req_ready,

  input  [FLIT_WIDTH-1:0] noc_in_res_flit,
  input                   noc_in_res_valid,
  output                  noc_in_res_ready,

  output [FLIT_WIDTH-1:0] noc_out_req_flit,
  output                  noc_out_req_valid,
  input                   noc_out_req_ready,

  output [FLIT_WIDTH-1:0] noc_out_res_flit,
  output                  noc_out_res_valid,
  input                   noc_out_res_ready,

  input                  apb4_if_hsel,
  input [ADDR_WIDTH-1:0] apb4_if_haddr,
  input [DATA_WIDTH-1:0] apb4_if_hwdata,
  input                  apb4_if_hwrite,
  input [           2:0] apb4_if_hsize,
  input [           2:0] apb4_if_hburst,
  input [           3:0] apb4_if_hprot,
  input [           1:0] apb4_if_htrans,
  input                  apb4_if_hmastlock,

  output [DATA_WIDTH-1:0] apb4_if_hrdata,
  output                  apb4_if_hready,
  output                  apb4_if_hresp,

  output reg                  apb4_hsel,
  output reg [ADDR_WIDTH-1:0] apb4_haddr,
  output reg [DATA_WIDTH-1:0] apb4_hwdata,
  output reg                  apb4_hwrite,
  output     [           2:0] apb4_hsize,
  output reg [           2:0] apb4_hburst,
  output reg [           3:0] apb4_hprot,
  output reg [           1:0] apb4_htrans,
  output reg                  apb4_hmastlock,

  input [DATA_WIDTH-1:0] apb4_hrdata,
  input                  apb4_hready,
  input                  apb4_hresp,

  output [TABLE_ENTRIES-1:0] irq
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam apb4_arb_req = 2'b00;
  localparam apb4_arb_res = 2'b01;
  localparam apb4_arb_target = 2'b10;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  wire [            ADDR_WIDTH-1:0] apb4_req_haddr;
  wire [            DATA_WIDTH-1:0] apb4_req_hwdata;
  wire                              apb4_req_hmastlock;
  wire                              apb4_req_hsel;
  wire                              apb4_req_hwrite;
  wire [                       3:0] apb4_req_hprot;
  wire [                       2:0] apb4_req_hburst;
  wire [                       1:0] apb4_req_htrans;

  reg  [            DATA_WIDTH-1:0] apb4_req_hrdata;
  reg                               apb4_req_hready;

  wire [            ADDR_WIDTH-1:0] apb4_res_haddr;
  wire [            DATA_WIDTH-1:0] apb4_res_hwdata;
  wire                              apb4_res_hmastlock;
  wire                              apb4_res_hsel;
  wire                              apb4_res_hwrite;
  wire [                       3:0] apb4_res_hprot;
  wire [                       2:0] apb4_res_hburst;
  wire [                       1:0] apb4_res_htrans;

  reg  [            DATA_WIDTH-1:0] apb4_res_hrdata;
  reg                               apb4_res_hready;

  wire [            ADDR_WIDTH-1:0] apb4_target_haddr;
  wire [            DATA_WIDTH-1:0] apb4_target_hwdata;
  wire                              apb4_target_hmastlock;
  wire                              apb4_target_hsel;
  wire                              apb4_target_hwrite;
  wire [                       2:0] apb4_target_hburst;
  wire [                       1:0] apb4_target_htrans;

  reg  [            DATA_WIDTH-1:0] apb4_target_hrdata;
  reg                               apb4_target_hready;

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                              ctrl_done_en;  // From ctrl_initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos;  // From ctrl_initiator
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos;  // From ctrl_initiator
  wire [DMA_REQUEST_WIDTH     -1:0] ctrl_read_req;  // From request_table
  wire [TABLE_ENTRIES         -1:0] done;  // From request_table
  wire                              if_valid_en;  // From wb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos;  // From wb interface
  wire                              if_valid_set;  // From wb interface
  wire                              if_validrd_en;  // From wb interface
  wire                              if_write_en;  // From wb interface
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos;  // From wb interface
  wire [DMA_REQUEST_WIDTH     -1:0] if_write_req;  // From wb interface
  wire [DMA_REQMASK_WIDTH     -1:0] if_write_select;  // From wb interface
  wire [TABLE_ENTRIES         -1:0] valid;  // From request_table
  wire [                       3:0] apb4_target_hprot;  // From target
  // End of automatics

  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_out_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_in_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_write_pos;

  reg  [                       1:0] apb4_arb;
  reg  [                       1:0] nxt_apb4_arb;

  wire                              apb4_arb_active;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  assign apb4_if_hresp     = 1'b0;

  assign ctrl_out_read_pos = 0;
  assign ctrl_in_read_pos  = 0;
  assign ctrl_write_pos    = 0;

  peripheral_dma_interface_apb4 #(
    .TILEID(TILEID)
  ) dma_interface_apb4 (
    .clk(clk),
    .rst(rst),

    .apb4_if_hsel     (apb4_if_hsel),
    .apb4_if_haddr    (apb4_if_haddr[ADDR_WIDTH-1:0]),
    .apb4_if_hrdata   (apb4_if_hrdata[DATA_WIDTH-1:0]),
    .apb4_if_hmastlock(apb4_if_hmastlock),
    .apb4_if_hwrite   (apb4_if_hwrite),

    .apb4_if_hwdata(apb4_if_hwdata[DATA_WIDTH-1:0]),
    .apb4_if_hready(apb4_if_hready),

    .if_write_req   (if_write_req[DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos   (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select(if_write_select[DMA_REQMASK_WIDTH-1:0]),
    .if_write_en    (if_write_en),

    .if_valid_pos (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set (if_valid_set),
    .if_valid_en  (if_valid_en),
    .if_validrd_en(if_validrd_en),

    .done(done[TABLE_ENTRIES-1:0])
  );

  peripheral_dma_request_table #(
    .GENERATE_INTERRUPT(GENERATE_INTERRUPT)
  ) dma_request_table (
    .clk(clk),
    .rst(rst),

    .if_write_req   (if_write_req[DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos   (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select(if_write_select[DMA_REQMASK_WIDTH-1:0]),
    .if_write_en    (if_write_en),

    .if_valid_pos (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set (if_valid_set),
    .if_valid_en  (if_valid_en),
    .if_validrd_en(if_validrd_en),

    .ctrl_read_req(ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),
    .ctrl_read_pos(ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),

    .ctrl_done_pos(ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en (ctrl_done_en),

    .valid(valid[TABLE_ENTRIES-1:0]),
    .done (done[TABLE_ENTRIES-1:0]),

    .irq(irq[TABLE_ENTRIES-1:0])
  );

  peripheral_dma_initiator_apb4 #(
    .TILEID(TILEID)
  ) dma_initiator_apb4 (
    .clk(clk),
    .rst(rst),

    .ctrl_read_pos(ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_read_req(ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),

    .ctrl_done_pos(ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en (ctrl_done_en),

    .valid(valid[TABLE_ENTRIES-1:0]),

    .noc_out_flit (noc_out_req_flit[FLIT_WIDTH-1:0]),
    .noc_out_valid(noc_out_req_valid),
    .noc_out_ready(noc_out_req_ready),

    .noc_in_flit (noc_in_res_flit[FLIT_WIDTH-1:0]),
    .noc_in_valid(noc_in_res_valid),
    .noc_in_ready(noc_in_res_ready),

    .apb4_req_hsel     (apb4_req_hsel),
    .apb4_req_haddr    (apb4_req_haddr[ADDR_WIDTH-1:0]),
    .apb4_req_hwdata   (apb4_req_hwdata[DATA_WIDTH-1:0]),
    .apb4_req_hwrite   (apb4_req_hwrite),
    .apb4_req_hburst   (apb4_req_hburst[2:0]),
    .apb4_req_hprot    (apb4_req_hprot[3:0]),
    .apb4_req_htrans   (apb4_req_htrans[1:0]),
    .apb4_req_hmastlock(apb4_req_hmastlock),

    .apb4_req_hrdata(apb4_req_hrdata[DATA_WIDTH-1:0]),
    .apb4_req_hready(apb4_req_hready),

    .apb4_res_hsel     (apb4_res_hsel),
    .apb4_res_haddr    (apb4_res_haddr[ADDR_WIDTH-1:0]),
    .apb4_res_hwdata   (apb4_res_hwdata[DATA_WIDTH-1:0]),
    .apb4_res_hwrite   (apb4_res_hwrite),
    .apb4_res_hburst   (apb4_res_hburst[2:0]),
    .apb4_res_hprot    (apb4_res_hprot[3:0]),
    .apb4_res_htrans   (apb4_res_htrans[1:0]),
    .apb4_res_hmastlock(apb4_res_hmastlock),

    .apb4_res_hrdata(apb4_res_hrdata[DATA_WIDTH-1:0]),
    .apb4_res_hready(apb4_res_hready)
  );

  peripheral_dma_target_apb4 #(
    .TILEID         (TILEID),
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  ) dma_target_apb4 (
    .clk(clk),
    .rst(rst),

    .noc_out_flit (noc_out_res_flit[FLIT_WIDTH-1:0]),
    .noc_out_valid(noc_out_res_valid),
    .noc_out_ready(noc_out_res_ready),

    .noc_in_flit (noc_in_req_flit[FLIT_WIDTH-1:0]),
    .noc_in_valid(noc_in_req_valid),
    .noc_in_ready(noc_in_req_ready),

    .apb4_hsel     (apb4_target_hsel),
    .apb4_haddr    (apb4_target_haddr[ADDR_WIDTH-1:0]),
    .apb4_hwdata   (apb4_target_hwdata[DATA_WIDTH-1:0]),
    .apb4_hwrite   (apb4_target_hwrite),
    .apb4_hburst   (apb4_target_hburst[2:0]),
    .apb4_hprot    (apb4_target_hprot[3:0]),
    .apb4_htrans   (apb4_target_htrans[1:0]),
    .apb4_hmastlock(apb4_target_hmastlock),

    .apb4_hrdata(apb4_target_hrdata[DATA_WIDTH-1:0]),
    .apb4_hready(apb4_target_hready)
  );

  always @(posedge clk) begin
    if (rst) begin
      apb4_arb <= apb4_arb_target;
    end else begin
      apb4_arb <= nxt_apb4_arb;
    end
  end

  assign apb4_arb_active = ((apb4_arb == apb4_arb_req) & apb4_req_hmastlock) | ((apb4_arb == apb4_arb_res) & apb4_res_hmastlock) | ((apb4_arb == apb4_arb_target) & apb4_target_hmastlock);

  always @(*) begin
    if (apb4_arb_active) begin
      nxt_apb4_arb = apb4_arb;
    end else begin
      if (apb4_target_hmastlock) begin
        nxt_apb4_arb = apb4_arb_target;
      end else if (apb4_res_hmastlock) begin
        nxt_apb4_arb = apb4_arb_res;
      end else if (apb4_req_hmastlock) begin
        nxt_apb4_arb = apb4_arb_req;
      end else begin
        nxt_apb4_arb = apb4_arb_target;
      end
    end
  end

  assign apb4_hsize = 3'b0;
  always @(*) begin
    if (apb4_arb == apb4_arb_target) begin
      apb4_haddr         = apb4_target_haddr;
      apb4_hwdata        = apb4_target_hwdata;
      apb4_hmastlock     = apb4_target_hmastlock;
      apb4_hsel          = apb4_target_hsel;
      apb4_hprot         = apb4_target_hprot;
      apb4_hwrite        = apb4_target_hwrite;
      apb4_htrans        = apb4_target_htrans;
      apb4_hburst        = apb4_target_hburst;
      apb4_target_hready = apb4_hready;
      apb4_target_hrdata = apb4_hrdata;
      apb4_req_hready    = 1'b0;
      apb4_req_hrdata    = 32'hx;
      apb4_res_hready    = 1'b0;
      apb4_res_hrdata    = 32'hx;
    end else if (apb4_arb == apb4_arb_res) begin
      apb4_haddr         = apb4_res_haddr;
      apb4_hwdata        = apb4_res_hwdata;
      apb4_hmastlock     = apb4_res_hmastlock;
      apb4_hsel          = apb4_res_hsel;
      apb4_hprot         = apb4_res_hprot;
      apb4_hwrite        = apb4_res_hwrite;
      apb4_htrans        = apb4_res_htrans;
      apb4_hburst        = apb4_res_hburst;
      apb4_res_hready    = apb4_hready;
      apb4_res_hrdata    = apb4_hrdata;
      apb4_req_hready    = 1'b0;
      apb4_req_hrdata    = 32'hx;
      apb4_target_hready = 1'b0;
      apb4_target_hrdata = 32'hx;
    end else if (apb4_arb == apb4_arb_req) begin
      apb4_haddr         = apb4_req_haddr;
      apb4_hwdata        = apb4_req_hwdata;
      apb4_hmastlock     = apb4_req_hmastlock;
      apb4_hsel          = apb4_req_hsel;
      apb4_hprot         = apb4_req_hprot;
      apb4_hwrite        = apb4_req_hwrite;
      apb4_htrans        = apb4_req_htrans;
      apb4_hburst        = apb4_req_hburst;
      apb4_req_hready    = apb4_hready;
      apb4_req_hrdata    = apb4_hrdata;
      apb4_res_hready    = 1'b0;
      apb4_res_hrdata    = 32'hx;
      apb4_target_hready = 1'b0;
      apb4_target_hrdata = 32'hx;
    end else begin
      apb4_haddr         = 32'h0;
      apb4_hwdata        = 32'h0;
      apb4_hmastlock     = 1'b0;
      apb4_hsel          = 1'b0;
      apb4_hprot         = 4'h0;
      apb4_hwrite        = 1'b0;
      apb4_htrans        = 2'b00;
      apb4_hburst        = 3'b000;
      apb4_req_hready    = 1'b0;
      apb4_req_hrdata    = 32'hx;
      apb4_res_hready    = 1'b0;
      apb4_res_hrdata    = 32'hx;
      apb4_target_hready = 1'b0;
      apb4_target_hrdata = 32'hx;
    end
  end
endmodule
