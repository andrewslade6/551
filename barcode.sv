module barcode(clk, rst_n, BC, clr_ID_vld, ID_vld, ID);
input clk, rst_n, BC, clr_ID_vld;
output ID, ID_vld;

wire clk, rst_n, BC;
reg[7:0] ID;
reg ID_vld;

reg BC_FALL_EDGE; // flag when BC signal has a falling edge
reg BC_ff1, BC_synch; // double flopped BC signal for edge detection

reg [21:0] 	sample_period, 	// half of bar code bit period used to determine when to sample BC
			sample_counter; // counts up to sample_period to sample BC

reg [4:0] bit_cnt; // counts to 8 to determine which bit of the code we are on
reg all_bits_sampled;

typedef enum reg[1:0] {IDLE, GET_TIMING, READ_CODE} state_t;
state_t state, next_state;

// double flopped input
// create neg edge detection for BC signal
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		BC_ff1 <= 1'b1;
		BC_synch <= 1'b1;
		end
	else begin
		BC_ff1 <= BC;
		BC_synch <= BC_ff1;
		end
end

assign BC_FALL_EDGE = (~BC_ff1 & BC_synch); // neg edge detection for BC signal
assign BC_RISE_EDGE = (BC_ff1 & ~BC_synch); // pos edge detection for BC signal


// sample counter, resets on BC_FALL_EDGE
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		sample_counter <= 22'b0;
	else if(BC_FALL_EDGE)
		sample_counter <= 22'b0;
	else
		sample_counter <= sample_counter + 1;
end
	

// logic to determine sample_period from start bit	
// resets to 3FFFFF (maximum counter value)
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		sample_period <= 22'h3FFFFF;
	else if (BC_RISE_EDGE && (state == GET_TIMING))
		sample_period <= sample_counter;
end
	
assign sample_code = (sample_counter == sample_period) ? 1'b1 : 1'b0; // set flag when its time to sample the bar code

// ID shift register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		ID <= 8'h00;
	else if(sample_code)
		ID <= {ID[6:0], BC_synch};
end

// counts which bar code bit we are on
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		bit_cnt <= 4'b000;
	else if((state == GET_TIMING) || clr_ID_vld)
		bit_cnt <= 4'b000;
	else if (sample_code)
		bit_cnt <= bit_cnt + 1;
end

assign all_bits_sampled = (bit_cnt == 4'd8) ? 1'b1 : 1'b0; // set flag when all 8 bits have been sampled


// state ff
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;
end


// state combinational logic	

always_comb begin
	next_state = IDLE;
	
	case (state)
		IDLE : if(BC_FALL_EDGE)
					next_state = GET_TIMING;
		
		GET_TIMING : if(BC_FALL_EDGE)
						next_state = READ_CODE;
					 else
						next_state = GET_TIMING;
						
		READ_CODE : if(all_bits_sampled) begin
						next_state = IDLE;
					end
					else 
						next_state = READ_CODE;
	
	
	endcase;
end
	
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		ID_vld <= 1'b0;
	else if(clr_ID_vld)
		ID_vld <= 1'b0;
	else if(all_bits_sampled)
		ID_vld <= 1'b1;
end





endmodule
