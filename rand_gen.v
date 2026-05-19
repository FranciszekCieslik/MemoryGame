module rand_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,        // impuls 1-taktowy od FSM
    input  wire [3:0]  round,        // 0..8
    input  wire [6:0]  base_ptr,     // adres bazowy bieżącej rundy
    output wire        we,
    output wire [6:0]  waddr,
    output wire [3:0]  wdata,
    output wire        len_we,
    output wire [3:0]  len_waddr,
    output wire [3:0]  len_wdata,
    output reg         done          // impuls 1-taktowy: sekwencja gotowa
);

    // FSM stany
    localparam S_IDLE    = 3'd0;
    localparam S_LEN     = 3'd1;  // losuj długość
    localparam S_INIT    = 3'd2;  // zeruj used[]
    localparam S_CAND    = 3'd3;  // losuj kandydata
    localparam S_CHECK   = 3'd4;  // sprawdź kolizję
    localparam S_WRITE   = 3'd5;  // zapisz do seq_mem
    localparam S_DONE    = 3'd6;

    reg [2:0]  state;
    reg [3:0]  seq_len;       // wylosowana długość sekwencji
    reg [9:0]  used;          // 10-bitowa mapa zajętości
    reg [3:0]  i_cnt;         // ile elementów już zapisano
    reg [6:0]  wp;            // lokalny write pointer
    reg [3:0]  cand;          // bieżący kandydat

    // LFSR_A — do długości (8-bit)
    wire [7:0] lfsr_a_out;
    wire lfsr_a_en = (state == S_LEN);
    lfsr #(.WIDTH(8), .TAPS(8'hB8)) LFSR_A (
        .clk(clk), .rst_n(rst_n), .en(lfsr_a_en), .out(lfsr_a_out)
    );

    // LFSR_B — do kandydatów (8-bit, inny seed przez inne TAPS)
    wire [7:0] lfsr_b_out;
    wire lfsr_b_en = (state == S_CAND);
    lfsr #(.WIDTH(8), .TAPS(8'hE1)) LFSR_B (
        .clk(clk), .rst_n(rst_n), .en(lfsr_b_en), .out(lfsr_b_out)
    );

    // oblicz kandydata: mod 10 przez odejmowanie (unika dzielenia)
    wire [3:0] raw_cand = lfsr_b_out[3:0];
    wire [3:0] cand_mod;
    assign cand_mod = (raw_cand >= 4'd10) ? raw_cand - 4'd10 : raw_cand;

    // port zapisu do seq_memory
    assign we        = (state == S_WRITE);
    assign waddr     = wp;
    assign wdata     = cand;
    assign len_we    = (state == S_DONE);
    assign len_waddr = round;
    assign len_wdata = seq_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            used    <= 10'd0;
            i_cnt   <= 4'd0;
            wp      <= 7'd0;
            seq_len <= 4'd0;
            cand    <= 4'd0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;  // domyślnie impuls nieaktywny

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_LEN;
                    end
                end

                S_LEN: begin
                    // jeden takt — LFSR_A przesuwa się (en=1)
                    // raw mod 10 + 1, zakres 1..10
                    // mod 10 bez dzielnika:
                    begin
                        reg [3:0] raw4;
                        raw4    = lfsr_a_out[3:0];
                        // raw może być 0..15; mapujemy na 0..9
                        seq_len = (raw4 >= 4'd10) ? raw4 - 4'd6 : raw4 + 4'd1;
                        // wynik: 1..10
                    end
                    state <= S_INIT;
                end

                S_INIT: begin
                    used  <= 10'd0;
                    i_cnt <= 4'd0;
                    wp    <= base_ptr;
                    state <= S_CAND;
                end

                S_CAND: begin
                    // LFSR_B przesuwa się (en=1)
                    cand  <= cand_mod;
                    state <= S_CHECK;
                end

                S_CHECK: begin
                    if (used[cand])
                        state <= S_CAND;   // kolizja — losuj ponownie
                    else
                        state <= S_WRITE;
                end

                S_WRITE: begin
                    used[cand] <= 1'b1;
                    i_cnt      <= i_cnt + 4'd1;
                    wp         <= wp + 7'd1;
                    if (i_cnt + 4'd1 >= seq_len)
                        state <= S_DONE;
                    else
                        state <= S_CAND;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule