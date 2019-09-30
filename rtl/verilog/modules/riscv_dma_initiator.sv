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

`include "riscv_mpsoc_pkg.sv"
`include "riscv_dma_pkg.sv"

module riscv_dma_initiator #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter NOC_PACKET_SIZE = 16,

  parameter TABLE_ENTRIES = 4,
  parameter DMA_REQUEST_WIDTH = 199,
  parameter DMA_REQFIELD_SIZE_WIDTH = 64,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4)
)
  (
    input                               clk,
    input                               rst,

    // Control read (request) interface
    output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos,
    input  [DMA_REQUEST_WIDTH     -1:0] ctrl_read_req,

    output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
    output                              ctrl_done_en,

    input [TABLE_ENTRIES          -1:0] valid,

    // NOC-Interface
    output [PLEN                  -1:0] noc_out_flit,
    output                              noc_out_last,
    output                              noc_out_valid,
    input                               noc_out_ready,

    input  [PLEN                  -1:0] noc_in_flit,
    input                               noc_in_last,
    input                               noc_in_valid,
    output                              noc_in_ready,

    // AHB interface for L2R data fetch
    output                              req_HSEL,
    output [PLEN                  -1:0] req_HADDR,
    output [XLEN                  -1:0] req_HWDATA,
    input  [XLEN                  -1:0] req_HRDATA,
    output                              req_HWRITE,
    output [                       2:0] req_HSIZE,
    output [                       2:0] req_HBURST,
    output [                       3:0] req_HPROT,
    output [                       1:0] req_HTRANS,
    output                              req_HMASTLOCK,
    input                               req_HREADY,
    input                               req_HRESP,

    // AHB interface for L2R data fetch
    output                              res_HSEL,
    output [PLEN                  -1:0] res_HADDR,
    output [XLEN                  -1:0] res_HWDATA,
    input  [XLEN                  -1:0] res_HRDATA,
    output                              res_HWRITE,
    output [                       2:0] res_HSIZE,
    output [                       2:0] res_HBURST,
    output [                       3:0] res_HPROT,
    output [                       1:0] res_HTRANS,
    output                              res_HMASTLOCK,
    input                               res_HREADY,
    input                               res_HRESP
);

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [XLEN                   -1:0] req_data;
  wire                               req_data_ready;
  wire                               req_data_valid;
  wire                               req_is_l2r;
  wire [XLEN                   -1:0] req_laddr;
  wire [DMA_REQFIELD_SIZE_WIDTH-3:0] req_size;
  wire                               req_start;
  // End of automatics

  riscv_dma_initiator_interface #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .DMA_REQFIELD_SIZE_WIDTH (DMA_REQFIELD_SIZE_WIDTH)
  )
  dma_initiator_interface (
    .clk            (clk),
    .rst            (rst),

    .req_HSEL       (req_HSEL),
    .req_HADDR      (req_HADDR[PLEN-1:0]),
    .req_HWDATA     (req_HWDATA[XLEN-1:0]),
    .req_HRDATA     (req_HRDATA[XLEN-1:0]),
    .req_HWRITE     (req_HWRITE),
    .req_HSIZE      (req_HSIZE[2:0]),
    .req_HBURST     (req_HBURST[2:0]),
    .req_HPROT      (req_HPROT[3:0]),
    .req_HTRANS     (req_HTRANS[1:0]),
    .req_HMASTLOCK  (req_HMASTLOCK),
    .req_HREADY     (req_HREADY),
    .req_HRESP      (req_HRESP),

    .req_start      (req_start),
    .req_is_l2r     (req_is_l2r),
    .req_size       (req_size[DMA_REQFIELD_SIZE_WIDTH-3:0]),
    .req_laddr      (req_laddr[XLEN-1:0]),
    .req_data_valid (req_data_valid),
    .req_data       (req_data[XLEN-1:0]),
    .req_data_ready (req_data_ready)
  );


  riscv_dma_initiator_request #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .TABLE_ENTRIES (TABLE_ENTRIES),
    .DMA_REQUEST_WIDTH (DMA_REQUEST_WIDTH),
    .DMA_REQFIELD_SIZE_WIDTH (DMA_REQFIELD_SIZE_WIDTH),
    .TABLE_ENTRIES_PTRWIDTH (TABLE_ENTRIES_PTRWIDTH)
  )
  dma_initiator_request (
    .clk            (clk),
    .rst            (rst),

    .noc_out_flit   (noc_out_flit[PLEN-1:0]),
    .noc_out_last   (noc_out_last),
    .noc_out_valid  (noc_out_valid),
    .noc_out_ready  (noc_out_ready),

    .ctrl_read_pos  (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_read_req  (ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),

    .valid          (valid[TABLE_ENTRIES-1:0]),

    .ctrl_done_pos  (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en   (ctrl_done_en),

    .req_start      (req_start),
    .req_laddr      (req_laddr[XLEN-1:0]),
    .req_data_valid (req_data_valid),
    .req_data_ready (req_data_ready),
    .req_data       (req_data[XLEN-1:0]),
    .req_is_l2r     (req_is_l2r),
    .req_size       (req_size[DMA_REQFIELD_SIZE_WIDTH-3:0])
  );


  riscv_dma_initiator_response #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .NOC_PACKET_SIZE (NOC_PACKET_SIZE),

    .TABLE_ENTRIES_PTRWIDTH (TABLE_ENTRIES_PTRWIDTH)
  )
  dma_initiator_response (
    .clk           (clk),
    .rst           (rst),

    .noc_in_flit   (noc_in_flit[PLEN-1:0]),
    .noc_in_last   (noc_in_last),
    .noc_in_valid  (noc_in_valid),
    .noc_in_ready  (noc_in_ready),

    .HSEL          (res_HSEL),
    .HADDR         (res_HADDR[PLEN-1:0]),
    .HWDATA        (res_HWDATA[XLEN-1:0]),
    .HRDATA        (res_HRDATA[XLEN-1:0]),
    .HWRITE        (res_HWRITE),
    .HSIZE         (res_HSIZE[2:0]),
    .HBURST        (res_HBURST[2:0]),
    .HPROT         (res_HPROT[3:0]),
    .HTRANS        (res_HTRANS[1:0]),
    .HMASTLOCK     (res_HMASTLOCK),
    .HREADY        (res_HREADY),
    .HRESP         (res_HRESP),

    .ctrl_done_pos (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en  (ctrl_done_en)
  );
endmodule
