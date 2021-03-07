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
//              WishBone Bus Interface                                        //
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

module peripheral_bfm_memory_wb #(
  //Wishbone parameters
  parameter DW = 32,
  parameter AW = 32,

  parameter DEBUG = 0,

  // Memory parameters
  parameter MEMORY_FILE = "",
  parameter MEM_SIZE_BYTES = 32'h0000_8000,  // 32KBytes
  parameter RD_MIN_DELAY = 0,
  parameter RD_MAX_DELAY = 4
)
  (
    input      wb_clk_i,
    input      wb_rst_i,

    input  [AW  -1:0] wb_adr_i,
    input  [DW  -1:0] wb_dat_i,
    input  [DW/8-1:0] wb_sel_i,
    input             wb_we_i,
    input  [     1:0] wb_bte_i,
    input  [     2:0] wb_cti_i,
    input             wb_cyc_i,
    input             wb_stb_i,

    output            wb_ack_o,
    output            wb_err_o,
    output            wb_rty_o,
    output [DW  -1:0] wb_dat_o
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam bytes_per_dw = (DW/8);
  localparam mem_words = (MEM_SIZE_BYTES/bytes_per_dw);

  parameter ADR_LSB = $clog2(bytes_per_dw);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  //Counters for read and write accesses
  integer        reads  = 0;
  integer        writes = 0;

  // synthesis attribute ram_style of mem is block
  reg [DW-1:0] mem [ 0 : mem_words-1 ];

  reg [AW-1:0]   address;
  reg [DW-1:0]   data;

  integer     i;
  integer     delay;
  integer     seed;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  peripheral_bfm_slave_wb #(
    .AW    (AW),
    .DW    (DW),
    .DEBUG (DEBUG)
  )
  bfm_slave_wb (
    .wb_clk   (wb_clk_i),
    .wb_rst   (wb_rst_i),
    .wb_adr_i (wb_adr_i),
    .wb_dat_i (wb_dat_i),
    .wb_sel_i (wb_sel_i),
    .wb_we_i  (wb_we_i),
    .wb_cyc_i (wb_cyc_i),
    .wb_stb_i (wb_stb_i),
    .wb_cti_i (wb_cti_i),
    .wb_bte_i (wb_bte_i),
    .wb_dat_o (wb_dat_o),
    .wb_ack_o (wb_ack_o),
    .wb_err_o (wb_err_o),
    .wb_rty_o (wb_rty_o)
  );

  always begin
    bfm_slave_wb.init();
    address = bfm_slave_wb.address; //Fetch start address

    if(bfm_slave_wb.op === WRITE)
      writes = writes + 1;
    else
      reads = reads + 1;
    while(bfm_slave_wb.has_next) begin
      //Set error on out of range accesses
      if(address[31:ADR_LSB] > mem_words) begin
        $display("%0d : Error : Attempt to access %x, which is outside of memory", $time, address);
        bfm_slave_wb.error_response();
      end
      else begin
        if(bfm_slave_wb.op === WRITE) begin
          bfm_slave_wb.write_ack(data);
          if(DEBUG) $display("%d : ram Write 0x%h = 0x%h %b", $time, address, data, bfm_slave_wb.mask);
          for(i=0;i < DW/8; i=i+1)
            if(bfm_slave_wb.mask[i])
              mem[address[31:ADR_LSB]][i*8+:8] = data[i*8+:8];
        end
        else begin
          data = {AW{1'b0}};
          for(i=0;i < DW/8; i=i+1)
            if(bfm_slave_wb.mask[i])
              data[i*8+:8] = mem[address[31:ADR_LSB]][i*8+:8];
          if(DEBUG) $display("%d : ram Read  0x%h = 0x%h %b", $time, address, data, bfm_slave_wb.mask);
          delay = $dist_uniform(seed, RD_MIN_DELAY, RD_MAX_DELAY);
          repeat(delay) @(posedge wb_clk_i);
          bfm_slave_wb.read_ack(data);
        end
      end
      if(bfm_slave_wb.cycle_type === BURST_CYCLE)
        address = wb_next_adr(address, wb_cti_i, wb_bte_i, DW);
    end
  end
endmodule
