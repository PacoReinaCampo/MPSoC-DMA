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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

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

  // AHB3
  logic [   FLIT_WIDTH-1:0] noc_ahb3_in_req_flit;
  logic                     noc_ahb3_in_req_valid;
  logic                     noc_ahb3_in_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb3_in_res_flit;
  logic                     noc_ahb3_in_res_valid;
  logic                     noc_ahb3_in_res_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb3_out_req_flit;
  logic                     noc_ahb3_out_req_valid;
  logic                     noc_ahb3_out_req_ready;

  logic [   FLIT_WIDTH-1:0] noc_ahb3_out_res_flit;
  logic                     noc_ahb3_out_res_valid;
  logic                     noc_ahb3_out_res_ready;

  logic                     ahb3_if_hsel;
  logic [   ADDR_WIDTH-1:0] ahb3_if_haddr;
  logic [   DATA_WIDTH-1:0] ahb3_if_hwdata;
  logic                     ahb3_if_hwrite;
  logic [              2:0] ahb3_if_hsize;
  logic [              2:0] ahb3_if_hburst;
  logic [              3:0] ahb3_if_hprot;
  logic [              1:0] ahb3_if_htrans;
  logic                     ahb3_if_hmastlock;

  logic [   DATA_WIDTH-1:0] ahb3_if_hrdata;
  logic                     ahb3_if_hready;
  logic                     ahb3_if_hresp;

  logic                     ahb3_hsel;
  logic [   ADDR_WIDTH-1:0] ahb3_haddr;
  logic [   DATA_WIDTH-1:0] ahb3_hwdata;
  logic                     ahb3_hwrite;
  logic [              2:0] ahb3_hsize;
  logic [              2:0] ahb3_hburst;
  logic [              3:0] ahb3_hprot;
  logic [              1:0] ahb3_htrans;
  logic                     ahb3_hmastlock;

  logic [   DATA_WIDTH-1:0] ahb3_hrdata;
  logic                     ahb3_hready;
  logic                     ahb3_hresp;

  logic [TABLE_ENTRIES-1:0] irq_ahb3;

  //////////////////////////////////////////////////////////////////////////////
  // Module Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT AHB3
  peripheral_dma_top_ahb3 #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),

    .TABLE_ENTRIES         (TABLE_ENTRIES),
    .TABLE_ENTRIES_PTRWIDTH(TABLE_ENTRIES_PTRWIDTH),
    .TILEID                (TILEID),
    .NOC_PACKET_SIZE       (NOC_PACKET_SIZE),
    .GENERATE_INTERRUPT    (GENERATE_INTERRUPT)
  ) peripheral_dma_top_ahb3 (
    .clk(clk),
    .rst(rst),

    .noc_in_req_flit (noc_ahb3_in_req_flit),
    .noc_in_req_valid(noc_ahb3_in_req_valid),
    .noc_in_req_ready(noc_ahb3_in_req_ready),

    .noc_in_res_flit (noc_ahb3_in_res_flit),
    .noc_in_res_valid(noc_ahb3_in_res_valid),
    .noc_in_res_ready(noc_ahb3_in_res_ready),

    .noc_out_req_flit (noc_ahb3_out_req_flit),
    .noc_out_req_valid(noc_ahb3_out_req_valid),
    .noc_out_req_ready(noc_ahb3_out_req_ready),

    .noc_out_res_flit (noc_ahb3_out_res_flit),
    .noc_out_res_valid(noc_ahb3_out_res_valid),
    .noc_out_res_ready(noc_ahb3_out_res_ready),

    .ahb3_if_hsel     (ahb3_if_hsel),
    .ahb3_if_haddr    (ahb3_if_haddr),
    .ahb3_if_hwdata   (ahb3_if_hwdata),
    .ahb3_if_hwrite   (ahb3_if_hwrite),
    .ahb3_if_hsize    (ahb3_if_hsize),
    .ahb3_if_hburst   (ahb3_if_hburst),
    .ahb3_if_hprot    (ahb3_if_hprot),
    .ahb3_if_htrans   (ahb3_if_htrans),
    .ahb3_if_hmastlock(ahb3_if_hmastlock),

    .ahb3_if_hrdata(ahb3_if_hrdata),
    .ahb3_if_hready(ahb3_if_hready),
    .ahb3_if_hresp (ahb3_if_hresp),

    .ahb3_hsel     (ahb3_hsel),
    .ahb3_haddr    (ahb3_haddr),
    .ahb3_hwdata   (ahb3_hwdata),
    .ahb3_hwrite   (ahb3_hwrite),
    .ahb3_hsize    (ahb3_hsize),
    .ahb3_hburst   (ahb3_hburst),
    .ahb3_hprot    (ahb3_hprot),
    .ahb3_htrans   (ahb3_htrans),
    .ahb3_hmastlock(ahb3_hmastlock),

    .ahb3_hrdata(ahb3_hrdata),
    .ahb3_hready(ahb3_hready),
    .ahb3_hresp (ahb3_hresp),

    .irq(irq_ahb3)
  );
endmodule
