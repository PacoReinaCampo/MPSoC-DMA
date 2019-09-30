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

module riscv_dma #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter NOC_PACKET_SIZE = 16,

  parameter TABLE_ENTRIES = 4,
  parameter DMA_REQMASK_WIDTH = 5,
  parameter DMA_REQUEST_WIDTH = 199,
  parameter DMA_REQFIELD_SIZE_WIDTH = 64,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4)
)
  (
    input                       clk,
    input                       rst,

    input  [PLEN          -1:0] noc_in_req_flit,
    input                       noc_in_req_last,
    input                       noc_in_req_valid,
    output                      noc_in_req_ready,

    input  [PLEN          -1:0] noc_in_res_flit,
    input                       noc_in_res_last,
    input                       noc_in_res_valid,
    output                      noc_in_res_ready,

    output [PLEN          -1:0] noc_out_req_flit,
    output                      noc_out_req_last,
    output                      noc_out_req_valid,
    input                       noc_out_req_ready,

    output [PLEN          -1:0] noc_out_res_flit,
    output                      noc_out_res_last,
    output                      noc_out_res_valid,
    input                       noc_out_res_ready,

    output [TABLE_ENTRIES -1:0] irq,

  //AHB master interface
    input                       mst_HSEL,
    input  [PLEN          -1:0] mst_HADDR,
    input  [XLEN          -1:0] mst_HWDATA,
    output [XLEN          -1:0] mst_HRDATA,
    input                       mst_HWRITE,
    input  [               2:0] mst_HSIZE,
    input  [               2:0] mst_HBURST,
    input  [               3:0] mst_HPROT,
    input  [               1:0] mst_HTRANS,
    input                       mst_HMASTLOCK,
    output                      mst_HREADYOUT,
    output                      mst_HRESP,

  //AHB slave interface
    output reg                  slv_HSEL,
    output reg [PLEN      -1:0] slv_HADDR,
    output reg [XLEN      -1:0] slv_HWDATA,
    input      [XLEN      -1:0] slv_HRDATA,
    output reg                  slv_HWRITE,
    output reg [           2:0] slv_HSIZE,
    output reg [           2:0] slv_HBURST,
    output reg [           3:0] slv_HPROT,
    output reg [           1:0] slv_HTRANS,
    output reg                  slv_HMASTLOCK,
    input                       slv_HREADY,
    input                       slv_HRESP
  );

  wire                     req_HSEL;
  wire [PLEN      -1:0]    req_HADDR;
  wire [XLEN      -1:0]    req_HWDATA;
  reg  [XLEN      -1:0]    req_HRDATA;
  wire                     req_HWRITE;
  wire [3:0]               req_HPROT;
  wire [2:0]               req_HSIZE;
  wire [2:0]               req_HBURST;
  wire [1:0]               req_HTRANS;
  wire                     req_HMASTLOCK;
  reg                      req_HREADY;
  reg                      req_HRESP;

  wire                     res_HSEL;
  wire [PLEN      -1:0]    res_HADDR;
  wire [XLEN      -1:0]    res_HWDATA;
  reg  [XLEN      -1:0]    res_HRDATA;
  wire                     res_HWRITE;
  wire [3:0]               res_HPROT;
  wire [2:0]               res_HSIZE;
  wire [2:0]               res_HBURST;
  wire [1:0]               res_HTRANS;
  wire                     res_HMASTLOCK;
  reg                      res_HREADY;
  reg                      res_HRESP;

  wire                     target_HSEL;
  wire [PLEN      -1:0]    target_HADDR;
  wire [XLEN      -1:0]    target_HWDATA;
  reg  [XLEN      -1:0]    target_HRDATA;
  wire                     target_HWRITE;
  wire [3:0]               target_HPROT;
  wire [2:0]               target_HSIZE;
  wire [2:0]               target_HBURST;
  wire [1:0]               target_HTRANS;
  wire                     target_HMASTLOCK;
  reg                      target_HREADY;
  reg                      target_HRESP;

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire                              ctrl_done_en;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos;
  wire [DMA_REQUEST_WIDTH     -1:0] ctrl_read_req;
  wire [TABLE_ENTRIES         -1:0] done;
  wire                              if_valid_en;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos;
  wire                              if_valid_set;
  wire                              if_validrd_en;
  wire                              if_write_en;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos;
  wire [DMA_REQUEST_WIDTH     -1:0] if_write_req;
  wire [DMA_REQMASK_WIDTH     -1:0] if_write_select;
  wire [TABLE_ENTRIES         -1:0] valid;

  // End of automatics
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_out_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_in_read_pos;
  wire [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_write_pos;

  assign ctrl_out_read_pos = 0;
  assign ctrl_in_read_pos  = 0;
  assign ctrl_write_pos    = 0;

  riscv_dma_interface #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .TABLE_ENTRIES (TABLE_ENTRIES),
    .DMA_REQMASK_WIDTH (DMA_REQMASK_WIDTH),
    .DMA_REQUEST_WIDTH (DMA_REQUEST_WIDTH),
    .TABLE_ENTRIES_PTRWIDTH (TABLE_ENTRIES_PTRWIDTH)
  )
  dma_wbinterface (
    .clk             (clk),
    .rst             (rst),

    .if_HSEL         (mst_HSEL),
    .if_HADDR        (mst_HADDR[PLEN-1:0]),
    .if_HWDATA       (mst_HWDATA[XLEN-1:0]),
    .if_HRDATA       (mst_HRDATA[XLEN-1:0]),
    .if_HWRITE       (mst_HWRITE),
    .if_HSIZE        (mst_HSIZE[2:0]),
    .if_HBURST       (mst_HBURST[2:0]),
    .if_HPROT        (mst_HPROT[3:0]),
    .if_HTRANS       (mst_HTRANS[1:0]),
    .if_HMASTLOCK    (mst_HMASTLOCK),
    .if_HREADYOUT    (mst_HREADYOUT),
    .if_HRESP        (mst_HRESP),

    .if_write_req    (if_write_req[DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos    (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select (if_write_select[DMA_REQMASK_WIDTH-1:0]),
    .if_write_en     (if_write_en),

    .if_valid_pos    (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set    (if_valid_set),
    .if_valid_en     (if_valid_en),
    .if_validrd_en   (if_validrd_en),

    .done            (done[TABLE_ENTRIES-1:0])
  );

  riscv_dma_transfer_table #(
    .DMA_REQUEST_WIDTH (DMA_REQUEST_WIDTH),
    .TABLE_ENTRIES (TABLE_ENTRIES),
    .TABLE_ENTRIES_PTRWIDTH (TABLE_ENTRIES_PTRWIDTH),
    .DMA_REQMASK_WIDTH (DMA_REQMASK_WIDTH)
  )
  dma_transfer_table (
    .clk                   (clk),
    .rst                   (rst),

    .if_write_req          (if_write_req[DMA_REQUEST_WIDTH-1:0]),
    .if_write_pos          (if_write_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_write_select       (if_write_select[DMA_REQMASK_WIDTH-1:0]),
    .if_write_en           (if_write_en),

    .if_valid_pos          (if_valid_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .if_valid_set          (if_valid_set),
    .if_valid_en           (if_valid_en),
    .if_validrd_en         (if_validrd_en),

    .ctrl_read_req         (ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),
    .ctrl_read_pos         (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),

    .ctrl_done_pos         (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en          (ctrl_done_en),

    .valid                 (valid[TABLE_ENTRIES-1:0]),
    .done                  (done[TABLE_ENTRIES-1:0]),

    .irq                   (irq[TABLE_ENTRIES-1:0])
  );

  riscv_dma_initiator #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .NOC_PACKET_SIZE (NOC_PACKET_SIZE),

    .TABLE_ENTRIES (TABLE_ENTRIES),
    .DMA_REQUEST_WIDTH (DMA_REQUEST_WIDTH),
    .DMA_REQFIELD_SIZE_WIDTH (DMA_REQFIELD_SIZE_WIDTH),
    .TABLE_ENTRIES_PTRWIDTH (TABLE_ENTRIES_PTRWIDTH)
  )
  dma_initiator (
    .clk           (clk),
    .rst           (rst),

    .ctrl_read_pos (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_read_req (ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),

    .ctrl_done_pos (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en  (ctrl_done_en),

    .valid         (valid[TABLE_ENTRIES-1:0]),

    .noc_out_flit  (noc_out_req_flit[PLEN-1:0]),
    .noc_out_last  (noc_out_req_last),
    .noc_out_valid (noc_out_req_valid),
    .noc_out_ready (noc_out_req_ready),

    .noc_in_flit   (noc_in_res_flit[PLEN-1:0]),
    .noc_in_last   (noc_in_res_last),
    .noc_in_valid  (noc_in_res_valid),
    .noc_in_ready  (noc_in_res_ready),

    .req_HSEL      (req_HSEL),
    .req_HADDR     (req_HADDR[PLEN-1:0]),
    .req_HWDATA    (req_HWDATA[XLEN-1:0]),
    .req_HRDATA    (req_HRDATA[XLEN-1:0]),
    .req_HWRITE    (req_HWRITE),
    .req_HSIZE     (req_HSIZE[2:0]),
    .req_HBURST    (req_HBURST[2:0]),
    .req_HPROT     (req_HPROT[3:0]),
    .req_HTRANS    (req_HTRANS[1:0]),
    .req_HMASTLOCK (req_HMASTLOCK),
    .req_HREADY    (req_HREADY),
    .req_HRESP     (req_HRESP),

    .res_HSEL      (res_HSEL),
    .res_HADDR     (res_HADDR[PLEN-1:0]),
    .res_HWDATA    (res_HWDATA[XLEN-1:0]),
    .res_HRDATA    (res_HRDATA[XLEN-1:0]),
    .res_HWRITE    (res_HWRITE),
    .res_HSIZE     (res_HSIZE[2:0]),
    .res_HBURST    (res_HBURST[2:0]),
    .res_HPROT     (res_HPROT[3:0]),
    .res_HTRANS    (res_HTRANS[1:0]),
    .res_HMASTLOCK (res_HMASTLOCK),
    .res_HREADY    (res_HREADY),
    .res_HRESP     (res_HRESP)
  );

  riscv_dma_transfer_target #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .NOC_PACKET_SIZE (NOC_PACKET_SIZE)
  )
  transfer_target (
    .clk           (clk),
    .rst           (rst),

    .noc_out_flit  (noc_out_res_flit[PLEN-1:0]),
    .noc_out_last  (noc_out_res_last),
    .noc_out_valid (noc_out_res_valid),
    .noc_out_ready (noc_out_res_ready),

    .noc_in_flit   (noc_in_req_flit[PLEN-1:0]),
    .noc_in_last   (noc_in_req_last),
    .noc_in_valid  (noc_in_req_valid),
    .noc_in_ready  (noc_in_req_ready),

    .HSEL          (target_HSEL),
    .HADDR         (target_HADDR[PLEN-1:0]),
    .HWDATA        (target_HWDATA[XLEN-1:0]),
    .HRDATA        (target_HRDATA[XLEN-1:0]),
    .HWRITE        (target_HWRITE),
    .HSIZE         (target_HSIZE[2:0]),
    .HBURST        (target_HBURST[2:0]),
    .HPROT         (target_HPROT[3:0]),
    .HTRANS        (target_HTRANS[1:0]),
    .HMASTLOCK     (target_HMASTLOCK),
    .HREADY        (target_HREADY),
    .HRESP         (target_HRESP)
  );

  localparam ahb_arb_req    = 2'b00;
  localparam ahb_arb_res    = 2'b01;
  localparam ahb_arb_target = 2'b10;

  reg [1:0]     ahb_arb;
  reg [1:0] nxt_ahb_arb;

  always @(posedge clk) begin
    if (rst) begin
      ahb_arb <= ahb_arb_target;
    end
    else begin
      ahb_arb <= nxt_ahb_arb;
    end
  end

  wire ahb_arb_active;
  assign ahb_arb_active = ((ahb_arb == ahb_arb_req) & req_HMASTLOCK) |
                          ((ahb_arb == ahb_arb_res) & res_HMASTLOCK) |
                          ((ahb_arb == ahb_arb_target) & target_HMASTLOCK);

  always @(*) begin
    if (ahb_arb_active) begin
      nxt_ahb_arb = ahb_arb;
    end
    else begin
      if (target_HMASTLOCK) begin
        nxt_ahb_arb = ahb_arb_target;
      end
      else if (res_HMASTLOCK) begin
        nxt_ahb_arb = ahb_arb_res;
      end
      else if (req_HMASTLOCK) begin
        nxt_ahb_arb = ahb_arb_req;
      end
      else begin
        nxt_ahb_arb = ahb_arb_target;
      end
    end
  end

  always @(*) begin
    if (ahb_arb == ahb_arb_target) begin
      slv_HSEL = target_HSEL;
      slv_HADDR = target_HADDR;
      slv_HWDATA = target_HWDATA;
      slv_HWRITE = target_HWRITE;
      slv_HBURST = target_HBURST;
      slv_HPROT = target_HPROT;
      slv_HTRANS = target_HTRANS;
      slv_HMASTLOCK = target_HMASTLOCK;
      target_HREADY = slv_HREADY;
      target_HRDATA = slv_HRDATA;
      req_HRDATA = 64'hx;
      req_HREADY = 1'b0;
      res_HRDATA = 64'hx;
      res_HREADY = 1'b0;
    end
    else if (ahb_arb == ahb_arb_res) begin
      slv_HSEL = res_HSEL;
      slv_HADDR = res_HADDR;
      slv_HWDATA = res_HWDATA;
      slv_HWRITE = res_HWRITE;
      slv_HBURST = res_HBURST;
      slv_HPROT = res_HPROT;
      slv_HTRANS = res_HTRANS;
      slv_HMASTLOCK = res_HMASTLOCK;
      res_HREADY = slv_HREADY;
      res_HRDATA = slv_HRDATA;
      req_HRDATA = 64'hx;
      req_HREADY = 1'b0;
      target_HRDATA = 64'hx;
      target_HREADY = 1'b0;
    end
    else if (ahb_arb == ahb_arb_req) begin
      slv_HSEL = req_HSEL;
      slv_HADDR = req_HADDR;
      slv_HWDATA = req_HWDATA;
      slv_HWRITE = req_HWRITE;
      slv_HBURST = req_HBURST;
      slv_HPROT = req_HPROT;
      slv_HTRANS = req_HTRANS;
      slv_HMASTLOCK = req_HMASTLOCK;
      req_HREADY = slv_HREADY;
      req_HRDATA = slv_HRDATA;
      res_HRDATA = 64'hx;
      res_HREADY = 1'b0;
      target_HRDATA = 64'hx;
      target_HREADY = 1'b0;
    end
    else begin // if (ahb_arb == ahb_arb_req)
      slv_HSEL = 1'b0;
      slv_HADDR = 64'h0;
      slv_HWDATA = 64'h0;
      slv_HWRITE = 1'b0;
      slv_HBURST = 3'b000;
      slv_HPROT = 4'h0;
      slv_HTRANS = 2'b00;
      slv_HMASTLOCK = 1'b0;
      req_HRDATA = 64'hx;
      req_HREADY = 1'b0;
      res_HRDATA = 64'hx;
      res_HREADY = 1'b0;
      target_HRDATA = 64'hx;
      target_HREADY = 1'b0;
    end
  end
endmodule
