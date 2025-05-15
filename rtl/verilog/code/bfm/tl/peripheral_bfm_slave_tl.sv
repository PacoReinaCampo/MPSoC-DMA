module peripheral_bfm_slave_tl #(
  parameter TL_AW=32,                        // Address width in bits
  parameter TL_DW=32,                        // Data width in bits
  parameter TL_SRCW=8,                       // Source id width in bits
  parameter TL_SINKW=1,                      // Sink id width in bits
  parameter TL_DBW=(TL_DW>>3),               // Data mask width in bits
  parameter TL_SZW=$clog2($clog2(TL_DBW)+1)  // Size width in bits
) (
  // Global Signals
  output reg  clk,
  output reg  reset,

  // Channel A Signals (Mandatory)
  input  wire [         2:0] a_opcode,
  input  wire [         2:0] a_param,
  input  wire [TL_SZW  -1:0] a_size,
  input  wire [TL_SRCW -1:0] a_source,
  input  wire [TL_AW   -1:0] a_address,
  input  wire [TL_DBW  -1:0] a_mask,
  input  wire [TL_DW   -1:0] a_data,
  input  wire                a_corrupt,
  input  wire                a_valid,
  output reg                 a_ready,

  // Channel B Signals (TL-C only)
  input  wire [         2:0] b_opcode,
  input  wire [         2:0] b_param,
  input  wire [TL_SZW  -1:0] b_size,
  input  wire [TL_SRCW -1:0] b_source,
  input  wire [TL_AW   -1:0] b_address,
  input  wire [TL_DBW  -1:0] b_mask,
  input  wire [TL_DW   -1:0] b_data,
  input  wire                b_corrupt,
  input  wire                b_valid,
  output reg                 b_ready,

  // Channel C Signals (TL-C only)
  input  wire [         2:0] c_opcode,
  input  wire [         2:0] c_param,
  input  wire [TL_SZW  -1:0] c_size,
  input  wire [TL_SRCW -1:0] c_source,
  input  wire [TL_AW   -1:0] c_address,
  input  wire [TL_DW   -1:0] c_data,
  input  wire                c_corrupt,
  input  wire                c_valid,
  output reg                 c_ready,

  // Channel D Signals (Mandatory)
  input  wire [         2:0] d_opcode,
  input  wire [         2:0] d_param,
  input  wire [TL_SZW  -1:0] d_size,
  input  wire [TL_SRCW -1:0] d_source,
  input  wire [TL_SINKW-1:0] d_sink,
  input  wire                d_denied
  input  wire [TL_DW   -1:0] d_data,
  input  wire                d_corrupt,
  input  wire                d_valid,
  input  wire                d_ready,

  // Channel E Signals (TL-C only)
  input  wire [TL_SINKW-1:0] e_sink,
  input  wire                e_valid,
  output reg                 e_ready
);
endmodule  // peripheral_bfm_slave_tl
