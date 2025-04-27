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
  logic [   FLIT_WIDTH-1:0] noc_ahb4_in_req_flit;
  logic                     noc_ahb4_in_req_valid;
  logic                     noc_ahb4_in_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb4_in_res_flit;
  logic                     noc_ahb4_in_res_valid;
  logic                     noc_ahb4_in_res_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb4_out_req_flit;
  logic                     noc_ahb4_out_req_valid;
  logic                     noc_ahb4_out_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb4_out_res_flit;
  logic                     noc_ahb4_out_res_valid;
  logic                     noc_ahb4_out_res_ready;

  logic                     ahb4_if_hsel;
  logic [   ADDR_WIDTH-1:0] ahb4_if_haddr;
  logic [   DATA_WIDTH-1:0] ahb4_if_hwdata;
  logic                     ahb4_if_hwrite;
  logic [              2:0] ahb4_if_hsize;
  logic [              2:0] ahb4_if_hburst;
  logic [              3:0] ahb4_if_hprot;
  logic [              1:0] ahb4_if_htrans;
  logic                     ahb4_if_hmastlock;

  logic [   DATA_WIDTH-1:0] ahb4_if_hrdata;
  logic                     ahb4_if_hready;
  logic                     ahb4_if_hresp;

  logic                     ahb4_hsel;
  logic [   ADDR_WIDTH-1:0] ahb4_haddr;
  logic [   DATA_WIDTH-1:0] ahb4_hwdata;
  logic                     ahb4_hwrite;
  logic [              2:0] ahb4_hsize;
  logic [              2:0] ahb4_hburst;
  logic [              3:0] ahb4_hprot;
  logic [              1:0] ahb4_htrans;
  logic                     ahb4_hmastlock;

  logic [   DATA_WIDTH-1:0] ahb4_hrdata;
  logic                     ahb4_hready;
  logic                     ahb4_hresp;

  logic [TABLE_ENTRIES-1:0] irq_ahb4;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT AHB4
  peripheral_dma_top_ahb4 #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),

    .TABLE_ENTRIES         (TABLE_ENTRIES),
    .TABLE_ENTRIES_PTRWIDTH(TABLE_ENTRIES_PTRWIDTH),
    .TILEID                (TILEID),
    .NOC_PACKET_SIZE       (NOC_PACKET_SIZE),
    .GENERATE_INTERRUPT    (GENERATE_INTERRUPT)
  ) peripheral_dma_top_ahb4 (
    .clk(clk),
    .rst(rst),

    .noc_in_req_flit (noc_ahb4_in_req_flit),
    .noc_in_req_valid(noc_ahb4_in_req_valid),
    .noc_in_req_ready(noc_ahb4_in_req_ready),

    .noc_in_res_flit (noc_ahb4_in_res_flit),
    .noc_in_res_valid(noc_ahb4_in_res_valid),
    .noc_in_res_ready(noc_ahb4_in_res_ready),

    .noc_out_req_flit (noc_ahb4_out_req_flit),
    .noc_out_req_valid(noc_ahb4_out_req_valid),
    .noc_out_req_ready(noc_ahb4_out_req_ready),

    .noc_out_res_flit (noc_ahb4_out_res_flit),
    .noc_out_res_valid(noc_ahb4_out_res_valid),
    .noc_out_res_ready(noc_ahb4_out_res_ready),

    .ahb4_if_hsel     (ahb4_if_hsel),
    .ahb4_if_haddr    (ahb4_if_haddr),
    .ahb4_if_hwdata   (ahb4_if_hwdata),
    .ahb4_if_hwrite   (ahb4_if_hwrite),
    .ahb4_if_hsize    (ahb4_if_hsize),
    .ahb4_if_hburst   (ahb4_if_hburst),
    .ahb4_if_hprot    (ahb4_if_hprot),
    .ahb4_if_htrans   (ahb4_if_htrans),
    .ahb4_if_hmastlock(ahb4_if_hmastlock),

    .ahb4_if_hrdata(ahb4_if_hrdata),
    .ahb4_if_hready(ahb4_if_hready),
    .ahb4_if_hresp (ahb4_if_hresp),

    .ahb4_hsel     (ahb4_hsel),
    .ahb4_haddr    (ahb4_haddr),
    .ahb4_hwdata   (ahb4_hwdata),
    .ahb4_hwrite   (ahb4_hwrite),
    .ahb4_hsize    (ahb4_hsize),
    .ahb4_hburst   (ahb4_hburst),
    .ahb4_hprot    (ahb4_hprot),
    .ahb4_htrans   (ahb4_htrans),
    .ahb4_hmastlock(ahb4_hmastlock),

    .ahb4_hrdata(ahb4_hrdata),
    .ahb4_hready(ahb4_hready),
    .ahb4_hresp (ahb4_hresp),

    .irq(irq_ahb4)
  );
endmodule
