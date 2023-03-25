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
//              Peripheral-GPIO for MPSoC                                     //
//              General Purpose Input Output for MPSoC                        //
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

module peripheral_bfm_testbench;
  parameter PDATA_SIZE = 8;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  //APB signals
  logic                    PSEL;
  logic                    PENABLE;
  logic [             3:0] PADDR;
  logic [PDATA_SIZE/8-1:0] PSTRB;
  logic [PDATA_SIZE  -1:0] PWDATA;
  logic [PDATA_SIZE  -1:0] PRDATA;
  logic                    PWRITE;
  logic                    PREADY;
  logic                    PSLVERR;

  //GPIOs
  logic [PDATA_SIZE -1:0] gpio_o, gpio_i, gpio_oe;

  //IRQ
  logic irq_o;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Clock & Reset
  //

  bit PCLK, PRESETn;

  initial begin : gen_PCLK
    PCLK <= 1'b0;
    forever #10 PCLK = ~PCLK;
  end : gen_PCLK

  initial begin : gen_PRESETn
    ;
    PRESETn = 1'b1;
    //ensure falling edge of PRESETn
    #10;
    PRESETn = 1'b0;
    #32;
    PRESETn = 1'b1;
  end : gen_PRESETn
  ;

  //////////////////////////////////////////////////////////////////////////////
  //
  // TB and DUT
  //
  peripheral_bfm_apb4 #(.PDATA_SIZE(PDATA_SIZE)) bfm_apb4 (.*);

  peripheral_gpio_apb4 #(.PDATA_SIZE(PDATA_SIZE)) dut (.*);
endmodule : peripheral_bfm_testbench
