`timescale 1 ns / 1 ps

/*
 *  AXI Stream FIFO
 */
module axis_lut_fifo #(
  parameter AXIS_DATA_WIDTH=256,
  parameter AXIS_TUSER_WIDTH=128,
  parameter ADDR_WIDTH = 12
) (
  input  wire       aclk,
  input  wire       resetn,

  // AXI Stream Slave
  input  wire [AXIS_DATA_WIDTH - 1:0]   write_tdata,
  input  wire [AXIS_DATA_WIDTH/8 - 1:0] write_tkeep,
  input  wire [AXIS_TUSER_WIDTH - 1:0]  write_tuser,
  input  wire                           write_tvalid,
  input  wire                           write_tlast,
  output wire                           write_tready,

  // AXI Stream Master
  output wire [AXIS_DATA_WIDTH - 1:0]   read_tdata,
  output wire [AXIS_DATA_WIDTH/8 - 1:0] read_tkeep,
  output wire [AXIS_TUSER_WIDTH - 1:0]  read_tuser,
  output wire                           read_tvalid,
  output wire                           read_tlast,
  input  wire                           read_tready
);

  localparam WORDS = 1 << ADDR_WIDTH;

  reg  [ADDR_WIDTH:0] write_ptr = 0;
  reg  [ADDR_WIDTH:0] read_ptr = 0;
  reg  [ADDR_WIDTH:0] next_read_ptr = 0;
  wire                empty;
  wire                full;
  wire                we;
  wire                re;

  // RAM --------
  lutram_w #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (AXIS_DATA_WIDTH + AXIS_DATA_WIDTH/8 + AXIS_TUSER_WIDTH + 1),
    .WORDS      (WORDS)
  )
  lutram_w_inst (
    .clk    (aclk),
    .we     (we),
    .r_addr (next_read_ptr[ADDR_WIDTH-1:0]),
    .r_data ({read_tdata, read_tkeep, read_tuser, read_tlast}),
    .w_addr (write_ptr[ADDR_WIDTH-1:0]),
    .w_data ({write_tdata, write_tkeep, write_tuser, write_tlast})
  );

  // Write Logic --------
  assign full = ((write_ptr[ADDR_WIDTH]  != read_ptr[ADDR_WIDTH])
                && (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]));
  assign write_tready = ~full;
  assign we = write_tready & write_tvalid;

  always @(posedge aclk) begin
    if (!resetn)
      write_ptr <= 0;
    else
      if (we) write_ptr <= write_ptr + 1;
  end

  // Read Logic --------
  assign empty = (write_ptr == read_ptr);
  assign read_tvalid = ~empty;
  assign re = read_tready & read_tvalid;

  always @(posedge aclk) begin
    if (!resetn)
      read_ptr <= 0;
    else
      read_ptr <= next_read_ptr;
  end

  always @(*) begin
    if (re)
      next_read_ptr = read_ptr + 1;
    else
      next_read_ptr = read_ptr;
  end

endmodule
