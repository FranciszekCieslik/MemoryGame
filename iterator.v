module iterator (
    input wire        clk,
    input wire        rst_n,
    input wire        start,         // impuls uruchamiający
    input wire        mode,          // 0: iteracja, 1: szybki skok (it)
    input wire [5:0]  it,            // który globalny element zwrócić (dla mode=1)
    input wire        next_elem,     // NOWE: żądanie kolejnego elementu z drivera LED

    // Połączenia z pamięcią seq_memory
    output reg        re,            // sygnał odczytu dla pamięci
    output reg [3:0]  raddr,         // adres rundy (0..8)
    input wire [3:0]  len_rdata,     // długość sekwencji z pamięci
    input wire [3:0]  rdata,         // dane z pamięci

    // Wyjścia iteratora
    output reg [3:0]  out,           // aktualnie czytany element
    output reg        valid,         // HIGH gdy dane na wyjściu 'out' są ważne
    output reg        done           // impuls końca pracy
);

    // Stany FSM
    localparam S_IDLE        = 2'd0;
    localparam S_CALC_INDEX  = 2'd1; 
    localparam S_READ_ELEM   = 2'd2; 
    localparam S_DONE        = 2'd3;

    reg [1:0] state;
    reg [3:0] element_cnt;
    reg [7:0] accumulator; 
    reg       wait_next; // Flaga oczekiwania na ruch ze strony drivera LED

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            re            <= 1'b0;
            raddr         <= 4'd0;
            out           <= 4'd0;
            valid         <= 1'b0;
            done          <= 1'b0;
            element_cnt   <= 4'd0;
            accumulator   <= 8'd0;
            wait_next     <= 1'b0;
        end else begin
            valid <= 1'b0;
            done  <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        accumulator <= 8'd0;
                        element_cnt <= 4'd0;
                        raddr       <= 4'd0;
                        re          <= 1'b1; 
                        wait_next   <= 1'b0;
                        
                        if (mode == 1'b1)
                            state <= S_CALC_INDEX; 
                        else
                            state <= S_READ_ELEM;  
                    end else begin
                        re <= 1'b0;
                    end
                end

                S_CALC_INDEX: begin
                    if (it >= accumulator && it < (accumulator + len_rdata)) begin
                        element_cnt <= it - accumulator; 
                        state       <= S_READ_ELEM; 
                    end else begin
                        accumulator <= accumulator + len_rdata;
                        if (raddr < 4'd8) begin
                            raddr <= raddr + 4'd1;
                        end else begin
                            state <= S_DONE; 
                        end
                    end
                end

                S_READ_ELEM: begin
                    if (mode == 1'b1) begin
                        out   <= rdata;
                        valid <= 1'b1;
                        state <= S_DONE;
                    end else begin
                        // --- ZSYNCHRONIZOWANY TRYB INTERACJI ---
                        if (len_rdata == 4'd0) begin
                            if (raddr < 4'd8) begin
                                raddr <= raddr + 4'd1;
                            end else begin
                                state <= S_DONE;
                            end
                        end else begin
                            if (!wait_next) begin
                                out       <= rdata;
                                valid     <= 1'b1;
                                wait_next <= 1'b1; // Wystawiono element, teraz czekamy na driver
                            end else if (next_elem) begin
                                // Driver prosi o kolejny element
                                if (element_cnt + 4'd1 < len_rdata) begin
                                    element_cnt <= element_cnt + 4'd1;
                                    wait_next   <= 1'b0; // Pozwól wystawić kolejny takt danych
                                end else begin
                                    element_cnt <= 4'd0;
                                    if (raddr < 4'd8) begin
                                        raddr     <= raddr + 4'd1;
                                        wait_next <= 1'b0;
                                    end else begin
                                        state <= S_DONE;
                                    end
                                end
                            end
                        end
                    end
                end

                S_DONE: begin
                    re    <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule