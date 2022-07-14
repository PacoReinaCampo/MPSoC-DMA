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

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_testbench;

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  parameter ADDR_WIDTH = 32;
  parameter DATA_WIDTH = 32;

  parameter TABLE_ENTRIES          = 4;
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4);
  parameter TILEID                 = 0;
  parameter NOC_PACKET_SIZE        = 16;
  parameter GENERATE_INTERRUPT     = 1;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic clk;
  logic rst;

  // WB
  logic [`FLIT_WIDTH-1:0] noc_wb_in_req_flit;
  logic                   noc_wb_in_req_valid;
  logic                   noc_wb_in_req_ready;

  logic [`FLIT_WIDTH-1:0] noc_wb_in_res_flit;
  logic                   noc_wb_in_res_valid;
  logic                   noc_wb_in_res_ready;

  logic [`FLIT_WIDTH-1:0] noc_wb_out_req_flit;
  logic                   noc_wb_out_req_valid;
  logic                   noc_wb_out_req_ready;

  logic [`FLIT_WIDTH-1:0] noc_wb_out_res_flit;
  logic                   noc_wb_out_res_valid;
  logic                   noc_wb_out_res_ready;

  logic [ADDR_WIDTH-1:0]  wb_if_addr_i;
  logic [DATA_WIDTH-1:0]  wb_if_dat_i;
  logic                   wb_if_cyc_i;
  logic                   wb_if_stb_i;
  logic                   wb_if_we_i;
  logic [DATA_WIDTH-1:0]  wb_if_dat_o;
  logic                   wb_if_ack_o;
  logic                   wb_if_err_o;
  logic                   wb_if_rty_o;

  logic [ADDR_WIDTH-1:0] wb_adr_o;
  logic [DATA_WIDTH-1:0] wb_dat_o;
  logic                  wb_cyc_o;
  logic                  wb_stb_o;
  logic [3:0]            wb_sel_o;
  logic                  wb_we_o;
  logic                  wb_cab_o;
  logic [2:0]            wb_cti_o;
  logic [1:0]            wb_bte_o;
  logic [DATA_WIDTH-1:0] wb_dat_i;
  logic                  wb_ack_i;

  logic [TABLE_ENTRIES-1:0] irq_wb;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //DUT WB
  mpsoc_dma_wb_top #(
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),

    .TABLE_ENTRIES          ( TABLE_ENTRIES ),
    .TABLE_ENTRIES_PTRWIDTH ( TABLE_ENTRIES_PTRWIDTH ),
    .TILEID                 ( TILEID ),
    .NOC_PACKET_SIZE        ( NOC_PACKET_SIZE ),
    .GENERATE_INTERRUPT     ( GENERATE_INTERRUPT )
  )
  wb_top (
    .clk (clk),
    .rst (rst),

    .noc_in_req_flit  (noc_wb_in_req_flit),
    .noc_in_req_valid (noc_wb_in_req_valid),
    .noc_in_req_ready (noc_wb_in_req_ready),

    .noc_in_res_flit  (noc_wb_in_res_flit),
    .noc_in_res_valid (noc_wb_in_res_valid),
    .noc_in_res_ready (noc_wb_in_res_ready),

    .noc_out_req_flit  (noc_wb_out_req_flit),
    .noc_out_req_valid (noc_wb_out_req_valid),
    .noc_out_req_ready (noc_wb_out_req_ready),

    .noc_out_res_flit  (noc_wb_out_res_flit),
    .noc_out_res_valid (noc_wb_out_res_valid),
    .noc_out_res_ready (noc_wb_out_res_ready),

    .wb_if_addr_i (wb_if_addr_i),
    .wb_if_dat_i  (wb_if_dat_i),
    .wb_if_cyc_i  (wb_if_cyc_i),
    .wb_if_stb_i  (wb_if_stb_i),
    .wb_if_we_i   (wb_if_we_i ),
    .wb_if_dat_o  (wb_if_dat_o),
    .wb_if_ack_o  (wb_if_ack_o),
    .wb_if_err_o  (wb_if_err_o),
    .wb_if_rty_o  (wb_if_rty_o),

    .wb_adr_o (wb_adr_o),
    .wb_dat_o (wb_dat_o),
    .wb_cyc_o (wb_cyc_o),
    .wb_stb_o (wb_stb_o),
    .wb_sel_o (wb_sel_o),
    .wb_we_o  (wb_we_o ),
    .wb_cab_o (wb_cab_o),
    .wb_cti_o (wb_cti_o),
    .wb_bte_o (wb_bte_o),
    .wb_dat_i (wb_dat_i),
    .wb_ack_i (wb_ack_i),

    .irq (irq_wb)
  );
endmodule
