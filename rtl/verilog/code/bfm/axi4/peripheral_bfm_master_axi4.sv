module peripheral_bfm_master_axi4 (

  // Global Signals
  input wire aclk,
  input wire aresetn, // Active LOW

  // Write Address Channel
  output reg  [ 3:0] awid,     // Address Write ID
  output reg  [31:0] awadr,    // Write Address
  output reg  [ 3:0] awlen,    // Burst Length
  output reg  [ 2:0] awsize,   // Burst Size
  output reg  [ 1:0] awburst,  // Burst Type
  output reg  [ 1:0] awlock,   // Lock Type
  output reg  [ 3:0] awcache,  // Cache Type
  output reg  [ 2:0] awprot,   // Protection Type
  output reg         awvalid,  // Write Address Valid   
  input  wire        awready,  // Write Address Ready

  // Write Data Channel
  output reg  [ 3:0] wid,     // Write ID
  output reg  [31:0] wrdata,  // Write Data
  output reg  [ 3:0] wstrb,   // Write Strobes
  output reg         wlast,   // Write Last
  output reg         wvalid,  // Write Valid   
  input  wire        wready,  // Write Ready

  // Write Response CHannel
  output reg  [3:0] bid,     // Response ID
  output reg  [1:0] bresp,   // Write Response
  output reg        bvalid,  // Write Response Valid   
  input  wire       bready,  // Response Ready

  // Read Address Channel
  output reg  [ 3:0] arid,     // Read Address ID
  output reg  [31:0] araddr,   // Read Address
  output reg  [ 3:0] arlen,    // Burst Length
  output reg  [ 2:0] arsize,   // Burst Size
  output reg  [ 1:0] arlock,   // Lock Type
  output reg  [ 3:0] arcache,  // Cache Type
  output reg  [ 2:0] arprot,   // Protection Type
  output reg         arvalid,  // Read Address Valid   
  input  wire        arready,  // Read Address Ready

  // Read Data Channel
  input  wire [ 3:0] rid,      // Read ID
  input  wire [31:0] rdata,    // Read Data
  input  wire [ 1:0] rresp,    // Read Response
  input  wire        rlast,    // Read Last
  input  wire        rvalid,   // Read Valid
  output reg         rready    // Read Ready
);
endmodule  // peripheral_bfm_master_axi4
