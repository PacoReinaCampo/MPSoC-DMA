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
//              Master Slave Interface                                        //
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

module peripheral_tap_generator #(
  parameter TAPFILE          = "",
  parameter NUM_TESTS        = 0,
  parameter MAX_STRING_LEN   = 80,
  parameter MAX_FILENAME_LEN = 1024
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  integer                          f;  // File handle
  integer                          cur_tc = 0;  // Current testcase index
  integer                          numtests = NUM_TESTS;  // Total number of testcases

  reg     [MAX_FILENAME_LEN*8-1:0] tapfile;  // TAP file to write

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

  task set_file;
    input [MAX_FILENAME_LEN*8-1:0] f;
    begin
      if (cur_tc) begin
        $display("Error: Can't change file. Already started writing to %0s", tapfile);
      end else begin
        tapfile = f;
      end
    end
  endtask

  task set_numtests;
    input integer i;
    begin
      if (cur_tc) begin
        $display("Error: Can't change number of tests. Already started writing to %0s", tapfile);
      end else begin
        numtests = i;
      end
    end
  endtask

  task write_tc;
    input [MAX_STRING_LEN*8-1:0] description;

    input ok_i;
    begin
      if (f === 32'dx) begin
        if (tapfile == 0) begin
          $display("No TAP file specified");
        end else if (numtests == 0) begin
          $display("Number of tests must be specified");
        end else begin
          f = $fopen(tapfile, "w");
          $fwrite(f, "1..%0d\n", numtests);
        end
      end

      if (f) begin
        cur_tc = cur_tc + 1;

        if (!ok_i) begin
          $fwrite(f, "not ");
        end
        $fwrite(f, "ok %0d - %0s\n", cur_tc, description);
      end
    end
  endtask

  task ok;
    input [MAX_STRING_LEN*8-1:0] description;
    begin
      write_tc(description, 1);
    end
  endtask

  task nok;
    input [MAX_STRING_LEN*8-1:0] description;
    begin
      write_tc(description, 0);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // Module Body
  //////////////////////////////////////////////////////////////////////////////

  initial begin
    // Grab CLI parameters and use parameters for default values
    if (!$value$plusargs("tapfile=%s", tapfile)) begin
      tapfile = TAPFILE;
    end
  end
endmodule
