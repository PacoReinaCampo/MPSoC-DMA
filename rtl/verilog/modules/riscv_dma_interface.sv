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
//              Network on Chip Direct Memory Access                          //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              Mesh Topology                                                 //
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

`include "riscv_dma_pkg.sv"

module riscv_dma_interface #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter TABLE_ENTRIES = 4,
  parameter DMA_REQMASK_WIDTH = 5,
  parameter DMA_REQUEST_WIDTH = 199,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4)
)
  (
    input                                   clk,
    input                                   rst,

    input                                   if_HSEL,
    input      [PLEN                  -1:0] if_HADDR,
    input      [XLEN                  -1:0] if_HWDATA,
    output reg [XLEN                  -1:0] if_HRDATA,
    input                                   if_HWRITE,
    input      [                       2:0] if_HSIZE,
    input      [                       2:0] if_HBURST,
    input      [                       3:0] if_HPROT,
    input      [                       1:0] if_HTRANS,
    input                                   if_HMASTLOCK,
    output reg                              if_HREADYOUT,
    output reg                              if_HRESP,

    output     [DMA_REQUEST_WIDTH     -1:0] if_write_req,
    output     [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos,
    output     [DMA_REQMASK_WIDTH     -1:0] if_write_select,
    output                                  if_write_en,

    // Interface read (status) interface
    output     [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos,
    output                                  if_valid_set,
    output                                  if_valid_en,
    output                                  if_validrd_en,

    input      [TABLE_ENTRIES         -1:0] done
  );

  assign if_write_req = {if_HWDATA[`DMA_REQFIELD_LADDR_WIDTH-1:0],
                         if_HWDATA[`DMA_REQFIELD_SIZE_WIDTH-1:0],
                         if_HWDATA[`DMA_REQFIELD_RTILE_WIDTH-1:0],
                         if_HWDATA[`DMA_REQFIELD_RADDR_WIDTH-1:0],
                         if_HWDATA[0]};

  assign if_write_pos  = if_HADDR[TABLE_ENTRIES_PTRWIDTH+4:5]; // ptrwidth MUST be <= 7 (=128 entries)
  assign if_write_en   = if_HMASTLOCK & if_HSEL & if_HWRITE;

  assign if_valid_pos  = if_HADDR[TABLE_ENTRIES_PTRWIDTH+4:5]; // ptrwidth MUST be <= 7 (=128 entries)
  assign if_valid_en   = if_HMASTLOCK & if_HSEL & (if_HADDR[4:0] == 5'h14) & if_HWRITE;
  assign if_validrd_en = if_HMASTLOCK & if_HSEL & (if_HADDR[4:0] == 5'h14) & ~if_HWRITE;
  assign if_valid_set  = if_HWRITE | (~if_HWRITE & ~done[if_valid_pos]);

  assign if_HREADYOUT  = if_HMASTLOCK & if_HSEL;

  always @(*) begin
    if (if_HADDR[4:0] == 5'h14) begin
      if_HRDATA = {63'h0,done[if_valid_pos]};
    end
  end

  genvar  i;
  // This assumes, that mask and address match
  generate
    for (i=0;i<DMA_REQMASK_WIDTH;i=i+1) begin
      assign if_write_select[i] = (if_HADDR[4:2] == i);
    end
  endgenerate
endmodule
