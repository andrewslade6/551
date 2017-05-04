// ALU for line tracer ** HW3 redux
module alu(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl, 
			src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

input [15:0] Accum, Pcomp;
input [13:0] Pterm;
input [11:0] Icomp, Iterm, Fwd, A2D_res, Error, Intgrl;
input [2:0] src0sel, src1sel;
input multiply, sub, mult2, mult4, saturate;

output [15:0] dst;

wire [15:0] src0, src1, 
			pre_src0, pre_src1,
			scaled_src0,
			add_res, sat_wire;
wire signed [14:0] signed_source0, signed_source1;
wire signed [15:0] mult_sat;
wire signed [29:0] mult_wire;

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

// code selection mux to select proper signals for the 
// adder's inputs.
assign pre_src0 = (src0sel == A2D2Src0) ? {4'b0000,A2D_res} :
				  (src0sel == Intgrl2Src0) ? {{4{Intgrl[11]}},Intgrl} :
				  (src0sel == Icomp2Src0) ? {{4{Icomp[11]}},Icomp} :
				  (src0sel == Pcomp2Src0) ? Pcomp :
				  {src0sel == Pterm2Src0} ? {2'b00,Pterm} :
				  16'hxxxx; // default to all x's if we get an invalid opcode
		
assign pre_src1 = (src1sel == Accum2Src1) ? Accum :
				(src1sel == Iterm2Src1) ? {4'b0000,Iterm} :
				(src1sel == Err2Src1) ? {{4{Error[11]}},Error} :
				(src1sel == ErrDiv22Src1) ? {{8{Error[11]}},Error[11:4]} :
				(src1sel == Fwd2Src1) ? {4'b0000,Fwd} :
				16'hxxxx; // default to all x's if we get an invalid opcode

				
// implement multipication by 2 or 4						
assign scaled_src0 = (mult2) ? {pre_src0[14:0],1'b0} :
					 (mult4) ? {pre_src0[13:0],2'b00} :
					 pre_src0;

// implement subraction functionality by conditionally flipping bits
assign src0	= (sub) ? ~scaled_src0 : scaled_src0;
				 
// add src0 and src1, if sub = 1 the carry in will implement 2's comp subtraction
assign	src1 = pre_src1;
assign 	add_res	= src0 + src1 + sub;		 

// implement 12 bit signed saturation of sum					 
assign sat_wire = (saturate && (add_res[15] == 0) && add_res[15:11] > 5'b00000) ? 16'h07FF :
				  (saturate && (add_res[15] == 1) && add_res[15:11] < 5'b11111) ? 16'hF802 :
				   add_res[15:0];  			

// implement 15 x 15 signed multiply
assign signed_source0 = src0[14:0];
assign signed_source1 = src1[14:0];
assign mult_wire = signed_source0 * signed_source1;
// saturate result
/*
assign mult_sat = ((mult_wire[29] == 0) && mult_wire[28:26] != 3'b000) ? 16'h3FFF :
		 ((mult_wire[29] == 1) && mult_wire[28:26] != 3'b111) ? 16'hC000 :
			mult_wire[27:12]; */	 
assign mult_sat = (mult_wire[29]) ? ((&mult_wire[28:26]) ? mult_wire[27:12] : 16'hC000) :
									 ((mult_wire[28:26]) ? 16'h3FFF : 
									   mult_wire[27:12]);
			
// assing output of ALU to be mux of addition side or multiplication side 
assign dst = (multiply) ? mult_sat : sat_wire;

endmodule
