// blinky.v
// Blink the green LED with frequency 12e6/2^24 = 0.7Hz approx.


`define ROWLEN 64


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

/*
    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .PLLOUT_SELECT("GENCLK"),
        .DIVR(4'b0000),
        .DIVF(7'b1001111),
        .DIVQ(3'b100),
        .FILTER_RANGE(3'b001)
    ) uut (
        .LOCK(lock),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .REFERENCECLK(clk),
        .PLLOUTCORE(clkout)
    );
*/

    wire nclk = ~clk;

    reg [7:0] pix [0:511];
    reg [3:0] rowsel;
/*
    initial pix[0] = 64'hffffffffffffffff;
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
 //   initial pix[15] = 64'hffffffffffffffff;

*/
    initial rowsel = 4'hf;
    initial stb = 0;


    reg[7:0] counter;

    initial counter = 7'h0;

    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];


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

            if (pix[rowsel+1][3*(63-counter)])
                redout0 <= 1;
            else
                redout0 <= 0;
            if (pix[rowsel+1][3*(63-counter)+1])
                greenout0 <= 1;
            else
                greenout0 <= 0;
            if (pix[rowsel+1][3*(63-counter)+2])
                blueout0 <= 1;
            else
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

