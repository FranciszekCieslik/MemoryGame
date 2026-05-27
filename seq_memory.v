module seq_memory (
    input  wire        clk,
    input  wire        rst_n,
    // port zapisu (Rand Gen)
    input  wire        we,         // impuls zapisu pojedynczego elementu (4 bity)
    input  wire        done,       // impuls końca generowania sekwencji (z rand_gen)
    input  wire [3:0]  len_seq,    // ostateczna ilość elementów w sekwencji
    input  wire [3:0]  wdata,      // 4-bitowy element przesyłany strumieniowo
    // port odczytu 
    input  wire        re,         // impuls/sygnał odczytu 
    input  wire [3:0]  raddr,      // adres rundy do odczytu (0..8)
    output reg  [3:0]  len_rdata,  // odczytana długość sekwencji dla danej rundy 
    output reg  [3:0]  rdata,       // odczytany element sekwencji (sekwencyjny) 
    output wire        last_element
);

    // Pamięć 2D: [runda 0..8][element 0..8]
    reg [3:0] seq_mem [0:8][0:8]; 
    reg [3:0] len_mem [0:8];       // [runda] zapisana długość sekwencji 

    reg [3:0] w_round_cnt;         // Licznik aktualnie zapisywanej rundy 
    reg [3:0] w_element_cnt;       // Licznik pozycji zapisu wewnątrz rundy
    reg [3:0] r_element_cnt;       // Licznik aktualnie odczytywanego elementu 

    integer r, e;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r = 0; r < 9; r = r + 1) begin
                len_mem[r] <= 4'd0;
                for (e = 0; e < 9; e = e + 1) begin 
                    seq_mem[r][e] <= 4'd0;
                end
            end
            w_round_cnt   <= 4'd0; 
            w_element_cnt <= 4'd0;
            r_element_cnt <= 4'd0;
        end else begin
            
            // 1. Logika Zapisu (Strumieniowa)
            if (we && (w_round_cnt < 4'd9) && (w_element_cnt < 4'd9)) begin
                seq_mem[w_round_cnt][w_element_cnt] <= wdata;
                w_element_cnt                       <= w_element_cnt + 4'd1;
            end

            // Zamknięcie rundy zapisu po odebraniu impulsu 'done' z generatora
            if (done && (w_round_cnt < 4'd9)) begin
                len_mem[w_round_cnt] <= len_seq;     // Zapisz ostateczną długość sekwencji
                w_element_cnt        <= 4'd0;        // Resetuj licznik pozycji dla nowej rundy
                w_round_cnt          <= w_round_cnt + 4'd1; // Przejdź do kolejnej rundy
            end

            // 2. Logika Odczytu 
            if (re) begin
                if (r_element_cnt + 4'd1 < len_mem[raddr]) begin 
                    r_element_cnt <= r_element_cnt + 4'd1; 
                end else begin
                    r_element_cnt <= 4'd0;
                end
            end else begin
                r_element_cnt <= 4'd0;
            end
        end
    end

    // Wyjścia kombinatoryczne 
    always @(*) begin
        if (raddr < 4'd9) begin
            len_rdata = len_mem[raddr];
            rdata     = seq_mem[raddr][r_element_cnt];
        end else begin
            len_rdata = 4'd0;
            rdata     = 4'd0;
        end
    end
    assign last_element = (re && (len_rdata > 4'd0)) ? (r_element_cnt == (len_rdata - 4'd1)) : 1'b0;

endmodule