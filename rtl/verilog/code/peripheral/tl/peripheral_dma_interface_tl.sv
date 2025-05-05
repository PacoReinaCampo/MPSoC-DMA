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
//              AMBA4 AHB-Lite Bus Interface                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Stefan Wallentowitz <stefan@wallentowitz.de>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_dma_pkg::*;

module peripheral_dma_interface_tl #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = 2,

  parameter TILEID = 0
) (
  input clk,
  input rst,

  input                  biu_if_hsel,
  input [ADDR_WIDTH-1:0] biu_if_haddr,
  input [DATA_WIDTH-1:0] biu_if_hwdata,
  input                  biu_if_hwrite,
  input                  biu_if_hmastlock,

  output reg [DATA_WIDTH-1:0] biu_if_hrdata,
  output                      biu_if_hready,

  output [DMA_REQUEST_WIDTH     -1:0] if_write_req,
  output [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos,
  output [DMA_REQMASK_WIDTH     -1:0] if_write_select,
  output                              if_write_en,

  // Interface read (status) interface
  output [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos,
  output                              if_valid_set,
  output                              if_valid_en,
  output                              if_validrd_en,

  input [TABLE_ENTRIES-1:0] done
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  genvar i;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  assign if_write_req   = {biu_if_hwdata[DMA_REQFIELD_LADDR_WIDTH-1:0], biu_if_hwdata[DMA_REQFIELD_SIZE_WIDTH-1:0], biu_if_hwdata[DMA_REQFIELD_RTILE_WIDTH-1:0], biu_if_hwdata[DMA_REQFIELD_RADDR_WIDTH-1:0], biu_if_hwdata[0]};

  assign if_write_pos   = biu_if_haddr[TABLE_ENTRIES_PTRWIDTH+4:5];  // ptrwidth MUST be <= 7 (=128 entries)
  assign if_write_en    = biu_if_hmastlock & biu_if_hsel & biu_if_hwrite;

  assign if_valid_pos   = biu_if_haddr[TABLE_ENTRIES_PTRWIDTH+4:5];  // ptrwidth MUST be <= 7 (=128 entries)
  assign if_valid_en    = biu_if_hmastlock & biu_if_hsel & (biu_if_haddr[4:0] == 5'h14) & biu_if_hwrite;
  assign if_validrd_en  = biu_if_hmastlock & biu_if_hsel & (biu_if_haddr[4:0] == 5'h14) & ~biu_if_hwrite;
  assign if_valid_set   = biu_if_hwrite | (~biu_if_hwrite & ~done[if_valid_pos]);

  assign biu_if_hready = biu_if_hmastlock & biu_if_hsel;

  always @(*) begin
    if (biu_if_haddr[4:0] == 5'h14) begin
      biu_if_hrdata = {31'h0, done[if_valid_pos]};
    end
  end

  // This assumes, that mask and address match
  generate
    for (i = 0; i < DMA_REQMASK_WIDTH; i = i + 1) begin
      assign if_write_select[i] = (biu_if_haddr[4:2] == i);
    end
  endgenerate
endmodule
