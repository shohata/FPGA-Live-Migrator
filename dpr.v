`timescale 1 ns / 1 ps

module dpr #(
  parameter AXIS_DATA_WIDTH  = 512,
  parameter AXIS_TUSER_WIDTH = 256
  parameter SC_WIDTH        = 32;
)
(
  input  wire                           axis_aclk,
  input  wire                           axis_resetn,

  output wire [AXIS_DATA_WIDTH - 1:0]   M_AXIS_S2MM_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] M_AXIS_S2MM_tkeep,
  output wire                           M_AXIS_S2MM_tlast,
  input  wire                           M_AXIS_S2MM_tready,
  output wire                           M_AXIS_S2MM_tvalid,

  input  wire [AXIS_DATA_WIDTH - 1:0]   S_AXIS_MM2S_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] S_AXIS_MM2S_tkeep,
  input  wire                           S_AXIS_MM2S_tlast,
  output wire                           S_AXIS_MM2S_tready,
  input  wire                           S_AXIS_MM2S_tvalid,

  output wire [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep,
  output wire                           m_axis_tlast,
  input  wire                           m_axis_tready,
  output wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser,
  output wire                           m_axis_tvalid,

  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep,
  input  wire                           s_axis_tlast,
  output wire                           s_axis_tready,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser,
  input  wire                           s_axis_tvalid,

  input  wire [SC_WIDTH - 1:0]          s_axis_sc_tdata,
  input  wire [SC_WIDTH/8 - 1:0]        s_axis_sc_tkeep,
  input  wire                           s_axis_sc_tvalid,
  output wire                           s_axis_sc_tready,
  input  wire                           s_axis_sc_tlast,

  output wire [SC_WIDTH - 1:0]          m_axis_sc_tdata,
  output wire [SC_WIDTH/8 - 1:0]        m_axis_sc_tkeep,
  output wire                           m_axis_sc_tvalid,
  input  wire                           m_axis_sc_tready,
  output wire                           m_axis_sc_tlast,

  input  wire                           sc_load,
  input  wire                           sc_save,
  input  wire [3:0]                     sc_port,

  input  wire                           migration_progress,
  output wire                           migration_ready,
  input  wire [1:0]                     buffering_type,
  input  wire [7:0]                     buffering_port,
  input  wire [3:0]                     decouple
);

  localparam        RP_NUMBER       = 4;
  localparam        BROADCAST_WIDTH = RP_NUMBER + 2;
  localparam [47:0] FPGA_MAC_ADDR_0 = 48'h_DA_02_03_04_05_00;
  localparam [47:0] FPGA_MAC_ADDR_1 = 48'h_DA_02_03_04_05_01;
  localparam [47:0] FPGA_MAC_ADDR_2 = 48'h_DA_02_03_04_05_02;
  localparam [47:0] FPGA_MAC_ADDR_3 = 48'h_DA_02_03_04_05_03;
  localparam [31:0] FPGA_IP_ADDR_0  = 32'h_C0_A8_01_0a;
  localparam [31:0] FPGA_IP_ADDR_1  = 32'h_C0_A8_01_0b;
  localparam [31:0] FPGA_IP_ADDR_2  = 32'h_C0_A8_01_0c;
  localparam [31:0] FPGA_IP_ADDR_3  = 32'h_C0_A8_01_0d;
  localparam [15:0] RP_0_PORT_NUM   = 16'd4000;
  localparam [15:0] RP_1_PORT_NUM   = 16'd4001;
  localparam [15:0] RP_2_PORT_NUM   = 16'd4002;
  localparam [15:0] RP_3_PORT_NUM   = 16'd4003;
  localparam [15:0] TYPE_IP         = 16'h0800;


  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH - 1:0]    m_axis_bc_tdata;
  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH/8  - 1:0] m_axis_bc_tkeep;
  wire [BROADCAST_WIDTH*AXIS_TUSER_WIDTH - 1:0]   m_axis_bc_tuser;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_bc_tvalid;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_bc_tready;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_bc_tlast;

  wire [AXIS_DATA_WIDTH - 1:0]                    s_axis_prd_tdata  [RP_NUMBER - 1:0];
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  s_axis_prd_tkeep  [RP_NUMBER - 1:0];
  wire [AXIS_TUSER_WIDTH - 1:0]                   s_axis_prd_tuser  [RP_NUMBER - 1:0];
  wire                                            s_axis_prd_tvalid [RP_NUMBER - 1:0];
  wire                                            s_axis_prd_tready [RP_NUMBER - 1:0];
  wire                                            s_axis_prd_tlast  [RP_NUMBER - 1:0];

  wire [AXIS_DATA_WIDTH - 1:0]                    s_axis_rp_tdata  [RP_NUMBER - 1:0];
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  s_axis_rp_tkeep  [RP_NUMBER - 1:0];
  wire [AXIS_TUSER_WIDTH - 1:0]                   s_axis_rp_tuser  [RP_NUMBER - 1:0];
  wire                                            s_axis_rp_tvalid [RP_NUMBER - 1:0];
  wire                                            s_axis_rp_tready [RP_NUMBER - 1:0];
  wire                                            s_axis_rp_tlast  [RP_NUMBER - 1:0];

  wire [AXIS_DATA_WIDTH - 1:0]                    m_axis_rp_tdata  [RP_NUMBER - 1:0];
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  m_axis_rp_tkeep  [RP_NUMBER - 1:0];
  wire [AXIS_TUSER_WIDTH - 1:0]                   m_axis_rp_tuser  [RP_NUMBER - 1:0];
  wire                                            m_axis_rp_tvalid [RP_NUMBER - 1:0];
  wire                                            m_axis_rp_tready [RP_NUMBER - 1:0];
  wire                                            m_axis_rp_tlast  [RP_NUMBER - 1:0];

  wire [AXIS_DATA_WIDTH - 1:0]                    m_axis_prd_tdata  [RP_NUMBER - 1:0];
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  m_axis_prd_tkeep  [RP_NUMBER - 1:0];
  wire [AXIS_TUSER_WIDTH - 1:0]                   m_axis_prd_tuser  [RP_NUMBER - 1:0];
  wire                                            m_axis_prd_tvalid [RP_NUMBER - 1:0];
  wire                                            m_axis_prd_tready [RP_NUMBER - 1:0];
  wire                                            m_axis_prd_tlast  [RP_NUMBER - 1:0];

  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH - 1:0]    s_axis_sw_tdata;
  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH/8  - 1:0] s_axis_sw_tkeep;
  wire [BROADCAST_WIDTH*AXIS_TUSER_WIDTH - 1:0]   s_axis_sw_tuser;
  wire [BROADCAST_WIDTH - 1:0]                    s_axis_sw_tvalid;
  wire [BROADCAST_WIDTH - 1:0]                    s_axis_sw_tready;
  wire [BROADCAST_WIDTH - 1:0]                    s_axis_sw_tlast;

  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH - 1:0]    m_axis_sw_tdata;
  wire [BROADCAST_WIDTH*AXIS_DATA_WIDTH/8  - 1:0] m_axis_sw_tkeep;
  wire [BROADCAST_WIDTH*AXIS_TUSER_WIDTH - 1:0]   m_axis_sw_tuser;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_sw_tvalid;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_sw_tready;
  wire [BROADCAST_WIDTH - 1:0]                    m_axis_sw_tlast;

  wire [AXIS_DATA_WIDTH - 1:0]                    s_axis_mb_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  s_axis_mb_tkeep;
  wire                                            s_axis_mb_tvalid;
  wire                                            s_axis_mb_tready;
  wire                                            s_axis_mb_tlast;

  wire [AXIS_DATA_WIDTH - 1:0]                    s_axis_dpr_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  s_axis_dpr_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]                   s_axis_dpr_tuser;
  wire                                            s_axis_dpr_tvalid;
  wire                                            s_axis_dpr_tready;
  wire                                            s_axis_dpr_tlast;

  wire [AXIS_DATA_WIDTH - 1:0]                    s_axis_buf_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  s_axis_buf_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]                   s_axis_buf_tuser;
  wire                                            s_axis_buf_tvalid;
  wire                                            s_axis_buf_tready;
  wire                                            s_axis_buf_tlast;

  wire [AXIS_DATA_WIDTH - 1:0]                    m_axis_buf_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0]                  m_axis_buf_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]                   m_axis_buf_tuser;
  wire                                            m_axis_buf_tvalid;
  wire                                            m_axis_buf_tready;
  wire                                            m_axis_buf_tlast;

  // Scan-Chain --------------------------------
  wire [PR_NUMBER*SC_WIDTH - 1:0]                 s_axis_sc_rp_tdata;
  wire [PR_NUMBER*SC_WIDTH/8  - 1:0]              s_axis_sc_rp_tkeep;
  wire [PR_NUMBER - 1:0]                          s_axis_sc_rp_tvalid;
  wire [PR_NUMBER - 1:0]                          s_axis_sc_rp_tready;
  wire [PR_NUMBER - 1:0]                          s_axis_sc_rp_tlast;

  wire [PR_NUMBER*SC_WIDTH - 1:0]                 m_axis_sc_rp_tdata;
  wire [PR_NUMBER*SC_WIDTH/8  - 1:0]              m_axis_sc_rp_tkeep;
  wire [PR_NUMBER - 1:0]                          m_axis_sc_rp_tvalid;
  wire [PR_NUMBER - 1:0]                          m_axis_sc_rp_tready;
  wire [PR_NUMBER - 1:0]                          m_axis_sc_rp_tlast;



  // AXI-Stream Broadcaster
  axis_broadcaster #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (4),
    .M_INTF_NUM       (BROADCAST_WIDTH)
  )
  axis_broadcaster_inst (
    .aclk              (axis_aclk),
    .aresetn           (axis_resetn),
    .s_axis_tdata      (s_axis_tdata),
    .s_axis_tkeep      (s_axis_tkeep),
    .s_axis_tuser      (s_axis_tuser),
    .s_axis_tvalid     (s_axis_tvalid),
    .s_axis_tready     (s_axis_tready_bc),
    .s_axis_tlast      (s_axis_tlast),
    .s_axis_dpr_tdata  (s_axis_dpr_tdata),
    .s_axis_dpr_tkeep  (s_axis_dpr_tkeep),
    .s_axis_dpr_tuser  (s_axis_dpr_tuser),
    .s_axis_dpr_tvalid (s_axis_dpr_tvalid),
    .s_axis_dpr_tready (s_axis_dpr_tready),
    .s_axis_dpr_tlast  (s_axis_dpr_tlast),
    .m_axis_tdata      (m_axis_bc_tdata),
    .m_axis_tkeep      (m_axis_bc_tkeep),
    .m_axis_tuser      (m_axis_bc_tuser),
    .m_axis_tvalid     (m_axis_bc_tvalid),
    .m_axis_tready     (m_axis_bc_tready),
    .m_axis_tlast      (m_axis_bc_tlast)
  );


  // FIFO for Reconfigurable Partition
  genvar i;
  generate
  for (i = 0; i < RP_NUMBER; i = i + 1) begin: GenerateRP

    // AXI-Stream Data FIFO
    axis_lut_fifo # (
      .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
      .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
      .ADDR_WIDTH       (4)
    )
    axis_lut_fifo_pre (
      .aclk         (axis_aclk),
      .resetn       (axis_resetn),
      .write_tdata  (m_axis_bc_tdata [i*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
      .write_tkeep  (m_axis_bc_tkeep [i*AXIS_DATA_WIDTH/8  +: AXIS_DATA_WIDTH/8]),
      .write_tuser  (m_axis_bc_tuser [i*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
      .write_tvalid (m_axis_bc_tvalid[i]),
      .write_tready (m_axis_bc_tready[i]),
      .write_tlast  (m_axis_bc_tlast [i]),
      .read_tdata   (s_axis_prd_tdata [i]),
      .read_tkeep   (s_axis_prd_tkeep [i]),
      .read_tuser   (s_axis_prd_tuser [i]),
      .read_tvalid  (s_axis_prd_tvalid[i]),
      .read_tready  (s_axis_prd_tready[i]),
      .read_tlast   (s_axis_prd_tlast [i])
    );

    // Partial Reconfiguration Decoupler
    pr_decoupler_ip
    pr_decoupler (
      .s_intf_0_TDATA   (s_axis_prd_tdata [i]),
      .s_intf_0_TKEEP   (s_axis_prd_tkeep [i]),
      .s_intf_0_TUSER   (s_axis_prd_tuser [i]),
      .s_intf_0_TVALID  (s_axis_prd_tvalid[i]),
      .s_intf_0_TREADY  (s_axis_prd_tready[i]),
      .s_intf_0_TLAST   (s_axis_prd_tlast [i]),
      .rp_intf_0_TDATA  (s_axis_rp_tdata [i]),
      .rp_intf_0_TKEEP  (s_axis_rp_tkeep [i]),
      .rp_intf_0_TUSER  (s_axis_rp_tuser [i]),
      .rp_intf_0_TVALID (s_axis_rp_tvalid[i]),
      .rp_intf_0_TREADY (s_axis_rp_tready[i]),
      .rp_intf_0_TLAST  (s_axis_rp_tlast [i]),
      .rp_intf_1_TDATA  (m_axis_rp_tdata [i]),
      .rp_intf_1_TKEEP  (m_axis_rp_tkeep [i]),
      .rp_intf_1_TUSER  (m_axis_rp_tuser [i]),
      .rp_intf_1_TVALID (m_axis_rp_tvalid[i]),
      .rp_intf_1_TREADY (m_axis_rp_tready[i]),
      .rp_intf_1_TLAST  (m_axis_rp_tlast [i]),
      .s_intf_1_TDATA   (m_axis_prd_tdata [i]),
      .s_intf_1_TKEEP   (m_axis_prd_tkeep [i]),
      .s_intf_1_TUSER   (m_axis_prd_tuser [i]),
      .s_intf_1_TVALID  (m_axis_prd_tvalid[i]),
      .s_intf_1_TREADY  (m_axis_prd_tready[i]),
      .s_intf_1_TLAST   (m_axis_prd_tlast [i]),
      .decouple         (decouple [i])
    );

    axis_lut_fifo # (
      .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
      .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
      .ADDR_WIDTH       (4)
    )
    axis_lut_fifo_post (
      .aclk         (axis_aclk),
      .resetn       (axis_resetn),
      .write_tdata  (m_axis_prd_tdata [i]),
      .write_tkeep  (m_axis_prd_tkeep [i]),
      .write_tuser  (m_axis_prd_tuser [i]),
      .write_tvalid (m_axis_prd_tvalid[i]),
      .write_tready (m_axis_prd_tready[i]),
      .write_tlast  (m_axis_prd_tlast [i]),
      .read_tdata   (s_axis_sw_tdata [i*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
      .read_tkeep   (s_axis_sw_tkeep [i*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
      .read_tuser   (s_axis_sw_tuser [i*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
      .read_tvalid  (s_axis_sw_tvalid[i]),
      .read_tready  (s_axis_sw_tready[i]),
      .read_tlast   (s_axis_sw_tlast [i])
    );

  end
  endgenerate


  selector # (
    .AXIS_DATA_WIDTH (SC_WIDTH),
    .SEL_WIDTH       (4),
    .INTF_NUM        (RP_NUMBER)
  )
  (
    .sel               (sc_port),
    .s_axis_tdata      (s_axis_sc_tdata ),
    .s_axis_tkeep      (s_axis_sc_tkeep ),
    .s_axis_tvalid     (s_axis_sc_tvalid),
    .s_axis_tready     (s_axis_sc_tready),
    .s_axis_tlast      (s_axis_sc_tlast ),
    .s_axis_sel_tdata  (s_axis_sc_rp_tdata ),
    .s_axis_sel_tkeep  (s_axis_sc_rp_tkeep ),
    .s_axis_sel_tvalid (s_axis_sc_rp_tvalid),
    .s_axis_sel_tready (s_axis_sc_rp_tready),
    .s_axis_sel_tlast  (s_axis_sc_rp_tlast ),
    .m_axis_sel_tdata  (m_axis_sc_rp_tdata ),
    .m_axis_sel_tkeep  (m_axis_sc_rp_tkeep ),
    .m_axis_sel_tvalid (m_axis_sc_rp_tvalid),
    .m_axis_sel_tready (m_axis_sc_rp_tready),
    .m_axis_sel_tlast  (m_axis_sc_rp_tlast ),
    .m_axis_tdata      (m_axis_sc_tdata ),
    .m_axis_tkeep      (m_axis_sc_tkeep ),
    .m_axis_tvalid     (m_axis_sc_tvalid),
    .m_axis_tready     (m_axis_sc_tready),
    .m_axis_tlast      (m_axis_sc_tlast ),
  );


  // Reconfigurable Partition
  reconfigurable_partition
  reconfigurable_partition_0 (
    .axis_aclk        (axis_aclk),
    .axis_resetn      (axis_resetn),
    .DEST_PORT_NUM    (RP_0_PORT_NUM),
    .sc_save          ((sc_port == 0)? sc_save : 1'b0),
    .sc_load          ((sc_port == 0)? sc_load : 1'b0),
    .s_axis_sc_tdata  (s_axis_sc_rp_tdata [0*SC_WIDTH +: SC_WIDTH]),
    .s_axis_sc_tkeep  (s_axis_sc_rp_tkeep [0*SC_WIDTH/8 +: SC_WIDTH/8]),
    .s_axis_sc_tvalid (s_axis_sc_rp_tvalid[0]),
    .s_axis_sc_tready (s_axis_sc_rp_tready[0]),
    .s_axis_sc_tlast  (s_axis_sc_rp_tlast [0]),
    .m_axis_sc_tdata  (m_axis_sc_rp_tdata [0*SC_WIDTH +: SC_WIDTH]),
    .m_axis_sc_tkeep  (m_axis_sc_rp_tkeep [0*SC_WIDTH/8 +: SC_WIDTH/8]),
    .m_axis_sc_tvalid (m_axis_sc_rp_tvalid[0]),
    .m_axis_sc_tready (m_axis_sc_rp_tready[0]),
    .m_axis_sc_tlast  (m_axis_sc_rp_tlast [0]),
    .s_axis_tdata     (s_axis_rp_tdata [0]),
    .s_axis_tkeep     (s_axis_rp_tkeep [0]),
    .s_axis_tuser     (s_axis_rp_tuser [0]),
    .s_axis_tvalid    (s_axis_rp_tvalid[0]),
    .s_axis_tready    (s_axis_rp_tready[0]),
    .s_axis_tlast     (s_axis_rp_tlast [0]),
    .m_axis_tdata     (m_axis_rp_tdata [0]),
    .m_axis_tkeep     (m_axis_rp_tkeep [0]),
    .m_axis_tuser     (m_axis_rp_tuser [0]),
    .m_axis_tvalid    (m_axis_rp_tvalid[0]),
    .m_axis_tready    (m_axis_rp_tready[0]),
    .m_axis_tlast     (m_axis_rp_tlast [0])
  );

  reconfigurable_partition
  reconfigurable_partition_1 (
    .axis_aclk        (axis_aclk),
    .axis_resetn      (axis_resetn),
    .DEST_PORT_NUM    (RP_1_PORT_NUM),
    .sc_save          ((sc_port == 1)? sc_save : 1'b0),
    .sc_load          ((sc_port == 1)? sc_load : 1'b0),
    .s_axis_sc_tdata  (s_axis_sc_rp_tdata [1*SC_WIDTH +: SC_WIDTH]),
    .s_axis_sc_tkeep  (s_axis_sc_rp_tkeep [1*SC_WIDTH/8 +: SC_WIDTH/8]),
    .s_axis_sc_tvalid (s_axis_sc_rp_tvalid[1]),
    .s_axis_sc_tready (s_axis_sc_rp_tready[1]),
    .s_axis_sc_tlast  (s_axis_sc_rp_tlast [1]),
    .m_axis_sc_tdata  (m_axis_sc_rp_tdata [1*SC_WIDTH +: SC_WIDTH]),
    .m_axis_sc_tkeep  (m_axis_sc_rp_tkeep [1*SC_WIDTH/8 +: SC_WIDTH/8]),
    .m_axis_sc_tvalid (m_axis_sc_rp_tvalid[1]),
    .m_axis_sc_tready (m_axis_sc_rp_tready[1]),
    .m_axis_sc_tlast  (m_axis_sc_rp_tlast [1]),
    .s_axis_tdata     (s_axis_rp_tdata [1]),
    .s_axis_tkeep     (s_axis_rp_tkeep [1]),
    .s_axis_tuser     (s_axis_rp_tuser [1]),
    .s_axis_tvalid    (s_axis_rp_tvalid[1]),
    .s_axis_tready    (s_axis_rp_tready[1]),
    .s_axis_tlast     (s_axis_rp_tlast [1]),
    .m_axis_tdata     (m_axis_rp_tdata [1]),
    .m_axis_tkeep     (m_axis_rp_tkeep [1]),
    .m_axis_tuser     (m_axis_rp_tuser [1]),
    .m_axis_tvalid    (m_axis_rp_tvalid[1]),
    .m_axis_tready    (m_axis_rp_tready[1]),
    .m_axis_tlast     (m_axis_rp_tlast [1])
  );

  reconfigurable_partition
  reconfigurable_partition_2 (
    .axis_aclk        (axis_aclk),
    .axis_resetn      (axis_resetn),
    .DEST_PORT_NUM    (RP_2_PORT_NUM),
    .sc_save          ((sc_port == 2)? sc_save : 1'b0),
    .sc_load          ((sc_port == 2)? sc_load : 1'b0),
    .s_axis_sc_tdata  (s_axis_sc_rp_tdata [2*SC_WIDTH +: SC_WIDTH]),
    .s_axis_sc_tkeep  (s_axis_sc_rp_tkeep [2*SC_WIDTH/8 +: SC_WIDTH/8]),
    .s_axis_sc_tvalid (s_axis_sc_rp_tvalid[2]),
    .s_axis_sc_tready (s_axis_sc_rp_tready[2]),
    .s_axis_sc_tlast  (s_axis_sc_rp_tlast [2]),
    .m_axis_sc_tdata  (m_axis_sc_rp_tdata [2*SC_WIDTH +: SC_WIDTH]),
    .m_axis_sc_tkeep  (m_axis_sc_rp_tkeep [2*SC_WIDTH/8 +: SC_WIDTH/8]),
    .m_axis_sc_tvalid (m_axis_sc_rp_tvalid[2]),
    .m_axis_sc_tready (m_axis_sc_rp_tready[2]),
    .m_axis_sc_tlast  (m_axis_sc_rp_tlast [2]),
    .s_axis_tdata     (s_axis_rp_tdata [2]),
    .s_axis_tkeep     (s_axis_rp_tkeep [2]),
    .s_axis_tuser     (s_axis_rp_tuser [2]),
    .s_axis_tvalid    (s_axis_rp_tvalid[2]),
    .s_axis_tready    (s_axis_rp_tready[2]),
    .s_axis_tlast     (s_axis_rp_tlast [2]),
    .m_axis_tdata     (m_axis_rp_tdata [2]),
    .m_axis_tkeep     (m_axis_rp_tkeep [2]),
    .m_axis_tuser     (m_axis_rp_tuser [2]),
    .m_axis_tvalid    (m_axis_rp_tvalid[2]),
    .m_axis_tready    (m_axis_rp_tready[2]),
    .m_axis_tlast     (m_axis_rp_tlast [2])
  );

  reconfigurable_partition
  reconfigurable_partition_3 (
    .axis_aclk        (axis_aclk),
    .axis_resetn      (axis_resetn),
    .DEST_PORT_NUM    (RP_3_PORT_NUM),
    .sc_save          ((sc_port == 3)? sc_save : 1'b0),
    .sc_load          ((sc_port == 3)? sc_load : 1'b0),
    .s_axis_sc_tdata  (s_axis_sc_rp_tdata [3*SC_WIDTH +: SC_WIDTH]),
    .s_axis_sc_tkeep  (s_axis_sc_rp_tkeep [3*SC_WIDTH/8 +: SC_WIDTH/8]),
    .s_axis_sc_tvalid (s_axis_sc_rp_tvalid[3]),
    .s_axis_sc_tready (s_axis_sc_rp_tready[3]),
    .s_axis_sc_tlast  (s_axis_sc_rp_tlast [3]),
    .m_axis_sc_tdata  (m_axis_sc_rp_tdata [3*SC_WIDTH +: SC_WIDTH]),
    .m_axis_sc_tkeep  (m_axis_sc_rp_tkeep [3*SC_WIDTH/8 +: SC_WIDTH/8]),
    .m_axis_sc_tvalid (m_axis_sc_rp_tvalid[3]),
    .m_axis_sc_tready (m_axis_sc_rp_tready[3]),
    .m_axis_sc_tlast  (m_axis_sc_rp_tlast [3]),
    .s_axis_tdata     (s_axis_rp_tdata [3]),
    .s_axis_tkeep     (s_axis_rp_tkeep [3]),
    .s_axis_tuser     (s_axis_rp_tuser [3]),
    .s_axis_tvalid    (s_axis_rp_tvalid[3]),
    .s_axis_tready    (s_axis_rp_tready[3]),
    .s_axis_tlast     (s_axis_rp_tlast [3]),
    .m_axis_tdata     (m_axis_rp_tdata [3]),
    .m_axis_tkeep     (m_axis_rp_tkeep [3]),
    .m_axis_tuser     (m_axis_rp_tuser [3]),
    .m_axis_tvalid    (m_axis_rp_tvalid[3]),
    .m_axis_tready    (m_axis_rp_tready[3]),
    .m_axis_tlast     (m_axis_rp_tlast [3])
  );


  // MicroBlaze
  mac_filter #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .MAC_ADDR_NUM     (4),
    .TYPE             (TYPE_IP)
  )
  mac_filter_inst (
    .axis_aclk          (axis_aclk),
    .axis_resetn        (axis_resetn),
    .target_mac_addr    (
      {
        FPGA_MAC_ADDR_0,
        FPGA_MAC_ADDR_1,
        FPGA_MAC_ADDR_2,
        FPGA_MAC_ADDR_3
      }
    ),
    .s_axis_tdata       (m_axis_bc_tdata [RP_NUMBER*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
    .s_axis_tkeep       (m_axis_bc_tkeep [RP_NUMBER*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
    .s_axis_tuser       (m_axis_bc_tuser [RP_NUMBER*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
    .s_axis_tvalid      (m_axis_bc_tvalid[RP_NUMBER]),
    .s_axis_tready      (m_axis_bc_tready[RP_NUMBER]),
    .s_axis_tlast       (m_axis_bc_tlast [RP_NUMBER]),
    .m_axis_tdata       (s_axis_mb_tdata),
    .m_axis_tkeep       (s_axis_mb_tkeep),
    .m_axis_tuser       (256'b0),
    .m_axis_tvalid      (s_axis_mb_tvalid),
    .m_axis_tready      (s_axis_mb_tready),
    .m_axis_tlast       (s_axis_mb_tlast)
  );

  axis_lut_fifo # (
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (1),
    .ADDR_WIDTH       (4)
  )
  axis_lut_fifo_mb_pre (
    .aclk         (axis_aclk),
    .resetn       (axis_resetn),
    .write_tdata  (s_axis_mb_tdata ),
    .write_tkeep  (s_axis_mb_tkeep ),
    .write_tuser  (1'b0),
    .write_tvalid (s_axis_mb_tvalid),
    .write_tready (s_axis_mb_tready),
    .write_tlast  (s_axis_mb_tlast ),
    .read_tdata   (M_AXIS_S2MM_tdata ),
    .read_tkeep   (M_AXIS_S2MM_tkeep ),
    .read_tuser   (1'b0),
    .read_tvalid  (M_AXIS_S2MM_tvalid),
    .read_tready  (M_AXIS_S2MM_tready),
    .read_tlast   (M_AXIS_S2MM_tlast )
  );

  axis_lut_fifo # (
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (1),
    .ADDR_WIDTH       (4)
  )
  axis_lut_fifo_mb_post (
    .aclk         (axis_aclk),
    .resetn       (axis_resetn),
    .write_tdata  (S_AXIS_MM2S_tdata ),
    .write_tkeep  (S_AXIS_MM2S_tkeep ),
    .write_tuser  (1'b0),
    .write_tvalid (S_AXIS_MM2S_tvalid),
    .write_tready (S_AXIS_MM2S_tready),
    .write_tlast  (S_AXIS_MM2S_tlast ),
    .read_tdata   (s_axis_sw_tdata [RP_NUMBER*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
    .read_tkeep   (s_axis_sw_tkeep [RP_NUMBER*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
    .read_tuser   (1'b0),
    .read_tvalid  (s_axis_sw_tvalid[RP_NUMBER]),
    .read_tready  (s_axis_sw_tready[RP_NUMBER]),
    .read_tlast   (s_axis_sw_tlast [RP_NUMBER])
  );

  // [ 15: 0] [143:128] Length of the packet in bytes
  // [ 23:16] [151:144] Source Port
  // [ 31:24] [159:152] Destination Port
  // [127:32] [255:160] User definable meta data slot 0-5
  assign s_axis_sw_tuser[RP_NUMBER*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]
    = {{96'b0, 8'b1, 8'b1, 16'd1024}, {96'b0, 8'b1, 8'b1, 16'd1024}};


  // ARP Reply
  arp_reply #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .MAC_ADDR_0       (FPGA_MAC_ADDR_0),
    .MAC_ADDR_1       (FPGA_MAC_ADDR_1),
    .MAC_ADDR_2       (FPGA_MAC_ADDR_2),
    .MAC_ADDR_3       (FPGA_MAC_ADDR_3),
    .IP_ADDR_0        (FPGA_IP_ADDR_0),
    .IP_ADDR_1        (FPGA_IP_ADDR_1),
    .IP_ADDR_2        (FPGA_IP_ADDR_2),
    .IP_ADDR_3        (FPGA_IP_ADDR_3)
  )
  arp_reply_inst (
    .axis_aclk          (axis_aclk),
    .axis_resetn        (axis_resetn),
    .s_axis_tdata       (m_axis_bc_tdata [(RP_NUMBER + 1)*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
    .s_axis_tkeep       (m_axis_bc_tkeep [(RP_NUMBER + 1)*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
    .s_axis_tuser       (m_axis_bc_tuser [(RP_NUMBER + 1)*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
    .s_axis_tvalid      (m_axis_bc_tvalid[RP_NUMBER + 1]),
    .s_axis_tready      (m_axis_bc_tready[RP_NUMBER + 1]),
    .s_axis_tlast       (m_axis_bc_tlast [RP_NUMBER + 1]),
    .m_axis_tdata       (s_axis_sw_tdata [(RP_NUMBER + 1)*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
    .m_axis_tkeep       (s_axis_sw_tkeep [(RP_NUMBER + 1)*AXIS_DATA_WIDTH/8 +: AXIS_DATA_WIDTH/8]),
    .m_axis_tuser       (s_axis_sw_tuser [(RP_NUMBER + 1)*AXIS_TUSER_WIDTH +: AXIS_TUSER_WIDTH]),
    .m_axis_tvalid      (s_axis_sw_tvalid[RP_NUMBER + 1]),
    .m_axis_tready      (s_axis_sw_tready[RP_NUMBER + 1]),
    .m_axis_tlast       (s_axis_sw_tlast [RP_NUMBER + 1])
  );


  // AXI-Stream Switch
  axis_switch #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (4),
    .S_INTF_NUM       (BROADCAST_WIDTH)
  )
  axis_switch_inst (
    .aclk           (axis_aclk),
    .aresetn        (axis_resetn),
    .s_axis_tdata   (s_axis_sw_tdata),
    .s_axis_tkeep   (s_axis_sw_tkeep),
    .s_axis_tuser   (s_axis_sw_tuser),
    .s_axis_tvalid  (s_axis_sw_tvalid),
    .s_axis_tready  (s_axis_sw_tready),
    .s_axis_tlast   (s_axis_sw_tlast),
    .m_axis_tdata   (m_axis_sw_tdata),
    .m_axis_tkeep   (m_axis_sw_tkeep),
    .m_axis_tuser   (m_axis_sw_tuser),
    .m_axis_tvalid  (m_axis_sw_tvalid),
    .m_axis_tready  (m_axis_sw_tready),
    .m_axis_tlast   (m_axis_sw_tlast)
  );


  // Stream Maneger
  stream_manager #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH)
  )
  stream_manager_inst (
    .axis_aclk          (axis_aclk  ),
    .axis_resetn        (axis_resetn),
    .s_axis_tdata       (m_axis_sw_tdata ),
    .s_axis_tkeep       (m_axis_sw_tkeep ),
    .s_axis_tuser       (m_axis_sw_tuser ),
    .s_axis_tvalid      (m_axis_sw_tvalid),
    .s_axis_tready      (m_axis_sw_tready),
    .s_axis_tlast       (m_axis_sw_tlast ),
    .m_axis_tdata       (m_axis_tdata ),
    .m_axis_tkeep       (m_axis_tkeep ),
    .m_axis_tuser       (m_axis_tuser ),
    .m_axis_tvalid      (m_axis_tvalid),
    .m_axis_tready      (m_axis_tready),
    .m_axis_tlast       (m_axis_tlast ),
    .s_axis_buf_tdata   (s_axis_buf_tdata ),
    .s_axis_buf_tkeep   (s_axis_buf_tkeep ),
    .s_axis_buf_tuser   (s_axis_buf_tuser ),
    .s_axis_buf_tvalid  (s_axis_buf_tvalid),
    .s_axis_buf_tready  (s_axis_buf_tready),
    .s_axis_buf_tlast   (s_axis_buf_tlast ),
    .m_axis_buf_tdata   (m_axis_buf_tdata ),
    .m_axis_buf_tkeep   (m_axis_buf_tkeep ),
    .m_axis_buf_tuser   (m_axis_buf_tuser ),
    .m_axis_buf_tvalid  (m_axis_buf_tvalid),
    .m_axis_buf_tready  (m_axis_buf_tready),
    .m_axis_buf_tlast   (m_axis_buf_tlast ),
    .migration_progress (migration_progress),
    .migration_ready    (migration_ready   ),
    .buffering_type     (buffering_type    ),
    .buffering_port     (buffering_port    )
  );

  // Buffer
  axis_fifo #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .ADDR_WIDTH       (16)
  )
  buffer_inst (
    .aclk         (axis_aclk),
    .resetn       (axis_resetn),
    .write_tdata  (s_axis_buf_tdata ),
    .write_tkeep  (s_axis_buf_tkeep ),
    .write_tuser  (s_axis_buf_tuser ),
    .write_tvalid (s_axis_buf_tvalid),
    .write_tlast  (s_axis_buf_tready),
    .write_tready (s_axis_buf_tlast ),
    .read_tdata   (m_axis_buf_tdata ),
    .read_tkeep   (m_axis_buf_tkeep ),
    .read_tuser   (m_axis_buf_tuser ),
    .read_tvalid  (m_axis_buf_tvalid),
    .read_tlast   (m_axis_buf_tready),
    .read_tready  (m_axis_buf_tlast )
  );

endmodule
