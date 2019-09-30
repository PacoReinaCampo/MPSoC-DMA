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
//              Network on Chip Message Passing Buffer                        //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              Mesh Topology                                                 //
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

module riscv_mpb #(
  parameter PLEN     = 64,
  parameter XLEN     = 64,
  parameter CHANNELS = 2,
  parameter SIZE     = 16
)
  (
    //Common signals
    input                  HRESETn,
    input                  HCLK,

    //NoC Interface
    input      [CHANNELS-1:0][PLEN -1:0] noc_in_flit,
    input      [CHANNELS-1:0]            noc_in_last,
    input      [CHANNELS-1:0]            noc_in_valid,
    output reg [CHANNELS-1:0]            noc_in_ready,

    output reg [CHANNELS-1:0][PLEN -1:0] noc_out_flit,
    output reg [CHANNELS-1:0]            noc_out_last,
    output reg [CHANNELS-1:0]            noc_out_valid,
    input      [CHANNELS-1:0]            noc_out_ready,

    //AHB input interface
    input                  mst_HSEL,
    input      [PLEN -1:0] mst_HADDR,
    input      [XLEN -1:0] mst_HWDATA,
    output     [XLEN -1:0] mst_HRDATA,
    input                  mst_HWRITE,
    input      [      2:0] mst_HSIZE,
    input      [      2:0] mst_HBURST,
    input      [      3:0] mst_HPROT,
    input      [      1:0] mst_HTRANS,
    input                  mst_HMASTLOCK,
    output                 mst_HREADYOUT,
    output                 mst_HRESP
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam CHANNELS_BITS = $clog2(CHANNELS);

  ////////////////////////////////////////////////////////////////
  //
  // Functions
  //

  function integer onehot2int;
    input [CHANNELS-1:0] onehot;

    for (onehot2int = - 1; |onehot; onehot2int++) onehot = onehot >> 1;
  endfunction //onehot2int

  function [2:0] highest_requested_priority (
    input [CHANNELS-1:0] hsel
  );
    logic [2:0] priorities [CHANNELS];
    integer n;
    highest_requested_priority = 0;
    for (n=0; n<CHANNELS; n++) begin
      priorities[n] = n;
      if (hsel[n] && priorities[n] > highest_requested_priority) highest_requested_priority = priorities[n];
    end
  endfunction //highest_requested_priority

  function [CHANNELS-1:0] requesters;
    input [CHANNELS-1:0] hsel;
    input [         2:0] priority_select;
    logic [2:0] priorities [CHANNELS];
    integer n;

    for (n=0; n<CHANNELS; n++) begin
      priorities[n] = n;
      requesters[n] = (priorities[n] == priority_select) & hsel[n];
    end
  endfunction //requesters

  function [CHANNELS-1:0] nxt_master;
    input [CHANNELS-1:0] pending_masters;  //pending masters for the requesed priority level
    input [CHANNELS-1:0] last_master;      //last granted master for the priority level
    input [CHANNELS-1:0] current_master;   //current granted master (indpendent of priority level)

    integer n, offset;
    logic [CHANNELS*2-1:0] sr;

    //default value, don't switch if not needed
    nxt_master = current_master;

    //implement round-robin
    offset = onehot2int(last_master) + 1;

    sr = {pending_masters, pending_masters};
    for (n = 0; n < CHANNELS; n++)
      if ( sr[n + offset] ) return (1 << ((n+offset) % CHANNELS));
  endfunction

  ////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  genvar c;

  //AHB interface
  logic [CHANNELS-1:0]            bus_HSEL;
  logic [CHANNELS-1:0][PLEN -1:0] bus_HADDR;
  logic [CHANNELS-1:0][XLEN -1:0] bus_HWDATA;
  logic [CHANNELS-1:0][XLEN -1:0] bus_HRDATA;
  logic [CHANNELS-1:0]            bus_HWRITE;
  logic [CHANNELS-1:0][      2:0] bus_HSIZE;
  logic [CHANNELS-1:0][      2:0] bus_HBURST;
  logic [CHANNELS-1:0][      3:0] bus_HPROT;
  logic [CHANNELS-1:0][      1:0] bus_HTRANS;
  logic [CHANNELS-1:0]            bus_HMASTLOCK;
  logic [CHANNELS-1:0]            bus_HREADYOUT;
  logic [CHANNELS-1:0]            bus_HRESP;

  logic [         2:0] requested_priority_lvl;   //requested priority level
  logic [CHANNELS-1:0] priority_masters;         //all masters at this priority level

  logic [CHANNELS-1:0] pending_master,           //next master waiting to be served
                      last_granted_master;      //for requested priority level
  logic [CHANNELS-1:0] last_granted_masters [3]; //per priority level, for round-robin


  logic [CHANNELS_BITS-1:0] granted_master_idx;     //granted master as index

  logic [CHANNELS-1:0] granted_master;

  ////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //get highest priority from selected masters
  assign requested_priority_lvl = highest_requested_priority(bus_HSEL);

  //get pending masters for the highest priority requested
  assign priority_masters = requesters(bus_HSEL, requested_priority_lvl);

  //get last granted master for the priority requested
  assign last_granted_master = last_granted_masters[requested_priority_lvl];

  //get next master to serve
  assign pending_master = nxt_master(priority_masters, last_granted_master, granted_master);

  //select new master
  always @(posedge HCLK, negedge HRESETn) begin
    if      ( !HRESETn  ) granted_master <= 'h1;
    else if ( !mst_HSEL ) granted_master <= pending_master;
  end

  //store current master (for this priority level)
  always @(posedge HCLK, negedge HRESETn) begin
    if      ( !HRESETn  ) last_granted_masters[requested_priority_lvl] <= 'h1;
    else if ( !mst_HSEL ) last_granted_masters[requested_priority_lvl] <= pending_master;
  end

  //get signals from current requester
  always @(posedge HCLK, negedge HRESETn) begin
    if      ( !HRESETn  ) granted_master_idx <= 'h0;
    else if ( !mst_HSEL ) granted_master_idx <= onehot2int(pending_master);
  end

  generate
    for (c=0; c < CHANNELS; c=c+1) begin
      assign bus_HSEL      [c] = mst_HSEL;
      assign bus_HADDR     [c] = mst_HADDR;
      assign bus_HWDATA    [c] = mst_HWDATA;
      assign bus_HWRITE    [c] = mst_HWRITE;
      assign bus_HSIZE     [c] = mst_HSIZE;
      assign bus_HBURST    [c] = mst_HBURST;
      assign bus_HPROT     [c] = mst_HPROT;
      assign bus_HTRANS    [c] = mst_HTRANS;
      assign bus_HMASTLOCK [c] = mst_HMASTLOCK;
    end
  endgenerate

  assign mst_HRDATA    = bus_HRDATA    [granted_master_idx];
  assign mst_HREADYOUT = bus_HREADYOUT [granted_master_idx];
  assign mst_HRESP     = bus_HRESP     [granted_master_idx];

  generate
    for (c=0; c < CHANNELS; c=c+1) begin
      riscv_mpb_endpoint #(
        .XLEN ( XLEN ),
        .PLEN ( PLEN ),
        .SIZE ( SIZE )
      )
      mpb_endpoint (
        //Common signals
        .HRESETn ( HRESETn ),
        .HCLK    ( HCLK    ),

        //NoC Interface
        .noc_in_flit   ( noc_in_flit   [c] ),
        .noc_in_last   ( noc_in_last   [c] ),
        .noc_in_valid  ( noc_in_valid  [c] ),
        .noc_in_ready  ( noc_in_ready  [c] ),

        .noc_out_flit  ( noc_out_flit   [c] ),
        .noc_out_last  ( noc_out_last   [c] ),
        .noc_out_valid ( noc_out_valid  [c] ),
        .noc_out_ready ( noc_out_ready  [c] ),

        //AHB master interface
        .HSEL          ( bus_HSEL      [c] ),
        .HADDR         ( bus_HADDR     [c] ),
        .HWDATA        ( bus_HWDATA    [c] ),
        .HRDATA        ( bus_HRDATA    [c] ),
        .HWRITE        ( bus_HWRITE    [c] ),
        .HSIZE         ( bus_HSIZE     [c] ),
        .HBURST        ( bus_HBURST    [c] ),
        .HPROT         ( bus_HPROT     [c] ),
        .HTRANS        ( bus_HTRANS    [c] ),
        .HMASTLOCK     ( bus_HMASTLOCK [c] ),
        .HREADYOUT     ( bus_HREADYOUT [c] ),
        .HRESP         ( bus_HRESP     [c] )
      );
    end
  endgenerate
endmodule
