// blinky.v
// Blink the green LED with frequency 12e6/2^24 = 0.7Hz approx.


`define ROWLEN 64

module mem(input clk, wen, input [7:0] addr, input [15:0] wdata, output reg [15:0] rdata);
  reg [15:0] mem [0:255];
  initial mem[0] = 255;
  initial mem[22] = 1;
  initial mem[7] = 1;
  always @(posedge clk) begin
        if (wen) mem[addr] <= wdata;
        rdata <= mem[addr];
  end
endmodule



module top (
    input clk,
    output sel_a,
    output sel_b,
    output sel_c,
    output sel_d,

    output clkout,
    output stb,
    output oe,
    output redout0,
    output blueout0,
    output greenout0,

    );

    wire nclk = ~clk;

    reg [63:0] pix [0:15];
    reg [3:0] rowsel;

    initial pix[0] = 8'h01;
/*
    initial pix[1] = 64'h0000000000000001;
    initial pix[2] = 64'h8000000000000000;
    initial pix[3] = 64'h0000000000000000;
    initial pix[4] = 64'h0000000000000000;
    initial pix[5] = 64'h0000000000000000;
    initial pix[6] = 64'h0000000000000000;
    initial pix[7] = 64'h0000000000000000;
    initial pix[8] = 64'h0000000000000000;
    initial pix[9] = 64'h0000000000000000;
    initial pix[10] = 64'h0000000000000000;
    initial pix[11] = 64'h0000000000000000;
    initial pix[12] = 64'h0000000000000000;
    initial pix[13] = 64'h0000000000000000;
    initial pix[14] = 64'h0000000000000000;
    initial pix[15] = 64'h0000000000000000;
    initial pix[15] = 64'hffffffffffffffff;
*/

    initial rowsel = 4'hf;
    initial stb = 0;


    reg[7:0] counter;

    initial counter = 7'h0;

    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];

    wire [15:0] dbus;

    mem mem_0(clk, 0, counter[5:0], 16'h0000, dbus);


    always @(posedge clk) begin
        if (stb) begin
         counter <= 0;
         rowsel <= rowsel + 1;
         pix[0] <= pix[0] + 1;
        end else
         counter <= counter +1;
    end




    always @(negedge clk) begin
        if (counter == 64) begin
            stb <= 1;
            oe <= 1;
        end else begin
            stb <= 0;
            oe <= 0;
        end
    end



// This is where we need to update out data values

    always @ (negedge clk) begin
        if (counter < 64) begin

            if (dbus[0])
                redout0 <= 1;
            else
                redout0 <= 0;

//            if (pix[rowsel][counter])
//                greenout0 <= 1;
//            else
                greenout0 <= 0;
//            if (pix[rowsel][counter])
//                blueout0 <= 1;
//            else
                blueout0 <= 0;
        end
    end



// This is where we update the clock pin
//  don't make a positive edge during the latch period

    always @ (clk) begin
        if (clk) begin
          if (~stb)
            clkout <= 1;
        end else
          clkout <= 0;
    end

endmodule

