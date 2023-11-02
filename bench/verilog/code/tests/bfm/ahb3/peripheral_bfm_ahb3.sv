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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import peripheral_ahb3_pkg::*;

module peripheral_bfm_ahb3 #(
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
  //
  // Constants
  //

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
  //
  // Variables
  //
  int reset_watchdog;
  int got_reset;
  int errors;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Instantiate the AHB-Master
  //
  peripheral_bfm_master_ahb3 #(
    .HADDR_SIZE(HADDR_SIZE),
    .HDATA_SIZE(HDATA_SIZE)
  ) bfm_master_ahb3 (
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

    // Test number of timers
    test_ienable_timers();

    // Test registers
    test_registers_rw32();

    // Program prescale register
    // program_prescaler(PRESCALE_VALUE -1); // counts N+1

    // Test Timer0
    test_timer0();

    // Test all timers

    // Finish simulation
    repeat (100) @(posedge HCLK);
    finish_text();
    $finish();
  end

  //////////////////////////////////////////////////////////////////////////////
  //
  // Tasks
  //
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

  task test_ienable_timers;
    // enable interrupts for all 32 possible timers
    // only the LSBs for the available timers should be '1'

    // create buffer
    logic [HDATA_SIZE-1:0] wbuffer[], rbuffer[];
    wbuffer = new[1];
    rbuffer = new[1];

    $write("Testing amount of timers ... ");
    wbuffer[0] = {HDATA_SIZE{1'b1}};
    bfm_master_ahb3.write(IENABLE, wbuffer, HSIZE_WORD, HBURST_SINGLE);  // write all '1's
    bfm_master_ahb3.idle();  // wait for HWDATA
    bfm_master_ahb3.read(IENABLE, rbuffer, HSIZE_WORD, HBURST_SINGLE);  // read actual value
    wbuffer[0] = {HDATA_SIZE{1'b0}};
    bfm_master_ahb3.write(IENABLE, wbuffer, HSIZE_WORD, HBURST_SINGLE);  // restore all '0's
    bfm_master_ahb3.idle();  // Idle bus
    wait fork;  // wait for all threads to complete

    if (rbuffer[0] !== {TIMERS{1'b1}}) begin
      errors++;
      $display("FAILED");
      $error("Wrong number of timers. Expected %0d, got %0d", TIMERS, $clog2(rbuffer[0]));
    end else begin
      $display("OK");
    end

    // discard buffers
    rbuffer.delete();
    wbuffer.delete();
  endtask : test_ienable_timers

  task test_registers_rw32;
    int error;
    int hsize;
    int hburst;
    int n;
    localparam int reg_cnt = 4 + 2 * TIMERS;

    logic [HADDR_SIZE-1:0] registers[reg_cnt];
    logic [HDATA_SIZE-1:0] wbuffer[][], rbuffer[][];

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
    wbuffer = new[reg_cnt];
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
          wbuffer[n]    = new[1];
          rbuffer[n]    = new[1];
          wbuffer[n][0] = $random;
        end else begin
          wbuffer[n] = new[4];
          rbuffer[n] = new[4];
          for (int i = 0; i < 4; i++) wbuffer[n][i] = $random & 'hff;
        end
      end

      for (n = 0; n < reg_cnt; n++) begin
        bfm_master_ahb3.write(registers[n], wbuffer[n], hsize, hburst);  // write register
      end

      bfm_master_ahb3.idle();  // wait for HWDATA

      for (n = 0; n < reg_cnt; n++) begin
        bfm_master_ahb3.read(registers[n], rbuffer[n], hsize, hburst);  // read register
      end

      bfm_master_ahb3.idle();  // Idle bus
      wait fork;  // wait for all threads to complete

      for (n = 0; n < reg_cnt; n++) begin
        for (int beat = 0; beat < rbuffer[n].size(); beat++) begin
          // mask byte ...
          if (HSIZE == HSIZE_BYTE) begin
            rbuffer[n][beat] &= 'hff;
          end

          if (n == 1) begin  // IENABLE
            wbuffer[n][beat] &= {{32 - TIMERS{1'b0}}, {TIMERS{1'b1}}};
            wbuffer[n][beat] >>= 8 * beat;
          end

          if (rbuffer[n][beat] != wbuffer[n][beat]) begin
            $display("%0d,%0d: got %x, expected %x", n, beat, rbuffer[n][beat], wbuffer[n][beat]);
            error = 1;
            errors++;
          end
        end
      end

      if (error) $display("FAILED");
      else $display("OK");
    end

    // reset registers to all '0'
    wbuffer[0][0] = 0;
    for (n = 0; n < reg_cnt; n++) begin
      bfm_master_ahb3.write(registers[n], wbuffer[0], HSIZE_WORD, HBURST_SINGLE);  // write register
    end

    // discard buffers
    rbuffer.delete();
    wbuffer.delete();
  endtask : test_registers_rw32

  task program_prescaler(
    input [31:0] value
  );
    // create buffer
    logic [HDATA_SIZE-1:0] buffer[];
    buffer    = new[1];

    // assign buffer
    buffer[0] = value;

    $write("Programming prescaler ... ");
    bfm_master_ahb3.write(PRESCALE, buffer, HSIZE_WORD, HBURST_SINGLE);  // write value
    bfm_master_ahb3.idle();  // wait for HWDATA
    bfm_master_ahb3.read(PRESCALE, buffer, HSIZE_WORD, HBURST_SINGLE);  // read back value
    bfm_master_ahb3.idle();  // IDLE bus
    wait fork;

    if (buffer[0] !== value) begin
      errors++;
      $display("FAILED");
      $error("Wrong register value. Expected %0d, got %0d", value, buffer[0]);
    end else $display("OK");

    // discard buffer
    buffer.delete();
  endtask : program_prescaler

  task test_timer0();
    int cnt;
    localparam timecmp_value = 12;

    // create buffer
    logic [HDATA_SIZE-1:0] buffer[];
    buffer = new[1];

    $display("Testing timer0 ... ");
    $display("  Programming registers ... ");
    buffer[0] = timecmp_value;
    bfm_master_ahb3.write(TIMECMP, buffer, HSIZE_WORD, HBURST_SINGLE);  // write TIMECMP
    buffer[0] = 1;
    bfm_master_ahb3.write(IENABLE, buffer, HSIZE_BYTE, HBURST_SINGLE);  // Enable Timer0-interrupt
    buffer[0] = PRESCALE_VALUE - 1;
    bfm_master_ahb3.write(PRESCALE, buffer, HSIZE_WORD, HBURST_SINGLE);  // Enable core
    buffer[0] = 0;
    bfm_master_ahb3.write(TIME, buffer, HSIZE_WORD, HBURST_SINGLE);  // write TIME_LSB
    bfm_master_ahb3.write(TIME_MSB, buffer, HSIZE_WORD, HBURST_SINGLE);
    bfm_master_ahb3.idle();  // wait for HWDATA
    wait fork;

    // now wait for interrupt to rise
    $write("  Waiting for timer interrupt ... ");
    cnt = 0;
    while (!tint) begin
      @(posedge HCLK);

      cnt++;  // cnt should start increasing as soon as enable[0]='1'

      if (cnt > 1000) begin  // some watchdog value
        $display("FAILED");
        $error("Timer interrupt failed");
        break;
      end
    end

    if (tint) begin
      $display("OK");

      // check 'cnt' should be PRESCALE_VALUE * TIMECMP -1
      $write("  Checking time delay ... ");
      if (cnt !== PRESCALE_VALUE * timecmp_value - 1) begin
        errors++;
        $display("FAILED");
        $error("Wrong time delay. Expected %0d, got %0d", PRESCALE_VALUE * timecmp_value - 1, cnt);
      end else begin
        $display("OK");
      end
    end

    // A write to TIMECMP should clear the interrupt
    $write("  Clearing timer interrupt ... ");
    buffer[0] = 1000;  // some high number to prevent new interrupts
    bfm_master_ahb3.write(TIMECMP, buffer, HSIZE_WORD, HBURST_SINGLE);  // write TIMECMP
    bfm_master_ahb3.idle();

    cnt = 0;
    while (tint) begin
      @(posedge HCLK);

      cnt++;  // cnt should start increasing as soon as enable[0]='1'

      if (cnt > 1000) begin  // some watchdog value
        $display("FAILED");
        $error("Clearing interrupt failed");
        break;
      end
    end

    if (!tint) begin
      $display("OK");
    end

    // discard buffer
    buffer.delete();
  endtask : test_timer0
endmodule : peripheral_bfm_ahb3
