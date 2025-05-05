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

module peripheral_dma_initiator_axi4 #(
  // parameters
  parameter ADDR_WIDTH             = 32,
  parameter DATA_WIDTH             = 32,
  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID                 = 0,
  parameter NOC_PACKET_SIZE        = 16
) (
  input clk,
  input rst,

  // Control read (request) interface
  output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos,
  input  [     DMA_REQUEST_WIDTH-1:0] ctrl_read_req,

  output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
  output                              ctrl_done_en,

  input [TABLE_ENTRIES-1:0] valid,

  // NOC-Interface
  output [FLIT_WIDTH-1:0] noc_out_flit,
  output                  noc_out_valid,
  input                   noc_out_ready,

  input  [FLIT_WIDTH-1:0] noc_in_flit,
  input                   noc_in_valid,
  output                  noc_in_ready,

  // Wishbone interface for L2R data fetch
  output                  axi4_req_hsel,
  output [ADDR_WIDTH-1:0] axi4_req_haddr,
  output [DATA_WIDTH-1:0] axi4_req_hwdata,
  output                  axi4_req_hwrite,
  output [           2:0] axi4_req_hburst,
  output [           3:0] axi4_req_hprot,
  output [           1:0] axi4_req_htrans,
  output                  axi4_req_hmastlock,

  input [DATA_WIDTH-1:0] axi4_req_hrdata,
  input                  axi4_req_hready,

  // Wishbone interface for L2R data fetch
  output                  axi4_res_hsel,
  output [ADDR_WIDTH-1:0] axi4_res_haddr,
  output [DATA_WIDTH-1:0] axi4_res_hwdata,
  output                  axi4_res_hwrite,
  output [           2:0] axi4_res_hburst,
  output [           3:0] axi4_res_hprot,
  output [           1:0] axi4_res_htrans,
  output                  axi4_res_hmastlock,

  input [DATA_WIDTH-1:0] axi4_res_hrdata,
  input                  axi4_res_hready
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [DATA_WIDTH             -1:0] req_data;
  wire                               req_data_ready;
  wire                               req_data_valid;
  wire                               req_is_l2r;
  wire [ADDR_WIDTH             -1:0] req_laddr;
  wire [DMA_REQFIELD_SIZE_WIDTH-3:0] req_size;
  wire                               req_start;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  peripheral_dma_initiator_req_axi4 dma_initiator_req_axi4 (
    .clk(clk),
    .rst(rst),

    .axi4_req_hsel     (axi4_req_hsel),
    .axi4_req_haddr    (axi4_req_haddr[ADDR_WIDTH-1:0]),
    .axi4_req_hwdata   (axi4_req_hwdata[DATA_WIDTH-1:0]),
    .axi4_req_hwrite   (axi4_req_hwrite),
    .axi4_req_hburst   (axi4_req_hburst[2:0]),
    .axi4_req_hprot    (axi4_req_hprot[3:0]),
    .axi4_req_htrans   (axi4_req_htrans[1:0]),
    .axi4_req_hmastlock(axi4_req_hmastlock),

    .axi4_req_hready(axi4_req_hready),
    .axi4_req_hrdata(axi4_req_hrdata[DATA_WIDTH-1:0]),

    .req_start     (req_start),
    .req_is_l2r    (req_is_l2r),
    .req_size      (req_size[DMA_REQFIELD_SIZE_WIDTH-3:0]),
    .req_laddr     (req_laddr[ADDR_WIDTH-1:0]),
    .req_data_valid(req_data_valid),
    .req_data      (req_data[DATA_WIDTH-1:0]),
    .req_data_ready(req_data_ready)
  );

  peripheral_dma_initiator_nocreq #(
    .TILEID         (TILEID),
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  ) dma_initiator_nocreq (
    .clk(clk),
    .rst(rst),

    .noc_out_flit (noc_out_flit[FLIT_WIDTH-1:0]),
    .noc_out_valid(noc_out_valid),
    .noc_out_ready(noc_out_ready),

    .ctrl_read_pos(ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_read_req(ctrl_read_req[DMA_REQUEST_WIDTH-1:0]),

    .valid(valid[TABLE_ENTRIES-1:0]),

    .ctrl_done_pos(ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en (ctrl_done_en),

    .req_start     (req_start),
    .req_laddr     (req_laddr[ADDR_WIDTH-1:0]),
    .req_data_valid(req_data_valid),
    .req_data_ready(req_data_ready),
    .req_data      (req_data[DATA_WIDTH-1:0]),
    .req_is_l2r    (req_is_l2r),
    .req_size      (req_size[DMA_REQFIELD_SIZE_WIDTH-3:0])
  );

  peripheral_dma_initiator_nocres_axi4 #(
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  ) dma_initiator_nocres_axi4 (
    .clk(clk),
    .rst(rst),

    .noc_in_flit (noc_in_flit[FLIT_WIDTH-1:0]),
    .noc_in_valid(noc_in_valid),
    .noc_in_ready(noc_in_ready),

    .axi4_hsel     (axi4_res_hsel),
    .axi4_haddr    (axi4_res_haddr[ADDR_WIDTH-1:0]),
    .axi4_hwdata   (axi4_res_hwdata[DATA_WIDTH-1:0]),
    .axi4_hwrite   (axi4_res_hwrite),
    .axi4_hburst   (axi4_res_hburst[2:0]),
    .axi4_hprot    (axi4_res_hprot[3:0]),
    .axi4_htrans   (axi4_res_htrans[1:0]),
    .axi4_hmastlock(axi4_res_hmastlock),

    .axi4_hrdata(axi4_res_hrdata[DATA_WIDTH-1:0]),
    .axi4_hready(axi4_res_hready),

    .ctrl_done_pos(ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en (ctrl_done_en)
  );
endmodule
