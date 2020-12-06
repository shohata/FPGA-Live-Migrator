`timescale 1 ns / 1 ps

/*
 * ARP Reply
 */
module arp_reply #(
  parameter AXIS_DATA_WIDTH   = 512,
  parameter AXIS_TUSER_WIDTH  = 256,
  parameter [47:0] MAC_ADDR_0 = 48'hDA_02_03_04_05_00,
  parameter [47:0] MAC_ADDR_1 = 48'hDA_02_03_04_05_01,
  parameter [47:0] MAC_ADDR_2 = 48'hDA_02_03_04_05_02,
  parameter [47:0] MAC_ADDR_3 = 48'hDA_02_03_04_05_03,
  parameter [31:0] IP_ADDR_0  = 32'hC0_A8_01_0a,
  parameter [31:0] IP_ADDR_1  = 32'hC0_A8_01_0b,
  parameter [31:0] IP_ADDR_2  = 32'hC0_A8_01_0c,
  parameter [31:0] IP_ADDR_3  = 32'hC0_A8_01_0d
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
  output wire                           m_axis_tlast
);

  localparam [15:0] TYPE_ARP = 16'h0806;
  localparam [47:0] BROADCAST_MAC_ADDR = 48'hFF_FF_FF_FF_FF_FF;
  localparam [15:0] OPER_RQST = 16'h1;

  localparam [0:0] HEADER = 0, PAYLOAD = 1;

  reg  state = HEADER;
  wire we;
  wire valid;

  // AXI-Stream In
  wire [AXIS_DATA_WIDTH - 1:0]   i_axis_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] i_axis_tkeep;
  wire [AXIS_TUSER_WIDTH-1:0]    i_axis_tuser;
  wire                           i_axis_tvalid;
  wire                           i_axis_tready;
  wire                           i_axis_tlast;

  // AXI-Stream Out
  reg  [AXIS_DATA_WIDTH - 1:0]   o_axis_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] o_axis_tkeep;
  wire [AXIS_TUSER_WIDTH-1:0]    o_axis_tuser;
  wire                           o_axis_tvalid;
  wire                           o_axis_tready;
  wire                           o_axis_tlast;

  // MAC Header
  wire [47:0] dest_mac_addr;  // Destination MAC Address
  wire [47:0] src_mac_addr;   // Source MAC Address
  wire [15:0] type;           // Type

  // ARP Header
  wire [15:0] htype;          // Hardware Type
  wire [15:0] ptype;          // Protocol Type
  wire  [7:0] hlen;           // Hardware Length
  wire  [7:0] plen;           // Protocol Length
  wire [15:0] oper;           // Operation
  wire [47:0] sha;            // Sender Hardware Address
  wire [31:0] spa;            // Sender Protocol Address
  wire [47:0] tha;            // Target Hardware Address
  wire [31:0] tpa;            // Target Protocol Address


  // AXI-Stream FIFO
  axis_lut_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (2)
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
    .read_tdata   (i_axis_tdata ),
    .read_tkeep   (i_axis_tkeep ),
    .read_tuser   (i_axis_tuser ),
    .read_tvalid  (i_axis_tvalid),
    .read_tlast   (i_axis_tlast ),
    .read_tready  (i_axis_tready)
  );

  axis_lut_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH (2)
  )
  axis_lut_fifo_post (
    .aclk   (axis_aclk),
    .resetn (axis_resetn),

    // AXI Stream Slave
    .write_tdata  (o_axis_tdata ),
    .write_tkeep  (o_axis_tkeep ),
    .write_tuser  (o_axis_tuser ),
    .write_tvalid (o_axis_tvalid),
    .write_tlast  (o_axis_tlast ),
    .write_tready (o_axis_tready),

    // AXI Stream Master
    .read_tdata   (m_axis_tdata ),
    .read_tkeep   (m_axis_tkeep ),
    .read_tuser   (m_axis_tuser ),
    .read_tvalid  (m_axis_tvalid),
    .read_tlast   (m_axis_tlast ),
    .read_tready  (m_axis_tready)
  );


  // Assign --------
  assign valid = (type == TYPE_ARP && oper == OPER_RQST
                && (dest_mac_addr == BROADCAST_MAC_ADDR
                  || dest_mac_addr == MAC_ADDR_0
                  || dest_mac_addr == MAC_ADDR_1
                  || dest_mac_addr == MAC_ADDR_2
                  || dest_mac_addr == MAC_ADDR_3)
                && (tpa == IP_ADDR_0
                  || tpa == IP_ADDR_1
                  || tpa == IP_ADDR_2
                  || tpa == IP_ADDR_3));
  assign we = ((state == HEADER && valid) || state == PAYLOAD);

  assign o_axis_tkeep  = i_axis_tkeep;
  assign o_axis_tvalid = i_axis_tvalid & we;
  assign o_axis_tlast  = i_axis_tlast;
  assign i_axis_tready = o_axis_tready;

  // [ 15: 0] [143:128] Length of the packet in bytes
  // [ 23:16] [151:144] Source Port
  // [ 31:24] [159:152] Destination Port
  // [127:32] [255:160] User definable meta data slot 0-5
  assign o_axis_tuser =
    {i_axis_tuser[255:160], i_axis_tuser[151:144], i_axis_tuser[151:144], i_axis_tuser[143:128],
     i_axis_tuser[127: 32], i_axis_tuser[ 23: 16], i_axis_tuser[ 23: 16], i_axis_tuser[ 15:  0]};


  // State Machine --------
  always @(posedge axis_aclk) begin
    if (!axis_resetn)
      state <= HEADER;
    else begin
      if (i_axis_tready && i_axis_tvalid) begin
        if (i_axis_tlast)
          state <= HEADER;
        else
          if (we) state <= PAYLOAD;
      end
    end
  end


  // Header Parser --------
  assign dest_mac_addr =
    {
      i_axis_tdata [  7:  0],
      i_axis_tdata [ 15:  8],
      i_axis_tdata [ 23: 16],
      i_axis_tdata [ 31: 24],
      i_axis_tdata [ 39: 32],
      i_axis_tdata [ 47: 40]
    };
  assign src_mac_addr =
    {
      i_axis_tdata [ 55: 48],
      i_axis_tdata [ 63: 56],
      i_axis_tdata [ 71: 64],
      i_axis_tdata [ 79: 72],
      i_axis_tdata [ 87: 80],
      i_axis_tdata [ 95: 88]
    };
  assign type =
    {
      i_axis_tdata [103: 96],
      i_axis_tdata [111:104]
    };
  assign htype =
    {
      i_axis_tdata [119:112],
      i_axis_tdata [127:120]
    };
  assign ptype =
    {
      i_axis_tdata [135:128],
      i_axis_tdata [143:136]
    };
  assign hlen = i_axis_tdata [151:144];
  assign plen = i_axis_tdata [159:152];
  assign oper =
    {
      i_axis_tdata [167:160],
      i_axis_tdata [175:168]
    };
  assign sha =
    {
      i_axis_tdata [183:176],
      i_axis_tdata [191:184],
      i_axis_tdata [199:192],
      i_axis_tdata [207:200],
      i_axis_tdata [215:208],
      i_axis_tdata [223:216]
    };
  assign spa =
    {
      i_axis_tdata [231:224],
      i_axis_tdata [239:232],
      i_axis_tdata [247:240],
      i_axis_tdata [255:248]
    };
  assign tha =
    {
      i_axis_tdata [263:256],
      i_axis_tdata [271:264],
      i_axis_tdata [279:272],
      i_axis_tdata [287:280],
      i_axis_tdata [295:288],
      i_axis_tdata [303:296]
    };
  assign tpa =
    {
      i_axis_tdata [311:304],
      i_axis_tdata [319:312],
      i_axis_tdata [327:320],
      i_axis_tdata [335:328]
    };


  // Packet Generator --------
  always @(*) begin
    case (state)
      HEADER: begin
        {
          o_axis_tdata [  7:  0],
          o_axis_tdata [ 15:  8],
          o_axis_tdata [ 23: 16],
          o_axis_tdata [ 31: 24],
          o_axis_tdata [ 39: 32],
          o_axis_tdata [ 47: 40]
        }                         = src_mac_addr;         // Destination MAC Address
        case (tpa)                                        // Source MAC Address
          IP_ADDR_0:
            {
              o_axis_tdata [ 55: 48],
              o_axis_tdata [ 63: 56],
              o_axis_tdata [ 71: 64],
              o_axis_tdata [ 79: 72],
              o_axis_tdata [ 87: 80],
              o_axis_tdata [ 95: 88]
            }                         = MAC_ADDR_0;
          IP_ADDR_1:
            {
              o_axis_tdata [ 55: 48],
              o_axis_tdata [ 63: 56],
              o_axis_tdata [ 71: 64],
              o_axis_tdata [ 79: 72],
              o_axis_tdata [ 87: 80],
              o_axis_tdata [ 95: 88]
            }                         = MAC_ADDR_1;
          IP_ADDR_2:
            {
              o_axis_tdata [ 55: 48],
              o_axis_tdata [ 63: 56],
              o_axis_tdata [ 71: 64],
              o_axis_tdata [ 79: 72],
              o_axis_tdata [ 87: 80],
              o_axis_tdata [ 95: 88]
            }                         = MAC_ADDR_2;
          IP_ADDR_3:
            {
              o_axis_tdata [ 55: 48],
              o_axis_tdata [ 63: 56],
              o_axis_tdata [ 71: 64],
              o_axis_tdata [ 79: 72],
              o_axis_tdata [ 87: 80],
              o_axis_tdata [ 95: 88]
            }                         = MAC_ADDR_3;
          default: o_axis_tdata [ 95: 48] = 48'h0;
        endcase
        {
          o_axis_tdata [103: 96],
          o_axis_tdata [111:104]
        }                         = type;                 // Type
        {
          o_axis_tdata [119:112],
          o_axis_tdata [127:120]
        }                         = htype;                // Hardware Type
        {
          o_axis_tdata [135:128],
          o_axis_tdata [143:136]
        }                         = ptype;                // Protocol Type
        o_axis_tdata [151:144]    = hlen;                 // Hardware Length
        o_axis_tdata [159:152]    = plen;                 // Protocol Length
        {
          o_axis_tdata [167:160],
          o_axis_tdata [175:168]
        }                         = 16'h2;                // Operation (1:Request, 2:Reply)
        case (tpa)                                        // Sender Hardware Address
          IP_ADDR_0:
            {
              o_axis_tdata [183:176],
              o_axis_tdata [191:184],
              o_axis_tdata [199:192],
              o_axis_tdata [207:200],
              o_axis_tdata [215:208],
              o_axis_tdata [223:216]
            }                         = MAC_ADDR_0;
          IP_ADDR_1:
            {
              o_axis_tdata [183:176],
              o_axis_tdata [191:184],
              o_axis_tdata [199:192],
              o_axis_tdata [207:200],
              o_axis_tdata [215:208],
              o_axis_tdata [223:216]
            }                         = MAC_ADDR_1;
          IP_ADDR_2:
            {
              o_axis_tdata [183:176],
              o_axis_tdata [191:184],
              o_axis_tdata [199:192],
              o_axis_tdata [207:200],
              o_axis_tdata [215:208],
              o_axis_tdata [223:216]
            }                         = MAC_ADDR_2;
          IP_ADDR_3:
            {
              o_axis_tdata [183:176],
              o_axis_tdata [191:184],
              o_axis_tdata [199:192],
              o_axis_tdata [207:200],
              o_axis_tdata [215:208],
              o_axis_tdata [223:216]
            }                         = MAC_ADDR_3;
          default: o_axis_tdata [223:176] = 48'h0;
        endcase
        {
          o_axis_tdata [231:224],
          o_axis_tdata [239:232],
          o_axis_tdata [247:240],
          o_axis_tdata [255:248]
        }                         = tpa;                  // Sender Protocol Address
        {
          o_axis_tdata [263:256],
          o_axis_tdata [271:264],
          o_axis_tdata [279:272],
          o_axis_tdata [287:280],
          o_axis_tdata [295:288],
          o_axis_tdata [303:296]
        }                         = sha;                  // Target Hardware Address
        {
          o_axis_tdata [311:304],
          o_axis_tdata [319:312],
          o_axis_tdata [327:320],
          o_axis_tdata [335:328]
        }                         = spa;                  // Target Protocol Address
        o_axis_tdata [511: 336] = i_axis_tdata [511:336];
        end
      PAYLOAD: o_axis_tdata = i_axis_tdata;
    endcase
  end

endmodule
