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

module peripheral_bfm_testbench;
  //////////////////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam AW = 32;
  localparam DW = 32;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg wb_clk = 1'b1;
  reg wb_rst = 1'b1;

  wire done;

  wire [AW-1:0] wb_m2s_adr;
  wire [DW-1:0] wb_m2s_dat;
  wire [   3:0] wb_m2s_sel;
  wire          wb_m2s_we ;
  wire          wb_m2s_cyc;
  wire          wb_m2s_stb;
  wire [   2:0] wb_m2s_cti;
  wire [   1:0] wb_m2s_bte;
  wire [DW-1:0] wb_s2m_dat;
  wire          wb_s2m_ack;
  wire          wb_s2m_err;
  wire          wb_s2m_rty;

  integer TRANSACTIONS;
  integer SUBTRANSACTIONS;
  integer SEED;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  peripheral_utils_testbench testbench_utils ();
  peripheral_tap_generator #("wb_bfm.tap", 1) tap_generator();

  always #5 wb_clk <= ~wb_clk;
  initial  #100 wb_rst <= 0;

  peripheral_bfm_transactor_wb #(
  .MEM_HIGH (32'h00007fff),
  .AUTORUN (0),
  .VERBOSE (0)
  )
  bfm_transactor_wb (
    .wb_clk_i (wb_clk),
    .wb_rst_i (wb_rst),
    .wb_adr_o (wb_m2s_adr),
    .wb_dat_o (wb_m2s_dat),
    .wb_sel_o (wb_m2s_sel),
    .wb_we_o  (wb_m2s_we ),
    .wb_cyc_o (wb_m2s_cyc),
    .wb_stb_o (wb_m2s_stb),
    .wb_cti_o (wb_m2s_cti),
    .wb_bte_o (wb_m2s_bte),
    .wb_dat_i (wb_s2m_dat),
    .wb_ack_i (wb_s2m_ack),
    .wb_err_i (wb_s2m_err),
    .wb_rty_i (wb_s2m_rty),
    .done     (done)
  );

  peripheral_bfm_memory_wb #(
  .DEBUG (0)
  )
  bfm_memory_wb (
    .wb_clk_i (wb_clk),
    .wb_rst_i (wb_rst),
    .wb_adr_i (wb_m2s_adr),
    .wb_dat_i (wb_m2s_dat),
    .wb_sel_i (wb_m2s_sel),
    .wb_we_i  (wb_m2s_we ),
    .wb_cyc_i (wb_m2s_cyc),
    .wb_stb_i (wb_m2s_stb),
    .wb_cti_i (wb_m2s_cti),
    .wb_bte_i (wb_m2s_bte),
    .wb_dat_o (wb_s2m_dat),
    .wb_ack_o (wb_s2m_ack),
    .wb_err_o (wb_s2m_err),
    .wb_rty_o (wb_s2m_rty)
  );

  initial begin
    //Grab CLI parameters
    if($value$plusargs("transactions=%d", TRANSACTIONS))
      bfm_transactor_wb.set_transactions(TRANSACTIONS);
    if($value$plusargs("subtransactions=%d", SUBTRANSACTIONS))
      bfm_transactor_wb.set_subtransactions(SUBTRANSACTIONS);
    if($value$plusargs("seed=%d", SEED))
      bfm_transactor_wb.SEED = SEED;

    bfm_transactor_wb.display_settings;
    bfm_transactor_wb.run;
    bfm_transactor_wb.display_stats;
  end

  always @(posedge done) begin
    tap_generator.ok("All tests complete");
    $display("All tests complete");
    $finish;
  end
endmodule