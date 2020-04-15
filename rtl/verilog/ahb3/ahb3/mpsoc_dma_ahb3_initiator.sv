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

module mpsoc_dma_ahb3_initiator #(
  //parameters
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter TABLE_ENTRIES = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),
  parameter TILEID = 0,
  parameter NOC_PACKET_SIZE = 16
)
  (
    input  clk,
    input  rst,
 
    // Control read (request) interface
    output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos,
    input  [`DMA_REQUEST_WIDTH-1:0]     ctrl_read_req,

    output [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
    output                              ctrl_done_en,

    input  [TABLE_ENTRIES-1:0]          valid,

    // NOC-Interface
    output [`FLIT_WIDTH-1:0]                noc_out_flit,
    output                                  noc_out_valid,
    input                                   noc_out_ready,

    input  [`FLIT_WIDTH-1:0]                noc_in_flit,
    input                                   noc_in_valid,
    output                                  noc_in_ready,

    // Wishbone interface for L2R data fetch
    input                                   ahb3_req_hready,
    output                                  ahb3_req_hmastlock,
    output                                  ahb3_req_hsel,
    output                                  ahb3_req_hwrite,
    input  [DATA_WIDTH-1:0]                 ahb3_req_hrdata,
    output [DATA_WIDTH-1:0]                 ahb3_req_hwdata,
    output [ADDR_WIDTH-1:0]                 ahb3_req_haddr,
    output [           2:0]                 ahb3_req_hburst,
    output [           1:0]                 ahb3_req_htrans,
    output [           3:0]                 ahb3_req_hprot,

    // Wishbone interface for L2R data fetch
    input                                   ahb3_res_hready,
    output                                  ahb3_res_hmastlock,
    output                                  ahb3_res_hsel,
    output                                  ahb3_res_hwrite,
    input  [DATA_WIDTH-1:0]                 ahb3_res_hrdata,
    output [DATA_WIDTH-1:0]                 ahb3_res_hwdata,
    output [ADDR_WIDTH-1:0]                 ahb3_res_haddr,
    output [           2:0]                 ahb3_res_hburst,
    output [           1:0]                 ahb3_res_htrans,
    output [           3:0]                 ahb3_res_hprot
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [DATA_WIDTH-1:0]               req_data;
  wire                                req_data_ready;
  wire                                req_data_valid;
  wire                                req_is_l2r;
  wire [ADDR_WIDTH-1:0]               req_laddr;
  wire [`DMA_REQFIELD_SIZE_WIDTH-3:0] req_size;
  wire                                req_start;


  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  mpsoc_dma_ahb3_initiator_req
  ahb3_initiator_req (
    // Outputs
    .ahb3_req_hmastlock        (ahb3_req_hmastlock),
    .ahb3_req_hsel             (ahb3_req_hsel),
    .ahb3_req_hwrite           (ahb3_req_hwrite),
    .ahb3_req_hwdata           (ahb3_req_hwdata[DATA_WIDTH-1:0]),
    .ahb3_req_haddr            (ahb3_req_haddr[ADDR_WIDTH-1:0]),
    .ahb3_req_hburst           (ahb3_req_hburst[2:0]),
    .ahb3_req_htrans           (ahb3_req_htrans[1:0]),
    .ahb3_req_hprot            (ahb3_req_hprot[3:0]),
    .req_data_valid            (req_data_valid),
    .req_data                  (req_data[DATA_WIDTH-1:0]),
    // Inputs
    .clk                       (clk),
    .rst                       (rst),
    .ahb3_req_hready           (ahb3_req_hready),
    .ahb3_req_hrdata           (ahb3_req_hrdata[DATA_WIDTH-1:0]),
    .req_start                 (req_start),
    .req_is_l2r                (req_is_l2r),
    .req_size                  (req_size[`DMA_REQFIELD_SIZE_WIDTH-3:0]),
    .req_laddr                 (req_laddr[ADDR_WIDTH-1:0]),
    .req_data_ready            (req_data_ready)
  );

  mpsoc_dma_initiator_nocreq #(
    .TILEID          (TILEID),
    .NOC_PACKET_SIZE (NOC_PACKET_SIZE)
  )
  initiator_nocreq (
    // Outputs
    .noc_out_flit               (noc_out_flit[`FLIT_WIDTH-1:0]),
    .noc_out_valid              (noc_out_valid),
    .ctrl_read_pos              (ctrl_read_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .req_start                  (req_start),
    .req_laddr                  (req_laddr[ADDR_WIDTH-1:0]),
    .req_data_ready             (req_data_ready),
    .req_is_l2r                 (req_is_l2r),
    .req_size                   (req_size[`DMA_REQFIELD_SIZE_WIDTH-3:0]),
    // Inputs
    .clk                        (clk),
    .rst                        (rst),
    .noc_out_ready              (noc_out_ready),
    .ctrl_read_req              (ctrl_read_req[`DMA_REQUEST_WIDTH-1:0]),
    .valid                      (valid[TABLE_ENTRIES-1:0]),
    .ctrl_done_pos              (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en               (ctrl_done_en),
    .req_data_valid             (req_data_valid),
    .req_data                   (req_data[DATA_WIDTH-1:0])
  );

  mpsoc_dma_ahb3_initiator_nocres #(
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  )
  ahb3_initiator_nocres (
    // Outputs
    .noc_in_ready              (noc_in_ready),
    .ahb3_hmastlock            (ahb3_res_hmastlock),               // Templated
    .ahb3_hsel                 (ahb3_res_hsel),                    // Templated
    .ahb3_hwrite               (ahb3_res_hwrite),                  // Templated
    .ahb3_hwdata               (ahb3_res_hwdata[DATA_WIDTH-1:0]),  // Templated
    .ahb3_haddr                (ahb3_res_haddr[ADDR_WIDTH-1:0]),   // Templated
    .ahb3_hburst               (ahb3_res_hburst[2:0]),             // Templated
    .ahb3_htrans               (ahb3_res_htrans[1:0]),             // Templated
    .ahb3_hprot                (ahb3_res_hprot[3:0]),              // Templated
    .ctrl_done_pos             (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en              (ctrl_done_en),
    // Inputs
    .clk                       (clk),
    .rst                       (rst),
    .noc_in_flit               (noc_in_flit[`FLIT_WIDTH-1:0]),
    .noc_in_valid              (noc_in_valid),
    .ahb3_hready               (ahb3_res_hready),                 // Templated
    .ahb3_hrdata               (ahb3_res_hrdata[DATA_WIDTH-1:0])  // Templated
  );
endmodule
