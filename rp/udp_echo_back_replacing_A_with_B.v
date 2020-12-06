`timescale 1 ns / 1 ps

/*
 * UDP echo back
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

  localparam [15:0] TYPE_IP = 16'h0800;
  localparam [ 7:0] PROTOCOL_UDP = 8'd17;

  localparam [0:0] HEADER = 0, PAYLOAD = 1;


  integer i;

  reg  state;
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
  wire  [47:0] dest_mac_addr;  // Destination MAC Address
  wire  [47:0] src_mac_addr;   // Source MAC Address
  wire  [15:0] type;           // Type

  // IP Header
  wire  [3:0] version;        // Version
  wire  [3:0] ihl;            // Internet Header Length
  wire  [7:0] tos;            // Type Of Service
  wire [15:0] total_len;      // Total Length
  wire [15:0] id;             // Identification
  wire  [2:0] flag;           // Various Control Flags
  wire [12:0] offset;         // Fragment Offset
  wire  [7:0] ttl;            // Time To Live
  wire  [7:0] protocol;       // Protocol
  wire [15:0] ip_checksum;    // Header Checksum
  wire [31:0] src_ip_addr;    // Source IP Address
  wire [31:0] dest_ip_addr;   // Destination IP Address

  // UDP Header
  wire [15:0] src_port_num;   // Source Port Number
  wire [15:0] dest_port_num;  // Destination Port Number
  wire [15:0] data_len;       // Data Length
  wire [15:0] udp_checksum;   // Header Checksum


  // AXI-Stream FIFO
  axis_lut_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (6)
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
    .ADDR_WIDTH (6)
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
  assign valid = (type == TYPE_IP && protocol == PROTOCOL_UDP && dest_port_num == DEST_PORT_NUM);
  assign we = ((state == HEADER && valid) || state == PAYLOAD);

  assign o_axis_tkeep  = i_axis_tkeep;
  assign o_axis_tuser  = {i_axis_tuser[127:32], i_axis_tuser[23:16], i_axis_tuser[23:16], i_axis_tuser[15:0]};
  assign o_axis_tvalid = i_axis_tvalid & we;
  assign o_axis_tlast  = i_axis_tlast;
  assign i_axis_tready = o_axis_tready;


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
        }                         <= src_mac_addr;  // Dest MAC Addr
        {
          o_axis_tdata [ 55: 48],
          o_axis_tdata [ 63: 56],
          o_axis_tdata [ 71: 64],
          o_axis_tdata [ 79: 72],
          o_axis_tdata [ 87: 80],
          o_axis_tdata [ 95: 88]
        }                         <= dest_mac_addr; // Srs MAC Addr
        {
          o_axis_tdata [103: 96],
          o_axis_tdata [111:104]
        }                         <= type;
        o_axis_tdata [115:112]    <= version;
        o_axis_tdata [119:116]    <= ihl;
        o_axis_tdata [127:120]    <= tos;
        {
          o_axis_tdata [135:128],
          o_axis_tdata [143:136]
        }                         <= total_len;
        {
          o_axis_tdata [151:144],
          o_axis_tdata [159:152]
        }                         <= id;
        o_axis_tdata [162:160]    <= flag;
        {
          o_axis_tdata [167:163],
          o_axis_tdata [175:168]
        }                         <= offset;
        o_axis_tdata [183:176]    <= ttl;
        o_axis_tdata [191:184]    <= protocol;
        {
          o_axis_tdata [199:192],
          o_axis_tdata [207:200]
        }                         <= ip_checksum;
        {
          o_axis_tdata [215:208],
          o_axis_tdata [223:216],
          o_axis_tdata [231:224],
          o_axis_tdata [239:232]
        }                         <= dest_ip_addr;  // Src IP Addr
        {
          o_axis_tdata [247:240],
          o_axis_tdata [255:248],
          o_axis_tdata [263:256],
          o_axis_tdata [271:264]
        }                         <= src_ip_addr;   // Dest IP Addr
        {
          o_axis_tdata [279:272],
          o_axis_tdata [287:280]
        }                         <= src_port_num;
        {
          o_axis_tdata [295:288],
          o_axis_tdata [303:296]
        }                         <= dest_port_num;
        {
          o_axis_tdata [311:304],
          o_axis_tdata [319:312]
        }                         <= data_len;
        {
          o_axis_tdata [327:320],
          o_axis_tdata [335:328]
        }                         <= 16'b0;         // UDP Checksum
        for (i = 336; i < 512; i = i + 8) begin
          // 'A' == 0x41, 'B' == 0x42
          case (i_axis_tdata[i+:8])
            8'h41: o_axis_tdata [i+:8] <= 8'h42;
            8'h42: o_axis_tdata [i+:8] <= 8'h41;
            default: o_axis_tdata [i+:8] <= i_axis_tdata[i+:8];
          endcase
        end
      end
      PAYLOAD: begin
        for (i = 0; i < 512; i = i + 8) begin
          // 'A' == 0x41, 'B' == 0x42
          case (i_axis_tdata[i+:8])
            8'h41: o_axis_tdata [i+:8] <= 8'h42;
            8'h42: o_axis_tdata [i+:8] <= 8'h41;
            default: o_axis_tdata [i+:8] <= i_axis_tdata[i+:8];
          endcase
        end
      end
    endcase
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
  assign src_mac_addr  =
    {
      i_axis_tdata [ 55: 48],
      i_axis_tdata [ 63: 56],
      i_axis_tdata [ 71: 64],
      i_axis_tdata [ 79: 72],
      i_axis_tdata [ 87: 80],
      i_axis_tdata [ 95: 88]
    };
  assign type          =
    {
      i_axis_tdata [103: 96],
      i_axis_tdata [111:104]
    };
  assign version       = i_axis_tdata [115:112];
  assign ihl           = i_axis_tdata [119:116];
  assign tos           = i_axis_tdata [127:120];
  assign total_len     =
    {
      i_axis_tdata [135:128],
      i_axis_tdata [143:136]
    };
  assign id            =
    {
      i_axis_tdata [151:144],
      i_axis_tdata [159:152]
    };
  assign flag          = i_axis_tdata [162:160];
  assign offset        =
    {
      i_axis_tdata [167:163],
      i_axis_tdata [175:168]
    };
  assign ttl           = i_axis_tdata [183:176];
  assign protocol      = i_axis_tdata [191:184];
  assign ip_checksum   =
    {
      i_axis_tdata [199:192],
      i_axis_tdata [207:200]
    };
  assign src_ip_addr   =
    {
      i_axis_tdata [215:208],
      i_axis_tdata [223:216],
      i_axis_tdata [231:224],
      i_axis_tdata [239:232]
    };
  assign dest_ip_addr  =
    {
      i_axis_tdata [247:240],
      i_axis_tdata [255:248],
      i_axis_tdata [263:256],
      i_axis_tdata [271:264]
    };
  assign src_port_num  =
    {
      i_axis_tdata [279:272],
      i_axis_tdata [287:280]
    };
  assign dest_port_num =
    {
      i_axis_tdata [295:288],
      i_axis_tdata [303:296]
    };
  assign data_len      =
    {
      i_axis_tdata [311:304],
      i_axis_tdata [319:312]
    };
  assign udp_checksum  =
    {
      i_axis_tdata [327:320],
      i_axis_tdata [335:328]
    };

endmodule
