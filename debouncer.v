module debouncer #(
    parameter CLK_FREQ    = 50_000_000,
    parameter DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire button_in,
    output reg  button_out
);
    localparam MAX_COUNT = (CLK_FREQ / 1000) * DEBOUNCE_MS;

    // FIX A: szerokość licznika gwarantowana min 1 bit ($clog2(0)=0 → problem)
    localparam CNT_W = (MAX_COUNT > 0) ? $clog2(MAX_COUNT + 1) : 1;
    reg [CNT_W-1:0] counter = 0;

    // FIX B: inicjalizacja rejestrów unika propagacji X po power-on
    reg [1:0] sync_reg   = 2'b00;
    initial   button_out = 1'b0;

    always @(posedge clk) begin
        // 2-stopniowy synchronizator (eliminuje metastabilność)
        sync_reg <= {sync_reg[0], button_in};

        if (sync_reg[1] != button_out) begin
            // FIX C: gdy MAX_COUNT=0 (CLK_FREQ bardzo małe) → natychmiastowe przejście
            if (counter >= MAX_COUNT) begin
                button_out <= sync_reg[1];
                counter    <= 0;
            end else begin
                counter <= counter + 1'b1;
            end
        end else begin
            counter <= 0;
        end
    end

endmodule
