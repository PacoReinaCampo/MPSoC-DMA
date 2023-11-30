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
//              Wishbone Bus Interface                                        //
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
//   Olof Kindgren <olof.kindgren@gmail.com>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_wb_pkg::*;

module peripheral_bfm_slave_wb #(
  parameter DW    = 32,
  parameter AW    = 32,
  parameter DEBUG = 0
) (
  input                 wb_clk,
  input                 wb_rst,
  input      [AW  -1:0] wb_adr_i,
  input      [DW  -1:0] wb_dat_i,
  input      [DW/8-1:0] wb_sel_i,
  input                 wb_we_i,
  input                 wb_cyc_i,
  input                 wb_stb_i,
  input      [     2:0] wb_cti_i,
  input      [     1:0] wb_bte_i,
  output reg [  DW-1:0] wb_dat_o,
  output reg            wb_ack_o,
  output reg            wb_err_o,
  output reg            wb_rty_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam TP = 1;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  reg            has_next = 1'b0;

  reg            op = READ;
  reg [AW  -1:0] address;
  reg [DW  -1:0] data;
  reg [DW/8-1:0] mask;
  reg            cycle_type;
  reg [     2:0] burst_type;

  reg            err = 0;

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

  task init;
    begin
      wb_ack_o <= #TP 1'b0;
      wb_dat_o <= #TP{DW{1'b0}};
      wb_err_o <= #TP 1'b0;
      wb_rty_o <= #TP 1'b0;

      if (wb_rst !== 1'b0) begin
        if (DEBUG) begin
          $display("%0d : waiting for reset release", $time);
        end

        @(negedge wb_rst);
        @(posedge wb_clk);

        if (DEBUG) begin
          $display("%0d : Reset was released", $time);
        end
      end

      // Catch start of next cycle
      if (!wb_cyc_i) begin
        @(posedge wb_cyc_i);
      end

      @(posedge wb_clk);

      // Make sure that wb_cyc_i is still asserted at next clock edge to avoid glitches
      while (wb_cyc_i !== 1'b1) begin
        @(posedge wb_clk);
      end

      if (DEBUG) begin
        $display("%0d : Got wb_cyc_i", $time);
      end

      cycle_type = get_cycle_type(wb_cti_i);

      op         = wb_we_i;
      address    = wb_adr_i;
      mask       = wb_sel_i;

      has_next   = 1'b1;
    end
  endtask

  task error_response;
    begin
      err = 1'b1;
      next();
      err = 1'b0;
    end
  endtask

  task read_ack;
    input [DW-1:0] data_i;
    begin
      data = data_i;
      next();
    end
  endtask

  task write_ack;
    output [DW-1:0] data_o;
    begin
      if (DEBUG) begin
        $display("%0d : Write ack", $time);
      end

      next();
      data_o = data;
    end
  endtask

  task next;
    begin
      if (DEBUG) begin
        $display("%0d : next address=0x%h, data=0x%h, op=%b", $time, address, data, op);
      end

      wb_dat_o <= #TP{DW{1'b0}};
      wb_ack_o <= #TP 1'b0;
      wb_err_o <= #TP 1'b0;
      wb_rty_o <= #TP 1'b0;  // TO-DO: rty not supported

      if (err) begin
        if (DEBUG) begin
          $display("%0d, Error", $time);
        end

        wb_err_o <= #TP 1'b1;
        has_next = 1'b0;
      end else begin
        if (op === READ) begin
          wb_dat_o <= #TP data;
        end

        wb_ack_o <= #TP 1'b1;
      end

      @(posedge wb_clk);

      wb_ack_o <= #TP 1'b0;
      wb_err_o <= #TP 1'b0;

      has_next = !wb_is_last(wb_cti_i) & !err;

      if (op === WRITE) begin
        data = wb_dat_i;
        mask = wb_sel_i;
      end

      address = wb_adr_i;
    end
  endtask
endmodule
