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
//              WishBone Bus Interface                                        //
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
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_dma_pkg::*;

module peripheral_dma_testbench;

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  parameter ADDR_WIDTH = 32;
  parameter DATA_WIDTH = 32;

  parameter TABLE_ENTRIES = 4;
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4);
  parameter TILEID = 0;
  parameter NOC_PACKET_SIZE = 16;
  parameter GENERATE_INTERRUPT = 1;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic                     clk;
  logic                     rst;

  // AHB4
  logic [   FLIT_WIDTH-1:0] noc_tl_in_req_flit;
  logic                     noc_tl_in_req_valid;
  logic                     noc_tl_in_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_tl_in_res_flit;
  logic                     noc_tl_in_res_valid;
  logic                     noc_tl_in_res_ready;

  logic [   FLIT_WIDTH-1:0] noc_tl_out_req_flit;
  logic                     noc_tl_out_req_valid;
  logic                     noc_tl_out_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_tl_out_res_flit;
  logic                     noc_tl_out_res_valid;
  logic                     noc_tl_out_res_ready;

  logic                     tl_if_hsel;
  logic [   ADDR_WIDTH-1:0] tl_if_haddr;
  logic [   DATA_WIDTH-1:0] tl_if_hwdata;
  logic                     tl_if_hwrite;
  logic [              2:0] tl_if_hsize;
  logic [              2:0] tl_if_hburst;
  logic [              3:0] tl_if_hprot;
  logic [              1:0] tl_if_htrans;
  logic                     tl_if_hmastlock;

  logic [   DATA_WIDTH-1:0] tl_if_hrdata;
  logic                     tl_if_hready;
  logic                     tl_if_hresp;

  logic                     tl_hsel;
  logic [   ADDR_WIDTH-1:0] tl_haddr;
  logic [   DATA_WIDTH-1:0] tl_hwdata;
  logic                     tl_hwrite;
  logic [              2:0] tl_hsize;
  logic [              2:0] tl_hburst;
  logic [              3:0] tl_hprot;
  logic [              1:0] tl_htrans;
  logic                     tl_hmastlock;

  logic [   DATA_WIDTH-1:0] tl_hrdata;
  logic                     tl_hready;
  logic                     tl_hresp;

  logic [TABLE_ENTRIES-1:0] irq_tl;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT AHB4
  peripheral_dma_top_tl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),

    .TABLE_ENTRIES         (TABLE_ENTRIES),
    .TABLE_ENTRIES_PTRWIDTH(TABLE_ENTRIES_PTRWIDTH),
    .TILEID                (TILEID),
    .NOC_PACKET_SIZE       (NOC_PACKET_SIZE),
    .GENERATE_INTERRUPT    (GENERATE_INTERRUPT)
  ) peripheral_dma_top_tl (
    .clk(clk),
    .rst(rst),

    .noc_in_req_flit (noc_tl_in_req_flit),
    .noc_in_req_valid(noc_tl_in_req_valid),
    .noc_in_req_ready(noc_tl_in_req_ready),

    .noc_in_res_flit (noc_tl_in_res_flit),
    .noc_in_res_valid(noc_tl_in_res_valid),
    .noc_in_res_ready(noc_tl_in_res_ready),

    .noc_out_req_flit (noc_tl_out_req_flit),
    .noc_out_req_valid(noc_tl_out_req_valid),
    .noc_out_req_ready(noc_tl_out_req_ready),

    .noc_out_res_flit (noc_tl_out_res_flit),
    .noc_out_res_valid(noc_tl_out_res_valid),
    .noc_out_res_ready(noc_tl_out_res_ready),

    .tl_if_hsel     (tl_if_hsel),
    .tl_if_haddr    (tl_if_haddr),
    .tl_if_hwdata   (tl_if_hwdata),
    .tl_if_hwrite   (tl_if_hwrite),
    .tl_if_hsize    (tl_if_hsize),
    .tl_if_hburst   (tl_if_hburst),
    .tl_if_hprot    (tl_if_hprot),
    .tl_if_htrans   (tl_if_htrans),
    .tl_if_hmastlock(tl_if_hmastlock),

    .tl_if_hrdata(tl_if_hrdata),
    .tl_if_hready(tl_if_hready),
    .tl_if_hresp (tl_if_hresp),

    .tl_hsel     (tl_hsel),
    .tl_haddr    (tl_haddr),
    .tl_hwdata   (tl_hwdata),
    .tl_hwrite   (tl_hwrite),
    .tl_hsize    (tl_hsize),
    .tl_hburst   (tl_hburst),
    .tl_hprot    (tl_hprot),
    .tl_htrans   (tl_htrans),
    .tl_hmastlock(tl_hmastlock),

    .tl_hrdata(tl_hrdata),
    .tl_hready(tl_hready),
    .tl_hresp (tl_hresp),

    .irq(irq_tl)
  );
endmodule
