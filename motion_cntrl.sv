module motion_cntrl(clk, rst_n, go, start_conv, chnnl, cnv_cmplt, A2D_res,
					IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht);
//////// MOTION CONTROL MODULE IO ////////////
input clk, rst_n, go, cnv_cmplt, A2D_res;
output start_conv, chnnl, IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht;

wire go, cnv_cmplt;
wire[11:0] A2D_res;

reg IR_in_en,
	IR_mid_en,
	IR_out_en,
	start_conv;
	
reg[2:0] chnnl;


reg[7:0] LEDs;
reg[11:0] lft_reg, rht_reg;
wire[10:0] lft, rht;




///////// ALU IO ///////////////////////////
reg[15:0] Accum, Pcomp;
reg[11:0] Error, Intgrl, Icomp, Fwd;
reg[2:0] src0sel, src1sel;
reg multiply, sub, mult2, mult4, saturate;
wire[15:0] dst;
wire[13:0] Pterm;
wire[11:0] Iterm;

// data select names for src1sel
localparam Accum2Src1 = 3'b000;
localparam Iterm2Src1 = 3'b001;
localparam Err2Src1 = 3'b010;
localparam ErrDiv22Src1 = 3'b011;
localparam Fwd2Src1 = 	3'b100;

// data select names for src0sel
localparam A2D2Src0 = 3'b000;
localparam Intgrl2Src0 = 3'b001;
localparam Icomp2Src0 = 3'b010;
localparam Pcomp2Src0 = 3'b011;
localparam Pterm2Src0 = 3'b100;

// create ALU
alu	ALU(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl, 
		src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

assign Pterm = 14'h3680;
assign Iterm = 12'h500;
		
/////////// PWM 8 bit////////////////////////////
wire PWM_sig_8;
pwm_8bit PWM8(clk, rst_n, PWM_sig_8);		

///////// Motion Control State Machine Control Signals ////////
reg dst2Accum, 
	dst2Err, 
	dst2Int, 
	dst2Icmp, 
	dst2Pcmp, 
	dst2lft, 
	dst2rht,
	clr_accum_cnt,
	clr_chnnl_cnt,
	inc_chnnl_cnt,
	set_chnnl,
	store_IR_in_rht,
	inc_PI_cycle_cnt;
	
reg[2:0] PI_calc_cnt;
reg[1:0] PI_cycle_cnt;
	
/////////////////////////////////////////////////////////////

typedef enum reg[2:0] {IDLE, TMR_WAIT_4096, WAIT_A2D_R, TMR_WAIT_32, WAIT_A2D_L, PI_MATH } state_t;
state_t state, next_state;


// Internal Sigs and Regs
reg[2:0] chnnl_cnt;		// counts to 6 for each IR channel
reg[11:0] timer_4096_cnt; 
reg[4:0] timer_32_cnt;
reg timer_32_en, timer_4096_en;

//////////////////////////////////////////////////////////
///////////// Motion Control Data Registers //////////////
//////////////////////////////////////////////////////////

// Accum Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Accum <= 16'h0000;
	else if(clr_accum_cnt)
		Accum <= 16'h0000;
	else if(store_IR_in_rht)
		Accum <= {4'b0000, A2D_res};
	else if(dst2Accum)
		Accum <= dst;
end

// Pcomp Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Pcomp <= 16'h0000;
	else if(dst2Pcmp)
		Pcomp <= dst;
end

// Error Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Error <= 12'h000;
	else if(dst2Err)
		Error <= dst[11:0];
end

assign LEDs = Error[11:4];

// Intgrl Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Intgrl <= 12'h000;
	else if(dst2Int)
		Intgrl <= dst[11:0];
end

// Icomp Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Icomp <= 12'h000;
	else if(dst2Icmp)
		Icomp <= dst[11:0];
end

// Fwd Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		Fwd <= 12'h000;
	else if(~go)
		Fwd <= 12'h000;
	else if(dst2Int & ~&Fwd[10:8])		//  <-------- not sure I understand this line
		Fwd <= Fwd + 1'b1;
end

// lft Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		lft_reg <= 12'h000;
	else if(~go)
		lft_reg <= 12'h000;
	else if(dst2lft)
		lft_reg <= dst[11:0];
end

// rht Register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		rht_reg <= 12'h000;
	else if(~go)
		rht_reg <= 12'h000;
	else if(dst2rht)
		rht_reg <= dst[11:0];
end

// take only top 11 bits for motor drive
assign lft = lft_reg[11:1];
assign rht = rht_reg[11:1];

///////////////////////////////////////////////////
///////////////////////////////////////////////////

// channel counter to count to 6
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		chnnl_cnt <= 3'b0;
	else if(clr_chnnl_cnt)
		chnnl_cnt <= 3'b0;
	else if(inc_chnnl_cnt)
		chnnl_cnt <= chnnl_cnt + 1;
end

// 4096 timer
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		timer_4096_cnt <= 12'h000;
	else if(!timer_4096_en)
		timer_4096_cnt <= 12'h000;
	else
		timer_4096_cnt <= timer_4096_cnt + 1;
end

// 32 timer
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		timer_32_cnt <= 5'b00000;
	else if(!timer_32_en)
		timer_32_cnt <= 5'b00000;
	else
		timer_32_cnt <= timer_32_cnt + 1;
end

// channel for ADC
/*
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		chnnl <= 3'b001;
	else if(cnv_cmplt) begin
			if(chnnl_cnt == 0)
				chnnl <= 3'd1;
			else if (chnnl_cnt == 1)
				chnnl <= 3'd0;
			else if (chnnl_cnt == 2)
				chnnl <= 3'd4;
			else if (chnnl_cnt == 3)
				chnnl <= 3'd2;
			else if (chnnl_cnt == 4)
				chnnl <= 3'd3;
			else if (chnnl_cnt == 5)
				chnnl <= 3'd7;
	end
end
*/

assign chnnl = (chnnl_cnt == 0) ? 3'd1 :
	(chnnl_cnt == 1) ? 3'd0 :
	(chnnl_cnt == 2) ? 3'd4 :
	(chnnl_cnt == 3) ? 3'd2 :
	(chnnl_cnt == 4) ? 3'd3 :
	(chnnl_cnt == 5) ? 3'd7 :
	3'bzzz;



reg[2:0] encoder_out;
// IR sensor switching logic 
always_comb begin
	if(chnnl_cnt == 3'd0 || chnnl_cnt == 3'd1)
		encoder_out = {PWM_sig_8, 2'b00};
	else if(chnnl_cnt == 3'd2 || chnnl_cnt == 3'd3)
		encoder_out = {1'b0, PWM_sig_8, 1'b0};
	else if(chnnl_cnt == 3'd4 || chnnl_cnt == 3'd5)
		encoder_out = {2'b00, PWM_sig_8};
	else
		encoder_out = 3'b000;
end
// assign enables to bits of encoder out
assign IR_in_en = encoder_out[2];
assign IR_mid_en = encoder_out[1];
assign IR_out_en = encoder_out[0];


// PI calculation counter
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		PI_calc_cnt <= 3'b000;
	else if(state == PI_MATH)
		PI_calc_cnt <= PI_calc_cnt + 1;
	else
		PI_calc_cnt <= 3'b000;
end

// PI cycle count to integrate only 4 PI cycles
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		PI_cycle_cnt <= 2'b00;
	else if(inc_PI_cycle_cnt)
		PI_cycle_cnt <= PI_cycle_cnt + 1;
end


// state flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;
end

// state combinational logic
always_comb begin
	// default next state
	next_state = IDLE;
	// set default outputs of all control signals
	dst2Accum = 0;
	dst2Err = 0;
	dst2Int = 0; 
	dst2Icmp = 0;
	dst2Pcmp = 0;
	dst2lft = 0;
	dst2rht = 0;
	store_IR_in_rht = 0;
	inc_PI_cycle_cnt = 0;
	
	// counter controls
	clr_chnnl_cnt = 0;
	clr_accum_cnt = 0;
	timer_4096_en = 0;
	timer_32_en = 0;
	inc_chnnl_cnt = 0;
	start_conv = 0;
	//set_chnnl = 0;
	
	// ALU control signals
	src0sel = A2D2Src0;
	src1sel = Accum2Src1;
	mult2 = 0;
	mult4 = 0;
	sub = 0;
	multiply = 0;
	saturate = 0;
	
	case(state)
		IDLE : begin 
				if(go) begin
					next_state = TMR_WAIT_4096;
					clr_chnnl_cnt = 1;
					clr_accum_cnt = 1;
					timer_4096_en = 1;
				end
			end
		TMR_WAIT_4096 : begin
						timer_4096_en = 1;
						next_state = TMR_WAIT_4096;
						if(timer_4096_cnt == 12'd4095) begin
							next_state = WAIT_A2D_R;
							start_conv = 1;
							//set_chnnl = 1;
						end
					end
		WAIT_A2D_R : begin
					next_state = WAIT_A2D_R;
					if(cnv_cmplt) begin
					next_state = TMR_WAIT_32;
						// determine what calculation based on chnnl_cnt
						case(chnnl_cnt)
							0 : store_IR_in_rht = 1;
							2 : begin
									src0sel = A2D2Src0;
									src1sel = Accum2Src1;
									mult2 = 1;
									dst2Accum = 1;
								end
							4 : begin
									src0sel = A2D2Src0;
									src1sel = Accum2Src1;
									mult4 = 1;
									dst2Accum = 1;
								end
						endcase
						inc_chnnl_cnt = 1;
					end
				end
		TMR_WAIT_32 : begin
						timer_32_en = 1;
						next_state = TMR_WAIT_32;
						if(timer_32_cnt == 5'd31) begin
							next_state = WAIT_A2D_L;
							start_conv = 1;
							//set_chnnl = 1;
						end
					end
		WAIT_A2D_L : begin
					next_state = WAIT_A2D_L;

					if(cnv_cmplt) begin
					next_state = TMR_WAIT_4096;
					
						// determine what calculation based on chnnl_cnt
						case(chnnl_cnt)
							1 : begin
									src0sel = A2D2Src0;
									src1sel = Accum2Src1;
									dst2Accum = 1;
									sub = 1;
								end
							3 : begin
									src0sel = A2D2Src0;
									src1sel = Accum2Src1;
									mult2 = 1;
									dst2Accum = 1;
									sub = 1;
								end
							5 : begin
									src0sel = A2D2Src0;
									src1sel = Accum2Src1;
									mult4 = 1;
									saturate = 1;
									dst2Err = 1;
									sub = 1;
								end
						endcase
						inc_chnnl_cnt = 1;
						// if we've sampled all 6 sensors, go to PI_MATH state
						if(chnnl_cnt == 3'd5) begin
							next_state = PI_MATH;
						end
					end
				end
		PI_MATH : begin
					next_state = PI_MATH;
					case(PI_calc_cnt)
						0 : begin
								src0sel = Intgrl2Src0;
								src1sel = ErrDiv22Src1;
								saturate = 1;
								if(PI_cycle_cnt == 2'b11)
									dst2Int = 1;
								else
									dst2Int = 0;
							end
						1 : begin
								src0sel = Icomp2Src0;
								src1sel = Iterm2Src1;
								multiply = 1;
								dst2Icmp = 1;
							end
						2 : begin
								src0sel = Pterm2Src0;
								src1sel = Err2Src1;
								multiply = 1;
								dst2Pcmp = 1;
							end
						3 : begin
								src0sel = Pcomp2Src0;
								src1sel = Fwd2Src1;
								dst2Accum = 1;
								sub = 1;
							end
						4 : begin
								src0sel = Icomp2Src0;
								src1sel = Accum2Src1;
								saturate = 1;
								dst2rht = 1;
								sub = 1;
							end
						5 : begin
								src0sel = Pcomp2Src0;
								src1sel = Fwd2Src1;
								dst2Accum = 1;
							end
						6 : begin
								src0sel = Icomp2Src0;
								src1sel = Accum2Src1;
								saturate = 1;
								dst2lft = 1;
							end
						7 : begin
								inc_PI_cycle_cnt = 1;
								next_state = IDLE;
							end
					endcase
				end
	
	endcase
end


////////////////////////////////////////////
/// JUST FOR TESTING /////
reg[7:0] in_PI_math;

always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		in_PI_math <= 8'h00;
	else if((next_state == PI_MATH) && (state != PI_MATH))
		in_PI_math <= in_PI_math + 1;
end
////////////////////////////////////////////


endmodule