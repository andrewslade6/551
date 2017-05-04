module motor_cntrl(clk, rst_n, lft, rht, fwd_lft, rev_lft, fwd_rht, rev_rht);

input clk, rst_n;

input[10:0] lft, rht;
output reg fwd_lft, rev_lft, fwd_rht, rev_rht;
wire leftPWM, rightPWM;
reg [9:0] dutyLEFT, dutyRIGHT;
reg brake_lft_n, brake_rht_n;
reg [10:0] twosLEFT, twosRIGHT;

//instantiate pwm generators, one for each side
pwm LEFTWAVE(clk, rst_n, dutyLEFT, leftPWM);
pwm RIGHTWAVE(clk, rst_n, dutyRIGHT, rightPWM);


//left side output logic
always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    fwd_lft <= 1'b1;       //brake when reset
    rev_lft <= 1'b1;
    end
	
  else if(!brake_lft_n) begin
    fwd_lft <= 1'b1;       //brake when brake is on
    rev_lft <= 1'b1;
  end  
  else if(!lft[10]) begin
    fwd_lft <= leftPWM;    //forward operation, 11th bit of lft is 0
    rev_lft <= 1'b0;
  end
  else begin
    fwd_lft <= 1'b0;       //reverse operation
    rev_lft <= leftPWM;
  end
end
//right side output logic
always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    fwd_rht <= 1'b1;       //brake when reset
    rev_rht <= 1'b1;
    end
  else if(!brake_rht_n) begin
    fwd_rht <= 1'b1;       //brake when brake is on
    rev_rht <= 1'b1;
  end
  else if(!rht[10]) begin
    fwd_rht <= rightPWM;    //forward operation
    rev_rht <= 1'b0;
  end
  else begin
    fwd_rht <= 1'b0;       //reverse operation
    rev_rht <= rightPWM;
  end
end


//if all values in input are zero, this will activate brake behavior
assign brake_lft_n = | lft;
assign brake_rht_n = | rht;


//2's complements for use with absolute value calculation
assign twosLEFT  = ~lft + 1;
assign twosRIGHT = ~rht + 1;

//10 bit magnitudes for PWM module
assign dutyLEFT = (lft[10])  ? {1'b0, twosLEFT[8:0]} :
								{1'b0, lft[8:0]};
assign dutyRIGHT = (rht[10]) ? {1'b0, twosRIGHT[8:0]}:
								{1'b0, rht[8:0]};


endmodule
