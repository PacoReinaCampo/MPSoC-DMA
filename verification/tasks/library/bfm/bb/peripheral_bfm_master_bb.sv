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

import peripheral_bb_pkg::*;

module peripheral_bfm_master_bb #(
  parameter HADDR_SIZE = 16,
  parameter HDATA_SIZE = 32
) (
  input HRESETn,
  input HCLK,

  // AHB Master Interface
  output reg                  HSEL,
  output reg [HADDR_SIZE-1:0] HADDR,
  output reg [HDATA_SIZE-1:0] HWDATA,
  input      [HDATA_SIZE-1:0] HRDATA,
  output reg                  HWRITE,
  output reg [           2:0] HSIZE,
  output reg [           2:0] HBURST,
  output reg [           3:0] HPROT,
  output reg [           1:0] HTRANS,
  output reg                  HMASTLOCK,
  input                       HREADY,
  input                       HRESP
);

  always @(negedge HRESETn) begin
    reset();
  end

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

  task reset();
    // Reset AHB Bus
    HSEL      = 1'b0;
    HADDR     = 'hx;
    HWDATA    = 'hx;
    HWRITE    = 'hx;
    HSIZE     = 'hx;
    HBURST    = 'hx;
    HPROT     = 'hx;
    HTRANS    = HTRANS_IDLE;
    HMASTLOCK = 'h0;

    @(posedge HRESETn);
  endtask

  task idle();
    // Put AHB Bus in IDLE state
    // Call after write or read sequence
    wait4hready();
    HSEL   <= 1'b0;
    HTRANS <= HTRANS_IDLE;
  endtask

  task automatic write(
    input [HADDR_SIZE-1:0] address,
    ref [HDATA_SIZE-1:0] data[],
    input [2:0] size,
    input [2:0] burst
  );
    int beats;

    beats = get_beats_per_burst(burst);
    if (beats < 0) begin
      beats = data.size();
    end

    fork
      ahb_cmd(address, size, burst, 1'b1, beats);
      ahb_data(address, size, burst, 1'b1, beats, data);
    join_any
  endtask

  task automatic read(
    input [HADDR_SIZE-1:0] address,
    ref [HDATA_SIZE-1:0] data[],
    input [2:0] size,
    input [2:0] burst
  );
    int beats;

    beats = get_beats_per_burst(burst);
    if (beats < 0) begin
      beats = data.size();
    end

    fork
      ahb_cmd(address, size, burst, 1'b0, beats);
      ahb_data(address, size, burst, 1'b0, beats, data);
    join_any
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

  task wait4hready;
    do @(posedge HCLK); while (!HREADY);
  endtask : wait4hready

  task automatic ahb_cmd(
    input [HADDR_SIZE-1:0] addr,
    input [2:0] size,
    input [2:0] burst,
    input rw,
    input int beats
  );
    wait4hready();
    HSEL      <= 1'b1;
    HADDR     <= addr;
    HWRITE    <= rw;
    HSIZE     <= size;
    HBURST    <= burst;
    HPROT     <= 'hx;
    HTRANS    <= HTRANS_NONSEQ;
    HMASTLOCK <= 1'b0;

    repeat (beats - 1) begin
      wait4hready();
      HADDR  <= next_address(size, burst);
      HTRANS <= HTRANS_SEQ;
    end
  endtask : ahb_cmd

  task automatic ahb_data(
    input [HADDR_SIZE-1:0] address,
    input [2:0] size,
    input [2:0] burst,
    input rw,
    input int beats,
    ref [HDATA_SIZE-1:0] data[]
  );

    logic [(HDATA_SIZE+7)/8 -1:0] byte_offset;
    logic [HDATA_SIZE       -1:0] data_copy[], tmp_var;

    if (!rw) begin
      HWDATA <= 'hx;

      // extra cycle for reading
      // read at the end of the cycle
      wait4hready();
    end else begin
      // copy data, prevent it being overwritten by caller
      data_copy = data;
    end

    wait4hready();

    // get the address offset. No checks if the offset is legal
    byte_offset = address % (HDATA_SIZE / 8);

    // transfer beats
    for (int nbeat = 0; nbeat < beats; nbeat++) begin
      wait4hready();

      if (rw) begin
        // writing ... transfer from data-buffer to AHB-HWDATA
        HWDATA <= 'hx;

        //'byte' is reserved, so use nbyte
        for (int nbyte = 0; nbyte < get_bytes_per_beat(size); nbyte++) begin
          HWDATA[(nbyte+byte_offset)*8+:8] <= data_copy[nbeat][nbyte*8+:8];
        end
      end else begin
        // reading ... transfer from AHB-HRDATA to data-buffer

        // 'byte' is reserved, so use nbyte
        // Store in temporary variable.
        // Using data[nbeat] directly fails when calling with a multi-dimensional dynamic array. Why????
        for (int nbyte = 0; nbyte < get_bytes_per_beat(size); nbyte++) begin
          tmp_var[nbyte*8+:8] = HRDATA[(nbyte+byte_offset)*8+:8];
        end

        // copy read-data
        data[nbeat] = tmp_var;
      end

      byte_offset += get_bytes_per_beat(size) % (HDATA_SIZE / 8);
    end
  endtask : ahb_data

  //////////////////////////////////////////////////////////////////////////////
  // Functions
  //////////////////////////////////////////////////////////////////////////////

  function int get_bytes_per_beat(
    input [2:0] hsize
  );
    case (hsize)
      HSIZE_B8:    get_bytes_per_beat = 1;
      HSIZE_B16:   get_bytes_per_beat = 2;
      HSIZE_B32:   get_bytes_per_beat = 4;
      HSIZE_B64:   get_bytes_per_beat = 8;
      HSIZE_B128:  get_bytes_per_beat = 16;
      HSIZE_B256:  get_bytes_per_beat = 32;
      HSIZE_B512:  get_bytes_per_beat = 64;
      HSIZE_B1024: get_bytes_per_beat = 128;
    endcase
  endfunction : get_bytes_per_beat

  function int get_beats_per_burst(
    input [2:0] hburst
  );
    case (hburst)
      HBURST_SINGLE: get_beats_per_burst = 1;
      HBURST_INCR:   get_beats_per_burst = -1;
      HBURST_INCR4:  get_beats_per_burst = 4;
      HBURST_WRAP4:  get_beats_per_burst = 4;
      HBURST_INCR8:  get_beats_per_burst = 8;
      HBURST_WRAP8:  get_beats_per_burst = 8;
      HBURST_INCR16: get_beats_per_burst = 16;
      HBURST_WRAP16: get_beats_per_burst = 16;
    endcase
  endfunction : get_beats_per_burst

  function [HADDR_SIZE-1:0] next_address(
    input [2:0] hsize, 
    input [2:0] hburst
  );
    // generate address mask
    int          beats_per_burst;
    logic [10:0] addr_mask;

    beats_per_burst = get_beats_per_burst(hburst);
    beats_per_burst = beats_per_burst > 0 ? beats_per_burst : 1;
    addr_mask       = (get_bytes_per_beat(hsize) * beats_per_burst) - 1;

    case (hburst)
      HBURST_WRAP4: begin
        next_address = (HADDR & ~addr_mask) | ((HADDR + get_bytes_per_beat(hsize)) & addr_mask);
      end
      HBURST_WRAP8: begin
        next_address = (HADDR & ~addr_mask) | ((HADDR + get_bytes_per_beat(hsize)) & addr_mask);
      end
      HBURST_WRAP16: begin
        next_address = (HADDR & ~addr_mask) | ((HADDR + get_bytes_per_beat(hsize)) & addr_mask);
      end
      default: begin
        next_address = HADDR + get_bytes_per_beat(hsize);
      end
    endcase
  endfunction : next_address
endmodule : peripheral_bfm_master_bb
