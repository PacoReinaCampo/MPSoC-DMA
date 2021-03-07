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

module peripheral_bfm_transactor_wb # (
  parameter                AW                    = 32,
  parameter                DW                    = 32,
  parameter                AUTORUN               = 1,
  parameter                MEM_HIGH              = 32'hffffffff,
  parameter                MEM_LOW               = 0,
  parameter                TRANSACTIONS_PARAM    = 1000,
  parameter                SEGMENT_SIZE          = 0,
  parameter                NUM_SEGMENTS          = 0,
  parameter                SUBTRANSACTIONS_PARAM = 100,
  parameter                VERBOSE               = 0,
  parameter                MAX_BURST_LEN         = 32,
  parameter                MAX_WAIT_STATES       = 8,
  parameter                CLASSIC_PROB          = 33,
  parameter                CONST_BURST_PROB      = 33,
  parameter                INCR_BURST_PROB       = 34,
  parameter                SEED_PARAM            = 0
)
  (
    input 	      wb_clk_i,
    input 	      wb_rst_i,
    output [AW-1:0]   wb_adr_o,
    output [DW-1:0]   wb_dat_o,
    output [DW/8-1:0] wb_sel_o,
    output 	      wb_we_o,
    output 	      wb_cyc_o,
    output 	      wb_stb_o,
    output [2:0]      wb_cti_o,
    output [1:0]      wb_bte_o,
    input [DW-1:0]    wb_dat_i,
    input 	      wb_ack_i,
    input 	      wb_err_i,
    input 	      wb_rty_i,
    output reg 	      done
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  parameter CLASSIC_CYCLE = 1'b0;
  parameter BURST_CYCLE   = 1'b1;

  parameter READ  = 1'b0;
  parameter WRITE = 1'b1;

  parameter [2:0] CTI_CLASSIC      = 3'b000;
  parameter [2:0] CTI_CONST_BURST  = 3'b001;
  parameter [2:0] CTI_INC_BURST    = 3'b010;
  parameter [2:0] CTI_END_OF_BURST = 3'b111;


  parameter [1:0] BTE_LINEAR  = 2'd0;
  parameter [1:0] BTE_WRAP_4  = 2'd1;
  parameter [1:0] BTE_WRAP_8  = 2'd2;
  parameter [1:0] BTE_WRAP_16 = 2'd3;

  parameter ADR_LSB = $clog2(DW/8);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  integer SEED            = SEED_PARAM;
  integer TRANSACTIONS    = TRANSACTIONS_PARAM;
  integer SUBTRANSACTIONS = SUBTRANSACTIONS_PARAM;

  integer cnt_cti_classic     = 0;
  integer cnt_cti_const_burst = 0;
  integer cnt_cti_inc_burst   = 0;
  integer cnt_cti_invalid     = 0;

  integer cnt_bte_linear  = 0;
  integer cnt_bte_wrap_4  = 0;
  integer cnt_bte_wrap_8  = 0;
  integer cnt_bte_wrap_16 = 0;

  integer                   burst_length;
  reg [1:0]                 burst_type;

  reg [2:0]                 cycle_type;

  integer                   transaction;
  integer                   subtransaction;

  reg                       err;

  reg [AW-1:0]              t_address;
  reg [AW-1:0]              t_adr_high;
  reg [AW-1:0]              t_adr_low;
  reg [AW-1:0]              st_address;
  reg                       st_type;

  integer 		     mem_lo;
  integer 		     mem_hi;
  integer 		     segment;

  //////////////////////////////////////////////////////////////////
  //
  // Functions
  //
  function [AW-1:0] gen_adr;
    input integer low;
    input integer high;
    begin
      gen_adr = (low + ({$random(SEED)} % (high-low))) &  {{AW-ADR_LSB{1'b1}},{ADR_LSB{1'b0}}};
    end
  endfunction

  function [2:0] gen_cycle_type;
    input integer cycle_type_prob;
    begin
      if (cycle_type_prob <= CLASSIC_PROB) begin
        gen_cycle_type                = 3'b000;
      end else if (cycle_type_prob <= (CLASSIC_PROB + CONST_BURST_PROB)) begin
        gen_cycle_type                = CTI_CONST_BURST;
      end
      else begin
        gen_cycle_type                = CTI_INC_BURST;
      end
    end
  endfunction

  function [AW+3+2+32-1:0] gen_cycle_params;
    input [AW-1:0] adr_min_i;
    input [AW-1:0] adr_max_i;

    reg [AW-1:0]   adr_low;
    reg [AW-1:0]   adr_high;

    reg [AW-1:0]   address;
    reg [2:0]      cycle_type;
    reg [1:0]      burst_type;
    reg [31:0]     burst_length;

    begin
      adr_low  = 0;
      adr_high = 0;
      // Repeat check for MEM_LOW/MEM_HIGH bounds until satisfied
      while((adr_high > adr_max_i) || (adr_low < adr_min_i) || (adr_high == adr_low)) begin
        address                = gen_adr(adr_min_i, adr_max_i);
        cycle_type             = gen_cycle_type({$random(SEED)} % 100);

        burst_type = (cycle_type === CTI_INC_BURST) ? ({$random(SEED)} % 4) : 0;

        burst_length = (cycle_type === CTI_CLASSIC) ? 1 :
        ({$random(SEED)} % MAX_BURST_LEN) + 1;

        {adr_high, adr_low} = adr_range(address, burst_length, cycle_type, burst_type);
      end
      gen_cycle_params = {address, cycle_type, burst_type, burst_length};
    end
  endfunction

  `ifdef BROKEN_CLOG2
  function integer clog2;
    input integer in;
    begin
      in = in - 1;
      for (clog2 = 0; in > 0; clog2=clog2+1)
        in = in >> 1;
    end
  endfunction
  `endif

  /*Return a 2*AW array with the highest and lowest accessed addresses
    based on starting address and burst type
    TODO: Account for short wrap bursts. Fix for 8-bit mode*/
  function [2*AW-1:0] adr_range;
    input [AW-1:0]          adr_i;
    input [$clog2(MAX_BURST_LEN+1):0] len_i;
    input [2:0]             cti_i;
    input [1:0]             bte_i;
    parameter               bpw = DW/8; //Bytes per word
    reg [AW-1:0]            adr;
    reg [AW-1:0]            adr_high;
    reg [AW-1:0]            adr_low;
    integer 		     shift;

    begin
      //if (bpw == 4) begin
      `ifdef BROKEN_CLOG2
      shift = clog2(bpw);
      `else
      shift = $clog2(bpw);
      `endif
      adr                   = adr_i>>shift;
      if (cti_i === CTI_INC_BURST)
        case (bte_i)
          BTE_LINEAR : begin
            adr_high          = adr+len_i;
            adr_low           = adr;
          end
          BTE_WRAP_4   : begin
            adr_high          = adr[AW-1:2]*4+4;
            adr_low           = adr[AW-1:2]*4;
          end
          BTE_WRAP_8   : begin
            adr_high          = adr[AW-1:3]*8+8;
            adr_low           = adr[AW-1:3]*8;
          end
          BTE_WRAP_16  : begin
            adr_high          = adr[AW-1:4]*16+16;
            adr_low           = adr[AW-1:4]*16;
          end
          default : begin
            $display("%d : Illegal burst type (%b)", $time, bte_i);
            adr_range         = {2*AW{1'bx}};
          end
        endcase // case (bte_i)
      else begin
        adr_high          = adr+1;
        adr_low           = adr;
      end

      adr_high = (adr_high << shift)-1;
      adr_low  = adr_low << shift;
      adr_range             = {adr_high, adr_low};
      //end
    end
  endfunction

  //////////////////////////////////////////////////////////////////
  //
  // Tasks
  //

  //Gather transaction statistics
  //TODO: Record shortest/longest bursts.
  task update_stats;
    input [2:0] cti;
    input [1:0] bte;
    input integer burst_length;
    begin
      case (cti)
        CTI_CLASSIC:     cnt_cti_classic = cnt_cti_classic + 1;
        CTI_CONST_BURST: cnt_cti_const_burst = cnt_cti_const_burst + 1;
        CTI_INC_BURST:   cnt_cti_inc_burst = cnt_cti_inc_burst + 1;
        default:         cnt_cti_invalid = cnt_cti_invalid + 1;
      endcase // case (cti)
      if (cti === CTI_INC_BURST)
        case (bte)
          BTE_LINEAR  : cnt_bte_linear  = cnt_bte_linear  + 1;
          BTE_WRAP_4  : cnt_bte_wrap_4  = cnt_bte_wrap_4  + 1;
          BTE_WRAP_8  : cnt_bte_wrap_8  = cnt_bte_wrap_8  + 1;
          BTE_WRAP_16 : cnt_bte_wrap_16 = cnt_bte_wrap_16 + 1;
          default : $display("Invalid BTE %2b", bte);
        endcase // case (bte)
    end
  endtask

  task display_stats;
    begin
      $display("#################################");
      $display("##### Cycle Type Statistics #####");
      $display("#################################");
      $display("Invalid cycle types   : %0d", cnt_cti_invalid);
      $display("Classic cycles        : %0d", cnt_cti_classic);
      $display("Constant burst cycles : %0d", cnt_cti_const_burst);
      $display("Increment burst cycles: %0d", cnt_cti_inc_burst);
      $display("   Linear bursts      : %0d", cnt_bte_linear);
      $display("   4-beat bursts      : %0d", cnt_bte_wrap_4);
      $display("   8-beat bursts      : %0d", cnt_bte_wrap_8);
      $display("  16-beat bursts      : %0d", cnt_bte_wrap_16);
    end
  endtask

  task display_subtransaction;
    input [AW-1:0] address;
    input [2:0]    cycle_type;
    input [1:0]    burst_type;
    input integer  burst_length;
    input 	   wr;

    begin
      if (VERBOSE > 0) begin
        $write("  Subtransaction %0d.%0d ", transaction, subtransaction);
        if (wr)
          $write("(Write)");
        else
          $write("(Read) ");
        $display(": Start Address: %h, Cycle Type: %b, Burst Type: %b, Burst Length: %0d", address, cycle_type, burst_type, burst_length);
      end
    end
  endtask

  task set_transactions;
    input integer transactions_i;
    begin
      TRANSACTIONS = transactions_i;
    end
  endtask

  task set_subtransactions;
    input integer transactions_i;
    begin
      SUBTRANSACTIONS = transactions_i;
    end
  endtask

  // Task to fill Write Data array.
  // random data will be used.
  task fill_wdata_array;
    input  [31:0]            burst_length;

    integer 		     word;

    begin
      // Fill write data array
      for(word = 0; word <= burst_length-1; word = word + 1) begin
        bfm_master_wb.write_data[word] = $random;
      end
    end
  endtask

  task display_settings;
    begin
      $display("##############################################################");
      $display("############# Wishbone Master Test Configuration #############");
      $display("##############################################################");
      $display("");
      $display("%m:");
      if (NUM_SEGMENTS > 0) begin
        $display("  Number of segments    : %0d", NUM_SEGMENTS);
        $display("  Segment size          : %h", SEGMENT_SIZE);
        $display("  Memory High Address   : %h", MEM_LOW+NUM_SEGMENTS*SEGMENT_SIZE-1);
        $display("  Memory Low Address    : %h", MEM_LOW);
      end
      else begin
        $display("  Memory High Address   : %h", MEM_HIGH);
        $display("  Memory Low Address    : %h", MEM_LOW);
      end
      $display("  Transactions          : %0d", TRANSACTIONS);
      $display("  Subtransactions       : %0d", SUBTRANSACTIONS);
      $display("  Max Burst Length      : %0d", MAX_BURST_LEN);
      $display("  Max Wait States       : %0d", MAX_WAIT_STATES);
      $display("  Classic Cycle Prob    : %0d", CLASSIC_PROB);
      $display("  Const Addr Cycle Prob : %0d", CONST_BURST_PROB);
      $display("  Incr Addr Cycle Prob  : %0d", INCR_BURST_PROB);
      $display("  Write Data            : Random");
      $display("  Buffer Data           : Mirrors RAM");
      $display("  $random Seed          : %0d", SEED);
      $display("  Verbosity             : %0d", VERBOSE);
      $display("");
      $display("############# Starting Wishbone Master Tests...  #############");
      $display("");
    end
  endtask

  task run;
    begin
      if(TRANSACTIONS < 1) begin
        $display("%0d transactions requested. Number of transactions must be set to > 0", TRANSACTIONS);
        $finish;
      end
      bfm_master_wb.reset;
      done    = 0;
      st_type = 0;
      err     = 0;

      for(transaction = 1 ; transaction <= TRANSACTIONS; transaction = transaction + 1) begin
        if (VERBOSE>0)
          $display("%m : Transaction: %0d/%0d", transaction, TRANSACTIONS);
        else if(!(transaction%(SUBTRANSACTIONS/10)))
          $display("%m : Transaction: %0d/%0d", transaction, TRANSACTIONS);

        // Generate the random value for the number of wait states. This will
        // be used for all of this transaction
        bfm_master_wb.wait_states                 = {$random(SEED)} % (MAX_WAIT_STATES+1);
        if (VERBOSE>2)
          $display("  Number of Wait States for Transaction %0d is %0d", transaction, bfm_master_wb.wait_states);

        //If running in segment mode, cap mem_high/mem_low to a segment
        if (NUM_SEGMENTS > 0) begin
          segment = {$random(SEED)} % NUM_SEGMENTS;
          mem_lo =  MEM_LOW + segment    * SEGMENT_SIZE;
          mem_hi =  MEM_LOW + (segment+1) * SEGMENT_SIZE - 1;
        end
        else begin
          mem_lo = MEM_LOW;
          mem_hi = MEM_HIGH;
        end

        // Check if initial base address and max burst length lie within
        // mem_hi/mem_lo bounds. If not, regenerate random values until condition met.
        t_adr_high  = 0;
        t_adr_low   = 0;
        while((t_adr_high > mem_hi) || (t_adr_low < mem_lo) || (t_adr_high == t_adr_low)) begin
          t_address                   = gen_adr(mem_lo, mem_hi);
          {t_adr_high,t_adr_low}      = adr_range(t_address, MAX_BURST_LEN, CTI_INC_BURST, BTE_LINEAR);
        end

        // Write Transaction
        if (VERBOSE>0)
          $display("  Transaction %0d Initialisation (Write): Start Address: %h, Burst Length: %0d", transaction, t_address, MAX_BURST_LEN);

        // Fill Write Array then Send the Write Transaction
        fill_wdata_array(MAX_BURST_LEN);
        bfm_master_wb.write_burst(t_address, t_address, {DW/8{1'b1}}, CTI_INC_BURST, BTE_LINEAR, MAX_BURST_LEN, err);
        update_stats(cycle_type, burst_type, burst_length);

        // Read data can be read back from wishbone memory.
        if (VERBOSE>0)
          $display("  Transaction %0d Initialisation (Read): Start Address: %h, Burst Length: %0d", transaction, t_address, MAX_BURST_LEN);
        bfm_master_wb.read_burst_comp(t_address, t_address, {DW/8{1'b1}}, CTI_INC_BURST, BTE_LINEAR, MAX_BURST_LEN, err);
        update_stats(cycle_type, burst_type, burst_length);

        if (VERBOSE>0)
          $display("Transaction %0d initialisation ok (Start Address: %h, Cycle Type: %b, Burst Type: %b, Burst Length: %0d)", transaction, t_address, CTI_INC_BURST, BTE_LINEAR, MAX_BURST_LEN);

        // Start subtransaction loop.
        for (subtransaction = 1; subtransaction <= SUBTRANSACTIONS ; subtransaction = subtransaction + 1) begin

          // Transaction Type: 0=Read, 1=Write
          st_type                     = {$random(SEED)} % 2;

          {st_address, cycle_type, burst_type, burst_length} = gen_cycle_params(t_adr_low, t_adr_high);

          display_subtransaction(st_address, cycle_type, burst_type, burst_length, st_type);

          if (~st_type) begin

            // Send Read Transaction
            bfm_master_wb.read_burst_comp(t_address, st_address, {DW/8{1'b1}}, cycle_type, burst_type, burst_length, err);
          end
          else begin
            // Fill Write Array then Send the Write Transaction
            fill_wdata_array(burst_length);
            bfm_master_wb.write_burst(t_address, st_address, {DW/8{1'b1}}, cycle_type, burst_type, burst_length, err);

          end // if (st_type)
          update_stats(cycle_type, burst_type, burst_length);
        end // for (subtransaction=0;...

        // Final consistency check...
        if (VERBOSE>0)
          $display("Transaction %0d Buffer Consistency Check: Start Address: %h, Burst Length: %0d", transaction, t_address, MAX_BURST_LEN);
        bfm_master_wb.read_burst_comp(t_address, t_address, 4'hf, CTI_INC_BURST, BTE_LINEAR, MAX_BURST_LEN, err);

        if (VERBOSE>0)
          $display("Transaction %0d Completed Successfully", transaction);

        // Clear Buffer Data before next transaction
        bfm_master_wb.clear_buffer_data;
      end // for (transaction=0;...
      done = 1;
    end
  endtask

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // Check Cycle Probability values add up to 100
  initial begin
    if ((CLASSIC_PROB + CONST_BURST_PROB + INCR_BURST_PROB) != 100) begin
      $display("ERROR: Wishbone Cycle Probability values must total 100. Current values total %0d:", (CLASSIC_PROB + CONST_BURST_PROB + INCR_BURST_PROB));
      $display("         Classic Cycle Probability                    : %0d", CLASSIC_PROB);
      $display("         Constant Address Burst Cycle Probability     : %0d", CONST_BURST_PROB);
      $display("         Incrementing Address Burst Cycle Probability : %0d", INCR_BURST_PROB);
      $finish(1);
    end
    if (AUTORUN) begin
      display_settings;
      run;
      display_stats;
      done = 1;
    end
  end

  peripheral_bfm_master_wb #(
    .DW (DW),
    .MAX_BURST_LEN           (MAX_BURST_LEN),
    .MAX_WAIT_STATES         (MAX_WAIT_STATES),
    .VERBOSE                 (VERBOSE)
  )
  bfm_master_wb (
    .wb_clk_i                (wb_clk_i),
    .wb_rst_i                (wb_rst_i),
    .wb_adr_o                (wb_adr_o),
    .wb_dat_o                (wb_dat_o),
    .wb_sel_o                (wb_sel_o),
    .wb_we_o                 (wb_we_o),
    .wb_cyc_o                (wb_cyc_o),
    .wb_stb_o                (wb_stb_o),
    .wb_cti_o                (wb_cti_o),
    .wb_bte_o                (wb_bte_o),
    .wb_dat_i                (wb_dat_i),
    .wb_ack_i                (wb_ack_i),
    .wb_err_i                (wb_err_i),
    .wb_rty_i                (wb_rty_i)
  );
endmodule
