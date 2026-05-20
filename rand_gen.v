module rand_gen (
    input  wire        clk,
    input  wire        en,
    input  wire        rst_n,
    input  wire        start,        // impuls 1-taktowy od FSM
    output reg [3:0]   len_seq,
    output reg [35:0]  seq,
    output reg         done          // impuls 1-taktowy: sekwencja gotowa
);

    // Stany maszyny FSM
    localparam STATE_WAIT_START  = 2'd0;
    localparam STATE_GEN_LEN_SEQ = 2'd1;
    localparam STATE_GEN_SEQ     = 2'd2;
    localparam STATE_DONE        = 2'd3;

    reg [1:0] current_state;
    reg [3:0] gen_cnt; // Licznik wygenerowanych już elementów sekwencji

    // Sygnały dla modułu LFSR
    wire [7:0] lfsr_out;
    wire       lfsr_en = (current_state == STATE_WAIT_START && start) || (current_state == STATE_GEN_SEQ && en);

    // Instancjonowanie Twojego modułu LFSR
    lfsr #(.WIDTH(8), .TAPS(8'hB8)) u_lfsr (
        .clk(clk),
        .rst_n(rst_n),
        .en(lfsr_en),
        .out(lfsr_out)
    );

    // Mapowanie wyjścia LFSR na zakres 1..6 dla długości sekwencji
    // (Zamiast dzielenia mod 6, używamy prostej logiki kombinatorycznej)
    wire [3:0] lfsr_mod9 = (lfsr_out[3:0] >= 4'd9) ? lfsr_out[3:0] - 4'd9 : lfsr_out[3:0];
    wire [3:0] target_len = lfsr_mod9 + 4'd1;

    // Maszyna Stanów 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_WAIT_START;
            len_seq       <= 4'd0;
            seq           <= 36'hF_FFFF_FFFF;
            gen_cnt       <= 4'd0;
            done          <= 1'b0;
        end else begin
            done <= 1'b0; // Domyślnie wyczyszczone

            case (current_state)
                STATE_WAIT_START: begin
                    if (start) begin
                        seq           <= 36'd0;
                        gen_cnt       <= 4'd0;
                        current_state <= STATE_GEN_LEN_SEQ;
                    end
                end

                STATE_GEN_LEN_SEQ: begin
                    // Zatrzaskujemy wylosowaną długość sekwencji
                    len_seq       <= target_len;
                    current_state <= STATE_GEN_SEQ;
                end

                STATE_GEN_SEQ: begin
                    if (en) begin
                        
                        seq[gen_cnt * 6 +: 4] <= lfsr_mod9; // Przypisanie zmapowanej wartości mod 9
                        gen_cnt               <= gen_cnt + 4'd1; 

                        if (gen_cnt + 4'd1 >= len_seq) begin 
                            current_state <= STATE_DONE; 
                        end
                    end
                end

                STATE_DONE: begin
                    done          <= 1'b1; // Wystaw impuls DONE na jeden takt
                    current_state <= STATE_WAIT_START;
                end

                default: current_state <= STATE_WAIT_START;
            endcase
        end
    end

endmodule