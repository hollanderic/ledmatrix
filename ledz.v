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
/*
  initial mem[128] = 16'hf800;
  initial mem[128+1] = 16'h4803;

  initial mem[192+1] = 16'h6804;

  initial mem[256 +1] = 16'hf800;
  initial mem[256+64+1] = 16'ha806;
  initial mem[256+128+1] = 16'hc807;
  initial mem[256+192+1] = 16'hf008;
*/

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
    output tout0,
    );

    reg [2:0] clkp;

    reg [63:0] pix [0:15];
    reg [3:0] rowsel;
    wire [3:0] rows;
    assign rows = {rowsel};

    reg clk2;

    assign tout0 = rowsel[3];

    initial rowsel = 4'hf;
    initial stb = 0;

    reg[5:0] scan_counter;
    reg[6:0] counter;

    initial counter = 7'h0;

    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];


    wire [15:0] dbus;
    wire [9:0] abus;

    assign abus = {rowsel[3:0] + 1, counter[5:0]};

    wire [4:0] rbus;
    assign rbus = {dbus[15:11]};

    mem mem_0(clk, 0, abus, 16'h0000, dbus);

    wire [5:0] scanner;
    assign scanner = {scan_counter[5:0]};

    always @(posedge clk) begin
        clk2 <= clk2 + 1;
    end

    always @(negedge sel_d) begin
            scan_counter <= scan_counter +1;
    end

    always @(negedge clk) begin
        if (clk2 == 0) begin
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
        if (clk2)
            if (counter < 64) begin
                if (counter[0])
                    redout0 <= 1;
                else
                if (counter[6:1] > scanner)
                    redout0 <= 1;
                else
                    redout0 <= 0;

                if (dbus[10:5]  > scan_counter)
                    greenout0 <= 1;
                else
                    greenout0 <= 0;

                if (dbus[4:0]  > scanner)
                    blueout0 <= 1;
                else
                    blueout0 <= 0;


            end
    end



// This is where we update the clock pin
//  don't make a positive edge during the latch period

    always @ (clk2) begin
        if (clk2) begin
          if (counter < 65)
            clkout <= 1;
        end else
          clkout <= 0;
    end

endmodule

