// blinky.v
// Blink the green LED with frequency 12e6/2^24 = 0.7Hz approx.


`define ROWLEN 64

module mem(input clk, wen, input [9:0] wr_addr, input [9:0] addr, input [15:0] wdata, output reg [15:0] rdata);
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
        if (wen) mem[wr_addr] <= wdata;
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

module junk(input sysclk, output stro);
begin
  reg temp;
  initial temp = 0;
  always @(posedge sysclk) begin
    temp<=temp +1;
    stro<=temp;
  end
end
endmodule

module spi_slave(input syclk, input sclk, input mosi, input cs,
                 output [10:0] wr_addr, output wren, output [15:0] data, output test);

  reg [3:0] bitcount;
  reg [15:0] datareg;
  reg [10:0] addr;
  reg word_ready;
  reg fsync;
  reg [2:0] data_valid;

  initial fsync = 0;
  initial data_valid = 0;



  always @(cs) begin
    if (cs)
      fsync <= 0;
    else
      fsync <= 1;
  end


  always @(posedge sclk) begin
      if (cs) begin
        if (bitcount == 4'b1111) begin
          word_ready <= 1;
          addr <= addr + 1;
        end else begin
          word_ready <= 0;
        end
        datareg <= {datareg[14:0], mosi};
        bitcount <= bitcount + 1;
        test <= mosi;
      end else begin
        addr <= 0;
        bitcount <= 0;
        word_ready <= 0;
      end
  end

  always @(posedge syclk) begin
    if (word_ready) begin
      wr_addr <= addr - 1;
      data <= datareg;
      data_valid <= 2;
      wren <= 1;
    end else if (data_valid) begin
      data_valid <= data_valid - 1;
    end else begin
      wren <= 0;
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
    output redout1,
    output blueout1,
    output greenout1,

    input spi_cs,
    input spi_sclk,
    input spi_mosi,
    output test0,
    output test1,
    output test2,
    output test3
    );


    reg [3:0] rowsel;
    reg       bit_clock;
    reg [5:0] scan_counter;
    reg [6:0] counter;

    initial stb = 0;
    initial counter = 7'h0;



    assign sel_a = rowsel[0];
    assign sel_b = rowsel[1];
    assign sel_c = rowsel[2];
    assign sel_d = rowsel[3];

    wire [15:0] dbus0;
    wire [15:0] dbus1;

    wire [9:0]  read_abus;

    wire wren;
    wire [10:0] wr_addr;
    wire [15:0] wr_data;

    wire wren1 = test1 & wr_addr[10];

    assign read_abus = {rowsel[3:0] + 1, counter[5:0]};

    // Memory bank for low half of display
    mem mem_0(clk, test1, wr_addr[9:0], read_abus, wr_data, dbus0);
    // Memory bank for upper half of display
    mem mem_1(clk, wren1, wr_addr[9:0], read_abus, wr_data, dbus1);


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
    rgb16_decode rgb0(clk, bit_clock, counter, dbus0, scan_counter,
                      redout0, greenout0, blueout0);
    rgb16_decode rgb1(clk, bit_clock, counter, dbus1, scan_counter,
                      redout1, greenout1, blueout1);

//    always @( spi_cs) begin
//      if (spi_cs)
//        test0 <= 1;
//      else begin
//        test0 <= 0;
//      end
//    end



    spi_slave spi0(clk, spi_sclk, spi_mosi, spi_cs,
                   wr_addr, test1, wr_data, test0);

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

