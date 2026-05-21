module led_driver #(
    parameter LED_ON_TIME = 200_000_000, // czas świecenia (cykle)
    parameter WAIT_TIME   = 100_000_000  // czas przerwy (cykle)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  in,         // podpięte pod 'out' z iteratora
    input  wire        valid,      // podpięte pod 'valid' z iteratora
    output reg         next_elem,  // żądanie kolejnego elementu do iteratora
    output reg  [9:0]  LED,
    output reg         ready       // HIGH gdy driver jest bezczynny i gotowy
);

    // Pamięć podręczna na sekwencję z jednej rundy (max 9 elementów + znacznik końca)
    reg [3:0] Q [0:9]; 
    
    // Liczniki i wskaźniki
    reg [3:0]  wr_ptr;
    reg [3:0]  rd_ptr;
    reg [31:0] timer;

    // Maszyna stanów drivera
    localparam S_READY      = 3'd0;
    localparam S_LOAD       = 3'd1;
    localparam S_REQ_NEXT   = 3'd2;
    localparam S_SHOW_LED   = 3'd3;
    localparam S_WAIT_GAP   = 3'd4;

    reg [2:0] state;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_READY;
            LED       <= 10'd0;
            ready     <= 1'b1;
            next_elem <= 1'b0;
            wr_ptr    <= 4'd0;
            rd_ptr    <= 4'd0;
            timer     <= 32'd0;
            for (i = 0; i < 10; i = i + 1) begin
                Q[i] <= 4'hF; // Wypełnienie znacznikami pustego elementu
            end
        end else begin
            next_elem <= 1'b0;

            case (state)
                // Driver czeka na inicjalizację ze strony systemu/iteratora
                S_READY: begin
                    ready  <= 1'b1;
                    LED    <= 10'd0;
                    wr_ptr <= 4'd0;
                    rd_ptr <= 4'd0;
                    
                    if (valid) begin
                        ready      <= 1'b0;
                        Q[wr_ptr]  <= in;
                        wr_ptr     <= wr_ptr + 4'd1;
                        state      <= S_REQ_NEXT;
                    end
                end

                // Generowanie impulsu żądania kolejnego bitu do iteratora
                S_REQ_NEXT: begin
                    next_elem <= 1'b1;
                    timer     <= 32'd0;
                    state     <= S_LOAD;
                end

                // Buforowanie strumienia danych
                S_LOAD: begin
                    timer <= timer + 32'd1;
                    
                    if (valid) begin
                        Q[wr_ptr] <= in;
                        wr_ptr    <= wr_ptr + 4'd1;
                        state     <= S_REQ_NEXT;
                    end
                    // Jeśli przez 5 taktów iterator milczy, uznajemy, że runda została pobrana
                    else if (timer >= 32'd5) begin
                        Q[wr_ptr] <= 4'hF; // Wstaw znacznik końca rundy
                        timer     <= 32'd0;
                        state     <= S_SHOW_LED;
                    end
                end

                // Wyświetlanie aktualnego elementu na diodach LED (Konwersja na One-Hot)
                S_SHOW_LED: begin
                    if (Q[rd_ptr] == 4'hF) begin
                        // Trafiliśmy na koniec sekwencji dla tej rundy
                        state <= S_READY;
                    end else begin
                        // Dekoder 4-bit na 10-bit dla LED (zapalenie diody o indeksie Q[rd_ptr])
                        LED <= (10'b00_0000_0001 << Q[rd_ptr]);
                        
                        if (timer + 32'd1 >= LED_ON_TIME) begin
                            timer <= 32'd0;
                            LED   <= 10'd0; // Zgaś diody na czas przerwy
                            state <= S_WAIT_GAP;
                        end else begin
                            timer <= timer + 32'd1;
                        end
                    end
                end

                // Przerwa zaciemnienia (WAIT_TIME) pomiędzy kolejnymi mignięciami diod
                S_WAIT_GAP: begin
                    if (timer + 32'd1 >= WAIT_TIME) begin
                        timer  <= 32'd0;
                        rd_ptr <= rd_ptr + 4'd1; // Przygotuj kolejną pozycję z bufora Q
                        state  <= S_SHOW_LED;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                default: state <= S_READY;
            endcase
        end
    end
endmodule