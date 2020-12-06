module header_parser #(
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
  output wire [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output wire                           m_axis_tvalid,
  input  wire                           m_axis_tready,
  output wire                           m_axis_tlast,

  output wire [31:0]                    src_ip_addr,    // Source IP Address
  output wire [31:0]                    dest_ip_addr,   // Destination IP Address
  output wire  [7:0]                    protocol,       // Protocol
  output wire [15:0]                    src_port_num,   // Source Port Number
  output wire [15:0]                    dest_port_num,  // Destination Port Number
  output wire                           fin_flag,
  output wire                           five_tuple_valid
);

  localparam [15:0] TYPE_IP = 16'h0800;
  localparam [ 7:0] PROTOCOL_UDP = 8'd17, PROTOCOL_TCP = 8'd6;
  localparam [0:0] IDLE = 0, SEND = 1;

  wire        we;
  reg         state;
  wire [15:0] type;


  axis_ff #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH)
  )
  axis_ff_inst (
    .axis_aclk     (axis_aclk  ),
    .axis_resetn   (axis_resetn),

    .s_axis_tdata  (s_axis_tdata ),
    .s_axis_tkeep  (s_axis_tkeep ),
    .s_axis_tuser  (s_axis_tuser ),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready ),
    .s_axis_tlast  (s_axis_tlast),

    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .m_axis_tuser  (m_axis_tuser ),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .m_axis_tlast  (m_axis_tlast )
  );


  assign type          = {s_axis_tdata[103:96], s_axis_tdata[111:104]};
  assign protocol      = s_axis_tdata[191:184];
  assign src_ip_addr   = s_axis_tdata[239:208];
  assign dest_ip_addr  = s_axis_tdata[271:240];
  assign src_port_num  = s_axis_tdata[287:272];
  assign dest_port_num = s_axis_tdata[303:288];
  assign fin_flag      = s_axis_tdata[383];

  assign we = s_axis_tvalid & s_axis_tready;
  assign five_tuple_valid = (we && state == IDLE && type == TYPE_IP && protocol == PROTOCOL_TCP);


  always @(posedge axis_aclk) begin
    if (axis_resetn) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (we && !s_axis_tlast) state <= SEND;
        end
        SEND: begin
          if (we && s_axis_tlast) state <= IDLE;
        end
      endcase
    end
  end

endmodule
