`timescale 1 ns / 1 ps

module axis_broadcaster #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256,
  parameter ADDR_WIDTH = 6,
  parameter M_INTF_NUM = 7        // Number of Master Interface
)
(
  input         aclk,
  input         aresetn,

  input  wire [M_INTF_NUM-1:0]          dpr_intf,
  input  wire                           dpr_intf_valid,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,
  input  wire                           s_axis_tlast,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_dpr_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_dpr_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_dpr_tuser,
  input  wire                           s_axis_dpr_tvalid,
  output wire                           s_axis_dpr_tready,
  input  wire                           s_axis_dpr_tlast,

  output wire [M_INTF_NUM*AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output wire [M_INTF_NUM*AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output wire [M_INTF_NUM*AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output wire [M_INTF_NUM - 1:0]                   m_axis_tvalid,
  input  wire [M_INTF_NUM - 1:0]                   m_axis_tready,
  output wire [M_INTF_NUM - 1:0]                   m_axis_tlast
);

  wire [M_INTF_NUM - 1:0] s_axis_fifo_tready;


  assign s_axis_tready = &s_axis_fifo_tready;
  assign s_axis_dpr_tready = s_axis_fifo_tready[dpr_intf];

  genvar i;
  generate
  for (i = 0; i < M_INTF_NUM; i = i + 1) begin: GenIntf

    axis_lut_fifo #(
      .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
      .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
      .ADDR_WIDTH       (ADDR_WIDTH)
    )
    axis_lut_fifo_inst (
      .aclk   (aclk),
      .resetn (aresetn),

      .write_tdata  ((dpr_intf_valid && dpr_intf == i)? s_axis_dpr_tdata  : s_axis_tdata ),
      .write_tkeep  ((dpr_intf_valid && dpr_intf == i)? s_axis_dpr_tkeep  : s_axis_tkeep ),
      .write_tuser  ((dpr_intf_valid && dpr_intf == i)? s_axis_dpr_tuser  : s_axis_tuser ),
      .write_tvalid ((dpr_intf_valid && dpr_intf == i)? s_axis_dpr_tvalid : s_axis_tvalid),
      .write_tlast  ((dpr_intf_valid && dpr_intf == i)? s_axis_dpr_tlast  : s_axis_tlast ),
      .write_tready (s_axis_fifo_tready[i]),

      .read_tdata   (m_axis_tdata [i*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
      .read_tkeep   (m_axis_tkeep [i*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
      .read_tuser   (m_axis_tuser [i*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
      .read_tvalid  (m_axis_tvalid[i]),
      .read_tlast   (m_axis_tlast [i]),
      .read_tready  (m_axis_tready[i])
    );

  end
  endgenerate

endmodule
