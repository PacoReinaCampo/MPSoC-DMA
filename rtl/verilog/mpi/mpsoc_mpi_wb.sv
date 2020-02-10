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
//              Message Passing Interface                                     //
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

module mpsoc_mpi_wb #(
  parameter NoC_DATA_WIDTH = 32,
  parameter NoC_TYPE_WIDTH = 2,
  parameter FIFO_DEPTH     = 16,
  parameter NoC_FLIT_WIDTH = 34,
  parameter SIZE_WIDTH     = 5
)
  (
    input clk,
    input rst,

    // NoC interface
    output [NoC_FLIT_WIDTH-1:0] noc_out_flit,
    output                      noc_out_valid,
    input                       noc_out_ready,

    input  [NoC_FLIT_WIDTH-1:0] noc_in_flit,
    input                       noc_in_valid,
    output                      noc_in_ready,

    input  [               5:0] wb_addr_i,
    input                       wb_we_i,
    input                       wb_cyc_i,
    input                       wb_stb_i,
    input  [NoC_DATA_WIDTH-1:0] wb_dat_i,
    output [NoC_DATA_WIDTH-1:0] wb_dat_o,
    output                      wb_ack_o,

    output                      irq
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Bus side (generic)
  wire [               5:0] bus_addr;
  wire                      bus_we;
  wire                      bus_en;
  wire [NoC_DATA_WIDTH-1:0] bus_data_in;
  wire [NoC_DATA_WIDTH-1:0] bus_data_out;
  wire                      bus_ack;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign bus_addr    = wb_addr_i;
  assign bus_we      = wb_we_i;
  assign bus_en      = wb_cyc_i & wb_stb_i;
  assign bus_data_in = wb_dat_i;
  assign wb_dat_o    = bus_data_out;
  assign wb_ack_o    = bus_ack;

  mpsoc_mpi #(
    .NoC_DATA_WIDTH ( NoC_DATA_WIDTH ),
    .NoC_TYPE_WIDTH ( NoC_TYPE_WIDTH ),
    .FIFO_DEPTH     ( FIFO_DEPTH     )
  )
  mpi (
    .clk                     (clk),
    .rst                     (rst),

    // Outputs
    .noc_out_flit            (noc_out_flit[NoC_FLIT_WIDTH-1:0]),
    .noc_out_valid           (noc_out_valid),
    .noc_in_ready            (noc_in_ready),
    // Inputs
    .noc_out_ready           (noc_out_ready),
    .noc_in_flit             (noc_in_flit[NoC_FLIT_WIDTH-1:0]),
    .noc_in_valid            (noc_in_valid),

    .bus_data_out            (bus_data_out[NoC_DATA_WIDTH-1:0]),
    .bus_ack                 (bus_ack),
    .irq                     (irq),

    .bus_addr                (bus_addr[5:0]),
    .bus_we                  (bus_we),
    .bus_en                  (bus_en),
    .bus_data_in             (bus_data_in[NoC_DATA_WIDTH-1:0])
  );
endmodule // mpsoc_mpi_wb
