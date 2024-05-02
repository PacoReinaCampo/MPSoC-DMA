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
//              AMBA3 AHB-Lite Bus Interface                                  //
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
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import peripheral_axi4_pkg::*;

module peripheral_bfm_axi4 #(
  parameter TIMERS = 2,  // Number of timers

  parameter HADDR_SIZE = 16,
  parameter HDATA_SIZE = 32
) (
  input HRESETn,
  input HCLK,

  output                  HSEL,
  output [HADDR_SIZE-1:0] HADDR,
  output [HDATA_SIZE-1:0] HWDATA,
  input  [HDATA_SIZE-1:0] HRDATA,
  output                  HWRITE,
  output [           2:0] HSIZE,
  output [           2:0] HBURST,
  output [           3:0] HPROT,
  output [           1:0] HTRANS,
  output                  HMASTLOCK,
  input                   HREADY,
  input                   HRESP,

  input tint
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam [HADDR_SIZE-1:0] PRESCALE = 'h0;
  localparam [HADDR_SIZE-1:0] RESERVED = 'h4;
  localparam [HADDR_SIZE-1:0] IPENDING = 'h8;
  localparam [HADDR_SIZE-1:0] IENABLE = 'hc;
  localparam [HADDR_SIZE-1:0] IPENDING_IENABLE = IPENDING;  // for 64bit access
  localparam [HADDR_SIZE-1:0] TIME = 'h10;
  localparam [HADDR_SIZE-1:0] TIME_MSB = 'h14;  // for 32bit access
  localparam [HADDR_SIZE-1:0] TIMECMP = 'h18;  // address = n*'h08 + 'h18;
  localparam [HADDR_SIZE-1:0] TIMECMP_MSB = 'h1c;  // address = n*'h08 + 'h1c;

  localparam PRESCALE_VALUE = 5;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  int reset_watchdog;
  int got_reset;
  int errors;

  //////////////////////////////////////////////////////////////////////////////
  // Instantiate the AHB-Master
  //////////////////////////////////////////////////////////////////////////////
  peripheral_bfm_master_axi4 #(
    .HADDR_SIZE(HADDR_SIZE),
    .HDATA_SIZE(HDATA_SIZE)
  ) bfm_master_axi4 (
    .*
  );

  initial begin
    errors         = 0;
    reset_watchdog = 0;
    got_reset      = 0;

    forever begin
      reset_watchdog++;
      @(posedge HCLK);
      if (!got_reset && reset_watchdog == 1000) begin
        $fatal(-1, "HRESETn not asserted\nTestbench requires an AHB reset");
      end
    end
  end

  always @(negedge HRESETn) begin
    // wait for reset to negate
    @(posedge HRESETn);
    got_reset = 1;

    welcome_text();

    // check initial values
    test_reset_register_values();

    // Test registers
    test_registers_rw32();

    // Program prescale register
    // program_prescaler(PRESCALE_VALUE -1); // counts N+1

    // Finish simulation
    repeat (100) @(posedge HCLK);
    finish_text();
    $finish();
  end

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

  task welcome_text();
    $display("---------------------------------------------------------------------------------------------------------");
    $display("                                                                                                         ");
    $display("                                                                                                         ");
    $display("                                                              ***                     ***          **    ");
    $display("                                                            ** ***    *                ***          **   ");
    $display("                                                           **   ***  ***                **          **   ");
    $display("                                                           **         *                 **          **   ");
    $display("    ****    **   ****                                      **                           **          **   ");
    $display("   * ***  *  **    ***  *    ***       ***    ***  ****    ******   ***        ***      **      *** **   ");
    $display("  *   ****   **     ****    * ***     * ***    **** **** * *****     ***      * ***     **     ********* ");
    $display(" **    **    **      **    *   ***   *   ***    **   ****  **         **     *   ***    **    **   ****  ");
    $display(" **    **    **      **   **    *** **    ***   **    **   **         **    **    ***   **    **    **   ");
    $display(" **    **    **      **   ********  ********    **    **   **         **    ********    **    **    **   ");
    $display(" **    **    **      **   *******   *******     **    **   **         **    *******     **    **    **   ");
    $display(" **    **    **      **   **        **          **    **   **         **    **          **    **    **   ");
    $display("  *******     ******* **  ****    * ****    *   **    **   **         **    ****    *   **    **    **   ");
    $display("   ******      *****   **  *******   *******    ***   ***  **         *** *  *******    *** *  *****     ");
    $display("       **                   *****     *****      ***   ***  **         ***    *****      ***    ***      ");
    $display("       **                                                                                                ");
    $display("       **                                                                                                ");
    $display("        **                                                                                               ");
    $display(" AHB3Lite Timer Testbench Initialized                                                                    ");
    $display(" Timers: %0d                                                                                             ", TIMERS);
    $display("---------------------------------------------------------------------------------------------------------");
  endtask : welcome_text

  task finish_text();
    if (errors > 0) begin
      $display("------------------------------------------------------------");
      $display(" AHB3Lite Timer Testbench failed with (%0d) errors @%0t", errors, $time);
      $display("------------------------------------------------------------");
    end else begin
      $display("------------------------------------------------------------");
      $display(" AHB3Lite Timer Testbench finished successfully @%0t", $time);
      $display("------------------------------------------------------------");
    end
  endtask : finish_text

  task test_reset_register_values;
    // all zeros ... why bother
  endtask : test_reset_register_values

  task test_registers_rw32;
    int error;
    int hsize;
    int hburst;
    int n;
    localparam int reg_cnt = 4 + 2 * TIMERS;

    logic [HADDR_SIZE-1:0] registers[reg_cnt];
    logic [HDATA_SIZE-1:0] axi4uffer[][], rbuffer[][];

    // create list of registers
    for (n = 0; n < reg_cnt; n++) begin
      case (n)
        0:       registers[n] = PRESCALE;
        1:       registers[n] = IENABLE;
        2:       registers[n] = TIME;
        3:       registers[n] = TIME_MSB;
        default: registers[n] = (n - 4) * 'h08 + (n[0] ? TIMECMP_MSB : TIMECMP);
      endcase
    end

    // create buffers
    axi4uffer = new[reg_cnt];
    rbuffer = new[reg_cnt];

    $display("Testing registers ... ");
    for (hsize = 2; hsize >= 0; hsize -= 2) begin
      error = 0;
      if (hsize == HSIZE_WORD) begin
        hburst = HBURST_SINGLE;
        $write("  Testing word (32bit) accesses ... ");
      end else begin
        hburst = HBURST_INCR4;
        $write("  Testing byte burst (8bit) accesses ... ");
      end

      for (n = 0; n < reg_cnt; n++) begin
        if (hsize == HSIZE_WORD) begin
          axi4uffer[n]    = new[1];
          rbuffer[n]    = new[1];
          axi4uffer[n][0] = $random;
        end else begin
          axi4uffer[n] = new[4];
          rbuffer[n] = new[4];
          for (int i = 0; i < 4; i++) axi4uffer[n][i] = $random & 'hff;
        end
      end

      for (n = 0; n < reg_cnt; n++) begin
        bfm_master_axi4.write(registers[n], axi4uffer[n], hsize, hburst);  // write register
      end

      bfm_master_axi4.idle();  // wait for HWDATA

      for (n = 0; n < reg_cnt; n++) begin
        bfm_master_axi4.read(registers[n], rbuffer[n], hsize, hburst);  // read register
      end

      bfm_master_axi4.idle();  // Idle bus
      wait fork;  // wait for all threads to complete

      for (n = 0; n < reg_cnt; n++) begin
        for (int beat = 0; beat < rbuffer[n].size(); beat++) begin
          // mask byte ...
          if (HSIZE == HSIZE_BYTE) begin
            rbuffer[n][beat] &= 'hff;
          end

          if (n == 1) begin  // IENABLE
            axi4uffer[n][beat] &= {{32 - TIMERS{1'b0}}, {TIMERS{1'b1}}};
            axi4uffer[n][beat] >>= 8 * beat;
          end

          if (rbuffer[n][beat] != axi4uffer[n][beat]) begin
            $display("%0d,%0d: got %x, expected %x", n, beat, rbuffer[n][beat], axi4uffer[n][beat]);
            error = 1;
            errors++;
          end
        end
      end

      if (error) begin
        $display("FAILED");
      end else begin
        $display("OK");
      end
    end

    // reset registers to all '0'
    axi4uffer[0][0] = 0;
    for (n = 0; n < reg_cnt; n++) begin
      bfm_master_axi4.write(registers[n], axi4uffer[0], HSIZE_WORD, HBURST_SINGLE);  // write register
    end

    // discard buffers
    rbuffer.delete();
    axi4uffer.delete();
  endtask : test_registers_rw32

  task program_prescaler(input [31:0] value);
    // create buffer
    logic [HDATA_SIZE-1:0] buffer[];
    buffer    = new[1];

    // assign buffer
    buffer[0] = value;

    $write("Programming prescaler ... ");
    bfm_master_axi4.write(PRESCALE, buffer, HSIZE_WORD, HBURST_SINGLE);  // write value
    bfm_master_axi4.idle();  // wait for HWDATA
    bfm_master_axi4.read(PRESCALE, buffer, HSIZE_WORD, HBURST_SINGLE);  // read back value
    bfm_master_axi4.idle();  // IDLE bus
    wait fork;

    if (buffer[0] !== value) begin
      errors++;
      $display("FAILED");
      $error("Wrong register value. Expected %0d, got %0d", value, buffer[0]);
    end else begin
      $display("OK");
    end

    // discard buffer
    buffer.delete();
  endtask : program_prescaler
endmodule : peripheral_bfm_axi4
