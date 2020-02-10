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

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_ahb3_top #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID = 0,
  parameter NOC_PACKET_SIZE = 16,
  parameter GENERATE_INTERRUPT = 1
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

    input  [ADDR_WIDTH-1:0]  ahb3_if_haddr,
    input  [DATA_WIDTH-1:0]  ahb3_if_hrdata,
    input                    ahb3_if_hmastlock,
    input                    ahb3_if_hsel,
    input                    ahb3_if_hwrite,
    output [DATA_WIDTH-1:0]  ahb3_if_hwdata,
    output                   ahb3_if_hready,
    output                   ahb3_if_hresp,

    output reg [ADDR_WIDTH-1:0] ahb3_haddr,
    output reg [DATA_WIDTH-1:0] ahb3_hwdata,
    output reg                  ahb3_hmastlock,
    output reg                  ahb3_hsel,
    output reg [3:0]            ahb3_hprot,
    output reg                  ahb3_hwrite,
    output     [2:0]            ahb3_hsize,
    output reg [2:0]            ahb3_hburst,
    output reg [1:0]            ahb3_htrans,
    input      [DATA_WIDTH-1:0] ahb3_hrdata,
    input                       ahb3_hready,

    output [TABLE_ENTRIES-1:0] irq
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam ahb3_arb_req    = 2'b00;
  localparam ahb3_arb_res    = 2'b01;
  localparam ahb3_arb_target = 2'b10;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  wire [ADDR_WIDTH-1:0]    ahb3_req_haddr;
  wire [DATA_WIDTH-1:0]    ahb3_req_hwdata;
  wire                     ahb3_req_hmastlock;
  wire                     ahb3_req_hsel;
  wire                     ahb3_req_hwrite;
  wire [3:0]               ahb3_req_hprot;
  wire [2:0]               ahb3_req_hburst;
  wire [1:0]               ahb3_req_htrans;
  reg  [DATA_WIDTH-1:0]    ahb3_req_hrdata;
  reg                      ahb3_req_hready;

  wire [ADDR_WIDTH-1:0]    ahb3_res_haddr;
  wire [DATA_WIDTH-1:0]    ahb3_res_hwdata;
  wire                     ahb3_res_hmastlock;
  wire                     ahb3_res_hsel;
  wire                     ahb3_res_hwrite;
  wire [3:0]               ahb3_res_hprot;
  wire [2:0]               ahb3_res_hburst;
  wire [1:0]               ahb3_res_htrans;
  reg  [DATA_WIDTH-1:0]    ahb3_res_hrdata;
  reg                      ahb3_res_hready;

  wire [ADDR_WIDTH-1:0]    ahb3_target_haddr;
  wire [DATA_WIDTH-1:0]    ahb3_target_hwdata;
  wire                     ahb3_target_hmastlock;
  wire                     ahb3_target_hsel;
  wire                     ahb3_target_hwrite;
  wire [2:0]               ahb3_target_hburst;
  wire [1:0]               ahb3_target_htrans;
  reg  [DATA_WIDTH-1:0]    ahb3_target_hrdata;
  reg                      ahb3_target_hready;

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                              ctrl_done_en;       // From ctrl_initiator of lisnoc_dma_initiator.v
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos;      // From ctrl_initiator of lisnoc_dma_initiator.v
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos;      // From ctrl_initiator of lisnoc_dma_initiator.v
  wire [`DMA_REQUEST_WIDTH-1:0]     ctrl_read_req;      // From request_table of lisnoc_dma_request_table.v
  wire [TABLE_ENTRIES-1:0]          done;               // From request_table of lisnoc_dma_request_table.v
  wire                              if_valid_en;        // From wbinterface of lisnoc_dma_wbinterface.v
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos;       // From wbinterface of lisnoc_dma_wbinterface.v
  wire                              if_valid_set;       // From wbinterface of lisnoc_dma_wbinterface.v
  wire                              if_validrd_en;      // From wbinterface of lisnoc_dma_wbinterface.v
  wire                              if_write_en;        // From wbinterface of lisnoc_dma_wbinterface.v
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos;       // From wbinterface of lisnoc_dma_wbinterface.v
  wire [`DMA_REQUEST_WIDTH-1:0]     if_write_req;       // From wbinterface of lisnoc_dma_wbinterface.v
  wire [`DMA_REQMASK_WIDTH-1:0]     if_write_select;    // From wbinterface of lisnoc_dma_wbinterface.v
  wire [TABLE_ENTRIES-1:0]          valid;              // From request_table of lisnoc_dma_request_table.v
  wire [3:0]                        ahb3_target_hprot;  // From target of lisnoc_dma_target.v
  // End of automatics

  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_out_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_in_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_write_pos;

  reg [1:0]                         ahb3_arb;
  reg [1:0]                         nxt_ahb3_arb;

  wire ahb3_arb_active;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign ahb3_if_hresp = 1'b0;

  assign ctrl_out_read_pos = 0;
  assign ctrl_in_read_pos = 0;
  assign ctrl_write_pos = 0;

  mpsoc_dma_ahb3_interface #(
    .TILEID(TILEID)
  )
  ahb3_interface (
    // Outputs
    .ahb3_if_hwdata          (ahb3_if_hwdata[DATA_WIDTH-1:0]),
    .ahb3_if_hready          (ahb3_if_hready),
    .if_write_req            (if_write_req[`DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos            (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select         (if_write_select[`DMA_REQMASK_WIDTH-1:0]),
    .if_write_en             (if_write_en),
    .if_valid_pos            (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set            (if_valid_set),
    .if_valid_en             (if_valid_en),
    .if_validrd_en           (if_validrd_en),
    // Inputs
    .clk                     (clk),
    .rst                     (rst),
    .ahb3_if_haddr           (ahb3_if_haddr[ADDR_WIDTH-1:0]),
    .ahb3_if_hrdata          (ahb3_if_hrdata[DATA_WIDTH-1:0]),
    .ahb3_if_hmastlock       (ahb3_if_hmastlock),
    .ahb3_if_hsel            (ahb3_if_hsel),
    .ahb3_if_hwrite          (ahb3_if_hwrite),
    .done                    (done[TABLE_ENTRIES-1:0])
  );

  mpsoc_dma_request_table #(
    .GENERATE_INTERRUPT(GENERATE_INTERRUPT)
  )
  request_table (
    // Outputs
    .ctrl_read_req         (ctrl_read_req[`DMA_REQUEST_WIDTH-1:0]),
    .valid                 (valid[TABLE_ENTRIES-1:0]),
    .done                  (done[TABLE_ENTRIES-1:0]),
    .irq                   (irq[TABLE_ENTRIES-1:0]),
    // Inputs
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
    .ctrl_read_pos         (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_pos         (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en          (ctrl_done_en));

  mpsoc_dma_ahb3_initiator #(
    .TILEID (TILEID)
  )
  ahb3_initiator (
    // Outputs
    .ctrl_read_pos        (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_pos        (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en         (ctrl_done_en),
    .noc_out_flit         (noc_out_req_flit[`FLIT_WIDTH-1:0]),  // Templated
    .noc_out_valid        (noc_out_req_valid),                  // Templated
    .noc_in_ready         (noc_in_res_ready),                   // Templated
    .ahb3_req_hmastlock   (ahb3_req_hmastlock),
    .ahb3_req_hsel        (ahb3_req_hsel),
    .ahb3_req_hwrite      (ahb3_req_hwrite),
    .ahb3_req_hwdata      (ahb3_req_hwdata[DATA_WIDTH-1:0]),
    .ahb3_req_haddr       (ahb3_req_haddr[ADDR_WIDTH-1:0]),
    .ahb3_req_hburst      (ahb3_req_hburst[2:0]),
    .ahb3_req_htrans      (ahb3_req_htrans[1:0]),
    .ahb3_req_hprot       (ahb3_req_hprot[3:0]),
    .ahb3_res_hmastlock   (ahb3_res_hmastlock),
    .ahb3_res_hsel        (ahb3_res_hsel),
    .ahb3_res_hwrite      (ahb3_res_hwrite),
    .ahb3_res_hwdata      (ahb3_res_hwdata[DATA_WIDTH-1:0]),
    .ahb3_res_haddr       (ahb3_res_haddr[ADDR_WIDTH-1:0]),
    .ahb3_res_hburst      (ahb3_res_hburst[2:0]),
    .ahb3_res_htrans      (ahb3_res_htrans[1:0]),
    .ahb3_res_hprot       (ahb3_res_hprot[3:0]),
    // Inputs
    .clk                  (clk),
    .rst                  (rst),
    .ctrl_read_req        (ctrl_read_req[`DMA_REQUEST_WIDTH-1:0]),
    .valid                (valid[TABLE_ENTRIES-1:0]),
    .noc_out_ready        (noc_out_req_ready),                 // Templated
    .noc_in_flit          (noc_in_res_flit[`FLIT_WIDTH-1:0]),  // Templated
    .noc_in_valid         (noc_in_res_valid),                  // Templated
    .ahb3_req_hready      (ahb3_req_hready),
    .ahb3_req_hrdata      (ahb3_req_hrdata[DATA_WIDTH-1:0]),
    .ahb3_res_hready      (ahb3_res_hready),
    .ahb3_res_hrdata      (ahb3_res_hrdata[DATA_WIDTH-1:0]));

  mpsoc_dma_ahb3_target #(
    .TILEID(TILEID),
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  )
  ahb3_target (
    // Outputs
    .noc_out_flit                 (noc_out_res_flit[`FLIT_WIDTH-1:0]),   // Templated
    .noc_out_valid                (noc_out_res_valid),                   // Templated
    .noc_in_ready                 (noc_in_req_ready),                    // Templated
    .ahb3_hmastlock               (ahb3_target_hmastlock),               // Templated
    .ahb3_hsel                    (ahb3_target_hsel),                    // Templated
    .ahb3_hwrite                  (ahb3_target_hwrite),                  // Templated
    .ahb3_hwdata                  (ahb3_target_hwdata[DATA_WIDTH-1:0]),  // Templated
    .ahb3_haddr                   (ahb3_target_haddr[ADDR_WIDTH-1:0]),   // Templated
    .ahb3_hprot                   (ahb3_target_hprot[3:0]),              // Templated
    .ahb3_hburst                  (ahb3_target_hburst[2:0]),             // Templated
    .ahb3_htrans                  (ahb3_target_htrans[1:0]),             // Templated
    // Inputs
    .clk                          (clk),
    .rst                          (rst),
    .noc_out_ready                (noc_out_res_ready),                  // Templated
    .noc_in_flit                  (noc_in_req_flit[`FLIT_WIDTH-1:0]),   // Templated
    .noc_in_valid                 (noc_in_req_valid),                   // Templated
    .ahb3_hready                  (ahb3_target_hready),                 // Templated
    .ahb3_hrdata                  (ahb3_target_hrdata[DATA_WIDTH-1:0])  // Templated
  );

  always @(posedge clk) begin
    if (rst) begin
      ahb3_arb <= ahb3_arb_target;
    end
    else begin
      ahb3_arb <= nxt_ahb3_arb;
    end
  end

  assign ahb3_arb_active = ((ahb3_arb == ahb3_arb_req)    & ahb3_req_hmastlock) |
                           ((ahb3_arb == ahb3_arb_res)    & ahb3_res_hmastlock) |
                           ((ahb3_arb == ahb3_arb_target) & ahb3_target_hmastlock);

  always @(*) begin
    if (ahb3_arb_active) begin
      nxt_ahb3_arb = ahb3_arb;
    end
    else begin
      if (ahb3_target_hmastlock) begin
        nxt_ahb3_arb = ahb3_arb_target;
      end
      else if (ahb3_res_hmastlock) begin
        nxt_ahb3_arb = ahb3_arb_res;
      end
      else if (ahb3_req_hmastlock) begin
        nxt_ahb3_arb = ahb3_arb_req;
      end
      else begin
        nxt_ahb3_arb = ahb3_arb_target;
      end
    end
  end

  assign ahb3_hsize = 3'b0;
  always @(*) begin
    if (ahb3_arb == ahb3_arb_target) begin
      ahb3_haddr = ahb3_target_haddr;
      ahb3_hwdata = ahb3_target_hwdata;
      ahb3_hmastlock = ahb3_target_hmastlock;
      ahb3_hsel = ahb3_target_hsel;
      ahb3_hprot = ahb3_target_hprot;
      ahb3_hwrite = ahb3_target_hwrite;
      ahb3_htrans = ahb3_target_htrans;
      ahb3_hburst = ahb3_target_hburst;
      ahb3_target_hready = ahb3_hready;
      ahb3_target_hrdata = ahb3_hrdata;
      ahb3_req_hready = 1'b0;
      ahb3_req_hrdata = 32'hx;
      ahb3_res_hready = 1'b0;
      ahb3_res_hrdata = 32'hx;
    end
    else if (ahb3_arb == ahb3_arb_res) begin
      ahb3_haddr = ahb3_res_haddr;
      ahb3_hwdata = ahb3_res_hwdata;
      ahb3_hmastlock = ahb3_res_hmastlock;
      ahb3_hsel = ahb3_res_hsel;
      ahb3_hprot = ahb3_res_hprot;
      ahb3_hwrite = ahb3_res_hwrite;
      ahb3_htrans = ahb3_res_htrans;
      ahb3_hburst = ahb3_res_hburst;
      ahb3_res_hready = ahb3_hready;
      ahb3_res_hrdata = ahb3_hrdata;
      ahb3_req_hready = 1'b0;
      ahb3_req_hrdata = 32'hx;
      ahb3_target_hready = 1'b0;
      ahb3_target_hrdata = 32'hx;
    end
    else if (ahb3_arb == ahb3_arb_req) begin
      ahb3_haddr = ahb3_req_haddr;
      ahb3_hwdata = ahb3_req_hwdata;
      ahb3_hmastlock = ahb3_req_hmastlock;
      ahb3_hsel = ahb3_req_hsel;
      ahb3_hprot = ahb3_req_hprot;
      ahb3_hwrite = ahb3_req_hwrite;
      ahb3_htrans = ahb3_req_htrans;
      ahb3_hburst = ahb3_req_hburst;
      ahb3_req_hready = ahb3_hready;
      ahb3_req_hrdata = ahb3_hrdata;
      ahb3_res_hready = 1'b0;
      ahb3_res_hrdata = 32'hx;
      ahb3_target_hready = 1'b0;
      ahb3_target_hrdata = 32'hx;
    end
    else begin // if (ahb3_arb == ahb3_arb_req)
      ahb3_haddr = 32'h0;
      ahb3_hwdata = 32'h0;
      ahb3_hmastlock = 1'b0;
      ahb3_hsel = 1'b0;
      ahb3_hprot = 4'h0;
      ahb3_hwrite = 1'b0;
      ahb3_htrans = 2'b00;
      ahb3_hburst = 3'b000;
      ahb3_req_hready = 1'b0;
      ahb3_req_hrdata = 32'hx;
      ahb3_res_hready = 1'b0;
      ahb3_res_hrdata = 32'hx;
      ahb3_target_hready = 1'b0;
      ahb3_target_hrdata = 32'hx;
    end
  end
endmodule // lisnoc_dma
