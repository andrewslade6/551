module UART_rcv_tb();

reg[7:0] tx_data;
//genvar i;
reg[3:0] i;
reg clk, rst_n, RX, rx_rdy_clr, rx_rdy;
wire[7:0] rx_data;

UART_rcv iDUT(RX, clk, rst_n, rx_rdy_clr, rx_data, rx_rdy);

initial begin
rst_n = 0;
clk = 1;
RX = 1;
rx_rdy_clr = 0;
tx_data = 8'b1010_1010;
#5 rst_n = 1;
RX = 0;
// start transmition by setting RX low
for(i = 0; i < 4'd8; i++) begin
	#(2604*10) RX = tx_data[0];
	tx_data = {1'b0,tx_data[7:1]};
end
// pull RX high after byte has been transmitted
#(2604*10) RX = 1;
#(2604*10*2)


tx_data = 8'b1110_1011;
RX = 0;
// start transmition by setting RX low
for(i = 0; i < 4'd8; i++) begin
	#(2604*10) RX = tx_data[0];
	tx_data = {1'b0,tx_data[7:1]};
end
// pull RX high after byte has been transmitted
#(2604*10) RX = 1;
#(2604*10*2) $stop;

end


always #5 clk = ~clk;

endmodule
