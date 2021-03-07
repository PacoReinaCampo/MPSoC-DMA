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

module mpsoc_dma_bb_initiator_req #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32
)
  (
    input clk,
    input rst,

    output reg [ADDR_WIDTH-1:0] bb_req_addr_o,
    output     [DATA_WIDTH-1:0] bb_req_din_o,
    output reg                  bb_req_en_o,
    output                      bb_req_we_o,
    input      [DATA_WIDTH-1:0] bb_req_dout_i,

    input                                 req_start,
    input                                 req_is_l2r,
    input  [`DMA_REQFIELD_SIZE_WIDTH-3:0] req_size,
    input  [ADDR_WIDTH              -1:0] req_laddr,
    output                                req_data_valid,
    output [DATA_WIDTH              -1:0] req_data,
    input                                 req_data_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  // Blackbone state machine
  `define WB_REQ_WIDTH 2
  `define WB_REQ_IDLE  2'b00
  `define WB_REQ_DATA  2'b01
  `define WB_REQ_WAIT  2'b10

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // State logic
  reg [`WB_REQ_WIDTH-1:0] bb_req_state;
  reg [`WB_REQ_WIDTH-1:0] nxt_bb_req_state;

  // Counter for the state machine for loaded words
  reg [`DMA_REQFIELD_SIZE_WIDTH-3:0] bb_req_count;
  reg [`DMA_REQFIELD_SIZE_WIDTH-3:0] nxt_bb_req_count;

   /*
    * The wishbone data fetch and the NoC interface are seperated by a FIFO.
    * This FIFO relaxes problems with bursts and their termination and decouples
    * the timing of the NoC side and the wishbone side (in terms of termination).
    */

  // The intermediate store a FIFO of three elements
  //
  // There should be no combinatorial path from input to output, so
  // that it takes one cycle before the wishbone interface knows
  // about back pressure from the NoC. Additionally, the wishbone
  // interface needs one extra cycle for burst termination. The data
  // should be stored and not discarded. Finally, there is one
  // element in the FIFO that is the normal timing decoupling.

  reg  [DATA_WIDTH-1:0]               data_fifo [0:2]; // data storage
  wire                                data_fifo_pop;   // NoC pops
  reg                                 data_fifo_push;  // WB pushes

  wire [DATA_WIDTH-1:0]               data_fifo_out; // Current first element
  wire [DATA_WIDTH-1:0]               data_fifo_in;  // Push element
  // Shift register for current position (4th bit is full mark)
  reg [            3:0]               data_fifo_pos;

  wire        data_fifo_empty; // FIFO empty
  wire        data_fifo_ready; // FIFO accepts new elements

  integer i;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Connect the fifo signals to the ports
  assign data_fifo_pop = req_data_ready;
  assign req_data_valid = ~data_fifo_empty;
  assign req_data = data_fifo_out;

  assign data_fifo_empty = data_fifo_pos[0]; // Empty when pushing to first one
  assign data_fifo_out = data_fifo[0]; // First element is out

  // FIFO is not ready when back-pressure would result in discarded data,
  // that is, we need one store element (high-water).
  assign data_fifo_ready = ~|data_fifo_pos[3:2];

  // FIFO position pointer logic
  always @(posedge clk) begin
    if (rst) begin
      data_fifo_pos <= 4'b001;
    end
    else begin
      if (data_fifo_push & ~data_fifo_pop) begin
        // push and no pop
        data_fifo_pos <= data_fifo_pos << 1;
      end
      else if (~data_fifo_push & data_fifo_pop) begin
        // pop and no push
        data_fifo_pos <= data_fifo_pos >> 1;
      end
      else begin
        // * no push or pop or
        // * both push and pop
        data_fifo_pos <= data_fifo_pos;
      end
    end
  end

  // FIFO data shifting logic
  always @(posedge clk) begin : data_fifo_shift
    // Iterate all fifo elements, starting from lowest
    for (i=0;i<3;i=i+1) begin
      if (data_fifo_pop) begin
        // when popping data..
        if (data_fifo_push & data_fifo_pos[i+1])
          // .. and we also push this cycle, we need to check
          // whether the pointer was on the next one
          data_fifo[i] <= data_fifo_in;
        else if (i<2)
          // .. otherwise shift if not last
          data_fifo[i] <= data_fifo[i+1];
        else
          // the last stays static
          data_fifo[i] <= data_fifo[i];
      end
      else if (data_fifo_push & data_fifo_pos[i]) begin
        // when pushing only and this is the current write
        // position
        data_fifo[i] <= data_fifo_in;
      end
      else begin
        // else just keep
        data_fifo[i] <= data_fifo[i];
      end
    end
  end

  // Blackbone interface logic

  // Statically zero (this interface reads)
  assign bb_req_din_o = 32'h0000_0000;
  assign bb_req_we_o = 1'b0;

  // The input to the fifo is the data from the bus
  assign data_fifo_in = bb_req_dout_i;

  // Next state, wishbone combinatorial signals and counting
  always @(*) begin
    // Signal defaults
    nxt_bb_req_count = bb_req_count;
    bb_req_en_o      = 1'b0;
    data_fifo_push   = 1'b0;

    bb_req_addr_o = 32'hx;

    case (bb_req_state)
      `WB_REQ_IDLE: begin
        // We are idle'ing

        // Always reset counter
        nxt_bb_req_count = 0;

        if (req_start & req_is_l2r)
          // start when new request is handled and it is a L2R
          // request. Direct transition to data fetching from bus,
          // as the FIFO is always empty at this point.
          nxt_bb_req_state = `WB_REQ_DATA;
        else
          // otherwise keep idle'ing
          nxt_bb_req_state = `WB_REQ_IDLE;
      end
      `WB_REQ_DATA: begin
        // We get data from the bus

        // Signal cycle and strobe. We do bursts, but don't insert
        // wait states, so both of them are always equal.
        bb_req_en_o = 1'b1;

        // The address is the base address plus the counter
        // Counter counts words, not bytes
        bb_req_addr_o = req_laddr + (bb_req_count << 2);

        // ..otherwise we still wait for the acknowledgement
        nxt_bb_req_state = `WB_REQ_DATA;
      end
      `WB_REQ_WAIT: begin
        // Waiting for FIFO to accept new data
        if (data_fifo_ready)
          // FIFO ready, restart burst
          nxt_bb_req_state = `WB_REQ_DATA;
        else
          // wait
          nxt_bb_req_state = `WB_REQ_WAIT;
      end
      default: begin
        nxt_bb_req_state = `WB_REQ_IDLE;
      end
    endcase
  end

  // Sequential part of the state machine
  always @(posedge clk) begin
    if (rst) begin
      bb_req_state <= `WB_REQ_IDLE;
      bb_req_count <= 0;
    end
    else begin
      bb_req_state <= nxt_bb_req_state;
      bb_req_count <= nxt_bb_req_count;
    end
  end
endmodule
