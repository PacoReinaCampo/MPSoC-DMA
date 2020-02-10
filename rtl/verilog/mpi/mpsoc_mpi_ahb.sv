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

module mpsoc_mpi_ahb #(
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

    input  [               5:0] HADDR,
    input                       HWRITE,
    input                       HMASTLOCK,
    input                       HSEL,
    input  [NoC_DATA_WIDTH-1:0] HRDATA,
    output [NoC_DATA_WIDTH-1:0] HWDATA,
    output                      HREADY,

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

  assign bus_addr    = HADDR;
  assign bus_we      = HWRITE;
  assign bus_en      = HMASTLOCK & HSEL;
  assign bus_data_in = HRDATA;
  assign HWDATA      = bus_data_out;
  assign HREADY      = bus_ack;

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
