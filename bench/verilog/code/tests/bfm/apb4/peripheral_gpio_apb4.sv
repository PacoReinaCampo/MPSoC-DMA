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
//              AMBA4 APB-Lite Bus Interface                                  //
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

module peripheral_gpio_apb4 #(
  PDATA_SIZE = 8,  // must be a multiple of 8
  PADDR_SIZE = 4
) (
  input                         PRESETn,
  input                         PCLK,
  input                         PSEL,
  input                         PENABLE,
  input      [PADDR_SIZE  -1:0] PADDR,
  input                         PWRITE,
  input      [PDATA_SIZE/8-1:0] PSTRB,
  input      [PDATA_SIZE  -1:0] PWDATA,
  output reg [PDATA_SIZE  -1:0] PRDATA,
  output                        PREADY,
  output                        PSLVERR,

  output reg irq_o,

  input      [PDATA_SIZE  -1:0] gpio_i,
  output reg [PDATA_SIZE  -1:0] gpio_o,
  output reg [PDATA_SIZE  -1:0] gpio_oe
);
  //////////////////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam MODE = 0;
  localparam DIRECTION = 1;
  localparam OUTPUT = 2;
  localparam INPUT = 3;
  localparam TR_TYPE = 4;
  localparam TR_LVL0 = 5;
  localparam TR_LVL1 = 6;
  localparam TR_STAT = 7;
  localparam IRQ_ENA = 8;

  // Number of synchronisation flipflop stages on GPIO inputs
  localparam INPUT_STAGES = 2;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Control registers
  logic [PDATA_SIZE-1:0] mode_reg;
  logic [PDATA_SIZE-1:0] dir_reg;
  logic [PDATA_SIZE-1:0] out_reg;
  logic [PDATA_SIZE-1:0] in_reg;
  logic [PDATA_SIZE-1:0] tr_type_reg;
  logic [PDATA_SIZE-1:0] tr_lvl0_reg;
  logic [PDATA_SIZE-1:0] tr_lvl1_reg;
  logic [PDATA_SIZE-1:0] tr_stat_reg;
  logic [PDATA_SIZE-1:0] irq_ena_reg;

  // Trigger registers
  logic [PDATA_SIZE-1:0] tr_in_dly_reg;
  logic [PDATA_SIZE-1:0] tr_rising_edge_reg;
  logic [PDATA_SIZE-1:0] tr_falling_edge_reg;
  logic [PDATA_SIZE-1:0] tr_status;

  // Input register, to prevent metastability
  logic [PDATA_SIZE-1:0] input_regs          [INPUT_STAGES];


  //////////////////////////////////////////////////////////////////////////////
  //
  // Functions
  //

  // Is this a valid read access?
  function automatic is_read();
    return PSEL & PENABLE & ~PWRITE;
  endfunction : is_read

  // Is this a valid write access?
  function automatic is_write();
    return PSEL & PENABLE & PWRITE;
  endfunction : is_write

  // Is this a valid write to address 0x...?
  // Take 'address' as an argument
  function automatic is_write_to_adr(input [PADDR_SIZE-1:0] address);
    return is_write() & (PADDR == address);
  endfunction : is_write_to_adr

  // What data is written?
  //- Handles PSTRB, takes previous register/data value as an argument
  function automatic [PDATA_SIZE-1:0] get_write_value(input [PDATA_SIZE-1:0] orig_val);
    for (int n = 0; n < PDATA_SIZE / 8; n++) begin
      get_write_value[n*8+:8] = PSTRB[n] ? PWDATA[n*8+:8] : orig_val[n*8+:8];
    end
  endfunction : get_write_value

  // Clear bits on write
  //- Handles PSTRB
  function automatic [PDATA_SIZE-1:0] get_clearonwrite_value(input [PDATA_SIZE-1:0] orig_val);
    for (int n = 0; n < PDATA_SIZE / 8; n++) begin
      get_clearonwrite_value[n*8 +: 8] = PSTRB[n] ? orig_val[n*8 +: 8] & ~PWDATA[n*8 +: 8] : orig_val[n*8 +: 8];
    end
  endfunction : get_clearonwrite_value

  //////////////////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // APB accesses

  // The core supports zero-wait state accesses on all transfers.
  // It is allowed to drive PREADY with a hard wired signal
  assign PREADY  = 1'b1;  // always ready
  assign PSLVERR = 1'b0;  // Never an error

  // APB Writes

  // APB write to Mode register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      mode_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(MODE)) begin
      mode_reg <= get_write_value(mode_reg);
    end
  end

  // APB write to Direction register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      dir_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(DIRECTION)) begin
      dir_reg <= get_write_value(dir_reg);
    end
  end

  // APB write to Output register
  // treat writes to Input register same
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      out_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(OUTPUT) || is_write_to_adr(INPUT)) begin
      out_reg <= get_write_value(out_reg);
    end
  end

  // APB write to Trigger Type register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_type_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(TR_TYPE)) begin
      tr_type_reg <= get_write_value(tr_type_reg);
    end
  end

  // APB write to Trigger Level/Edge0 register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_lvl0_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(TR_LVL0)) begin
      tr_lvl0_reg <= get_write_value(tr_lvl0_reg);
    end
  end

  // APB write to Trigger Level/Edge1 register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_lvl1_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(TR_LVL1)) begin
      tr_lvl1_reg <= get_write_value(tr_lvl1_reg);
    end
  end

  // APB write to Trigger Status register
  // Writing a '1' clears the status register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_stat_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(TR_STAT)) begin
      tr_stat_reg <= get_clearonwrite_value(tr_stat_reg) | tr_status;
    end else begin
      tr_stat_reg <= tr_stat_reg | tr_status;
    end
  end

  // APB write to Interrupt Enable register
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      irq_ena_reg <= {PDATA_SIZE{1'b0}};
    end else if (is_write_to_adr(IRQ_ENA)) begin
      irq_ena_reg <= get_write_value(irq_ena_reg);
    end
  end

  // APB Reads
  always @(posedge PCLK) begin
    case (PADDR)
      MODE:      PRDATA <= mode_reg;
      DIRECTION: PRDATA <= dir_reg;
      OUTPUT:    PRDATA <= out_reg;
      INPUT:     PRDATA <= in_reg;
      TR_TYPE:   PRDATA <= tr_type_reg;
      TR_LVL0:   PRDATA <= tr_lvl0_reg;
      TR_LVL1:   PRDATA <= tr_lvl1_reg;
      TR_STAT:   PRDATA <= tr_stat_reg;
      IRQ_ENA:   PRDATA <= irq_ena_reg;
      default:   PRDATA <= {PDATA_SIZE{1'b0}};
    endcase
  end

  // Internals
  always @(posedge PCLK) begin
    for (int n = 0; n < INPUT_STAGES; n++) begin
      if (n == 0) begin
        input_regs[n] <= gpio_i;
      end else begin
        input_regs[n] <= input_regs[n-1];
      end
    end
  end

  always @(posedge PCLK) begin
    in_reg <= input_regs[INPUT_STAGES-1];
  end

  // mode
  // 0=push-pull    drive out_reg value onto transmitter input
  // 1=open-drain   always drive '0' onto transmitter
  always @(posedge PCLK) begin
    for (int n = 0; n < PDATA_SIZE; n++) begin
      gpio_o[n] <= mode_reg[n] ? 1'b0 : out_reg[n];
    end
  end

  // direction  mode          out_reg
  // 0=input                           disable transmitter-enable (output enable)
  // 1=output   0=push-pull            always enable transmitter
  //            1=open-drain  1=Hi-Z   disable transmitter
  //                          0=low    enable transmitter
  always @(posedge PCLK) begin
    for (int n = 0; n < PDATA_SIZE; n++) begin
      gpio_oe[n] <= dir_reg[n] & ~(mode_reg[n] ? out_reg[n] : 1'b0);
    end
  end

  // Triggers

  // delay input register
  always @(posedge PCLK) begin
    tr_in_dly_reg <= in_reg;
  end

  // detect rising edge
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_rising_edge_reg <= {PDATA_SIZE{1'b0}};
    end else begin
      tr_rising_edge_reg <= in_reg & ~tr_in_dly_reg;
    end
  end

  // detect falling edge
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      tr_falling_edge_reg <= {PDATA_SIZE{1'b0}};
    end else begin
      tr_falling_edge_reg <= tr_in_dly_reg & ~in_reg;
    end
  end

  // trigger status
  always_comb begin
    for (int n = 0; n < PDATA_SIZE; n++) begin
      case (tr_type_reg[n])
        0: tr_status[n] = (tr_lvl0_reg[n] & ~in_reg[n]) | (tr_lvl1_reg[n] & in_reg[n]);
        1: tr_status[n] = (tr_lvl0_reg[n] & tr_falling_edge_reg[n]) | (tr_lvl1_reg[n] & tr_rising_edge_reg[n]);
      endcase
    end
  end

  // Interrupt
  always @(posedge PCLK, negedge PRESETn) begin
    if (!PRESETn) begin
      irq_o <= 1'b0;
    end else begin
      irq_o <= |(irq_ena_reg & tr_stat_reg);
    end
  end
endmodule
