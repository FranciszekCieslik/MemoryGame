module sw_driver #(
    parameter CLK_FREQ    = 50_000_000,
    parameter DEBOUNCE_MS = 20
)(
    input  wire        clk,
    output reg         pressed,
    input  wire [9:0]  SW,
    output reg  [3:0]  sw_idx
);

localparam SW_NUM = 10;
localparam WIDTH  = 4;   // $clog2(10) = 4

wire [9:0] button_out;   // Teraz wszystkie 10 bitów drivowane przez generate

genvar i;
generate
    for (i = 0; i < SW_NUM; i = i + 1) begin : debounce_gen
        debouncer #(
            .CLK_FREQ(CLK_FREQ),
            .DEBOUNCE_MS(DEBOUNCE_MS)
        ) db_inst (
            .clk(clk),
            .button_in(SW[i]),
            .button_out(button_out[i])
        );
    end
endgenerate

// Kombinacyjny priorytetowy enkoder — last pressed wins
reg        any_pressed;
reg [3:0]  next_idx;
integer    j;

always @(*) begin
    any_pressed = 1'b0;
    next_idx    = 4'd0;
    for (j = 0; j < SW_NUM; j = j + 1) begin
        if (button_out[j]) begin
            next_idx    = j[WIDTH-1:0];
            any_pressed = 1'b1;
        end
    end
end

initial begin
    pressed = 1'b0;
    sw_idx  = 4'd0;
end

always @(posedge clk) begin
    sw_idx  <= next_idx;
    pressed <= any_pressed;
end

endmodule
