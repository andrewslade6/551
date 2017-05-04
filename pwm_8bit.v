// PWM generator for motor control
module pwm_8bit(clk, rst_n, PWM_sig);

input clk, rst_n;
output reg PWM_sig;

// counter
reg [7:0] cnt;

// intermediate signals as input to duty cycle ff
wire set, reset;

// start PWM signal high, deassert set if duty cycle is 0
assign set = (cnt == 8'hFF) ? 1'b1 : 1'b0;
// once cnt reaches duty cycle, set the output low
assign reset = (cnt == 8'h8C) ? 1'b1 : 1'b0;

// 10 bit counter for duty cycle
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt <= 8'hFF;	
	else
		cnt <= cnt + 1;
end
// high or low logic
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		PWM_sig = 1'b1;
	else if(set)
		PWM_sig = 1'b1;
	else if(reset)
		PWM_sig = 1'b0;
	else
		PWM_sig = PWM_sig;
end
endmodule

