module led_driver #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire        clk,
    input  wire [3:0]  in,         // Dane wejściowe z iteratora
    output reg  [9:0]  LED = 10'd0,// Inicjalizacja stanu początkowego
    output reg         ready = 1'b1
);

    // Stany maszyny FSM
    localparam S_IDLE      = 2'd0;
    localparam S_LED_ON    = 2'd1;
    localparam S_WAIT_GAP  = 2'd2;

    reg [1:0]  state = S_IDLE;
    reg [31:0] timer = 32'd0;

    localparam ONE_SECOND = CLK_FREQ;

    always @(posedge clk) begin
        case (state)
            
            // Czeka na dane (wartość in inną niż 4'hF)
            S_IDLE: begin
                ready <= 1'b1;
                LED   <= 10'd0;
                timer <= 32'd0;
                
                // Jeśli pojawi się prawidłowy indeks elementu (0-9)
                if (in != 4'hF) begin
                    ready <= 1'b0;                  // Przestaje być gotowy (blokada)
                    LED   <= (10'b00_0000_0001 << in); // Dekoder One-Hot - zapala LED
                    state <= S_LED_ON;
                end
            end

            // Świeci przez 1 sekundę (ignoruje zmiany na szynie 'in')
            S_LED_ON: begin
                if (timer >= ONE_SECOND - 1) begin
                    timer <= 32'd0;
                    LED   <= 10'd0;                 // Gasi LED
                    state <= S_WAIT_GAP;
                end else begin
                    timer <= timer + 32'd1;
                end
            end

            // Czeka zgaszony przez 1 sekundę (nadal ignoruje szynę 'in')
            S_WAIT_GAP: begin
                if (timer >= ONE_SECOND - 1) begin
                    timer <= 32'd0;
                    ready <= 1'b1;                  // Informuje, że skończył wyświetlanie
                    state <= S_IDLE;                // Wraca do słuchania szyny 'in'
                end else begin
                    timer <= timer + 32'd1;
                end
            end

            default: state <= S_IDLE;
        endcase
    end

endmodule