`timescale 1 ns / 1 ps

/*
 * MAC Frame Filter
 */
module mac_filter #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256,
  parameter MAC_ADDR_NUM = 4,
  parameter [15:0] TYPE = 16'h0800
)
(
  input  wire                           axis_aclk,
  input  wire                           axis_resetn,

  input  wire [MAC_ADDR_NUM*48 - 1:0]   target_mac_addr,

  // Slave Stream Ports
  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,
  output reg                            s_axis_tready,
  input  wire                           s_axis_tlast,

  // Master Stream Ports
  output reg  [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output reg                            m_axis_tvalid,
  input  wire                           m_axis_tready,
  output reg                            m_axis_tlast
);

  localparam [1:0] IDLE=0, SEND=1, NOT_SEND=2;

  reg [1:0] state = IDLE;
  reg [MAC_ADDR_NUM - 1:0] is_target_mac_addr;
  wire flag;

  // MAC Header
  wire  [47:0] dest_mac_addr;  // Destination MAC Address
  wire  [47:0] src_mac_addr;   // Source MAC Address
  wire  [15:0] type;           // Type

  // Header Parser ----------------
  assign dest_mac_addr =
    {
      s_axis_tdata [  7:  0],
      s_axis_tdata [ 15:  8],
      s_axis_tdata [ 23: 16],
      s_axis_tdata [ 31: 24],
      s_axis_tdata [ 39: 32],
      s_axis_tdata [ 47: 40]
    };
  assign src_mac_addr =
    {
      s_axis_tdata [ 55: 48],
      s_axis_tdata [ 63: 56],
      s_axis_tdata [ 71: 64],
      s_axis_tdata [ 79: 72],
      s_axis_tdata [ 87: 80],
      s_axis_tdata [ 95: 88]
    };
  assign type =
    {
      s_axis_tdata [103: 96],
      s_axis_tdata [111:104]
    };


  // Judgement ----------------
  genvar i;
  generate
  for (i = 0; i < MAC_ADDR_NUM; i = i + 1) begin: DestMacAddr
    always @(*) begin
      if (dest_mac_addr == target_mac_addr[i*48+:48])
        is_target_mac_addr[i] = 1'b1;
      else
        is_target_mac_addr[i] = 1'b0;
    end
  end
  endgenerate

  assign flag = (type == TYPE && is_target_mac_addr)? 1'b1 : 1'b0;


  // State Machine ----------------
  always @(posedge axis_aclk) begin
    if (!axis_resetn)
      state <= IDLE;
    else begin
      case (state)
        IDLE: begin
          if (s_axis_tvalid && s_axis_tready) begin
            if (!s_axis_tlast) begin
              if (flag)
                state <= SEND;
              else
                state <= NOT_SEND;
            end
          end
        end
        SEND: begin
          if (s_axis_tvalid && s_axis_tready && s_axis_tlast)
            state <= IDLE;
        end
        NOT_SEND: begin
          if (s_axis_tvalid && s_axis_tready && s_axis_tlast)
            state <= IDLE;
        end
      endcase
    end
  end


  // Switch ----------------
  always @(*) begin
    if ((state == IDLE && flag) || state == SEND) begin
      m_axis_tdata  = s_axis_tdata;
      m_axis_tkeep  = s_axis_tkeep;
      m_axis_tuser  = s_axis_tuser;
      m_axis_tvalid = s_axis_tvalid;
      m_axis_tlast  = s_axis_tlast;
      s_axis_tready = m_axis_tready;
    end else begin
      m_axis_tdata  = {AXIS_DATA_WIDTH{1'b0}};
      m_axis_tkeep  = {AXIS_DATA_WIDTH/8{1'b0}};
      m_axis_tuser  = {AXIS_TUSER_WIDTH{1'b0}};
      m_axis_tvalid = 1'b0;
      m_axis_tlast  = 1'b0;
      s_axis_tready = 1'b1;
    end
  end

endmodule
