module UART_rcv(RX, clk, rst_n, rx_rdy_clr, rx_data, rx_rdy);
input clk, rst_n, RX, rx_rdy_clr;
output rx_data, rx_rdy;

wire clk, rst_n, rx_rdy_clr;
wire RX;

reg[3:0] shift_cnt;
reg[7:0] rx_data;
reg [11:0] baud_cnt;
reg half_baud_cnt,	// flag to set if baud counter is at half
	full_baud_cnt,  // flag to set if baud counter has expired
	start_rec, 		// set if the receive process should start
	sample_sig, 	// flag to set if the signal should be sampled
	RX_IN, 			// single bit register to hold the sampled RX signal
	right_shift, 	// flag to set if the rx_data register should be right shifted
	last_bit, // flag set when all 8 bits have been received
	rx_rdy,
	flop1,
	rx_synch;

//reg edge1, edge2;

typedef enum reg [1:0] {IDLE, RECEIVE, WAIT} state_t;
state_t state, next_state;

// baud rate counter, count up to 2604 when receiving data
// set to 0 on reset, at the start of transmit, or when count reaches baud rate
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		baud_cnt <= 0;
	else if(start_rec || full_baud_cnt)
			baud_cnt <= 0;
		else if(state != IDLE)
			baud_cnt <= baud_cnt+1;

// counts 9 shifts to determine if all data has been shifted in and shifts out start bit
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		shift_cnt <= 0;
	else if(start_rec)
			shift_cnt <= 0;
		else if(right_shift)
			shift_cnt <= shift_cnt+1;

// set flag if shift_cnt reaches 8
assign last_bit = (shift_cnt == 4'd8) ? 1'b1 : 1'b0;			
// set flag if baud count reaches half value		
assign half_baud_cnt = (baud_cnt == 12'd1302) ? 1'b1 : 1'b0;
// set flag if baud count reaches full value		
assign full_baud_cnt = (baud_cnt == 12'd2604) ? 1'b1 : 1'b0;

/*
// falling edge detection of start bit
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n) begin			//// 	IS THIS HOW YOU DO ELSE WITH BEGIN END????
		edge1 <= 0;
		edge2 <= 0;
	end
	// if RX was high and next clk is low we have found a falling edge
	// assert 'start_rec' and start receiving
	else begin
		edge1 <= RX;
		edge2 <= edge1;
		start_rec <= ((edge2 & ~edge1) & (state == IDLE));
	end
*/
always_ff @(posedge clk, negedge rst_n)	
	if(!rst_n) begin
		flop1 <= 1;
		rx_synch <= 1;
	end
	else begin
		flop1 <= RX;
		rx_synch <= flop1;
	end
		

	
// register to sample RX signal
always_ff @(posedge clk, negedge rst_n)	
	if(!rst_n)
		RX_IN <= 0;
	else if(sample_sig)
		RX_IN <= rx_synch;

		
// RX shift register
always_ff @(posedge clk, negedge rst_n)	
	if(!rst_n)
		rx_data[7:0] <= 8'b00000000;
	else if(right_shift)
		rx_data <= {RX_IN, rx_data[7:1]};

		
// next state flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		rx_rdy = 0;
	else if(start_rec || rx_rdy_clr)
		rx_rdy = 0;
		else if(last_bit && full_baud_cnt)
			rx_rdy = 1;

// next state logic
always_comb begin
// default outputs
next_state = IDLE;
sample_sig = 0;
right_shift = 0;
start_rec = 0;


	case(state)
		
		IDLE : begin
				// if start bit comes, start receiving data
				if(!rx_synch) begin
					next_state = RECEIVE;
					start_rec = 1;
				end
			end
		RECEIVE	: begin
				// if the baud counter reaches half way sample RX
				if(half_baud_cnt) begin
					sample_sig = 1;
					next_state = WAIT;
					end
				else 
					next_state = RECEIVE;
			end
		WAIT : begin
				// if the baud count is full and there are more bits to receiving, shift right and transition back to RECEIVE
				if(full_baud_cnt && !last_bit) begin
					right_shift = 1;
					next_state = RECEIVE;
				end
				// if the baud count is full and all the bits have been received, rx_data is ready return to IDLE
				else if(full_baud_cnt && last_bit) begin
					next_state = IDLE;
					right_shift = 1;
					end
					else
						next_state = WAIT;
			end
		
	
	endcase


end		
		
endmodule
