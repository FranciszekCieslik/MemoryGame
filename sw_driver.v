module sw_driver #(
    parameter CLK_FREQ    = 50_000_000,
    parameter DEBOUNCE_MS = 20,
    parameter SW_NUM      = 9,
    localparam WIDTH      = $clog2(SW_NUM)
)(
    input  wire [SW_NUM-1:0] SW, 
    input  wire              clk,
    output reg               pressed,
    output reg  [WIDTH-1:0]  sw_idx
);

    wire [SW_NUM-1:0] button_out;
    reg  [WIDTH-1:0]  next_idx;
    reg               any_pressed;

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


    integer j;
    always @(*) begin
        next_idx    = sw_idx;
        any_pressed = 1'b0;
        
        for (j = 0; j < SW_NUM; j = j + 1) begin
            if (button_out[j]) begin
                next_idx    = j[WIDTH-1:0];
                any_pressed = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        sw_idx  <= next_idx;
        pressed <= any_pressed;
    end

endmodule