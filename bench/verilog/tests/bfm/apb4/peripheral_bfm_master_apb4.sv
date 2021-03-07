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
//              Peripheral-BFM for MPSoC                                      //
//              Bus Functional Model for MPSoC                                //
//              AMBA4 APB-Lite Bus Interface                                  //
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

module peripheral_bfm_master_apb4 #(
  parameter PADDR_SIZE = 16,
  parameter PDATA_SIZE = 32
)
  (
    input                         PRESETn,
    input                         PCLK,

    //APB Master Interface
    output reg                    PSEL,
    output reg                    PENABLE,
    output reg [PADDR_SIZE  -1:0] PADDR,
    output reg [PDATA_SIZE/8-1:0] PSTRB,
    output reg [PDATA_SIZE  -1:0] PWDATA,
    input      [PDATA_SIZE  -1:0] PRDATA,
    output reg                    PWRITE,
    input                         PREADY,
    input                         PSLVERR
  );

  always @(negedge PRESETn) reset();

  /////////////////////////////////////////////////////////
  //
  // Tasks
  //

  task automatic reset();
    //Reset AHB Bus
    PSEL      = 1'b0;
    PENABLE   = 1'b0;
    PADDR     = 'hx;
    PSTRB     = 'hx;
    PWDATA    = 'hx;
    PWRITE    = 'hx;

    @(posedge PRESETn);
  endtask

  task automatic write (
    input [PADDR_SIZE  -1:0] address,
    input [PDATA_SIZE/8-1:0] strb,
    input [PDATA_SIZE  -1:0] data
  );
    PSEL    = 1'b1;
    PADDR   = address;
    PSTRB   = strb;
    PWDATA  = data;
    PWRITE  = 1'b1;
    @(posedge PCLK);

    PENABLE = 1'b1;
    @(posedge PCLK);

    while (!PREADY) @(posedge PCLK);

    PSEL    = 1'b0;
    PADDR   = {PADDR_SIZE{1'bx}};
    PSTRB   = {PDATA_SIZE/8{1'bx}};
    PWDATA  = {PDATA_SIZE{1'bx}};
    PWRITE  = 1'bx;
    PENABLE = 1'b0;
  endtask

  task automatic read (
    input  [PADDR_SIZE -1:0] address,
    output [PDATA_SIZE -1:0] data
  );
    PSEL    = 1'b1;
    PADDR   = address;
    PSTRB   = {PDATA_SIZE/8{1'bx}};
    PWDATA  = {PDATA_SIZE{1'bx}};
    PWRITE  = 1'b0;
    @(posedge PCLK);

    PENABLE = 1'b1;
    @(posedge PCLK);

    while (!PREADY) @(posedge PCLK);

    data = PRDATA;

    PSEL    = 1'b0;
    PADDR   = {PADDR_SIZE{1'bx}};
    PWRITE  = 1'bx;
    PENABLE = 1'b0;
  endtask
endmodule : peripheral_bfm_master_apb4
