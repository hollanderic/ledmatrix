module test(input clk, wen, input [10:0] addr, input [15:0] wdata, output reg [15:0] rdata);
  reg [15:0] mem [0:2047];
  initial mem[0] = 255;
  always @(posedge clk) begin
        if (wen) mem[addr] <= wdata;
        rdata <= mem[addr];
  end
endmodule