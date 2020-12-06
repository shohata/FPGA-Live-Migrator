module selector # (
  parameter AXIS_DATA_WIDTH = 32,
  parameter SEL_WIDTH = 2,
  parameter INTF_NUM = 4        // Number of Interface
)
(
  input  wire [SEL_WIDTH - 1:0]         sel,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,
  input  wire                           s_axis_tlast,

  output wire [M_INTF_NUM*AXIS_DATA_WIDTH - 1:0]   s_axis_sel_tdata,
  output wire [M_INTF_NUM*AXIS_DATA_WIDTH/8 - 1:0] s_axis_sel_tkeep,
  output wire [M_INTF_NUM - 1:0]                   s_axis_sel_tvalid,
  input  wire [M_INTF_NUM - 1:0]                   s_axis_sel_tready,
  output wire [M_INTF_NUM - 1:0]                   s_axis_sel_tlast,

  input  wire [M_INTF_NUM*AXIS_DATA_WIDTH - 1:0]   m_axis_sel_tdata,
  input  wire [M_INTF_NUM*AXIS_DATA_WIDTH/8 - 1:0] m_axis_sel_tkeep,
  input  wire [M_INTF_NUM - 1:0]                   m_axis_sel_tvalid,
  output wire [M_INTF_NUM - 1:0]                   m_axis_sel_tready,
  input  wire [M_INTF_NUM - 1:0]                   m_axis_sel_tlast,

  output wire [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output wire                           m_axis_tvalid,
  input  wire                           m_axis_tready,
  output wire                           m_axis_tlast
);

  always @(*) begin
    s_axis_sel_tdata  = {INTF_NUM*AXIS_DATA_WIDTH{1'b0}};
    s_axis_sel_tkeep  = {INTF_NUM*AXIS_DATA_WIDTH/8{1'b0}};
    s_axis_sel_tvalid = {INTF_NUM{1'b0}};
    s_axis_sel_tlast  = {INTF_NUM{1'b0}};

    s_axis_sel_tdata[AXIS_DATA_WIDTH*sel +: AXIS_DATA_WIDTH] = s_axis_tdata;
    s_axis_sel_tkeep[AXIS_DATA_WIDTH/8*sel +: AXIS_DATA_WIDTH/8] = s_axis_tkeep;
    s_axis_sel_tvalid[sel] = s_axis_tvalid;
    s_axis_sel_tlast[sel]  = s_axis_tlast;

    s_axis_tready = s_axis_sel_tready[sel];
  end

  always @(*) begin
    m_axis_tdata  = m_axis_sel_tdata[AXIS_DATA_WIDTH*sel +: AXIS_DATA_WIDTH];
    m_axis_tkeep  = m_axis_sel_tkeep[AXIS_DATA_WIDTH/8*sel +: AXIS_DATA_WIDTH/8];
    m_axis_tvalid = m_axis_sel_tvalid[sel];
    m_axis_tlast  = m_axis_sel_tlast[sel];

    m_axis_sel_tready = {INTF_NUM{1'b0}};
    m_axis_sel_tready[sel] = m_axis_tready;
  end

endmodule
