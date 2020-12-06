module timer #(
  parameter WIDTH = 32
)
(
  input  wire             clk,
  input  wire             rstn,
  output reg  [WIDTH-1:0] t
);

  reg [23:0] count = 0;

  initial t = 0;

  always @(posedge clk) begin
    if (!rstn) begin
      count <= 0;
      t <= 0;
    end else begin
      if (count == 12500000) begin
        count <= 0;
        t <= t + 1;
      end else begin
        count <= count + 1;
      end
    end
  end

endmodule
