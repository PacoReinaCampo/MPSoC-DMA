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

module riscv_dma_testbench;

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  parameter XLEN = 64;
  parameter PLEN = 64;

  parameter CHANNELS = 2;

  parameter NOC_PACKET_SIZE = 16;

  parameter TABLE_ENTRIES = 4;
  parameter DMA_REQMASK_WIDTH = 5;
  parameter DMA_REQUEST_WIDTH = 199;
  parameter DMA_REQFIELD_SIZE_WIDTH = 64;
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  wire                      clk;
  wire                      rst;

  wire [PLEN          -1:0] noc_in_req_flit;
  wire                      noc_in_req_last;
  wire                      noc_in_req_valid;
  wire                      noc_in_req_ready;

  wire [PLEN          -1:0] noc_in_res_flit;
  wire                      noc_in_res_last;
  wire                      noc_in_res_valid;
  wire                      noc_in_res_ready;

  wire [PLEN          -1:0] noc_out_req_flit;
  wire                      noc_out_req_last;
  wire                      noc_out_req_valid;
  wire                      noc_out_req_ready;

  wire [PLEN          -1:0] noc_out_res_flit;
  wire                      noc_out_res_last;
  wire                      noc_out_res_valid;
  wire                      noc_out_res_ready;

  wire [TABLE_ENTRIES -1:0] irq;

  //AHB master interface
  wire                      mst_HSEL;
  wire [PLEN          -1:0] mst_HADDR;
  wire [XLEN          -1:0] mst_HWDATA;
  wire [XLEN          -1:0] mst_HRDATA;
  wire                      mst_HWRITE;
  wire [               2:0] mst_HSIZE;
  wire [               2:0] mst_HBURST;
  wire [               3:0] mst_HPROT;
  wire [               1:0] mst_HTRANS;
  wire                      mst_HMASTLOCK;
  wire                      mst_HREADYOUT;
  wire                      mst_HRESP;

  //AHB slave interface
  reg                       slv_HSEL;
  reg  [PLEN          -1:0] slv_HADDR;
  reg  [XLEN          -1:0] slv_HWDATA;
  wire [XLEN          -1:0] slv_HRDATA;
  reg                       slv_HWRITE;
  reg  [               2:0] slv_HSIZE;
  reg  [               2:0] slv_HBURST;
  reg  [               3:0] slv_HPROT;
  reg  [               1:0] slv_HTRANS;
  reg                       slv_HMASTLOCK;
  wire                      slv_HREADY;
  wire                      slv_HRESP;

  //NoC Interface
  wire [CHANNELS-1:0][PLEN-1:0] noc_mpb_in_flit;
  wire [CHANNELS-1:0]           noc_mpb_in_last;
  wire [CHANNELS-1:0]           noc_mpb_in_valid;
  reg  [CHANNELS-1:0]           noc_mpb_in_ready;

  reg  [CHANNELS-1:0][PLEN-1:0] noc_mpb_out_flit;
  reg  [CHANNELS-1:0]           noc_mpb_out_last;
  reg  [CHANNELS-1:0]           noc_mpb_out_valid;
  wire [CHANNELS-1:0]           noc_mpb_out_ready;

  //AHB MPB master interface
  wire                      mst_mpb_HSEL;
  wire [PLEN          -1:0] mst_mpb_HADDR;
  wire [PLEN          -1:0] mst_mpb_HWDATA;
  wire [PLEN          -1:0] mst_mpb_HRDATA;
  wire                      mst_mpb_HWRITE;
  wire [               2:0] mst_mpb_HSIZE;
  wire [               2:0] mst_mpb_HBURST;
  wire [               3:0] mst_mpb_HPROT;
  wire [               1:0] mst_mpb_HTRANS;
  wire                      mst_mpb_HMASTLOCK;
  wire                      mst_mpb_HREADYOUT;
  wire                      mst_mpb_HRESP;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //DUT
  riscv_dma #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .NOC_PACKET_SIZE (NOC_PACKET_SIZE),

    .TABLE_ENTRIES           ( TABLE_ENTRIES           ),
    .DMA_REQMASK_WIDTH       ( DMA_REQMASK_WIDTH       ),
    .DMA_REQUEST_WIDTH       ( DMA_REQUEST_WIDTH       ),
    .DMA_REQFIELD_SIZE_WIDTH ( DMA_REQFIELD_SIZE_WIDTH ),
    .TABLE_ENTRIES_PTRWIDTH  ( TABLE_ENTRIES_PTRWIDTH  )
  )
  dma (
    .clk (clk),
    .rst (rst),

    .noc_in_req_flit  (noc_in_req_flit),
    .noc_in_req_last  (noc_in_req_last),
    .noc_in_req_valid (noc_in_req_valid),
    .noc_in_req_ready (noc_in_req_ready),

    .noc_in_res_flit  (noc_in_res_flit),
    .noc_in_res_last  (noc_in_res_last),
    .noc_in_res_valid (noc_in_res_valid),
    .noc_in_res_ready (noc_in_res_ready),

    .noc_out_req_flit  (noc_out_req_flit),
    .noc_out_req_last  (noc_out_req_last),
    .noc_out_req_valid (noc_out_req_valid),
    .noc_out_req_ready (noc_out_req_ready),

    .noc_out_res_flit  (noc_out_res_flit),
    .noc_out_res_last  (noc_out_res_last),
    .noc_out_res_valid (noc_out_res_valid),
    .noc_out_res_ready (noc_out_res_ready),

    .irq (irq),

    //AHB master interface
    .mst_HSEL      (mst_HSEL),
    .mst_HADDR     (mst_HADDR),
    .mst_HWDATA    (mst_HWDATA),
    .mst_HRDATA    (mst_HRDATA),
    .mst_HWRITE    (mst_HWRITE),
    .mst_HSIZE     (mst_HSIZE),
    .mst_HBURST    (mst_HBURST),
    .mst_HPROT     (mst_HPROT),
    .mst_HTRANS    (mst_HTRANS),
    .mst_HMASTLOCK (mst_HMASTLOCK),
    .mst_HREADYOUT (mst_HREADYOUT),
    .mst_HRESP     (mst_HRESP),

    //AHB slave interface
    .slv_HSEL      (slv_HSEL),
    .slv_HADDR     (slv_HADDR),
    .slv_HWDATA    (slv_HWDATA),
    .slv_HRDATA    (slv_HRDATA),
    .slv_HWRITE    (slv_HWRITE),
    .slv_HSIZE     (slv_HSIZE),
    .slv_HBURST    (slv_HBURST),
    .slv_HPROT     (slv_HPROT),
    .slv_HTRANS    (slv_HTRANS),
    .slv_HMASTLOCK (slv_HMASTLOCK),
    .slv_HREADY    (slv_HREADY),
    .slv_HRESP     (slv_HRESP)
  );

  //Instantiate RISC-V Message Passing Buffer End-Point
  riscv_mpb #(
    .PLEN     ( PLEN ),
    .XLEN     ( XLEN ),
    .CHANNELS ( CHANNELS ),
    .SIZE     ( 2 )
  )
  mpb (
    //Common signals
    .HRESETn ( rst ),
    .HCLK    ( clk ),

    //NoC Interface
    .noc_in_flit   ( noc_mpb_in_flit   ),
    .noc_in_last   ( noc_mpb_in_last   ),
    .noc_in_valid  ( noc_mpb_in_valid  ),
    .noc_in_ready  ( noc_mpb_in_ready  ),

    .noc_out_flit  ( noc_mpb_out_flit  ),
    .noc_out_last  ( noc_mpb_out_last  ),
    .noc_out_valid ( noc_mpb_out_valid ),
    .noc_out_ready ( noc_mpb_out_ready ),

    //AHB input interface
    .mst_HSEL      ( mst_mpb_HSEL      ),
    .mst_HADDR     ( mst_mpb_HADDR     ),
    .mst_HWDATA    ( mst_mpb_HWDATA    ),
    .mst_HRDATA    ( mst_mpb_HRDATA    ),
    .mst_HWRITE    ( mst_mpb_HWRITE    ),
    .mst_HSIZE     ( mst_mpb_HSIZE     ),
    .mst_HBURST    ( mst_mpb_HBURST    ),
    .mst_HPROT     ( mst_mpb_HPROT     ),
    .mst_HTRANS    ( mst_mpb_HTRANS    ),
    .mst_HMASTLOCK ( mst_mpb_HMASTLOCK ),
    .mst_HREADYOUT ( mst_mpb_HREADYOUT ),
    .mst_HRESP     ( mst_mpb_HRESP     )
  );
endmodule
