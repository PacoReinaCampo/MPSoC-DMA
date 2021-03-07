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
//              Blackbone Bus Interface                                       //
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
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "mpsoc_dma_pkg.sv"

module mpsoc_dma_bb_interface #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = 2,

  parameter TILEID = 0
)
  (
    input clk,
    input rst,

    input      [ADDR_WIDTH-1:0] bb_if_addr_i,
    input      [DATA_WIDTH-1:0] bb_if_din_i,
    input                       bb_if_en_i,
    input                       bb_if_we_i,
    output reg [DATA_WIDTH-1:0] bb_if_dout_o,

    output [`DMA_REQUEST_WIDTH    -1:0] if_write_req,
    output [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos,
    output [`DMA_REQMASK_WIDTH    -1:0] if_write_select,
    output                              if_write_en,

    // Interface read (status) interface
    output [TABLE_ENTRIES_PTRWIDTH-1:0]    if_valid_pos,
    output                                 if_valid_set,
    output                                 if_valid_en,
    output                                 if_validrd_en,

    input [TABLE_ENTRIES-1:0]              done
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  genvar i;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign if_write_req = { bb_if_din_i[`DMA_REQFIELD_LADDR_WIDTH -1:0],
                          bb_if_din_i[`DMA_REQFIELD_SIZE_WIDTH  -1:0],
                          bb_if_din_i[`DMA_REQFIELD_RTILE_WIDTH -1:0],
                          bb_if_din_i[`DMA_REQFIELD_RADDR_WIDTH -1:0],
                          bb_if_din_i[0] };

  assign if_write_pos = bb_if_addr_i[TABLE_ENTRIES_PTRWIDTH+4:5]; // ptrwidth MUST be <= 7 (=128 entries)
  assign if_write_en  = bb_if_en_i & bb_if_we_i;

  assign if_valid_pos  = bb_if_addr_i[TABLE_ENTRIES_PTRWIDTH+4:5]; // ptrwidth MUST be <= 7 (=128 entries)
  assign if_valid_en   = bb_if_en_i & (bb_if_addr_i[4:0] == 5'h14) & bb_if_we_i;
  assign if_validrd_en = bb_if_en_i & (bb_if_addr_i[4:0] == 5'h14) & ~bb_if_we_i;
  assign if_valid_set  = bb_if_we_i | (~bb_if_we_i & ~done[if_valid_pos]);

  always @(*) begin
    if (bb_if_addr_i[4:0] == 5'h14) begin
      bb_if_dout_o = {31'h0,done[if_valid_pos]};
    end
  end

  // This assumes, that mask and address match
  generate
    for (i=0;i<`DMA_REQMASK_WIDTH;i=i+1) begin
      assign if_write_select[i] = (bb_if_addr_i[4:2] == i);
    end
  endgenerate
endmodule
