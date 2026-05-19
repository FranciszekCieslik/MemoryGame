`timescale 1ns / 1ps

module lfsr_tb;

    // 1. Definicja parametrów testowych
    parameter WIDTH = 8;
    parameter TAPS  = 8'hB8;

    // 2. Deklaracja sygnałów dla DUT (Design Under Test)
    reg              clk;
    reg              rst_n;
    reg              en;
    wire [WIDTH-1:0] out;

    // 3. Instancjonowanie modułu LFSR z przekazaniem parametrów
    lfsr #(
        .WIDTH(WIDTH),
        .TAPS(TAPS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .out(out)
    );

    // 4. Generator zegara (okres 20ns -> częstotliwość 50MHz)
    always #10 clk = ~clk;

    // 5. Główny blok bodźców (Stimulus)
    initial begin
        $dumpfile("lfsr.vcd"); // Nazwa pliku z wykresami
        $dumpvars(0, lfsr_tb);      // Zapisuj wszystkie sygnały z lfsr_tb
        
        // Inicjalizacja sygnałów wejściowych
        clk   = 0;
        rst_n = 0; // Aktywujemy reset na starcie
        en    = 0;

        // Czekamy 15ns i zdejmujemy reset (w stanie wysokim rst_n)
        #15 rst_n = 1;
        #10;

        // Test 1: Sprawdzenie czy LFSR stoi w miejscu, gdy en = 0
        $display("--- Test 1: Brak en (LFSR powinien stać w miejscu) ---");
        #20; 

        // Test 2: Włączenie en i generowanie sekwencji
        $display("--- Test 2: Włączenie en (Generowanie sekwencji) ---");
        en = 1;
        #200; // Pozwalamy układowi działać przez 20 cykli zegara

        // Test 3: Wyłączenie en w trakcie pracy
        $display("--- Test 3: Zatrzymanie en w trakcie pracy ---");
        en = 0;
        #30;

        // Test 4: Ponowne włączenie i nagły reset
        $display("--- Test 4: Ponowne uruchomienie i asynchroniczny reset ---");
        en = 1;
        #30;
        rst_n = 0; // Nagły reset w trakcie pracy
        #10;
        rst_n = 1; // Powrót do pracy
        #50;

        // Zakończenie symulacji
        $display("--- Koniec symulacji ---");
        $finish;
    end

    // 6. Monitorowanie wyników w konsoli tekstowej
    initial begin
        $monitor("Czas: %0t ns | rst_n: %b | en: %b | out: %b (0x%h)", 
                 $time, rst_n, en, out, out);
    end

endmodule
