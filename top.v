`timescale 1 ns / 1 ps

module top (
  input  wire         eth0_abs,
  output wire         eth0_rx_led,
  input  wire         eth0_rxn,
  input  wire         eth0_rxp,
  output wire         eth0_tx_disable,
  input  wire         eth0_tx_fault,
  output wire         eth0_tx_led,
  output wire         eth0_txn,
  output wire         eth0_txp,
  input  wire         eth1_abs,
  output wire         eth1_rx_led,
  input  wire         eth1_rxn,
  input  wire         eth1_rxp,
  output wire         eth1_tx_disable,
  input  wire         eth1_tx_fault,
  output wire         eth1_tx_led,
  output wire         eth1_txn,
  output wire         eth1_txp,
  input  wire         eth2_abs,
  output wire         eth2_rx_led,
  input  wire         eth2_rxn,
  input  wire         eth2_rxp,
  output wire         eth2_tx_disable,
  input  wire         eth2_tx_fault,
  output wire         eth2_tx_led,
  output wire         eth2_txn,
  output wire         eth2_txp,
  input  wire         eth3_abs,
  output wire         eth3_rx_led,
  input  wire         eth3_rxn,
  input  wire         eth3_rxp,
  output wire         eth3_tx_disable,
  input  wire         eth3_tx_fault,
  output wire         eth3_tx_led,
  output wire         eth3_txn,
  output wire         eth3_txp,
  input  wire         fpga_sysclk_n,
  input  wire         fpga_sysclk_p,
  inout  wire         iic_fpga_scl_io,
  inout  wire         iic_fpga_sda_io,
  output wire [1:0]   iic_reset,
  input  wire [0:7]   pcie_7x_mgt_rxn,
  input  wire [0:7]   pcie_7x_mgt_rxp,
  output wire [7:0]   pcie_7x_mgt_txn,
  output wire [7:0]   pcie_7x_mgt_txp,
  input  wire         pcie_sys_resetn,
  input  wire         reset,
  input  wire         sfp_refclk_n,
  input  wire         sfp_refclk_p,
  input  wire         sys_clkn,
  input  wire         sys_clkp,
  input  wire         uart_rxd,
  output wire         uart_txd
);

  localparam AXIS_DATA_WIDTH  = 512;
  localparam AXIS_TUSER_WIDTH = 256;
  localparam SC_WIDTH         = 32;


  wire                           axis_aclk;
  wire                           axis_resetn;

  wire [AXIS_DATA_WIDTH - 1:0]   M_AXIS_MM2S_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] M_AXIS_MM2S_tkeep;
  wire                           M_AXIS_MM2S_tlast;
  wire                           M_AXIS_MM2S_tready;
  wire                           M_AXIS_MM2S_tvalid;

  wire [AXIS_DATA_WIDTH - 1:0]   S_AXIS_S2MM_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] S_AXIS_S2MM_tkeep;
  wire                           S_AXIS_S2MM_tlast;
  wire                           S_AXIS_S2MM_tready;
  wire                           S_AXIS_S2MM_tvalid;

  wire [AXIS_DATA_WIDTH - 1:0]   m_axis_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_tkeep;
  wire                           m_axis_tlast;
  wire                           m_axis_tready;
  wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_tuser;
  wire                           m_axis_tvalid;

  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_tkeep;
  wire                           s_axis_tlast;
  wire                           s_axis_tready;
  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_tuser;
  wire                           s_axis_tvalid;

  wire                           sc_load;
  wire                           sc_save;
  wire [3:0]                     sc_port;

  wire                           migration_progress;
  wire                           migration_ready;
  wire [1:0]                     buffering_type;
  wire [7:0]                     buffering_port;
  wire [3:0]                     decouple;


  reference_nic_wrapper
  reference_nic_wrapper_i (
    .eth0_abs           (eth0_abs       ),
    .eth0_rx_led        (eth0_rx_led    ),
    .eth0_rxn           (eth0_rxn       ),
    .eth0_rxp           (eth0_rxp       ),
    .eth0_tx_disable    (eth0_tx_disable),
    .eth0_tx_fault      (eth0_tx_fault  ),
    .eth0_tx_led        (eth0_tx_led    ),
    .eth0_txn           (eth0_txn       ),
    .eth0_txp           (eth0_txp       ),
    .eth1_abs           (eth1_abs       ),
    .eth1_rx_led        (eth1_rx_led    ),
    .eth1_rxn           (eth1_rxn       ),
    .eth1_rxp           (eth1_rxp       ),
    .eth1_tx_disable    (eth1_tx_disable),
    .eth1_tx_fault      (eth1_tx_fault  ),
    .eth1_tx_led        (eth1_tx_led    ),
    .eth1_txn           (eth1_txn       ),
    .eth1_txp           (eth1_txp       ),
    .eth2_abs           (eth2_abs       ),
    .eth2_rx_led        (eth2_rx_led    ),
    .eth2_rxn           (eth2_rxn       ),
    .eth2_rxp           (eth2_rxp       ),
    .eth2_tx_disable    (eth2_tx_disable),
    .eth2_tx_fault      (eth2_tx_fault  ),
    .eth2_tx_led        (eth2_tx_led    ),
    .eth2_txn           (eth2_txn       ),
    .eth2_txp           (eth2_txp       ),
    .eth3_abs           (eth3_abs       ),
    .eth3_rx_led        (eth3_rx_led    ),
    .eth3_rxn           (eth3_rxn       ),
    .eth3_rxp           (eth3_rxp       ),
    .eth3_tx_disable    (eth3_tx_disable),
    .eth3_tx_fault      (eth3_tx_fault  ),
    .eth3_tx_led        (eth3_tx_led    ),
    .eth3_txn           (eth3_txn       ),
    .eth3_txp           (eth3_txp       ),
    .fpga_sysclk_n      (fpga_sysclk_n  ),
    .fpga_sysclk_p      (fpga_sysclk_p  ),
    .iic_fpga_scl_io    (iic_fpga_scl_io),
    .iic_fpga_sda_io    (iic_fpga_sda_io),
    .iic_reset          (iic_reset      ),
    .pcie_7x_mgt_rxn    (pcie_7x_mgt_rxn),
    .pcie_7x_mgt_rxp    (pcie_7x_mgt_rxp),
    .pcie_7x_mgt_txn    (pcie_7x_mgt_txn),
    .pcie_7x_mgt_txp    (pcie_7x_mgt_txp),
    .pcie_sys_resetn    (pcie_sys_resetn),
    .reset              (reset          ),
    .sfp_refclk_n       (sfp_refclk_n   ),
    .sfp_refclk_p       (sfp_refclk_p   ),
    .sys_clkn           (sys_clkn       ),
    .sys_clkp           (sys_clkp       ),
    .uart_rxd           (uart_rxd       ),
    .uart_txd           (uart_txd       ),

    .axis_aclk          (axis_aclk  ),
    .axis_resetn        (axis_resetn),

    .M_AXIS_MM2S_tdata  (M_AXIS_MM2S_tdata ),
    .M_AXIS_MM2S_tkeep  (M_AXIS_MM2S_tkeep ),
    .M_AXIS_MM2S_tlast  (M_AXIS_MM2S_tlast ),
    .M_AXIS_MM2S_tready (M_AXIS_MM2S_tready),
    .M_AXIS_MM2S_tvalid (M_AXIS_MM2S_tvalid),

    .S_AXIS_S2MM_tdata  (S_AXIS_S2MM_tdata ),
    .S_AXIS_S2MM_tkeep  (S_AXIS_S2MM_tkeep ),
    .S_AXIS_S2MM_tlast  (S_AXIS_S2MM_tlast ),
    .S_AXIS_S2MM_tready (S_AXIS_S2MM_tready),
    .S_AXIS_S2MM_tvalid (S_AXIS_S2MM_tvalid),

    .m_axis_tdata       (m_axis_tdata ),
    .m_axis_tkeep       (m_axis_tkeep ),
    .m_axis_tlast       (m_axis_tlast ),
    .m_axis_tready      (m_axis_tready),
    .m_axis_tuser       (m_axis_tuser ),
    .m_axis_tvalid      (m_axis_tvalid),

    .s_axis_tdata       (s_axis_tdata ),
    .s_axis_tkeep       (s_axis_tkeep ),
    .s_axis_tlast       (s_axis_tlast ),
    .s_axis_tready      (s_axis_tready),
    .s_axis_tuser       (s_axis_tuser ),
    .s_axis_tvalid      (s_axis_tvalid),

    .s_axis_sc_tdata    (m_axis_sc_tdata ),
    .s_axis_sc_tkeep    (m_axis_sc_tkeep ),
    .s_axis_sc_tvalid   (m_axis_sc_tvalid),
    .s_axis_sc_tready   (m_axis_sc_tready),
    .s_axis_sc_tlast    (m_axis_sc_tlast ),

    .m_axis_sc_tdata    (s_axis_sc_tdata ),
    .m_axis_sc_tkeep    (s_axis_sc_tkeep ),
    .m_axis_sc_tvalid   (s_axis_sc_tvalid),
    .m_axis_sc_tready   (s_axis_sc_tready),
    .m_axis_sc_tlast    (s_axis_sc_tlast ),

    .migration_output   ({17'b0, migration_progress, buffering_type, buffering_port, decouple}),
    .migration_input    ({31'b0, migration_ready})
  );


  dpr #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH ),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH),
    .SC_WIDTH         (SC_WIDTH)
  )
  dpr_i (
    .axis_aclk          (axis_aclk  ),
    .axis_resetn        (axis_resetn),

    .M_AXIS_S2MM_tdata  (S_AXIS_S2MM_tdata ),
    .M_AXIS_S2MM_tkeep  (S_AXIS_S2MM_tkeep ),
    .M_AXIS_S2MM_tlast  (S_AXIS_S2MM_tlast ),
    .M_AXIS_S2MM_tready (S_AXIS_S2MM_tready),
    .M_AXIS_S2MM_tvalid (S_AXIS_S2MM_tvalid),

    .S_AXIS_MM2S_tdata  (M_AXIS_MM2S_tdata ),
    .S_AXIS_MM2S_tkeep  (M_AXIS_MM2S_tkeep ),
    .S_AXIS_MM2S_tlast  (M_AXIS_MM2S_tlast ),
    .S_AXIS_MM2S_tready (M_AXIS_MM2S_tready),
    .S_AXIS_MM2S_tvalid (M_AXIS_MM2S_tvalid),

    .m_axis_tdata       (s_axis_tdata ),
    .m_axis_tkeep       (s_axis_tkeep ),
    .m_axis_tlast       (s_axis_tlast ),
    .m_axis_tready      (s_axis_tready),
    .m_axis_tuser       (s_axis_tuser ),
    .m_axis_tvalid      (s_axis_tvalid),

    .s_axis_tdata       (m_axis_tdata ),
    .s_axis_tkeep       (m_axis_tkeep ),
    .s_axis_tlast       (m_axis_tlast ),
    .s_axis_tready      (m_axis_tready),
    .s_axis_tuser       (m_axis_tuser ),
    .s_axis_tvalid      (m_axis_tvalid),

    .s_axis_sc_tdata    (m_axis_sc_tdata ),
    .s_axis_sc_tkeep    (m_axis_sc_tkeep ),
    .s_axis_sc_tvalid   (m_axis_sc_tvalid),
    .s_axis_sc_tready   (m_axis_sc_tready),
    .s_axis_sc_tlast    (m_axis_sc_tlast ),

    .m_axis_sc_tdata    (s_axis_sc_tdata ),
    .m_axis_sc_tkeep    (s_axis_sc_tkeep ),
    .m_axis_sc_tvalid   (s_axis_sc_tvalid),
    .m_axis_sc_tready   (s_axis_sc_tready),
    .m_axis_sc_tlast    (s_axis_sc_tlast ),

    .sc_load            (sc_load),
    .sc_save            (sc_save),
    .sc_port            (sc_port),

    .migration_progress (migration_progress),
    .migration_ready    (migration_ready   ),
    .buffering_type     (buffering_type    ),
    .buffering_port     (buffering_port    ),
    .decouple           (decouple)
  );

endmodule
