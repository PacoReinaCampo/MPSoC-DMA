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
//              AMBA4 AXI-Lite Bus Interface                                  //
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

  // Free running clock
  reg aclk;

  initial begin
    aclk <= 0;
    forever #5 aclk <= ~aclk;
  end

  // Reset
  reg aresetn;

  initial begin
    aresetn <= 1;
    #11;
    aresetn <= 0;
    repeat (10) @(posedge aclk);
    aresetn <= 1;
  end

  reg         test_passed;

  wire [31:0] araddr;
  wire [ 3:0] arcache;
  wire [ 3:0] arid;
  wire [ 3:0] arlen;
  wire [ 1:0] arlock;
  wire [ 2:0] arprot;
  wire        arready;
  wire [ 2:0] arsize;
  wire        arvalid;
  wire [31:0] awadr;
  wire [ 1:0] awburst;
  wire [ 3:0] awcache;
  wire [ 3:0] awid;
  wire [ 3:0] awlen;
  wire [ 1:0] awlock;
  wire [ 2:0] awprot;
  wire        awready;
  wire [ 2:0] awsize;
  wire        awvalid;
  wire [ 3:0] bid;
  wire [ 1:0] bresp;
  wire        bvalid;
  wire [31:0] rdata;
  wire [ 3:0] rid;
  wire        rlast;
  wire        rready;
  wire [ 1:0] rresp;
  wire        rvalid;
  wire        test_fail;
  wire [ 3:0] wid;
  wire        wlast;
  wire [31:0] wrdata;
  wire        wready;
  wire [ 3:0] wstrb;
  wire        wvalid;

  peripheral_bfm_master_generic_axi4 master (
    // Global Signals
    .aclk   (aclk),
    .aresetn(aresetn),

    // Write Address Channel
    .awid   (awid[3:0]),
    .awadr  (awadr[31:0]),
    .awlen  (awlen[3:0]),
    .awsize (awsize[2:0]),
    .awburst(awburst[1:0]),
    .awlock (awlock[1:0]),
    .awcache(awcache[3:0]),
    .awprot (awprot[2:0]),
    .awvalid(awvalid),
    .awready(awready),

    // Write Data Channel
    .wid   (wid[3:0]),
    .wrdata(wrdata[31:0]),
    .wstrb (wstrb[3:0]),
    .wlast (wlast),
    .wvalid(wvalid),
    .wready(wready),

    // Write Response Channel
    .bid   (bid[3:0]),
    .bresp (bresp[1:0]),
    .bvalid(bvalid),
    .bready(bready),

    // Read Address Channel
    .arid   (arid[3:0]),
    .araddr (araddr[31:0]),
    .arlen  (arlen[3:0]),
    .arsize (arsize[2:0]),
    .arlock (arlock[1:0]),
    .arcache(arcache[3:0]),
    .arprot (arprot[2:0]),
    .arvalid(arvalid),
    .arready(arready),

    // Read Data Channel
    .rid   (rid[3:0]),
    .rdata (rdata[31:0]),
    .rresp (rresp[1:0]),
    .rlast (rlast),
    .rvalid(rvalid),
    .rready(rready),

    // Test Signals
    .test_fail(test_fail)
  );

  peripheral_bfm_slave_generic_axi4 slave (
    // Global Signals
    .aclk   (aclk),
    .aresetn(aresetn),

    // Write Address Channel
    .awid   (awid[3:0]),
    .awadr  (awadr[31:0]),
    .awlen  (awlen[3:0]),
    .awsize (awsize[2:0]),
    .awburst(awburst[1:0]),
    .awlock (awlock[1:0]),
    .awcache(awcache[3:0]),
    .awprot (awprot[2:0]),
    .awvalid(awvalid),
    .awready(awready),

    // Write Data Channel
    .wid   (wid[3:0]),
    .wrdata(wrdata[31:0]),
    .wstrb (wstrb[3:0]),
    .wlast (wlast),
    .wvalid(wvalid),
    .wready(wready),

    // Write Response Channel
    .bid   (bid[3:0]),
    .bresp (bresp[1:0]),
    .bvalid(bvalid),
    .bready(bready),

    // Read Address Channel
    .arid   (arid[3:0]),
    .araddr (araddr[31:0]),
    .arlen  (arlen[3:0]),
    .arsize (arsize[2:0]),
    .arlock (arlock[1:0]),
    .arcache(arcache[3:0]),
    .arprot (arprot[2:0]),
    .arvalid(arvalid),
    .arready(arready),

    // Read Data Channel
    .rid   (rid[3:0]),
    .rdata (rdata[31:0]),
    .rresp (rresp[1:0]),
    .rlast (rlast),
    .rvalid(rvalid),
    .rready(rready)
  );

  peripheral_bfm_basic test ();
  initial begin
    @(posedge test_fail);
    $display("TEST FAIL @ %d", $time);
    repeat (10) @(posedge aclk);
    $finish;
  end

  initial begin
    test_passed <= 0;
    @(posedge test_passed);
    $display("TEST PASSED: @ %d", $time);
    repeat (10) @(posedge aclk);
    $finish;
  end
endmodule  // peripheral_bfm_testbench
