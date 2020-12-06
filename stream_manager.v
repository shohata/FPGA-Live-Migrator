module stream_manager #(
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

  // Slave Stream Ports
  input  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_buf_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_buf_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_buf_tuser,
  input  wire                           s_axis_buf_tvalid,
  output wire                           s_axis_buf_tready,
  input  wire                           s_axis_buf_tlast,

  // Master Stream Ports
  output wire [AXIS_DATA_WIDTH - 1:0]   m_axis_buf_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] m_axis_buf_tkeep,
  output wire [AXIS_TUSER_WIDTH - 1:0]  m_axis_buf_tuser,
  output wire                           m_axis_buf_tvalid,
  input  wire                           m_axis_buf_tready,
  output wire                           m_axis_buf_tlast,

  input  wire                           migration_progress,
  output reg                            migration_ready,
  input  wire [1:0]                     buffering_type,
  input  wire [7:0]                     buffering_port
);

  localparam                      FIVE_TUPLE_WIDTH = 104;
  localparam                      HASH_WIDTH = 16;
  localparam [HASH_WIDTH-1:0]     POLYNOMIAL = 16'h1021;
  localparam                      TIME_WIDTH = 32;
  localparam [1:0]                BUF_NONE = 0, BUF_ALL = 1, BUF_STREAM = 3;
  localparam                      TIMEOUT = 1000;
  localparam [1:0]                IDLE = 0, PRE_STREAM_MIGRATION = 1, MIGRATION = 2, POST_MIGRATION = 3;

  wire [AXIS_DATA_WIDTH - 1:0]   s_axis_sw_tdata;
  wire [AXIS_DATA_WIDTH/8 - 1:0] s_axis_sw_tkeep;
  wire [AXIS_TUSER_WIDTH - 1:0]  s_axis_sw_tuser;
  wire                           s_axis_sw_tvalid;
  wire                           s_axis_sw_tready;
  wire                           s_axis_sw_tlast;

  wire [31:0]                    src_ip_addr;
  wire [31:0]                    dest_ip_addr;
  wire [7:0]                     protocol;
  wire [15:0]                    src_port_num;
  wire [15:0]                    dest_port_num;

  reg [1:0]                      state;

  wire                           fin_flag;
  reg                            fin_flag_reg;

  wire                           we0;
  wire                           we1;
  wire                           fin;
  wire                           update;

  wire [FIVE_TUPLE_WIDTH-1:0]    five_tuple;
  reg  [FIVE_TUPLE_WIDTH-1:0]    five_tuple_reg;
  wire                           five_tuple_valid;
  reg                            five_tuple_valid_reg;

  wire [HASH_WIDTH-1:0]          hash_val;
  reg  [HASH_WIDTH-1:0]          hash_val_reg;
  reg  [HASH_WIDTH-1:0]          addr;

  reg                            buffering;
  reg                            releasing;
  wire                           empty;
  wire                           buffering_flag;

  wire                           out_time_valid;
  wire [TIME_WIDTH-1:0]          out_time;
  wire [TIME_WIDTH-1:0]          in_time;
  wire [FIVE_TUPLE_WIDTH-1:0]    out_five_tuple;

  reg                            all_fin;
  reg [TIME_WIDTH-1:0]           start_time;


  header_parser # (
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH)
  )
  header_parser_inst (
    .axis_aclk        (axis_aclk  ),
    .axis_resetn      (axis_resetn),

    .s_axis_tdata     (s_axis_tdata ),
    .s_axis_tkeep     (s_axis_tkeep ),
    .s_axis_tuser     (s_axis_tuser ),
    .s_axis_tvalid    (s_axis_tvalid),
    .s_axis_tready    (s_axis_tready),
    .s_axis_tlast     (s_axis_tlast ),

    .m_axis_tdata     (s_axis_sw_tdata ),
    .m_axis_tkeep     (s_axis_sw_tkeep ),
    .m_axis_tuser     (s_axis_sw_tuser),
    .m_axis_tvalid    (s_axis_sw_tvalid),
    .m_axis_tready    (s_axis_sw_tready),
    .m_axis_tlast     (s_axis_sw_tlast ),

    .src_ip_addr      (src_ip_addr  ),
    .dest_ip_addr     (dest_ip_addr ),
    .protocol         (protocol     ),
    .src_port_num     (src_port_num ),
    .dest_port_num    (dest_port_num),

    .fin_flag         (fin_flag),

    .five_tuple_valid (five_tuple_valid)
  );

  packet_switch #(
    .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH (AXIS_TUSER_WIDTH)
  )
  packet_switch_inst (
    .axis_aclk         (axis_aclk),
    .axis_resetn       (axis_resetn),

    .s_axis_tdata      (s_axis_sw_tdata ),
    .s_axis_tkeep      (s_axis_sw_tkeep ),
    .s_axis_tuser      (s_axis_sw_tuser ),
    .s_axis_tvalid     (s_axis_sw_tvalid),
    .s_axis_tready     (s_axis_sw_tready),
    .s_axis_tlast      (s_axis_sw_tlast ),

    .m_axis_buf_tdata  (m_axis_buf_tdata ),
    .m_axis_buf_tkeep  (m_axis_buf_tkeep ),
    .m_axis_buf_tuser  (m_axis_buf_tuser ),
    .m_axis_buf_tvalid (m_axis_buf_tvalid),
    .m_axis_buf_tready (m_axis_buf_tready),
    .m_axis_buf_tlast  (m_axis_buf_tlast ),

    .s_axis_buf_tdata  (s_axis_buf_tdata ),
    .s_axis_buf_tkeep  (s_axis_buf_tkeep ),
    .s_axis_buf_tuser  (s_axis_buf_tuser ),
    .s_axis_buf_tvalid (s_axis_buf_tvalid),
    .s_axis_buf_tready (s_axis_buf_tready),
    .s_axis_buf_tlast  (s_axis_buf_tlast ),

    .m_axis_tdata      (m_axis_tdata ),
    .m_axis_tkeep      (m_axis_tkeep ),
    .m_axis_tuser      (m_axis_tuser ),
    .m_axis_tvalid     (m_axis_tvalid),
    .m_axis_tready     (m_axis_tready),
    .m_axis_tlast      (m_axis_tlast ),

    .buffering         (buffering_flag),
    .releasing         (releasing),
    .empty             (empty)
  );


  crc #(
    .DATA_WIDTH  (FIVE_TUPLE_WIDTH),
    .CRC_WIDTH   (HASH_WIDTH),
    .POLYNOMIAL  (POLYNOMIAL),
    .SEED_VAL    ({HASH_WIDTH{1'b0}}),
    .OUTPUT_EXOR ({HASH_WIDTH{1'b0}})
  )
  crc_inst (
    .datain (five_tuple),
    .crcout (hash_val)
  );

  ram_w #(
    .ADDR_WIDTH (HASH_WIDTH),
    .DATA_WIDTH (1 + TIME_WIDTH + FIVE_TUPLE_WIDTH),
    .WORDS      (1 << HASH_WIDTH)
  )
  ram_w_inst (
    .clk    (axis_aclk),
    .we     (state != PRE_STREAM_MIGRATION && update && five_tuple_valid_reg),
    .r_addr ((state == PRE_STREAM_MIGRATION && !five_tuple_valid)? addr : hash_val),
    .r_data ({out_time_valid, out_time, out_five_tuple}),
    .w_addr (hash_val_reg),
    .w_data ({fin_flag_reg, in_time, five_tuple_reg})
  );

  timer #(
    .WIDTH (TIME_WIDTH)
  )
  timer_inst (
    .clk  (axis_aclk),
    .rstn (axis_resetn),
    .t    (in_time)
  );

  assign we0 = s_axis_tready & s_axis_tvalid;
  assign we1 = s_axis_sw_tready & s_axis_sw_tvalid;

  assign five_tuple = {dest_port_num, src_port_num, protocol, dest_ip_addr, src_ip_addr};

  assign fin    = (!out_time_valid || in_time - out_time > TIMEOUT || fin_flag_reg);
  assign update = (out_five_tuple == five_tuple_reg || fin);


  always @(posedge axis_aclk) begin
    if (we0) begin
      five_tuple_reg       <= five_tuple;
      five_tuple_valid_reg <= five_tuple_valid;
      hash_val_reg         <= hash_val;
      fin_flag_reg         <= fin_flag;
    end
  end


  // All finished flag
  always @(posedge axis_aclk) begin
    if (!axis_resetn) begin
      addr <= 0;
      all_fin <= 1'b0;
    end else begin
      if (state == PRE_STREAM_MIGRATION) begin
        if (five_tuple_valid_reg) begin
          all_fin <= 1'b0;
        end else begin
          addr <= addr + 1;
          if (addr == 0) begin
            all_fin <= 1'b1;
          end else if (!fin) begin
            all_fin <= 1'b0;
          end
        end
      end
    end
  end


  // Buffering and Releasing
  assign first = we1 & five_tuple_valid_reg;
  always @(posedge axis_aclk) begin
    case (state)
      IDLE: begin
        start_time <= in_time;
        if (first) buffering <= 1'b0;
        releasing <= 1'b0;
      end
      PRE_STREAM_MIGRATION: begin
        if (first) begin
          if (out_time > start_time || fin) begin
            buffering <= 1'b1;
          end else begin
            buffering <= 1'b0;
          end
        end
      end
      MIGRATION: begin
        if (first) buffering <= 1'b1;
      end
      POST_MIGRATION: begin
        buffering <= 1'b1;
        releasing <= 1'b1;
      end
    endcase
  end

  assign buffering_flag = (buffering && (s_axis_sw_tuser[31:24] & buffering_port));

  // State
  always @(posedge axis_aclk) begin
    case (state)
      IDLE: begin
        if (migration_progress) begin
          case (buffering_type)
            BUF_NONE:   state <= IDLE;
            BUF_ALL:    state <= MIGRATION;
            BUF_STREAM: state <= PRE_STREAM_MIGRATION;
          endcase
        end
      end
      PRE_STREAM_MIGRATION: begin
        if (addr == 0 && all_fin == 1'b1) state <= MIGRATION;
      end
      MIGRATION: begin
        migration_ready <= 1'b1;
        if (!migration_progress) state <= POST_MIGRATION;
      end
      POST_MIGRATION: begin
        migration_ready <= 1'b0;
        if (empty) state <= IDLE;
      end
    endcase
  end


endmodule
