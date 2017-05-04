module A2D_intf_tb();
reg clk, rst_n, strt_cnv;
reg [2:0] chnnl;
wire [11:0] res;
reg [11:0] res_flipped; 
wire cnv_cmplt, a2d_SS_n, SCLK, MOSI, MISO;

A2D_intf iCONTROL(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),.cnv_cmplt(cnv_cmplt),.chnnl(chnnl),.res(res),.a2d_SS_n(a2d_SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
ADC128S_2cycle iADC(.clk(clk),.rst_n(rst_n),.SS_n(a2d_SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI));

assign res_flipped = ~res;

initial begin
rst_n = 0;
strt_cnv = 0;
chnnl = 3'b010;

#5 rst_n = 1;
strt_cnv = 1;
#10 strt_cnv = 0;

#12000 chnnl = 3'b011;
strt_cnv = 1;
#10 strt_cnv = 0;

#12000 $stop;


end

initial begin 
clk = 1;
forever #5 clk = ~clk;
end

endmodule
