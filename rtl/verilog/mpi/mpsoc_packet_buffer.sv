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

module mpsoc_packet_buffer #(
  parameter DATA_WIDTH = 32,
  parameter FIFO_DEPTH = 16,
  parameter FLIT_WIDTH = 34,
  parameter SIZE_WIDTH = 5,
  parameter READY      = 1'b0,
  parameter BUSY       = 1'b1
)
  (
    input                   clk,
    input                   rst,

    //inputs
    input [FLIT_WIDTH -1:0] in_flit,
    input                   in_valid,
    output                  in_ready,

    //outputs
    output [FLIT_WIDTH-1:0] out_flit,
    output                  out_valid,
    input                   out_ready,

    output reg [SIZE_WIDTH-1:0] out_size
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  parameter FLIT_TYPE_LAST   = 2'b10;
  parameter FLIT_TYPE_SINGLE = 2'b11;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Signals for fifo
  reg [FLIT_WIDTH-1:0] fifo_data [0:FIFO_DEPTH]; //actual fifo
  reg [FIFO_DEPTH  :0] fifo_write_ptr;

  reg [FIFO_DEPTH:0]   last_flits;

  wire                 full_packet;
  wire                 pop;
  wire                 push;

  wire [          1:0] in_flit_type;
  wire                 in_is_last;
  reg [FIFO_DEPTH-1:0] valid_flits;

  reg [SIZE_WIDTH-1:0] i;
  reg [SIZE_WIDTH-1:0] s;
  reg                  found;

  integer j, k;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign in_flit_type = in_flit[FLIT_WIDTH-1:FLIT_WIDTH-2];
  assign in_is_last   = (in_flit_type == FLIT_TYPE_LAST) || (in_flit_type == FLIT_TYPE_SINGLE);

  always @(*) begin : valid_flits_comb
    // Set first element
    valid_flits[FIFO_DEPTH-1] = fifo_write_ptr[FIFO_DEPTH];
    for (j=FIFO_DEPTH-2;j>=0;j=j-1) begin
      valid_flits[j] = fifo_write_ptr[j+1] | valid_flits[j+1];
    end
  end

  assign full_packet = |(last_flits[FIFO_DEPTH-1:0] & valid_flits);

  assign pop  = out_valid & out_ready;
  assign push = in_valid & in_ready;

  assign out_flit  = fifo_data[0];
  assign out_valid = full_packet;

  assign in_ready = !fifo_write_ptr[FIFO_DEPTH];

  always @(*) begin : findfirstlast
    s     = 0;
    found = 0;

    for (i=0;i<FIFO_DEPTH;i=i+1) begin
      if (last_flits[i] && !found) begin
        s     = i+1;
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
      for (k=0;k<FIFO_DEPTH-1;k=k+1) begin
        if (pop) begin
          if (push & fifo_write_ptr[k+1]) begin
            fifo_data  [k] <= in_flit;
            last_flits [k] <= in_is_last;
          end
          else begin
            fifo_data  [k] <= fifo_data[k+1];
            last_flits [k] <= last_flits[k+1];
          end
        end
        else if (push & fifo_write_ptr[k]) begin
          fifo_data  [k] <= in_flit;
          last_flits [k] <= in_is_last;
        end
      end
      // Handle last element
      if (pop &  push & fifo_write_ptr[k+1]) begin
        fifo_data  [k] <= in_flit;
        last_flits [k] <= in_is_last;
      end
      else if (push & fifo_write_ptr[k]) begin
        fifo_data  [k] <= in_flit;
        last_flits [k] <= in_is_last;
      end
    end
  end // block: shift_register
endmodule
