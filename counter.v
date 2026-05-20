module counter #(
    parameter MODULO = 8
)(
    input  wire             clk,
    input  wire             rstn,
    input  wire             inc,
    input  wire             mod_en,
    output reg  [WIDTH-1:0] out,
    output reg              is_max
);
    localparam WIDTH = $clog2(MODULO);
    // Logika licznika
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            out    <= 0;
            is_max <= 1'b0;
        end else begin
            if (inc) begin
                if (mod_en && (out == MODULO - 1)) begin
                    out <= 0;
                end else begin
                    out <= out + 1'b01;
                end
            end
            
            if (mod_en && (out == MODULO - 1)) begin
                is_max <= 1'b1;
            end else begin
                is_max <= 1'b0;
            end
        end
    end

endmodule