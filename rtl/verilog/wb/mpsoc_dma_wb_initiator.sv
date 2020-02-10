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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_wb_initiator #(
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
    input                                   wb_req_ack_i,
    output                                  wb_req_cyc_o,
    output                                  wb_req_stb_o,
    output                                  wb_req_we_o,
    input  [DATA_WIDTH-1:0]                 wb_req_dat_i,
    output [DATA_WIDTH-1:0]                 wb_req_dat_o,
    output [ADDR_WIDTH-1:0]                 wb_req_adr_o,
    output [           2:0]                 wb_req_cti_o,
    output [           1:0]                 wb_req_bte_o,
    output [           3:0]                 wb_req_sel_o,

    // Wishbone interface for L2R data fetch
    input                                   wb_res_ack_i,
    output                                  wb_res_cyc_o,
    output                                  wb_res_stb_o,
    output                                  wb_res_we_o,
    input  [DATA_WIDTH-1:0]                 wb_res_dat_i,
    output [DATA_WIDTH-1:0]                 wb_res_dat_o,
    output [ADDR_WIDTH-1:0]                 wb_res_adr_o,
    output [           2:0]                 wb_res_cti_o,
    output [           1:0]                 wb_res_bte_o,
    output [           3:0]                 wb_res_sel_o
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

  mpsoc_dma_wb_initiator_req
  wb_initiator_req (
    // Outputs
    .wb_req_cyc_o              (wb_req_cyc_o),
    .wb_req_stb_o              (wb_req_stb_o),
    .wb_req_we_o               (wb_req_we_o),
    .wb_req_dat_o              (wb_req_dat_o[DATA_WIDTH-1:0]),
    .wb_req_adr_o              (wb_req_adr_o[ADDR_WIDTH-1:0]),
    .wb_req_cti_o              (wb_req_cti_o[2:0]),
    .wb_req_bte_o              (wb_req_bte_o[1:0]),
    .wb_req_sel_o              (wb_req_sel_o[3:0]),
    .req_data_valid            (req_data_valid),
    .req_data                  (req_data[DATA_WIDTH-1:0]),
    // Inputs
    .clk                       (clk),
    .rst                       (rst),
    .wb_req_ack_i              (wb_req_ack_i),
    .wb_req_dat_i              (wb_req_dat_i[DATA_WIDTH-1:0]),
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

  mpsoc_dma_wb_initiator_nocres #(
    .NOC_PACKET_SIZE(NOC_PACKET_SIZE)
  )
  wb_initiator_nocres (
    // Outputs
    .noc_in_ready              (noc_in_ready),
    .wb_cyc_o                  (wb_res_cyc_o),                  // Templated
    .wb_stb_o                  (wb_res_stb_o),                  // Templated
    .wb_we_o                   (wb_res_we_o),                   // Templated
    .wb_dat_o                  (wb_res_dat_o[DATA_WIDTH-1:0]),  // Templated
    .wb_adr_o                  (wb_res_adr_o[ADDR_WIDTH-1:0]),  // Templated
    .wb_cti_o                  (wb_res_cti_o[2:0]),             // Templated
    .wb_bte_o                  (wb_res_bte_o[1:0]),             // Templated
    .wb_sel_o                  (wb_res_sel_o[3:0]),             // Templated
    .ctrl_done_pos             (ctrl_done_pos[TABLE_ENTRIES_PTRWIDTH-1:0]),
    .ctrl_done_en              (ctrl_done_en),
    // Inputs
    .clk                       (clk),
    .rst                       (rst),
    .noc_in_flit               (noc_in_flit[`FLIT_WIDTH-1:0]),
    .noc_in_valid              (noc_in_valid),
    .wb_ack_i                  (wb_res_ack_i),                 // Templated
    .wb_dat_i                  (wb_res_dat_i[DATA_WIDTH-1:0])  // Templated
  );
endmodule
