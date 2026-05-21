module master_controller(
input wire clk,
input  [2:0] CURRRENT_STATE,
output reg [1:0] STATE_CONTROL,

output reg      rg_en, 
output  reg     rg_rst_n,
output  reg     rg_start,

input  wire     rg_done,
output reg      it_start,
output reg      it_mode,

input wire       it_done,
input wire       led_ready
);

localparam S_RESET = 3'b000;
localparam S_GENERATE = 3'b001;
localparam S_SHOW = 3'b010;
localparam S_USER_INPUT = 3'b011;
localparam S_COMPARE = 3'b100;
localparam S_ERROR = 3'b101;

always @(clk) begin
    case (CURRRENT_STATE)

        S_GENERATE: begin
            rg_en <= 1'b1;
            rg_rst_n <= 1'b0;
            rg_start <= 1'b1;
            it_start <= 1'b0;
            it_mode <= 1'b0;
            if (rg_done)begin
                STATE_CONTROL <= 2'b01;
            end
        end

        S_SHOW: begin
            it_start <= 1'b1;
            it_mode <= 1'b0;
            if(it_done & led_ready) begin
                STATE_CONTROL <= 2'b01;
            end
        end

        S_USER_INPUT: begin

        end

        default: begin
            rg_en <= 1'b0;
            rg_rst_n <= 1'b1;
            rg_start <= 1'b0;
            STATE_CONTROL <= 2'b00;
        end

    endcase
end
endmodule