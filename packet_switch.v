module packet_switch #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256
)
(
  input  wire                           axis_aclk,
  input  wire                           axis_resetn,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,
  input  wire                           s_axis_tlast,

  output reg  [AXIS_DATA_WIDTH - 1:0]   m_axis_buf_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] m_axis_buf_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  m_axis_buf_tuser,
  output reg                            m_axis_buf_tvalid,
  input  wire                           m_axis_buf_tready,
  output reg                            m_axis_buf_tlast,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_buf_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_buf_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_buf_tuser,
  input  wire                           s_axis_buf_tvalid,
  output reg                            s_axis_buf_tready,
  input  wire                           s_axis_buf_tlast,

  output reg  [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output reg                            m_axis_tvalid,
  input  wire                           m_axis_tready,
  output reg                            m_axis_tlast,

  input  wire                           buffering,
  input  wire                           releasing,
  output wire                           empty
);

  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_ff_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_ff_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_ff_tuser;
  wire                           s_axis_ff_tvalid;
  reg                            s_axis_ff_tready;
  wire                           s_axis_ff_tlast;


  assign empty = ~s_axis_buf_tvalid & ~m_axis_buf_tvalid;

  axis_ff #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH)
  )
  axis_ff_inst (
    .axis_aclk     (axis_aclk),
    .axis_resetn   (axis_resetn),

    .s_axis_tdata  (s_axis_tdata ),
    .s_axis_tkeep  (s_axis_tkeep ),
    .s_axis_tuser  (s_axis_tuser ),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tlast  (s_axis_tlast ),

    .m_axis_tdata  (s_axis_ff_tdata ),
    .m_axis_tkeep  (s_axis_ff_tkeep ),
    .m_axis_tuser  (s_axis_ff_tuser ),
    .m_axis_tvalid (s_axis_ff_tvalid),
    .m_axis_tready (s_axis_ff_tready),
    .m_axis_tlast  (s_axis_ff_tlast )
  );

  always @(*) begin
    if (buffering) begin
      m_axis_buf_tdata  = s_axis_ff_tdata;
      m_axis_buf_tkeep  = s_axis_ff_tkeep;
      m_axis_buf_tuser  = s_axis_ff_tuser;
      m_axis_buf_tvalid = s_axis_ff_tvalid;
      m_axis_buf_tlast  = s_axis_ff_tlast;
    end else begin
      m_axis_buf_tdata  = {AXIS_DATA_WIDTH{1'b0}};
      m_axis_buf_tkeep  = {AXIS_DATA_WIDTH/8{1'b0}};
      m_axis_buf_tuser  = {AXIS_TUSER_WIDTH{1'b0}};
      m_axis_buf_tvalid = 1'b0;
      m_axis_buf_tlast  = 1'b0;
    end
  end

  always @(*) begin
    if (releasing) begin
      m_axis_tdata  = s_axis_buf_tdata;
      m_axis_tkeep  = s_axis_buf_tkeep;
      m_axis_tuser  = s_axis_buf_tuser;
      m_axis_tvalid = s_axis_buf_tvalid;
      m_axis_tlast  = s_axis_buf_tlast;
    end else begin
      if (buffering) begin
        m_axis_tdata  = {AXIS_DATA_WIDTH{1'b0}};
        m_axis_tkeep  = {AXIS_DATA_WIDTH/8{1'b0}};
        m_axis_tuser  = {AXIS_TUSER_WIDTH{1'b0}};
        m_axis_tvalid = 1'b0;
        m_axis_tlast  = 1'b0;
      end else begin
        m_axis_tdata  = s_axis_ff_tdata;
        m_axis_tkeep  = s_axis_ff_tkeep;
        m_axis_tuser  = s_axis_ff_tuser;
        m_axis_tvalid = s_axis_ff_tvalid;
        m_axis_tlast  = s_axis_ff_tlast;
      end
    end
  end

  always @(*) begin
    if (buffering)
      s_axis_ff_tready = m_axis_buf_tready;
    else begin
      if (releasing)
        s_axis_ff_tready = 1'b0;
      else
        s_axis_ff_tready = m_axis_tready;
    end
  end

  always @(*) begin
    if (releasing)
      s_axis_buf_tready = m_axis_tready;
    else
      s_axis_buf_tready = 1'b0;
  end

endmodule
