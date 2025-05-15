module peripheral_bfm_slave_axi4 (

  // Global Signals
  input wire aclk,
  input wire aresetn, // Active LOW

  // Write Address Channel
  input  wire [ 3:0] awid,     // Address Write ID
  input  wire [31:0] awadr,    // Write Address
  input  wire [ 3:0] awlen,    // Burst Length
  input  wire [ 2:0] awsize,   // Burst Size
  input  wire [ 1:0] awburst,  // Burst Type
  input  wire [ 1:0] awlock,   // Lock Type
  input  wire [ 3:0] awcache,  // Cache Type
  input  wire [ 2:0] awprot,   // Protection Type
  input  wire        awvalid,  // Write Address Valid
  output reg         awready,  // Write Address Ready

  // Write Data Channel
  input  wire [ 3:0] wid,     // Write ID
  input  wire [31:0] wrdata,  // Write Data
  input  wire [ 3:0] wstrb,   // Write Strobes
  input  wire        wlast,   // Write Last
  input  wire        wvalid,  // Write Valid
  output reg         wready,  // Write Ready

  // Write Response CHannel
  output reg  [3:0] bid,     // Response ID
  output reg  [1:0] bresp,   // Write Response
  output reg        bvalid,  // Write Response Valid
  input  wire       bready,  // Response Ready

  // Read Address Channel
  input  wire [ 3:0] arid,     // Read Address ID
  input  wire [31:0] araddr,   // Read Address
  input  wire [ 3:0] arlen,    // Burst Length
  input  wire [ 2:0] arsize,   // Burst Size
  input  wire [ 1:0] arlock,   // Lock Type
  input  wire [ 3:0] arcache,  // Cache Type
  input  wire [ 2:0] arprot,   // Protection Type
  input  wire        arvalid,  // Read Address Valid
  output reg         arready,  // Read Address Ready

  // Read Data Channel
  output reg  [ 3:0] rid,      // Read ID
  output reg  [31:0] rdata,    // Read Data
  output reg  [ 1:0] rresp,    // Read Response
  output reg         rlast,    // Read Last
  output reg         rvalid,   // Read Valid
  input  wire        rready    // Read Ready
);
endmodule  // peripheral_bfm_slave_axi4
