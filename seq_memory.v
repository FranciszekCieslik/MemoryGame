module seq_memory (
    input  wire        clk,
    input  wire        rst_n,
    // port zapisu (Rand Gen)
    input  wire        we,         // impuls zapisu (w reakcji na done rand_gen)
    input  wire [3:0]  len_seq,    // ilość elementów sekwencji do zapisania (max 9)
    input  wire [35:0] seq,        // spakowana sekwencja (9 elementów po 4 bity)
    // port odczytu 
    input  wire        re,         // impuls/sygnał odczytu
    input  wire [3:0]  raddr,      // adres rundy do odczytu (0..8)
    output reg  [3:0]  len_rdata,  // odczytana długość sekwencji dla danej rundy
    output reg  [3:0]  rdata       // odczytany element sekwencji (zmienia się sekwencyjnie)
);

    // Pamięć: 9 rund, każda runda może mieć maksymalnie 9 elementów po 4 bity
    // Organizacja pamięci: 2D tablica ułatwia mapowanie rund
    reg [3:0] seq_mem [0:8][0:8];  // [runda][element]
    reg [3:0] len_mem [0:8];       // [runda] zapisana długość sekwencji

    // Rejestry sterujące zapisem i odczytem
    reg [3:0] w_round_cnt;         // Licznik zapisanych rund (0..8)
    reg [3:0] r_element_cnt;       // Licznik aktualnie odczytywanego elementu (0..len_seq-1)

    integer r, e;

    // --- LOGIKA SEKWENCYJNA  ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Resetowanie pamięci
            for (r = 0; r < 9; r = r + 1) begin
                len_mem[r] <= 4'd0;
                for (e = 0; e < 9; e = e + 1) begin
                    seq_mem[r][e] <= 4'd0;
                end
            end
            w_round_cnt   <= 4'd0;
            r_element_cnt <= 4'd0;
        end else begin
            
            // 1. Logika Zapisu 
            if (we) begin
                if (w_round_cnt < 4'd9) begin
                    len_mem[w_round_cnt] <= len_seq; // Zapisz długość
                    
                    // Rozpakowanie 36-bitowego rejestru seq do pamięci 2D
                    seq_mem[w_round_cnt][0] <= seq[3:0];
                    seq_mem[w_round_cnt][1] <= seq[9:6];
                    seq_mem[w_round_cnt][2] <= seq[15:12];
                    seq_mem[w_round_cnt][3] <= seq[21:18];
                    seq_mem[w_round_cnt][4] <= seq[27:24];
                    seq_mem[w_round_cnt][5] <= seq[33:30];
                    seq_mem[w_round_cnt][6] <= seq[35:34];
                    seq_mem[w_round_cnt][7] <= 4'd0;
                    seq_mem[w_round_cnt][8] <= 4'd0;

                    w_round_cnt <= w_round_cnt + 4'd1; // Inkrementacja rundy zapisu
                end
            end

            // 2. Logika Odczytu 
            if (re) begin
                // Jeśli nie przekroczyliśmy długości zapisanej sekwencji, czytaj dalej
                if (r_element_cnt + 4'd1 < len_mem[raddr]) begin
                    r_element_cnt <= r_element_cnt + 4'd1;
                end else begin
                    r_element_cnt <= 4'd0; // Zawijaj licznik elementów dla danej rundy
                end
            end else begin
                r_element_cnt <= 4'd0; // Resetuj pozycję wskaźnika, gdy re opadnie
            end
        end
    end

    // --- Wystawianie danych na wyjścia ---
    always @(*) begin
        if (raddr < 4'd9) begin
            len_rdata = len_mem[raddr];
            rdata     = seq_mem[raddr][r_element_cnt];
        end else begin
            len_rdata = 4'd0;
            rdata     = 4'd0;
        end
    end

endmodule