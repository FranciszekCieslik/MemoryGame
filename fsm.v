module fsm(
input wire clk,
input wire [1:0] c,
output reg CURRRENT_STATE
);

parameter S_GENERATE = 3'b000;
parameter S_SHOW = 3'b001;
parameter S_USER_INPUT = 3'b010;
parameter S_COMPARE = 3'b011;
parameter S_ERROR = 3'b100;
parameter S_RESET = 3'b101;

always @(posedge clk) begin

case (CURRRENT_STATE)
	S_GENERATE:
		if (c == 2'b01)
			CURRRENT_STATE <= S_SHOW;
	S_SHOW:
		if (c == 2'b01)
			CURRRENT_STATE <= S_USER_INPUT;
	S_USER_INPUT:
		if (c == 2'b01)
			CURRRENT_STATE <= S_COMPARE;
	S_COMPARE:
		if (c == 2'b01)
			CURRRENT_STATE <= S_GENERATE;
		else if (c == 2'b10)
			CURRRENT_STATE <= S_ERROR;
		else if (c == 2'b11)
			CURRRENT_STATE <= S_USER_INPUT;
	S_ERROR:
		if (c == 2'b01)
			CURRRENT_STATE <= S_SHOW;
		else if (c == 2'b10)
			CURRRENT_STATE <= S_RESET;
	S_RESET:
		if (c == 2'b01)
			CURRRENT_STATE <= S_SHOW;
		else if (c == 2'b10)
			CURRRENT_STATE <= S_RESET;
	default: CURRRENT_STATE = S_RESET;	
endcase

end

endmodule