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
//              Network on Chip                                               //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              Wishbone Bus Interface                                        //
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

module mpsoc_dma_request_table #(
  parameter TABLE_ENTRIES          = 4,
  parameter TABLE_ENTRIES_PTRWIDTH = $clog2(4),

  parameter GENERATE_INTERRUPT = 1
)
  (
    input clk,
    input rst,

    // Interface write (request) interface
    input [`DMA_REQUEST_WIDTH    -1:0] if_write_req,
    input [TABLE_ENTRIES_PTRWIDTH-1:0] if_write_pos,
    input [`DMA_REQMASK_WIDTH    -1:0] if_write_select,
    input                              if_write_en,

    input [TABLE_ENTRIES_PTRWIDTH-1:0] if_valid_pos,
    input                              if_valid_set,
    input                              if_valid_en,
    input                              if_validrd_en,

    // Control read (request) interface
    output [`DMA_REQUEST_WIDTH   -1:0] ctrl_read_req,
    input [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_read_pos,

    // Control write (status) interface
    input [TABLE_ENTRIES_PTRWIDTH-1:0] ctrl_done_pos,
    input                              ctrl_done_en,

    // All valid bits of the entries
    output [TABLE_ENTRIES-1:0]         valid,
    output [TABLE_ENTRIES-1:0]         done,

    output [TABLE_ENTRIES-1:0] 	      irq
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // The storage of the requests ..
  reg [`DMA_REQUEST_WIDTH-1:0] transfer_request_table[0:TABLE_ENTRIES-1];

  reg [TABLE_ENTRIES-1:0]      transfer_valid;
  reg [TABLE_ENTRIES-1:0]      transfer_done;

  wire [`DMA_REQUEST_WIDTH-1:0] if_write_mask;

  integer i;
  genvar j;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign if_write_mask[`DMA_REQFIELD_LADDR_MSB:`DMA_REQFIELD_LADDR_LSB] = {`DMA_REQFIELD_LADDR_WIDTH{if_write_select[`DMA_REQMASK_LADDR]}};
  assign if_write_mask[`DMA_REQFIELD_SIZE_MSB:`DMA_REQFIELD_SIZE_LSB]   = {`DMA_REQFIELD_SIZE_WIDTH{if_write_select[`DMA_REQMASK_SIZE]}};
  assign if_write_mask[`DMA_REQFIELD_RTILE_MSB:`DMA_REQFIELD_RTILE_LSB] = {`DMA_REQFIELD_RTILE_WIDTH{if_write_select[`DMA_REQMASK_RTILE]}};
  assign if_write_mask[`DMA_REQFIELD_RADDR_MSB:`DMA_REQFIELD_RADDR_LSB] = {`DMA_REQFIELD_RADDR_WIDTH{if_write_select[`DMA_REQMASK_RADDR]}};
  assign if_write_mask[`DMA_REQFIELD_DIR] = if_write_select[`DMA_REQMASK_DIR];

  // Write to the request table
  always @(posedge clk) begin : proc_request_table
    if (rst) begin : reset
      //reset
      for (i = 0; i < TABLE_ENTRIES; i = i+1) begin
        { transfer_valid[i], transfer_done[i] } <= 2'b00;
      end //for
    end
    else begin
      if (if_write_en) begin
        transfer_request_table[if_write_pos] <= (~if_write_mask & transfer_request_table[if_write_pos]) | (if_write_mask & if_write_req);
      end
      for (i = 0; i<TABLE_ENTRIES; i=i+1 ) begin
        if (if_valid_en && (if_valid_pos == i)) begin
          // Start transfer
          transfer_valid[i] <= if_valid_set;
          transfer_done[i] <= 1'b0;
        end
        else if (if_validrd_en && (if_valid_pos==i) && (transfer_done[i])) begin
          // Check transfer and was done
          transfer_done[i] <= 1'b0;
          transfer_valid[i] <= 1'b0;
        end
        else if (ctrl_done_en && (ctrl_done_pos==i)) begin
          // Transfer is finished
          transfer_done[i] <= 1'b1;
        end
      end
    end
  end

  // Read interface to the request table
  assign ctrl_read_req = transfer_request_table[ctrl_read_pos];

  // Combine the valid and done bits to one signal
  generate
    for (j=0;j<TABLE_ENTRIES;j=j+1) begin
      assign valid[j] = transfer_valid[j] & ~transfer_done[j];
      assign done[j] = transfer_done[j];
    end
  endgenerate

  // The interrupt is set when any request is valid and done
  assign irq = (transfer_valid & transfer_done) & {(TABLE_ENTRIES){1'b1}};
endmodule
