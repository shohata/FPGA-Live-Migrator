`timescale 1 ns / 1 ps

/*
 * Path through
 */
module reconfigurable_partition #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256
)
(
  input  wire                           axis_aclk,
  input  wire                           axis_resetn,

  // 5-tuple
  input  wire [15:0]                    DEST_PORT_NUM,

  // Scan-Chain Control Flags
  input  wire                           sc_save,
  input  wire                           sc_load,

  // Slave Scan-Chain Ports
  input  wire [31:0]                    s_axis_sc_tdata,
  input  wire [7:0]                     s_axis_sc_tkeep,
  input  wire                           s_axis_sc_tvalid,
  output wire                           s_axis_sc_tready,
  input  wire                           s_axis_sc_tlast,

  // Master Scan-Chain Ports
  output reg  [31:0]                    m_axis_sc_tdata,
  output wire [7:0]                     m_axis_sc_tkeep,
  output wire                           m_axis_sc_tvalid,
  input  wire                           m_axis_sc_tready,
  output wire                           m_axis_sc_tlast,

  // Slave Stream Ports
  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,
  input  wire                           s_axis_tlast,

  // Master Stream Ports
  output wire [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output wire                           m_axis_tvalid,
  input  wire                           m_axis_tready,
  output wire                           m_axis_tlast
);

  localparam ADDR_WIDTH = 2;


  // AXI-Stream In
  wire [AXIS_DATA_WIDTH - 1:0]   in_axis_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] in_axis_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]  in_axis_tuser;
  wire                           in_axis_tvalid;
  wire                           in_axis_tlast;
  wire                           in_axis_tready;

  // AXI-Stream Out
  reg  [AXIS_DATA_WIDTH - 1:0]   out_axis_tdata;
  reg  [AXIS_DATA_WIDTH/8 - 1:0] out_axis_tkeep;
  reg  [AXIS_TUSER_WIDTH - 1:0]  out_axis_tuser;
  reg                            out_axis_tvalid;
  reg                            out_axis_tlast;


  // In to Out --------
  always @(*) begin
    out_axis_tdata  = in_axis_tdata;
    out_axis_tkeep  = in_axis_tkeep;
    out_axis_tuser  = in_axis_tuser;
    out_axis_tvalid = in_axis_tvalid;
    out_axis_tlast  = in_axis_tlast;
  end


  // Slave to In --------
  axis_lut_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (ADDR_WIDTH)
  )
  axis_lut_fifo_pre (
    .aclk   (axis_aclk),
    .resetn (axis_resetn),

    // AXI Stream Slave
    .write_tdata  (s_axis_tdata ),
    .write_tkeep  (s_axis_tkeep ),
    .write_tuser  (s_axis_tuser ),
    .write_tvalid (s_axis_tvalid),
    .write_tlast  (s_axis_tlast ),
    .write_tready (s_axis_tready),

    // AXI Stream Master
    .read_tdata   (in_axis_tdata ),
    .read_tkeep   (in_axis_tkeep ),
    .read_tuser   (in_axis_tuser ),
    .read_tvalid  (in_axis_tvalid),
    .read_tlast   (in_axis_tlast ),
    .read_tready  (in_axis_tready)
  );

  // Out to maser --------
  axis_lut_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (ADDR_WIDTH)
  )
  axis_lut_fifo_post (
    .aclk   (axis_aclk),
    .resetn (axis_resetn),

    // AXI Stream Slave
    .write_tdata  (out_axis_tdata ),
    .write_tkeep  (out_axis_tkeep ),
    .write_tuser  (out_axis_tuser ),
    .write_tvalid (out_axis_tvalid),
    .write_tlast  (out_axis_tlast ),
    .write_tready (in_axis_tready ),

    // AXI Stream Master
    .read_tdata   (m_axis_tdata ),
    .read_tkeep   (m_axis_tkeep ),
    .read_tuser   (m_axis_tuser ),
    .read_tvalid  (m_axis_tvalid),
    .read_tlast   (m_axis_tlast ),
    .read_tready  (m_axis_tready)
  );

endmodule
