module lfsr #(
    parameter WIDTH = 8,
    parameter TAPS  = 8'hB8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] out
);
    wire feedback = ^(out & TAPS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out <= {WIDTH{1'b1}};
        else if (en)
            out <= {out[WIDTH-2:0], feedback};
    end
endmodule