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

module mpsoc_dma_packet_buffer #(
  parameter DATA_WIDTH = 32,
  parameter FLIT_WIDTH = DATA_WIDTH+2,

  parameter FIFO_DEPTH = 16,
  parameter SIZE_WIDTH = $clog2(17),

  parameter READY = 1'b0, BUSY = 1'b1
)
  (
    //inputs
    input                   clk,
    input                   rst,

    input  [FLIT_WIDTH-1:0] in_flit,
    input                   in_valid,
    output                  in_ready,

    output [FLIT_WIDTH-1:0] out_flit,
    output                  out_valid,
    input                   out_ready,

    output reg [SIZE_WIDTH-1:0] out_size
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Signals for fifo
  reg [FLIT_WIDTH-1:0] fifo_data [0:FIFO_DEPTH]; //actual fifo
  reg [FIFO_DEPTH  :0] fifo_write_ptr;

  reg [FIFO_DEPTH  :0] last_flits;

  wire                 full_packet;
  wire                 pop;
  wire                 push;

  wire [1:0] in_flit_type;

  wire                        in_is_last;

  reg [FIFO_DEPTH-1:0]        valid_flits;

  reg [SIZE_WIDTH-1:0] k;
  reg [SIZE_WIDTH-1:0] s;
  reg                  found;

  integer i;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign in_flit_type = in_flit[FLIT_WIDTH-1:FLIT_WIDTH-2];

  assign in_is_last = (in_flit_type == `FLIT_TYPE_LAST) || (in_flit_type == `FLIT_TYPE_SINGLE);

  always @(*) begin : valid_flits_comb
    // Set first element
    valid_flits[FIFO_DEPTH-1] = fifo_write_ptr[FIFO_DEPTH];
    for (i=FIFO_DEPTH-2;i>=0;i=i-1) begin
      valid_flits[i] = fifo_write_ptr[i+1] | valid_flits[i+1];
    end
  end

  assign full_packet = |(last_flits[FIFO_DEPTH-1:0] & valid_flits);

  assign pop = out_valid & out_ready;
  assign push = in_valid & in_ready;

  assign out_flit = fifo_data[0];
  assign out_valid = full_packet;

  assign in_ready = !fifo_write_ptr[FIFO_DEPTH];

  always @(*) begin : findfirstlast
    s = 0;
    found = 0;
    for (k=0;k<FIFO_DEPTH;k=k+1) begin
      if (last_flits[k] && !found) begin
        s = k+1;
        found = 1;
      end
    end
    out_size = s;
  end

  always @(posedge clk) begin
    if (rst) begin
      fifo_write_ptr <= {{FIFO_DEPTH{1'b0}},1'b1};
    end
    else if (push & !pop) begin
      fifo_write_ptr <= fifo_write_ptr << 1;
    end
    else if (!push & pop) begin
      fifo_write_ptr <= fifo_write_ptr >> 1;
    end
  end

  always @(posedge clk) begin : shift_register
    if (rst) begin
      last_flits <= {FIFO_DEPTH+1{1'b0}};
    end
    else begin : shift
      for (i=0;i<FIFO_DEPTH-1;i=i+1) begin
        if (pop) begin
          if (push & fifo_write_ptr[i+1]) begin
            fifo_data[i] <= in_flit;
            last_flits[i] <= in_is_last;
          end
          else begin
            fifo_data[i] <= fifo_data[i+1];
            last_flits[i] <= last_flits[i+1];
          end
        end
        else if (push & fifo_write_ptr[i]) begin
          fifo_data[i] <= in_flit;
          last_flits[i] <= in_is_last;
        end
      end // for (i=0;i<FIFO_DEPTH-1;i=i+1)
      // Handle last element
      if (pop &  push & fifo_write_ptr[i+1]) begin
        fifo_data[i] <= in_flit;
        last_flits[i] <= in_is_last;
      end
      else if (push & fifo_write_ptr[i]) begin
        fifo_data[i] <= in_flit;
        last_flits[i] <= in_is_last;
      end
    end
  end // block: shift_register
endmodule
