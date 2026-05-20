`timescale 1ns / 1ps

module rand_gen_tb;

    // Parametry testbenchu
    localparam CLK_PERIOD = 20; // Zegar 50 MHz

    // Sygnały wejściowe do UUT (rejestry)
    reg  clk;
    reg  en;
    reg  rst_n;
    reg  start;

    // Sygnały wyjściowe z UUT (linie wire)
    wire [3:0]  len_seq;
    wire [35:0] seq;
    wire        done;

    // Instancjonowanie testowanego modułu (UUT)
    rand_gen uut (
        .clk(clk),
        .en(en),
        .rst_n(rst_n),
        .start(start),
        .len_seq(len_seq),
        .seq(seq),
        .done(done)
    );

    // 1. Generator zegara (Zapis do pliku VCD dla GTKWave)
    initial begin
        $dumpfile("rand_gen.vcd");
        $dumpvars(0, rand_gen_tb);
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // 2. Automatyczny weryfikator danych wyjściowych
    // Uruchamia się w momencie, gdy rand_gen wystawi sygnał done
    integer i;
    reg [3:0] current_val;
    reg       error_detected;

    always @(posedge clk) begin
        if (done) begin
            error_detected = 0;
            $display("[MONITOR: %t] FSM zgłasza DONE. Długość sekwencji: %d", $time, len_seq);
            $display("--- Analiza spakowanego rejestru seq (od tyłu): ---");
            
            // Dekodujemy rejestr seq element po elemencie na podstawie wylosowanej długości
            for (i = 0; i < len_seq; i = i + 1) begin
                current_val = seq[i*6 +: 4];
                
                // Sprawdzenie warunku modulo 9 (wartość musi być w zakresie 0..8)
                if (current_val >= 4'd9) begin
                    $display("[BŁĄD]: Element sekwencji nr %d ma wartość %d (Poza zakresem modulo 9!)", i, current_val);
                    error_detected = 1;
                end else begin
                    $display("  Pozycja %d: wartość = %d (OK)", i, current_val);
                end
            end
            
            if (!error_detected) begin
                $display("[SUKCES]: Cała sekwencja poprawna.\n");
            end else begin
                $display("[PORAŻKA]: Wykryto nieprawidłowe wartości w sekwencji!\n");
            end
        end
    end

    // 3. Scenariusz testowy (Stimulus)
    initial begin
        // Stan początkowy wejść
        rst_n = 0;
        start = 0;
        en    = 0;

        // Reset systemu przez 2 takty
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("======= ROZPOCZĘCIE TESTÓW MODUŁU RAND_GEN (MODULO 9) =======");

        // Wykonujemy 3 pełne cykle losowania sekwencji w strukturze fork-join
        fork
            begin
                // --- SEKWENCJA 1 ---
                run_generation_cycle();

                // --- SEKWENCJA 2 ---
                run_generation_cycle();

                // --- SEKWENCJA 3 ---
                run_generation_cycle();
            end
            
            // Watchdog - zabezpieczenie przed nieskończoną pętlą
            begin
                #(CLK_PERIOD * 300);
                $display("[KATASTROFA] Testbench przekroczył limit czasu! Prawdopodobny brak przejścia do stanu DONE.");
                $finish;
            end
        join_any

        $display("======= WSZYSTKIE CYKLE ZAKOŃCZONE =======");
        $finish;
    end

    // Zadanie (Task) automatyzujące pełne przejście maszyny stanów rand_gen
    task run_generation_cycle;
        begin
            // Krok A: Podanie impulsu start na dokładnie 1 takt
            @(posedge clk);
            #1;
            start = 1;
            @(posedge clk);
            #1;
            start = 0;

            // Krok B: Oczekiwanie na przejście modułu do stanu generowania danych
            // Moduł rand_gen potrzebuje 1 taktu w STATE_GEN_LEN_SEQ, zanim zacznie reagować na 'en'
            @(posedge clk);
            
            // Krok C: Podawanie sygnału 'en' i taktowanie procesu losowania liczb
            // Podajemy 'en' pulsacyjnie lub ciągle, dopóki moduł nie zgłosi sygnału 'done'
            while (!done) begin
                #1;
                en = 1;
                @(posedge clk);
                // Opcjonalnie: możesz dodać losowe opóźnienia wyłączenia en, 
                // aby sprawdzić, czy moduł poprawnie czeka z generowaniem na sygnał en.
            end
            
            #1;
            en = 0; // Wyczyszczenie sygnału en po zakończeniu losowania
            #(CLK_PERIOD * 3); // Odczekaj chwilę przerwy między kolejnymi losowaniami
        end
    endtask

endmodule