// PWM generator for motor control
module pwm(clk, rst_n, duty, PWM_sig);

input duty, clk, rst_n;
output reg PWM_sig;

// counter
reg [9:0] cnt;

wire [9:0] duty;
// intermediate signals as input to duty cycle ff
wire set, reset;

// start PWM signal high, deassert set if duty cycle is 0
assign set = ((cnt == 10'b1111111111) && (duty != 10'd0)) ? 1'b1 : 1'b0;
// once cnt reaches duty cycle, set the output low
assign reset = ((cnt == duty) || (duty == 10'd0)) ? 1'b1 : 1'b0;

// 10 bit counter for duty cycle
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt <= 10'b1111111111;	
	else
		cnt <= cnt + 1;
end

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

