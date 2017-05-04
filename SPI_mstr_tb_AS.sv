module SPI_mstr_tb_AS();

reg clk; 		// system clk
reg rst_n; 		// active low async reset
reg wrt; 		// set high when we need to start transmitting
reg [15:0] cmd;	// 16 bit data value to transmitting
reg done; 		// indicates SPI transaction has completed
reg [15:0] rd_data;	 	// data SPI master reads from slave
reg	SCLK;		// master slave clock
reg SS_n;		// active low slave select
reg MOSI;		// master output slave input
wire MISO;		// master input slave output
wire rdy;

SPI_master_AS iDUT(clk, rst_n, wrt, cmd, done, rd_data, SCLK, SS_n, MOSI, MISO);
ADC128S ADC(clk,rst_n,SS_n,SCLK,MISO,MOSI);

initial begin
clk = 1;
rst_n = 0;
wrt = 0;
cmd = 16'hA5A5;


#5 rst_n = 1;
wrt = 1;
#10 wrt = 0;
#6000

cmd = 16'hABBA;
wrt = 1;
#10 wrt = 0;
#6000
$stop;

end


always #5 clk = ~clk;
endmodule
