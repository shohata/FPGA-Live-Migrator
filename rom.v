`timescale 1 ns / 1 ps

module rom #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256,
  parameter ADDR_WIDTH = 12
)
(
  input  wire                           clk,

  input  wire [ADDR_WIDTH-1:0]          addr,

  // Master Stream Ports
  output reg  [AXIS_DATA_WIDTH - 1:0]   axis_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] axis_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  axis_tuser,
  output reg                            axis_tvalid,
  output reg                            axis_tlast
);

  localparam MEM_WIDTH = 1 << ADDR_WIDTH;

  reg [AXIS_DATA_WIDTH - 1:0]   tdata  [0:MEM_WIDTH-1];
  reg [AXIS_DATA_WIDTH/8 - 1:0] tkeep  [0:MEM_WIDTH-1];
  reg [AXIS_TUSER_WIDTH - 1:0]  tuser  [0:MEM_WIDTH-1];
  reg                           tvalid [0:MEM_WIDTH-1];
  reg                           tlast  [0:MEM_WIDTH-1];

  integer i;
  initial begin
    //for (i = 0; i < MEM_WIDTH; i = i + 1) tvalid[i] <= 1'b0;
    $readmemh("tdata.mem",  tdata);
    $readmemb("tkeep.mem",  tkeep);
    $readmemh("tuser.mem",  tuser);
    $readmemb("tvalid.mem", tvalid);
    $readmemb("tlast.mem",  tlast);
  end

  always @(posedge clk) begin
    axis_tdata  <= tdata [addr];
    axis_tkeep  <= tkeep [addr];
    axis_tuser  <= tuser [addr];
    axis_tvalid <= tvalid[addr];
    axis_tlast  <= tlast [addr];
  end

endmodule
