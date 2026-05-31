module comparator #(
parameter bit_num = 3'd4
)(
input clk,
input en,
input [bit_num - 1 : 0] usr_in,
input [bit_num - 1 : 0] mem_in,
output reg no_equ,
output reg equ
);

always @(posedge clk) begin
    if (en) begin       // en=1 → porównuj
        if (usr_in == mem_in) begin
            no_equ <= 1'b0;
            equ    <= 1'b1;
        end else begin
            no_equ <= 1'b1;
            equ    <= 1'b0;
        end
    end else begin
        no_equ <= 1'b0;
        equ    <= 1'b0;
    end
end
endmodule