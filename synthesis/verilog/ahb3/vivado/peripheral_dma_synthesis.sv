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
//              Universal Asynchronous Receiver-Transmitter                   //
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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module peripheral_dma_synthesis #(
  parameter HADDR_SIZE     = 8,
  parameter HDATA_SIZE     = 32,
  parameter APB_ADDR_WIDTH = 8,
  parameter APB_DATA_WIDTH = 32,
  parameter SYNC_DEPTH     = 3
) (
  //Common signals
  input HRESETn,
  input HCLK,

  //UART AHB3
  input                         dma_HSEL,
  input      [HADDR_SIZE  -1:0] dma_HADDR,
  input      [HDATA_SIZE  -1:0] dma_HWDATA,
  output reg [HDATA_SIZE  -1:0] dma_HRDATA,
  input                         dma_HWRITE,
  input      [             2:0] dma_HSIZE,
  input      [             2:0] dma_HBURST,
  input      [             3:0] dma_HPROT,
  input      [             1:0] dma_HTRANS,
  input                         dma_HMASTLOCK,
  output reg                    dma_HREADYOUT,
  input                         dma_HREADY,
  output reg                    dma_HRESP
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  //Common signals
  logic [APB_ADDR_WIDTH -1:0] dma_PADDR;
  logic [APB_DATA_WIDTH -1:0] dma_PWDATA;
  logic                       dma_PWRITE;
  logic                       dma_PSEL;
  logic                       dma_PENABLE;
  logic [APB_DATA_WIDTH -1:0] dma_PRDATA;
  logic                       dma_PREADY;
  logic                       dma_PSLVERR;

  logic                       dma_rx_i;  // Receiver input
  logic                       dma_tx_o;  // Transmitter output

  logic                       dma_event_o;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //DUT AHB3
  peripheral_bridge_apb2ahb #(
    .HADDR_SIZE(HADDR_SIZE),
    .HDATA_SIZE(HDATA_SIZE),
    .PADDR_SIZE(APB_ADDR_WIDTH),
    .PDATA_SIZE(APB_DATA_WIDTH),
    .SYNC_DEPTH(SYNC_DEPTH)
  ) bridge_apb2ahb (
    //AHB Slave Interface
    .HRESETn(HRESETn),
    .HCLK   (HCLK),

    .HSEL     (dma_HSEL),
    .HADDR    (dma_HADDR),
    .HWDATA   (dma_HWDATA),
    .HRDATA   (dma_HRDATA),
    .HWRITE   (dma_HWRITE),
    .HSIZE    (dma_HSIZE),
    .HBURST   (dma_HBURST),
    .HPROT    (dma_HPROT),
    .HTRANS   (dma_HTRANS),
    .HMASTLOCK(dma_HMASTLOCK),
    .HREADYOUT(dma_HREADYOUT),
    .HREADY   (dma_HREADY),
    .HRESP    (dma_HRESP),

    //APB Master Interface
    .PRESETn(HRESETn),
    .PCLK   (HCLK),

    .PSEL   (dma_PSEL),
    .PENABLE(dma_PENABLE),
    .PPROT  (),
    .PWRITE (dma_PWRITE),
    .PSTRB  (),
    .PADDR  (dma_PADDR),
    .PWDATA (dma_PWDATA),
    .PRDATA (dma_PRDATA),
    .PREADY (dma_PREADY),
    .PSLVERR(dma_PSLVERR)
  );

  peripheral_apb4_dma #(
    .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
    .APB_DATA_WIDTH(APB_DATA_WIDTH)
  ) apb4_dma (
    .RSTN(HRESETn),
    .CLK (HCLK),

    .PADDR  (dma_PADDR),
    .PWDATA (dma_PWDATA),
    .PWRITE (dma_PWRITE),
    .PSEL   (dma_PSEL),
    .PENABLE(dma_PENABLE),
    .PRDATA (dma_PRDATA),
    .PREADY (dma_PREADY),
    .PSLVERR(dma_PSLVERR),

    .rx_i(dma_rx_i),
    .tx_o(dma_tx_o),

    .event_o(dma_event_o)
  );
endmodule
