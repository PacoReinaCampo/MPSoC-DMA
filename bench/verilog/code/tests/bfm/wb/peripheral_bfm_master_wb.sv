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
 *   Olof Kindgren <olof.kindgren@gmail.com>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import peripheral_wb_pkg::*;

module peripheral_bfm_master_wb #(
  parameter AW              = 32,
  parameter DW              = 32,
  parameter TP              = 0,
  parameter MAX_BURST_LEN   = 32,
  parameter MAX_WAIT_STATES = 8,
  parameter VERBOSE         = 0
) (
  input                 wb_clk_i,
  input                 wb_rst_i,
  output reg [AW  -1:0] wb_adr_o,
  output reg [DW  -1:0] wb_dat_o,
  output reg [DW/8-1:0] wb_sel_o,
  output reg            wb_we_o,
  output reg            wb_cyc_o,
  output reg            wb_stb_o,
  output reg [     2:0] wb_cti_o,
  output reg [     1:0] wb_bte_o,
  input      [DW  -1:0] wb_dat_i,
  input                 wb_ack_i,
  input                 wb_err_i,
  input                 wb_rty_i
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  parameter BUFFER_WIDTH = $clog2(MAX_BURST_LEN);
  parameter ADR_LSB = $clog2(DW / 8);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////
  reg     [                 AW  -1:0] addr;
  reg     [                     31:0] index = 0;
  reg     [                 DW  -1:0] data = {DW{1'b0}};
  reg     [                 DW/8-1:0] mask;
  reg                                 op;

  reg     [                      2:0] cycle_type;
  reg     [                      2:0] burst_type;
  reg     [                     31:0] burst_length;
  reg     [         AW          -1:0] buffer_addr_tmp;
  reg     [         BUFFER_WIDTH-1:0] buffer_addr;

  reg     [                   DW-1:0] write_data        [0:MAX_BURST_LEN-1];
  reg     [                   DW-1:0] buffer_data       [0:MAX_BURST_LEN-1];

  reg     [$clog2(MAX_WAIT_STATES):0] wait_states;
  reg     [$clog2(MAX_WAIT_STATES):0] wait_states_cnt;

  integer                             word;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Tasks
  //

  task reset;
    begin
      wb_adr_o = {AW{1'b0}};
      wb_dat_o = {DW{1'b0}};
      wb_sel_o = {DW / 8{1'b0}};
      wb_we_o  = 1'b0;
      wb_cyc_o = 1'b0;
      wb_stb_o = 1'b0;
      wb_cti_o = 3'b000;
      wb_bte_o = 2'b00;
    end
  endtask

  task write;
    input [AW  -1:0] addr_i;
    input [DW  -1:0] data_i;
    input [DW/8-1:0] mask_i;

    output err_o;

    begin
      addr       = addr_i;
      data       = data_i;
      mask       = mask_i;
      cycle_type = CTI_CLASSIC;
      op         = WRITE;

      init;
      @(posedge wb_clk_i);
      next;
      err_o = wb_err_i;
      insert_wait_states;
    end
  endtask

  task write_burst;
    input [AW  -1:0] base_addr;
    input [AW  -1:0] addr_i;
    input [DW/8-1:0] mask_i;
    input [2:0] cycle_type_i;
    input [2:0] burst_type_i;
    input [31:0] burst_length_i;
    output err_o;
    begin

      addr            = addr_i;
      buffer_addr_tmp = addr_i - base_addr;
      buffer_addr     = buffer_addr_tmp[ADR_LSB+BUFFER_WIDTH-1:ADR_LSB];
      mask            = mask_i;
      op              = WRITE;
      burst_length    = burst_length_i;
      cycle_type      = cycle_type_i;
      burst_type      = burst_type_i;
      index           = 0;
      err_o           = 0;

      init;

      while (index < burst_length) begin
        buffer_data[buffer_addr] = write_data[index];
        data                     = write_data[index];

        if (VERBOSE > 2) begin
          $display("    %t: Write Data %h written to buffer at address %h at iteration %0d", $time, write_data[index], buffer_addr, index);
          $display("    %t: Write Data %h written to memory at address %h at iteration %0d", $time, write_data[index], addr, index);
        end else if (VERBOSE > 1) begin
          $display("    %t: Write Data %h written to memory at address %h at iteration %0d", $time, write_data[index], addr, index);
        end

        next;
        addr            = wb_next_adr(addr, cycle_type, burst_type, DW);
        buffer_addr_tmp = addr - base_addr;
        buffer_addr     = buffer_addr_tmp[ADR_LSB+BUFFER_WIDTH-1:ADR_LSB];
        index           = index + 1;
      end

      clear_write_data;

      insert_wait_states;
    end
  endtask

  task read_burst_comp;
    input [AW  -1:0] base_addr;
    input [AW  -1:0] addr_i;
    input [DW/8-1:0] mask_i;
    input [2:0] cycle_type_i;
    input [1:0] burst_type_i;
    input [31:0] burst_length_i;
    output err_o;
    begin

      addr            = addr_i;
      buffer_addr_tmp = addr_i - base_addr;
      buffer_addr     = buffer_addr_tmp[ADR_LSB+BUFFER_WIDTH-1:ADR_LSB];
      mask            = mask_i;
      op              = READ;
      cycle_type      = cycle_type_i;
      burst_type      = burst_type_i;
      burst_length    = burst_length_i;
      index           = 0;
      err_o           = 0;

      init;

      while (index < burst_length) begin
        next;
        data_compare(addr, data, index);
        addr            = wb_next_adr(addr, cycle_type, burst_type, DW);
        buffer_addr_tmp = addr - base_addr;
        buffer_addr     = buffer_addr_tmp[ADR_LSB+BUFFER_WIDTH-1:ADR_LSB];
        index           = index + 1;
      end

      insert_wait_states;
    end
  endtask

  task data_compare;
    input [AW-1:0] addr;
    input [DW-1:0] read_data;
    input [31:0] iteration;

    begin

      if (VERBOSE > 2) begin
        $display("    %t: Comparing Read Data for iteration %0d at address: %h", $time, iteration, addr);
        $display("    %t: Read Data: %h, buffer data: %h, buffer address: %h", $time, read_data, buffer_data[buffer_addr], buffer_addr);
      end else if (VERBOSE > 1) begin
        $display("    Comparing Read Data for iteration %0d at address: %h", iteration, addr);
      end

      if (buffer_data[buffer_addr] !== read_data) begin
        $display("Read data mismatch during iteration %0d at address %h", iteration, addr);
        $display("Expected %h", buffer_data[buffer_addr]);
        $display("Got      %h", read_data);
        #3 $finish;
      end else begin
        if (VERBOSE > 1) $display("    Data Matched");
      end
    end
  endtask

  task insert_wait_states;
    begin

      wb_cyc_o = #TP 1'b0;
      wb_stb_o = #TP 1'b0;
      wb_we_o  = #TP 1'b0;
      wb_cti_o = #TP 3'b000;
      wb_bte_o = #TP 2'b00;
      wb_sel_o = #TP{DW / 8{1'b0}};
      wb_adr_o = #TP{AW{1'b0}};
      wb_dat_o = #TP{DW{1'b0}};

      for (wait_states_cnt = 0; wait_states_cnt < wait_states; wait_states_cnt = wait_states_cnt + 1) begin
        @(posedge wb_clk_i);
      end
    end
  endtask

  task clear_write_data;
    begin
      for (word = 0; word < MAX_BURST_LEN - 1; word = word + 1) begin
        write_data[word] = {DW{1'bx}};
      end
    end
  endtask

  task clear_buffer_data;
    begin
      for (word = 0; word < MAX_BURST_LEN - 1; word = word + 1) begin
        buffer_data[word] = 32'hxxxxxxxx;
      end
    end
  endtask

  // Low level tasks
  task init;
    begin
      if (wb_rst_i !== 1'b0) begin
        @(negedge wb_rst_i);
        @(posedge wb_clk_i);
      end

      wb_sel_o <= #TP mask;
      wb_we_o  <= #TP op;
      wb_cyc_o <= #TP 1'b1;

      if (cycle_type == CTI_CLASSIC) begin
        if (VERBOSE > 1) begin
          $display("INIT: Classic Cycle");
        end
        wb_cti_o <= #TP 3'b000;
        wb_bte_o <= #TP 2'b00;
      end else if (index == burst_length - 1) begin
        if (VERBOSE > 1) begin
          $display("INIT: Burst - last cycle");
        end
        wb_cti_o <= #TP 3'b111;
        wb_bte_o <= #TP 2'b00;
      end else if (cycle_type == CTI_CONST_BURST) begin
        if (VERBOSE > 1) begin
          $display("INIT: Const Burst cycle");
        end
        wb_cti_o <= #TP 3'b001;
        wb_bte_o <= #TP 2'b00;
      end else begin
        if (VERBOSE > 1) begin
          $display("INIT: Incr Burst cycle");
        end
        wb_cti_o <= #TP 3'b010;
        wb_bte_o <= #TP burst_type[1:0];
      end
    end
  endtask

  task next;
    begin
      wb_adr_o <= #TP addr;
      wb_dat_o <= #TP(op === WRITE) ? data : {DW{1'b0}};
      wb_stb_o <= #TP 1'b1;  // FIXME: Add wait states

      if ((index == burst_length - 1) && (cycle_type !== CTI_CLASSIC)) begin
        wb_cti_o <= #TP 3'b111;
      end

      @(posedge wb_clk_i);
      while (wb_ack_i !== 1'b1) @(posedge wb_clk_i);
      data = wb_dat_i;
    end
  endtask
endmodule
