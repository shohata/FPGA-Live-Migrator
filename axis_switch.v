`timescale 1 ns / 1 ps

module axis_switch #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256,
  parameter ADDR_WIDTH = 6,
  parameter S_INTF_NUM = 7        // Number of Slave Interface
)
(
  input         aclk,
  input         aresetn,

  input  wire [S_INTF_NUM*AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [S_INTF_NUM*AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [S_INTF_NUM*AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire [S_INTF_NUM - 1:0]                   s_axis_tvalid,
  output wire [S_INTF_NUM - 1:0]                   s_axis_tready,
  input  wire [S_INTF_NUM - 1:0]                   s_axis_tlast,

  output reg  [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output reg                            m_axis_tvalid,
  input  wire                           m_axis_tready,
  output reg                            m_axis_tlast
);

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2 = 0; value > 0; clog2 = clog2 + 1)
        value = value >> 1;
    end
  endfunction

  //localparam PTR_WIDTH = clog2(S_INTF_NUM);
  localparam PTR_WIDTH = S_INTF_NUM;
  localparam [0:0] IDLE = 0, SEND = 1;

  reg state = IDLE;
  reg [PTR_WIDTH - 1:0] ptr = {PTR_WIDTH{1'b0}};

  wire [AXIS_DATA_WIDTH - 1:0]   m_axis_fifo_tdata [S_INTF_NUM - 1:0];
  wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_fifo_tkeep [S_INTF_NUM - 1:0];
  wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_fifo_tuser [S_INTF_NUM - 1:0];
  wire                           m_axis_fifo_tvalid[S_INTF_NUM - 1:0];
  reg                            m_axis_fifo_tready[S_INTF_NUM - 1:0];
  wire                           m_axis_fifo_tlast [S_INTF_NUM - 1:0];

  genvar i;
  generate
  for (i = 0; i < S_INTF_NUM; i = i + 1) begin: GenIntf

    axis_lut_fifo #(
      .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
      .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
      .ADDR_WIDTH       (ADDR_WIDTH)
    )
    axis_lut_fifo_inst (
      .aclk   (aclk),
      .resetn (aresetn),

      .write_tdata  (s_axis_tdata [i*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
      .write_tkeep  (s_axis_tkeep [i*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
      .write_tuser  (s_axis_tuser [i*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
      .write_tvalid (s_axis_tvalid[i]),
      .write_tlast  (s_axis_tlast [i]),
      .write_tready (s_axis_tready[i]),

      .read_tdata   (m_axis_fifo_tdata [i]),
      .read_tkeep   (m_axis_fifo_tkeep [i]),
      .read_tuser   (m_axis_fifo_tuser [i]),
      .read_tvalid  (m_axis_fifo_tvalid[i]),
      .read_tlast   (m_axis_fifo_tlast [i]),
      .read_tready  (m_axis_fifo_tready[i])
    );

  end
  endgenerate

  // Master Interface Connection
  always @(*) begin
    m_axis_tdata  = m_axis_fifo_tdata [ptr];
    m_axis_tkeep  = m_axis_fifo_tkeep [ptr];
    m_axis_tuser  = m_axis_fifo_tuser [ptr];
    m_axis_tvalid = m_axis_fifo_tvalid[ptr];
    m_axis_tlast  = m_axis_fifo_tlast [ptr];
  end

  integer j;
  always @(*) begin
    for (j = 0; j < S_INTF_NUM; j = j + 1)
      m_axis_fifo_tready[j] = 0;
    m_axis_fifo_tready[ptr] = m_axis_tready;
  end

  // State Machine ----------------
  always @(posedge aclk) begin
    if (!aresetn)
      state <= IDLE;
    else begin
      case (state)
        IDLE: begin
          if (m_axis_tready && m_axis_tvalid && !m_axis_tlast) state <= SEND;
        end
        SEND: begin
          if (m_axis_tready && m_axis_tvalid && m_axis_tlast) state <= IDLE;
        end
      endcase
    end
  end

  // Pointer ----------------
  always @(posedge aclk) begin
    if (!aresetn)
      ptr <= {PTR_WIDTH{1'b0}};
    else begin
      if (state == IDLE && !m_axis_tvalid) begin
        if (ptr == S_INTF_NUM - 1)
          ptr <= 0;
        else
          ptr <= ptr + 1;
      end
    end
  end

endmodule
