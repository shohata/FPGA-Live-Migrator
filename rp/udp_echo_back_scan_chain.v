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

  // Shift Register for Scan-Chain
  reg  [31:0] shift [256:0];
  reg   [8:0] count = 0;


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
          o_axis_tdata [i+:8] <= shift[i_axis_tdata[i+:8] + 1];
        end
      end
      PAYLOAD: begin
        for (i = 0; i < 512; i = i + 8) begin
          o_axis_tdata [i+:8] <= shift[i_axis_tdata[i+:8] + 1];
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


  assign s_axis_sc_tready = 1'b1;
  assign s_axis_sc_tkeep = 8'b11111111;
  assign s_axis_sc_tlast = (count == 256);

  // Scan-Chain
  always @(posedge axis_aclk) begin
    if ((sc_load && s_axis_sc_valid) || (sc_save && m_axis_sc_tready)) begin
      if (count == 256) begin
        count <= 0;
      end else begin
        count <= count + 1;
      end
      m_axis_sc_tvalid <= 1'b1;
      m_axis_sc_tdata <= shift[0];
      shift[0] <= shift[1];
      shift[1] <= shift[2];
      shift[2] <= shift[3];
      shift[3] <= shift[4];
      shift[4] <= shift[5];
      shift[5] <= shift[6];
      shift[6] <= shift[7];
      shift[7] <= shift[8];
      shift[8] <= shift[9];
      shift[9] <= shift[10];
      shift[10] <= shift[11];
      shift[11] <= shift[12];
      shift[12] <= shift[13];
      shift[13] <= shift[14];
      shift[14] <= shift[15];
      shift[15] <= shift[16];
      shift[16] <= shift[17];
      shift[17] <= shift[18];
      shift[18] <= shift[19];
      shift[19] <= shift[20];
      shift[20] <= shift[21];
      shift[21] <= shift[22];
      shift[22] <= shift[23];
      shift[23] <= shift[24];
      shift[24] <= shift[25];
      shift[25] <= shift[26];
      shift[26] <= shift[27];
      shift[27] <= shift[28];
      shift[28] <= shift[29];
      shift[29] <= shift[30];
      shift[30] <= shift[31];
      shift[31] <= shift[32];
      shift[32] <= shift[33];
      shift[33] <= shift[34];
      shift[34] <= shift[35];
      shift[35] <= shift[36];
      shift[36] <= shift[37];
      shift[37] <= shift[38];
      shift[38] <= shift[39];
      shift[39] <= shift[40];
      shift[40] <= shift[41];
      shift[41] <= shift[42];
      shift[42] <= shift[43];
      shift[43] <= shift[44];
      shift[44] <= shift[45];
      shift[45] <= shift[46];
      shift[46] <= shift[47];
      shift[47] <= shift[48];
      shift[48] <= shift[49];
      shift[49] <= shift[50];
      shift[50] <= shift[51];
      shift[51] <= shift[52];
      shift[52] <= shift[53];
      shift[53] <= shift[54];
      shift[54] <= shift[55];
      shift[55] <= shift[56];
      shift[56] <= shift[57];
      shift[57] <= shift[58];
      shift[58] <= shift[59];
      shift[59] <= shift[60];
      shift[60] <= shift[61];
      shift[61] <= shift[62];
      shift[62] <= shift[63];
      shift[63] <= shift[64];
      shift[64] <= shift[65];
      shift[65] <= shift[66];
      shift[66] <= shift[67];
      shift[67] <= shift[68];
      shift[68] <= shift[69];
      shift[69] <= shift[70];
      shift[70] <= shift[71];
      shift[71] <= shift[72];
      shift[72] <= shift[73];
      shift[73] <= shift[74];
      shift[74] <= shift[75];
      shift[75] <= shift[76];
      shift[76] <= shift[77];
      shift[77] <= shift[78];
      shift[78] <= shift[79];
      shift[79] <= shift[80];
      shift[80] <= shift[81];
      shift[81] <= shift[82];
      shift[82] <= shift[83];
      shift[83] <= shift[84];
      shift[84] <= shift[85];
      shift[85] <= shift[86];
      shift[86] <= shift[87];
      shift[87] <= shift[88];
      shift[88] <= shift[89];
      shift[89] <= shift[90];
      shift[90] <= shift[91];
      shift[91] <= shift[92];
      shift[92] <= shift[93];
      shift[93] <= shift[94];
      shift[94] <= shift[95];
      shift[95] <= shift[96];
      shift[96] <= shift[97];
      shift[97] <= shift[98];
      shift[98] <= shift[99];
      shift[99] <= shift[100];
      shift[100] <= shift[101];
      shift[101] <= shift[102];
      shift[102] <= shift[103];
      shift[103] <= shift[104];
      shift[104] <= shift[105];
      shift[105] <= shift[106];
      shift[106] <= shift[107];
      shift[107] <= shift[108];
      shift[108] <= shift[109];
      shift[109] <= shift[110];
      shift[110] <= shift[111];
      shift[111] <= shift[112];
      shift[112] <= shift[113];
      shift[113] <= shift[114];
      shift[114] <= shift[115];
      shift[115] <= shift[116];
      shift[116] <= shift[117];
      shift[117] <= shift[118];
      shift[118] <= shift[119];
      shift[119] <= shift[120];
      shift[120] <= shift[121];
      shift[121] <= shift[122];
      shift[122] <= shift[123];
      shift[123] <= shift[124];
      shift[124] <= shift[125];
      shift[125] <= shift[126];
      shift[126] <= shift[127];
      shift[127] <= shift[128];
      shift[128] <= shift[129];
      shift[129] <= shift[130];
      shift[130] <= shift[131];
      shift[131] <= shift[132];
      shift[132] <= shift[133];
      shift[133] <= shift[134];
      shift[134] <= shift[135];
      shift[135] <= shift[136];
      shift[136] <= shift[137];
      shift[137] <= shift[138];
      shift[138] <= shift[139];
      shift[139] <= shift[140];
      shift[140] <= shift[141];
      shift[141] <= shift[142];
      shift[142] <= shift[143];
      shift[143] <= shift[144];
      shift[144] <= shift[145];
      shift[145] <= shift[146];
      shift[146] <= shift[147];
      shift[147] <= shift[148];
      shift[148] <= shift[149];
      shift[149] <= shift[150];
      shift[150] <= shift[151];
      shift[151] <= shift[152];
      shift[152] <= shift[153];
      shift[153] <= shift[154];
      shift[154] <= shift[155];
      shift[155] <= shift[156];
      shift[156] <= shift[157];
      shift[157] <= shift[158];
      shift[158] <= shift[159];
      shift[159] <= shift[160];
      shift[160] <= shift[161];
      shift[161] <= shift[162];
      shift[162] <= shift[163];
      shift[163] <= shift[164];
      shift[164] <= shift[165];
      shift[165] <= shift[166];
      shift[166] <= shift[167];
      shift[167] <= shift[168];
      shift[168] <= shift[169];
      shift[169] <= shift[170];
      shift[170] <= shift[171];
      shift[171] <= shift[172];
      shift[172] <= shift[173];
      shift[173] <= shift[174];
      shift[174] <= shift[175];
      shift[175] <= shift[176];
      shift[176] <= shift[177];
      shift[177] <= shift[178];
      shift[178] <= shift[179];
      shift[179] <= shift[180];
      shift[180] <= shift[181];
      shift[181] <= shift[182];
      shift[182] <= shift[183];
      shift[183] <= shift[184];
      shift[184] <= shift[185];
      shift[185] <= shift[186];
      shift[186] <= shift[187];
      shift[187] <= shift[188];
      shift[188] <= shift[189];
      shift[189] <= shift[190];
      shift[190] <= shift[191];
      shift[191] <= shift[192];
      shift[192] <= shift[193];
      shift[193] <= shift[194];
      shift[194] <= shift[195];
      shift[195] <= shift[196];
      shift[196] <= shift[197];
      shift[197] <= shift[198];
      shift[198] <= shift[199];
      shift[199] <= shift[200];
      shift[200] <= shift[201];
      shift[201] <= shift[202];
      shift[202] <= shift[203];
      shift[203] <= shift[204];
      shift[204] <= shift[205];
      shift[205] <= shift[206];
      shift[206] <= shift[207];
      shift[207] <= shift[208];
      shift[208] <= shift[209];
      shift[209] <= shift[210];
      shift[210] <= shift[211];
      shift[211] <= shift[212];
      shift[212] <= shift[213];
      shift[213] <= shift[214];
      shift[214] <= shift[215];
      shift[215] <= shift[216];
      shift[216] <= shift[217];
      shift[217] <= shift[218];
      shift[218] <= shift[219];
      shift[219] <= shift[220];
      shift[220] <= shift[221];
      shift[221] <= shift[222];
      shift[222] <= shift[223];
      shift[223] <= shift[224];
      shift[224] <= shift[225];
      shift[225] <= shift[226];
      shift[226] <= shift[227];
      shift[227] <= shift[228];
      shift[228] <= shift[229];
      shift[229] <= shift[230];
      shift[230] <= shift[231];
      shift[231] <= shift[232];
      shift[232] <= shift[233];
      shift[233] <= shift[234];
      shift[234] <= shift[235];
      shift[235] <= shift[236];
      shift[236] <= shift[237];
      shift[237] <= shift[238];
      shift[238] <= shift[239];
      shift[239] <= shift[240];
      shift[240] <= shift[241];
      shift[241] <= shift[242];
      shift[242] <= shift[243];
      shift[243] <= shift[244];
      shift[244] <= shift[245];
      shift[245] <= shift[246];
      shift[246] <= shift[247];
      shift[247] <= shift[248];
      shift[248] <= shift[249];
      shift[249] <= shift[250];
      shift[250] <= shift[251];
      shift[251] <= shift[252];
      shift[252] <= shift[253];
      shift[253] <= shift[254];
      shift[254] <= shift[255];
      shift[255] <= shift[256];
      shift[256] <= s_axis_sc_tdata;
    end else begin
      if (m_axis_sc_tready) begin
        m_axis_sc_tvalid <= 1'b0;
      end
    end
  end

endmodule
