// blinky.v
// Blink the green LED with frequency 12e6/2^24 = 0.7Hz approx.


`define ROWLEN 64

module mem(input clk, wen, input [9:0] addr, input [15:0] wdata, output reg [15:0] rdata);
  reg [15:0] mem [0:1023];
  initial mem[0] = 255;
  initial mem[22] = 1;
  initial mem[7] = 1;
  initial mem[1000] = 2;
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

    reg clk2;

    initial rowsel = 4'hf;
    initial stb = 0;

    reg[4:0] scan_counter;
    reg[7:0] counter;

    initial counter = 7'h0;

    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];

    wire [15:0] dbus;
    wire [10:0] abus;

    assign abus = {rowsel, counter[5:0]};

    mem mem_0(clk, 0, abus, 16'h0000, dbus);

    always @(rowsel) begin
        if (rowsel == 0)
         scan_counter <= scan_counter + 1;
    end

    always @(posedge clk) begin
        clk2 <= clk2 + 1;
    end


    always @(negedge clk) begin
        if (clk2 == 0) begin
            if (counter == 64) begin
                stb <= 1;
                oe <= 1;
            end else begin
                stb <= 0;
                oe <= 0;
            end
            if (counter > 64) begin
                rowsel <= rowsel + 1;
                counter <= 0;
            end
        end else
            if (counter == 64)
                oe <= 1;
    end



// This is where we need to update out data values

    always @ (negedge clk) begin
        if (clk2)
            if (counter < 64) begin

                if (dbus[15:11]  > scan_counter)
                    redout0 <= 1;
                else
                    redout0 <= 0;

                if (dbus[10:5]  > scan_counter)
                    greenout0 <= 1;
                else
                    greenout0 <= 0;
                if (dbus[4:0]  > scan_counter)
                    blueout0 <= 1;
                else
                    blueout0 <= 0;


            end
    end



// This is where we update the clock pin
//  don't make a positive edge during the latch period

    always @ (clk2) begin
        if (clk2) begin
          if (~stb)
            clkout <= 1;
        end else
          clkout <= 0;
    end

endmodule

