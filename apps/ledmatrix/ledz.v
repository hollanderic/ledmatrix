
`define ROWLEN 64

//Generate 30MHz clock to drive spi block
//  (12MHz isn't sufficient to keep up with faster sclk speeds)
module clock30gen(input clk, output clkout);
  SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .PLLOUT_SELECT("GENCLK"),
    .DIVR(4'b0000),
    .DIVF(7'b1001111),
    .DIVQ(3'b101),
    .FILTER_RANGE(3'b001)
  ) uut (
    .RESETB(1'b1),
    .BYPASS(1'b0),
    .REFERENCECLK(clk),
    .PLLOUTCORE(clkout)
  );
endmodule


//Dual port memory module
module mem(input clk, wen, input [9:0] wr_addr, input [9:0] rd_addr, input [15:0] wdata, output reg [15:0] rdata);
  reg [15:0] mem [0:1023];
  //Put s test pattern in memory so we know it is running on startup
  initial mem[0] = 16'h001f;
  initial mem[1] = 16'h000f;
  initial mem[2] = 16'h000e;
  initial mem[3] = 16'h0003;
  initial mem[4] = 16'h0001;

  initial mem[`ROWLEN]   = 16'hf800;
  initial mem[`ROWLEN+1] = 16'he800;
  initial mem[`ROWLEN+2] = 16'h3800;
  initial mem[`ROWLEN+3] = 16'h1800;
  initial mem[`ROWLEN+4] = 16'h0800;
  always @(posedge clk) begin
        if (wen) mem[wr_addr] <= wdata;
        rdata <= mem[rd_addr];
  end
endmodule


//Decode 16-bit word into rgb components and drive serial line accordingly
//  bitcounter is used to determine if the pixel should be on for this refresh
//   this is used to provide 1/(max(bitcounter)) levels of brightness per color
module rgb16_decode(input sysclk, input bitclk, input [6:0] bitcounter,
                    input [15:0] data, input [5:0] duty_counter,
                    output red, output green, output blue
                    );
    always @ (negedge sysclk) begin
        if (bitclk)
            if (bitcounter < `ROWLEN) begin
              //Assuming bytes came from a little endian source
                if (data[7:3] > duty_counter)
                    red <= 1;
                else
                    red <= 0;

                if ({ data[2:0], data[15:13]} > duty_counter)
                    green <= 1;
                else
                    green <= 0;

                if (data[12:8] > duty_counter)
                    blue <= 1;
                else
                    blue <= 0;
            end
    end
endmodule

module spi_slave(input mod_clk,                       // clock for module logic
                 input sclk, input mosi, input cs,    // spi signals
                 output [10:0] wr_addr, output wren, output [15:0] data,
                 output [3:0] test);

  reg [3:0] bitcount;
  reg [15:0] datareg;
  reg [10:0] addr;
  reg word_ready = 0;
  reg [3:0] data_valid;

  initial data_valid = 0;

  assign test[0] = mod_clk;
  assign test[1] = word_ready;
  assign test[3] = wren;

  //Since spi clk is not syncronous with out clock, need to sample and
  //sync the signals into our clock domain.
  reg [2:0] sclk_r;  always @(posedge mod_clk) sclk_r <= {sclk_r[1:0], sclk};
  wire sclk_r_posedge = (sclk_r[2:1]==2'b01);
  wire sclk_r_negedge = (sclk_r[2:1]==2'b10);

  reg [2:0] cs_r;  always @(posedge mod_clk) cs_r <= {cs_r[1:0], cs};
  wire cs_r_state = cs_r[1];
  wire start_frame = (cs_r[2:1]==2'b01);
  wire end_frame = (cs_r[2:1]==2'b10);

  reg [1:0] mosi_r;  always @(posedge mod_clk) mosi_r <= {mosi_r[0], mosi};
  wire mosi_r_state = mosi_r[1];

  always @(posedge mod_clk)
  begin
    if(~cs_r_state)
      bitcount <= 4'b0000;
    else begin
      if(sclk_r_posedge)
      begin
        test[2] <= 1;
        bitcount <= bitcount + 4'b0001;
        datareg <= {datareg[14:0], mosi_r_state};
      end
      if(sclk_r_negedge) begin
        test[2] <= 0;
      end
    end
  end

  always @(posedge mod_clk) word_ready <= cs_r_state && sclk_r_posedge && (bitcount==4'b1111);

  always @(posedge mod_clk) begin
    if  (word_ready ) begin
      wr_addr <= addr;
      data <= datareg;
      data_valid <= 8;
    end

    if (data_valid) begin
    // Assuming mod_clk is faster than base clock of who we are feeding data to,
    //  need to stretch out the wren pulse to make sure it catches an edge
      if (data_valid == 8) begin
        wren <=1;
        addr <= addr + 1;
      end
      if (data_valid == 1) begin
        wren <=0;
      end
      data_valid <= data_valid - 1;
    end
    if (end_frame)
        addr <= 0;
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

    wire [3:0] test;
    assign test[0] = test0;
    assign test[1] = test1;
    assign test[2] = test2;
    assign test[3] = test3;

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

    wire wren0 = wren & ~wr_addr[10];
    wire wren1 = wren & wr_addr[10];

    assign read_abus = {rowsel[3:0] + 1, counter[5:0]};

    wire spiclk;
    clock30gen spiclk0(clk, spiclk);
// spi slave module (input only)
    spi_slave spi0(spiclk, spi_sclk, spi_mosi, spi_cs,
                   wr_addr, wren, wr_data, test);

    // Memory bank for low half of display
    mem mem_0(clk, wren0, wr_addr[9:0], read_abus, wr_data, dbus0);
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
            if (counter == `ROWLEN) begin
                oe <= 1;
            end
            if (counter == (`ROWLEN + 1))
                stb <= 1;
            if (counter == (`ROWLEN + 2))
                stb <= 0;
            if (counter == (`ROWLEN + 3))
                rowsel <= rowsel + 1;
            if (counter == (`ROWLEN + 4)) begin
                oe <= 0;
                counter <= 0;
            end
        end else begin
            if (counter == `ROWLEN)
                oe <= 1;
            counter <= counter + 1;
        end
    end

// This is where we need to update out data values
    rgb16_decode rgb0(clk, bit_clock, counter, dbus0, scan_counter,
                      redout0, greenout0, blueout0);
    rgb16_decode rgb1(clk, bit_clock, counter, dbus1, scan_counter,
                      redout1, greenout1, blueout1);

// This is where we update the clock pin
//  don't make a positive edge during the latch period
    always @ (bit_clock) begin
        if (bit_clock) begin
          if (counter < (`ROWLEN + 1))
            clkout <= 1;
        end else
          clkout <= 0;
    end

endmodule

