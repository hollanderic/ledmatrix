// blinky.v
// Blink the green LED with frequency 12e6/2^24 = 0.7Hz approx.


`define ROWLEN 64

module mem(input clk, wen, input [9:0] addr, input [15:0] wdata, output reg [15:0] rdata);
  reg [15:0] mem [0:1023];
  initial mem[0] = 16'h001f;
  initial mem[1] = 16'h000f;
  initial mem[2] = 16'h000e;
  initial mem[3] = 16'h0003;
  initial mem[4] = 16'h0001;

  initial mem[64]   = 16'hf800;
  initial mem[64+1] = 16'he800;
  initial mem[64+2] = 16'h3800;
  initial mem[64+3] = 16'h1800;
  initial mem[64+4] = 16'h0800;

  always @(posedge clk) begin
        if (wen) mem[addr] <= wdata;
        rdata <= mem[addr];
  end
endmodule

module rgb16_decode(input sysclk, input bitclk, input [6:0] bitcounter,
                    input [15:0] data, input [5:0] duty_counter,
                    output red, output green, output blue
                    );

    always @ (negedge sysclk) begin
        if (bitclk)
            if (bitcounter < 64) begin
                if (data[15:11] > duty_counter)
                    red <= 1;
                else
                    red <= 0;
                if (data[10:5] > duty_counter)
                    green <= 1;
                else
                    green <= 0;
                if (data[4:0] > duty_counter)
                    blue <= 1;
                else
                    blue <= 0;
            end
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
    output tout0,
    );

    reg [3:0] rowsel;
    reg       bit_clock;
    reg [5:0] scan_counter;
    reg [6:0] counter;

    assign tout0 = rowsel[3];  //tout0 is debug trigger output

    initial stb = 0;
    initial counter = 7'h0;

    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];

    wire [15:0] dbus0;
    wire [9:0]  abus;

    assign abus = {rowsel[3:0] + 1, counter[5:0]};

    // Memory bank for low half of display
    mem mem_0(clk, 0, abus, 16'h0000, dbus0);
    // Memory bank for upper half of display
    mem mem_1(clk, 0, abus, 16'h0000, dbus1);


// Divide input clock by 2 to get our bit clock
    always @(posedge clk) begin
        bit_clock <= bit_clock + 1;
    end

// Increment the scan counter each time a new scan starts
    always @(negedge sel_d) begin
            scan_counter <= scan_counter +1;
    end

    always @(negedge clk) begin
        if (bit_clock == 0) begin
            if (counter == 64) begin
                oe <= 1;
            end
            if (counter == 65)
                stb <= 1;
            if (counter == 66)
                stb <= 0;
            if (counter == 67)
                rowsel <= rowsel + 1;
            if (counter == 68) begin
                oe <= 0;
                counter <= 0;
            end
        end else begin
            if (counter == 64)
                oe <= 1;
            counter <= counter + 1;
        end
    end

// This is where we need to update out data values

    always @ (negedge clk) begin
        if (bit_clock)
            if (counter < 64) begin
                if (counter[0])
                    redout0 <= 1;
                else
                if (counter[6:1] > scan_counter)
                    redout0 <= 1;
                else
                    redout0 <= 0;

                if (dbus0[10:5]  > scan_counter)
                    greenout0 <= 1;
                else
                    greenout0 <= 0;

                if (dbus0[4:0]  > scan_counter)
                    blueout0 <= 1;
                else
                    blueout0 <= 0;
            end
    end

// This is where we update the clock pin
//  don't make a positive edge during the latch period

    always @ (bit_clock) begin
        if (bit_clock) begin
          if (counter < 65)
            clkout <= 1;
        end else
          clkout <= 0;
    end

endmodule

