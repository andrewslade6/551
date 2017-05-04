module cmd_cntrl(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

input[7:0] cmd, ID;
input clk, rst_n, cmd_rdy, OK2Move, ID_vld;
output clr_cmd_rdy, in_transit, go, buzz, buzz_n, clr_ID_vld;

localparam GO = 2'b01;
localparam STOP = 2'b00;

reg[5:0] dest_ID;
reg[13:0] buzz_cnt;

reg transitflag, 
	updateDestID, 
	clr_ID_vld,
	clr_cmd_rdy,
	in_transit,
	clr_ID_vld_flag,
	clr_cmd_rdy_flag;

wire go,
	piezoEn;
	
reg buzz,
	buzz_n;
	
	
typedef enum reg[1:0] {IDLE, IN_TRANSIT, VALIDATE_ID} state_t;
state_t state, nextstate;

//in_transit flop logic
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		in_transit <= 0;
	else if(transitflag) 
		in_transit <= 1;
	else 
		in_transit <= 0;
end

assign go = in_transit & OK2Move;

assign piezoEn = in_transit & ~OK2Move;


//TODO: Piezo Buzzer divider
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		buzz <= 1'b0;
		buzz_cnt <= 14'd0;
	end
	else begin
		if(piezoEn)
			buzz_cnt <= buzz_cnt + 1;
		if(buzz_cnt >= 14'd6250)
			buzz <= 1'b1;
		else
			buzz <= 1'b0;
		if(buzz_cnt == 14'd12500)
			buzz_cnt <= 14'd0;
	end	
end

assign buzz_n = (piezoEn) ? ~buzz : buzz;


//destination ID logic
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		dest_ID <= 0; 
	else if(updateDestID) 
		dest_ID <= cmd[5:0];
end

//clear ID vld flop logic
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		clr_ID_vld <= 0;
	else if(clr_ID_vld_flag)
		clr_ID_vld <= 1;
	else
		clr_ID_vld <= 0;
end

//clr_cmd_rdy flop logic
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		clr_cmd_rdy <= 0;
	else if(clr_cmd_rdy_flag)
		clr_cmd_rdy <= 1;
	else
		clr_cmd_rdy <= 0;
end


//state flops
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		state <= IDLE;
	else begin
		state <= nextstate;
	end
end

//state logic
always_comb begin
//defaults
	nextstate = IDLE;
	updateDestID = 0;
	transitflag = 0; //MUST SET TO 1 EVERY STATE
	clr_ID_vld_flag = 0;
	clr_cmd_rdy_flag = 0;
	
	case(state)
		IDLE: begin
			if(cmd_rdy && (cmd[7:6] == GO)) begin
				nextstate = IN_TRANSIT;
				transitflag = 1;
				updateDestID = 1;
				clr_cmd_rdy_flag = 1;
			end
		end
		
		IN_TRANSIT: begin
			//defaults
			nextstate = VALIDATE_ID;
			transitflag = 1;
			
			if(cmd_rdy && cmd[7:6] == GO) begin
				nextstate = IN_TRANSIT;
				updateDestID = 1;
				clr_cmd_rdy_flag = 1;
			end
			else if(cmd_rdy && cmd[7:6] == STOP) begin
				transitflag = 0;
				nextstate = IDLE;
				clr_cmd_rdy_flag = 1;
			end
		end
		
		VALIDATE_ID: begin
			transitflag = 1;
			nextstate = IN_TRANSIT;
			
			if(ID_vld && ID[5:0] == dest_ID) begin //ONLY comparing lower 6 bits
				nextstate = IDLE;
				clr_ID_vld_flag = 1;
				transitflag = 0;
			end
			else if(ID_vld) begin
				clr_ID_vld_flag = 1;
			end
		end
	endcase //end case statement
end //end comb block


endmodule