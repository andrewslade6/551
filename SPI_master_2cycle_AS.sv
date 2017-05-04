module SPI_master_2cycle_AS(clk, rst_n, wrt, cmd, done, rd_data, SCLK, SS_n, MOSI, MISO);

input clk, rst_n, wrt, cmd, MISO;
output SCLK, MOSI, SS_n, done, rd_data;

wire clk, rst_n, wrt, MISO;
wire[15:0] cmd;

reg SCLK, MOSI, SS_n, done;
reg [15:0] rd_data;


reg[4:0] SCLK_counter; // counts to 32 to be used in generating SCLK
reg[15:0] tx_register, rx_register; // transmit and receive registers

reg SCLK_ff1, SCLK_ff2;
reg SCLK_fall, SCLK_rise;

reg[5:0] bit_counter; // used to count up to all 16 bits being transmited
reg[4:0] delay_counter; // used to count 2 clk delays before chaning MOSI
reg two_clk_delay; // 1 if we've waited 2 clocks before changing MOSI
reg bck_porch_wait;
reg [2:0] bck_porch_counter;

typedef enum reg[2:0] {IDLE, WAIT, BACK_PORCH} state_t;
state_t state, next_state;

// SCLK generator from 4bit counter
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		SCLK_counter <= 0;
	else if(wrt) 
		SCLK_counter <= 0;
	else
		SCLK_counter <= SCLK_counter + 1;		
end

assign SCLK = (SS_n) ? 1'b1 : SCLK_counter[4];

// posedge detection for SCLK
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
		SCLK_ff1 <= 1'b1;
		SCLK_ff2 <= 1'b1;
		end
	else begin
	    SCLK_ff1 <= SCLK;
		SCLK_ff2 <= SCLK_ff1;
		end  

// negedge detection on SCLK
assign SCLK_fall = ~SCLK_ff1 & SCLK_ff2;
// posedge detection on SCLK
assign SCLK_rise = SCLK_ff1 & ~SCLK_ff2;


// counts to 16 and sets a flag when all bits have been transmited
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
		bit_counter <= 6'b000000;
	else if (wrt)
		bit_counter <= 6'b000000;
	else if (SCLK_rise)
		bit_counter <= bit_counter + 1;

assign all_bits_transfered = (bit_counter == 6'd32) ? 1'b1 : 1'b0;	
		
// counts a 2 clock delay before changes MOSI		
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
		delay_counter <= 5'b00000;
	else if(SCLK_rise)
		delay_counter <= 5'b00000;
	else
		delay_counter <= delay_counter + 1;

assign two_clk_delay = ((delay_counter == 5'h2) && (state == WAIT) && (bit_counter != 6'd0)) ? 1'b1 : 1'b0;

// shifts tx_register 2 clocks after rising edge
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
		tx_register <= 16'h0000;
	else if(wrt)
		tx_register <= cmd;
	else if(two_clk_delay)
		tx_register <= {tx_register[14:0], 1'b0};
		
assign MOSI = tx_register[15];
		
// samples MISO on rising edge of clk
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
		rx_register <= 16'h0000;
	else if(SCLK_rise)
		rx_register <= {rx_register[14:0], MISO};


always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
		bck_porch_counter <= 5'b00000;
	else if (bck_porch_wait)
		bck_porch_counter <= 5'b00000;
	else
		bck_porch_counter <= bck_porch_counter + 1;
		
		
		
// next state logic
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;
		
always_comb begin
done = 0;
next_state = IDLE;
bck_porch_wait = 0;
SS_n = 1'b1;

case (state)
	IDLE : if (wrt) begin
			next_state = WAIT;
			SS_n = 1'b0;
		end
	WAIT : if (all_bits_transfered) begin
			SS_n = 1'b0;
			next_state = BACK_PORCH;
			bck_porch_wait = 1'b1;
		end
			else begin
			SS_n = 1'b0;
			next_state = WAIT;
			end
	BACK_PORCH : if (bck_porch_counter == 3'b111) begin
					next_state = IDLE;
					SS_n = 1'b1;
					done = 1'b1;
				end
				else begin
					next_state = BACK_PORCH;
					SS_n = 1'b0;
				end
endcase
end

// assing rd_data rx_register after all data has been received
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		rd_data <= 16'hFFFF;
	else if (bck_porch_wait)
		rd_data <= rx_register;


endmodule
