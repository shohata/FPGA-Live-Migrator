`timescale 1 ns / 1 ps

/*
 * Simple Dual-Port Block RAM with One Clock (write-first)
 */
module ram_w #(
  parameter ADDR_WIDTH = 12,
  parameter DATA_WIDTH = 32,
  parameter WORDS = 4096
) (
  input  wire                  clk,
  input  wire                  we,
  input  wire [ADDR_WIDTH-1:0] r_addr,
  output wire [DATA_WIDTH-1:0] r_data,
  input  wire [ADDR_WIDTH-1:0] w_addr,
  input  wire [DATA_WIDTH-1:0] w_data
);

  (* ram_style = "BLOCK" *) reg [DATA_WIDTH-1:0] ram [WORDS-1:0];
  reg [ADDR_WIDTH-1:0] read_addr;

  integer i;
  initial begin
    for (i=0; i<WORDS; i=i+1) begin
      ram[i] = 0;
    end
  end

  always @(posedge clk) begin
    if (we) ram[w_addr] <= w_data;
  end

  always @(posedge clk) begin
    read_addr <= r_addr;
  end

  assign r_data = ram[read_addr];

endmodule
