module barcode_tb();
reg clk, rst_n, clr_ID_vld, send;
reg[21:0] period;
reg[7:0] station_ID;
wire ID_vld, BC_done, BC;
wire[7:0] ID;

barcode_mimic BARCODE_GEN(clk,rst_n,period,send,station_ID,BC_done,BC);
barcode iDUT(clk, rst_n, BC, clr_ID_vld, ID_vld, ID);


initial begin
rst_n = 0;
station_ID = 8'b10101110;
period = 22'd1024;
send = 0;
clr_ID_vld = 0;
#5
rst_n = 1;
send = 1;
#40;
send = 0;


#(1024 * 10 *10)
clr_ID_vld = 1;
#10 clr_ID_vld = 0;
station_ID = 8'hA8;
period = 22'd513;
send = 1;
#10
send = 0;
#(1024 * 10 *10) $stop;



end



initial begin
clk = 1;
forever #5 clk = ~clk;
end

endmodule
