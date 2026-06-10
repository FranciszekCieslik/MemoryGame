module fsm(
input wire clk,
input wire rst,
input wire [1:0] c,
output reg [2:0] CURRENT_STATE
);

localparam S_RESET      = 3'b000;
localparam S_GENERATE   = 3'b001;
localparam S_SHOW       = 3'b010;
localparam S_USER_INPUT = 3'b011;
localparam S_COMPARE    = 3'b100;
localparam S_ERROR      = 3'b101;


always @(posedge clk or posedge rst) begin
    if (rst) begin
        CURRENT_STATE <= S_RESET;
    end else begin
        case (CURRENT_STATE)
            S_RESET:
                if (c == 2'b01)
                    CURRENT_STATE <= S_GENERATE;
            S_GENERATE:
                if (c == 2'b01)
                    CURRENT_STATE <= S_SHOW;
            S_SHOW:
                if (c == 2'b01)
                    CURRENT_STATE <= S_USER_INPUT;
            S_USER_INPUT:
                if (c == 2'b01)
                    CURRENT_STATE <= S_COMPARE;
            S_COMPARE:
                if      (c == 2'b01) CURRENT_STATE <= S_SHOW;
                else if (c == 2'b10) CURRENT_STATE <= S_ERROR;
                else if (c == 2'b11) CURRENT_STATE <= S_USER_INPUT;
            S_ERROR:
                if      (c == 2'b01) CURRENT_STATE <= S_SHOW;
                else if (c == 2'b10) CURRENT_STATE <= S_RESET;
            default: CURRENT_STATE <= S_RESET;
        endcase
    end
end

endmodule