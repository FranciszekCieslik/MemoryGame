module counter #(
    parameter MODULO = 8
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             inc,
    output reg  [WIDTH-1:0] out,
    output reg              is_max
);
    localparam WIDTH = $clog2(MODULO);

    // FIX: reset asynchroniczny z prawidłową listą sensytywności
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out    <= 0;
            is_max <= 1'b0;
        end else begin
            if (inc) begin
                if (out == MODULO - 1)
                    out <= 0;
                else
                    out <= out + {{WIDTH-1{1'b0}}, 1'b1};
            end

            if (out == MODULO - 1)
                is_max <= 1'b1;
            else
                is_max <= 1'b0;
        end
    end

endmodule