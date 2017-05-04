module motor_cntrl_tb();

reg clk, rst_n;
reg[11:0] lft, rht;
wire fwd_lft, fwd_rht, rev_lft, rev_rht;

motor_cntrl MOTOR(clk, rst_n, lft, rht, fwd_lft, rev_lft, fwd_rht, rev_rht);

initial begin
rst_n = 0;
lft = 11'h8FF;
rht = 11'h8FF;
#5
rst_n = 1;
// forward
#(1024 * 10 * 2)
// reverse
lft = 11'h0FF;
rht = 11'h0FF;
#(1024 * 10 * 2) $stop;
end

initial begin
clk = 1;
forever #5 clk = ~clk;
end

endmodule
