module debouncer #(
    parameter CLK_FREQ = 50_000_000,
    parameter DEBOUNCE_MS = 20
)(
    input wire clk,
    input wire button_in,
    output reg button_out
);
    localparam MAX_COUNT = (CLK_FREQ / 1000) * DEBOUNCE_MS;
    reg [$clog2(MAX_COUNT)-1:0] counter;
    reg [1:0] sync_reg;

    // Synchronizer and debounce counter
    always @(posedge clk) begin
        sync_reg <= {sync_reg[0], button_in};
        if (sync_reg[1] != button_out) begin
            if (counter == MAX_COUNT) begin
                button_out <= sync_reg[1];
                counter <= 0;
            end else
                counter <= counter + 1;
        end else
            counter <= 0;
    end
endmodule