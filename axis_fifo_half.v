`timescale 1 ns / 1 ps

/*
 *  AXI Stream FIFO
 */
module axis_fifo_half #(
  parameter AXIS_DATA_WIDTH = 512,
  parameter AXIS_TUSER_WIDTH = 256,
  parameter ADDR_WIDTH = 12
) (
  input  wire       aclk,
  input  wire       resetn,

  // AXI Stream Slave
  input  wire [AXIS_DATA_WIDTH*2 - 1:0]   write_tdata,
  input  wire [AXIS_DATA_WIDTH/8*2 - 1:0] write_tkeep,
  input  wire [AXIS_TUSER_WIDTH*2 - 1:0]  write_tuser,
  input  wire                           write_tvalid,
  input  wire                           write_tlast,
  output wire                           write_tready,

  // AXI Stream Master
  output reg  [AXIS_DATA_WIDTH - 1:0]   read_tdata,
  output reg  [AXIS_DATA_WIDTH/8 - 1:0] read_tkeep,
  output reg  [AXIS_TUSER_WIDTH - 1:0]  read_tuser,
  output wire                           read_tvalid,
  output reg                            read_tlast,
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
  reg                 odd = 1'b0;

  wire [AXIS_DATA_WIDTH - 1:0]   read_tdata0, read_tdata1;
  wire [AXIS_DATA_WIDTH/8 - 1:0] read_tkeep0, read_tkeep1;
  wire [AXIS_TUSER_WIDTH - 1:0]  read_tuser0, read_tuser1;
  wire                           read_tlast0;

  // RAM --------
  ram_w #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (AXIS_DATA_WIDTH*2 + AXIS_DATA_WIDTH/8*2 + AXIS_TUSER_WIDTH*2 + 1),
    .WORDS      (WORDS)
  )
  ram_w_inst (
    .clk    (aclk),
    .we     (we),
    .r_addr (next_read_ptr[ADDR_WIDTH-1:0]),
    .r_data ({read_tdata1, read_tdata0, read_tkeep1, read_tkeep0, read_tuser1, read_tuser0, read_tlast0}),
    .w_addr (write_ptr[ADDR_WIDTH-1:0]),
    .w_data ({write_tdata, write_tkeep, write_tuser, write_tlast})
  );

  // Serial Read --------
  always @(*) begin
    read_tlast = read_tlast0;
    if (odd) begin
      read_tdata = read_tdata1;
      read_tkeep = read_tkeep1;
      read_tuser = read_tuser1;
    end else begin
      read_tdata = read_tdata0;
      read_tkeep = read_tkeep0;
      read_tuser = read_tuser0;
      if (read_tlast0) begin
        if (read_tkeep1)
          read_tlast = 1'b0;
        else
          read_tlast = 1'b1;
      end
    end
  end

  // Odd --------
  always @(posedge aclk) begin
    if (!resetn)
      odd <= 1'b0;
    else begin
      if (read_tvalid & read_tready) begin
        if (read_tlast)
          odd <= 1'b0;
        else
          odd <= ~odd;
      end
    end
  end

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
  assign re = read_tready & read_tvalid & (odd | (~odd & read_tlast0 & !read_tkeep1));

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
