module peripheral_bfm_master_tl #(
  parameter TL_AW=32,                        // Address width in bits
  parameter TL_DW=32,                        // Data width in bits
  parameter TL_SRCW=8,                       // Source id width in bits
  parameter TL_SINKW=1,                      // Sink id width in bits
  parameter TL_DBW=(TL_DW>>3),               // Data mask width in bits
  parameter TL_SZW=$clog2($clog2(TL_DBW)+1)  // Size width in bits
) (
  // Global Signals
  input  wire clk,
  input  wire reset,

  // Channel A Signals (Mandatory)
  output reg  [         2:0] a_opcode,
  output reg  [         2:0] a_param,
  output reg  [TL_SZW  -1:0] a_size,
  output reg  [TL_SRCW -1:0] a_source,
  output reg  [TL_AW   -1:0] a_address,
  output reg  [TL_DBW  -1:0] a_mask,
  output reg  [TL_DW   -1:0] a_data,
  output reg                 a_corrupt,
  output reg                 a_valid,
  input  wire                a_ready,

  // Channel B Signals (TL-C only)
  output reg  [         2:0] b_opcode,
  output reg  [         2:0] b_param,
  output reg  [TL_SZW  -1:0] b_size,
  output reg  [TL_SRCW -1:0] b_source,
  output reg  [TL_AW   -1:0] b_address,
  output reg  [TL_DBW  -1:0] b_mask,
  output reg  [TL_DW   -1:0] b_data,
  output reg                 b_corrupt,
  output reg                 b_valid,
  input  wire                b_ready,

  // Channel C Signals (TL-C only)
  output reg  [         2:0] c_opcode,
  output reg  [         2:0] c_param,
  output reg  [TL_SZW  -1:0] c_size,
  output reg  [TL_SRCW -1:0] c_source,
  output reg  [TL_AW   -1:0] c_address,
  output reg  [TL_DW   -1:0] c_data,
  output reg                 c_corrupt,
  output reg                 c_valid,
  input  wire                c_ready,

  // Channel D Signals (Mandatory)
  output reg  [         2:0] d_opcode,
  output reg  [         2:0] d_param,
  output reg  [TL_SZW  -1:0] d_size,
  output reg  [TL_SRCW -1:0] d_source,
  output reg  [TL_SINKW-1:0] d_sink,
  output reg                 d_denied
  output reg  [TL_DW   -1:0] d_data,
  output reg                 d_corrupt,
  output reg                 d_valid,
  input  wire                d_ready,

  // Channel E Signals (TL-C only)
  output reg  [TL_SINKW-1:0] e_sink,
  output reg                 e_valid,
  input  wire                e_ready
);
endmodule  // peripheral_bfm_master_tl
