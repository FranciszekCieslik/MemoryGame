module comparator #(
parameter bit_num = 1'd4
)(
input clk,
input en,
input [bit_num - 1 : 0] usr_in,
input [bit_num - 1 : 0] mem_in,
output no_equ,
output equ
);

always @(clk) begin

if(!en) begin
    if (usr_in == mem_in) begin
        no_equ <= 1'b0;
        equ <= 1'b1;
    end else begin
        no_equ <= 1'b1;
        equ <= 1'b0;
    end
end
end
endmodule