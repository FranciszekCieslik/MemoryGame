`timescale 1ns / 1ps

module top_tb;

    // --- Sygnały wejściowe do testowanego modułu (DUT) ---
    reg CLK;
    reg [9:0] SW;
    reg KEY_0;

    // --- Sygnały wyjściowe z DUT ---
    wire [9:0] LED;
    wire [6:0] HEX0;
    wire [6:0] HEX1;

    // --- Instancja testowanego modułu top ---
    top uut (
        .CLK(CLK),
        .SW(SW),
        .KEY_0(KEY_0),
        .LED(LED),
        .HEX0(HEX0),
        .HEX1(HEX1)
    );

    // --- Generowanie zegara 50 MHz (okres 20ns) ---
    always begin
        #10 CLK = ~CLK;
    end
    
    initial begin
        #30000000; // 30 ms
        $display("[TB] BŁĄD: Osiągnięto limit czasu symulacji (Timeout)!");
        $finish;
    end

    // --- Główna sekwencja testowa ---
    initial begin
        // Inicjalizacja sygnałów
        CLK = 0;
        SW = 10'b0000000000;
        KEY_0 = 1; // Zakładamy stan wysoki (nieaktywny)

        $display("Rozpoczęcie symulacji modułu top...");

        // 1. Krok: Reset systemu
        #40;
        KEY_0 = 0; // Aktywowanie resetu (jeśli KEY_0 odpowiada za reset sprzętowy)
        #40;
        KEY_0 = 1;
        #20;

        // Poczekaj chwilę w stanie RESET / GENERATE
        $display("System po resecie, oczekiwanie na zakończenie generowania sekwencji...");
        
        // 2. Krok: Symulacja zakończenia działania generatora losowego (rand_gen)
        // W prawdziwym układzie steruje tym FSM, tutaj czekamy aż u_rand_gen podniesie rg_done.
        // Dla celów testowych wymuszamy przejście stanów lub czekamy na stabilizację sygnałów.
        @(posedge uut.rg_done);
        $display("Generator losowy zakończył pracę (rg_done = 1).");

        // 3. Krok: Stan SHOW (Wyświetlanie sekwencji)
        // Oczekujemy, aż iterator zakończy podawanie danych do drivera LED
        $display("Oczekiwanie na zakończenie sekwencji wyświetlania (it_done)...");
        @(posedge uut.it_done);
        #100; // Krótka przerwa

        // 4. Krok: Symulacja wprowadzania danych przez użytkownika (S_USER_INPUT)
        // Sprawdzamy jaki element jest aktualnie oczekiwany w pamięci, aby podać poprawny switch.
        // uut.it_out reprezentuje poprawny element z pamięci dla aktualnego kroku użytkownika.
        
        $display("Rozpoczęcie wprowadzania sekwencji przez użytkownika.");
        
        // Krok USER 1: Poprawny przycisk
        #100;
        SW = (1 << uut.it_out); // Ustawiamy przełącznik odpowiadający oczekiwanemu indeksowi
        $display("Użytkownik klika przełącznik dla indeksu: %d", uut.it_out);
        #40;
        SW = 10'b0000000000; // Zwolnienie przełącznika
        
        // Oczekiwanie na przetworzenie porównania przez układ
        #200;

        // Krok USER 2: Symulacja kolejnego kliknięcia (jeśli gra wymaga kolejnego kroku)
        if (!uut.last_element) begin
            SW = (1 << uut.it_out);
            $display("Użytkownik klika kolejny przełącznik dla indeksu: %d", uut.it_out);
            #40;
            SW = 10'b0000000000;
            #200;
        end

        // Krok USER 3: Symulacja błędu użytkownika (kliknięcie złego przełącznika)
        // Odwracamy bit, aby podać błędną wartość do komparatora
        $display("Test: Symulacja błędnego kliknięcia...");
        SW = (uut.it_out == 0) ? 10'b0000000010 : 10'b0000000001; 
        #40;
        SW = 10'b0000000000;
        #200;

        // Sprawdzenie stanu liczników po błędzie
        $display("Aktualny stan licznika błędów: %d", uut.error_cnt_out);
        $display("Aktualny poziom gry (lvl): %d", uut.lvl_cnt_out);

        // Zakończenie symulacji po odpowiednim czasie
        #1000;
        $display("Symulacja zakończona sukcesem.");
        $finish;
    end

    // --- Monitorowanie stanów w konsoli symulatora ---
    initial begin
        $monitor("Czas: %0t | FSM State: %b | SW: %b | LED: %b | Wyświetlacz LVL (HEX1): %b", 
                 $time, uut.state, SW, LED, HEX1);
    end

endmodule