module axis_ff #(
  parameter AXIS_DATA_WIDTH   = 512,
  parameter AXIS_TUSER_WIDTH  = 256
)
(
  input  wire                           axis_aclk,
  input  wire                           axis_resetn,

  // Slave Stream Ports
  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,
  input  wire                           s_axis_tlast,

  // Master Stream Ports
  output reg  [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output reg                            m_axis_tvalid,
  input  wire                           m_axis_tready,
  output reg                            m_axis_tlast
);

  assign s_axis_tready = !m_axis_tvalid || m_axis_tready;
  always @(posedge axis_aclk) begin
    if (s_axis_tready) begin
      m_axis_tdata  <= s_axis_tdata;
      m_axis_tkeep  <= s_axis_tkeep;
      m_axis_tuser  <= s_axis_tuser;
      m_axis_tvalid <= s_axis_tvalid;
      m_axis_tlast  <= s_axis_tlast;
    end
  end

endmodule
