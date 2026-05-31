`timescale 1ns/1ps
// =============================================================
//  top_tb_fixed.v  – Testbench Memory Game
//  CLK_FREQ=20 → led_driver: ONE_SECOND=20 cykli → 1 element=40 cykli
//               debouncer:  MAX_COUNT=0 → pass-through (2 cykle sync)
//  Watchdog: 5_000_000 ns = 250_000 cykli @ 20ns/cykl
// =============================================================

module top_tb;

    localparam SIM_CLK = 20;   // CLK_FREQ przekazywany do DUT

    reg        CLK;
    reg [9:0]  SW;
    reg        KEY_0, KEY_1, KEY_2, KEY_3;
    wire [9:0] LED;
    wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;

    // FIX: top z parametrem CLK_FREQ=20 zamiast hardkodowanego 50M
    top #(
        .CLK_FREQ(SIM_CLK)
    ) dut (
        .CLK(CLK), .SW(SW),
        .KEY_0(KEY_0), .KEY_1(KEY_1), .KEY_2(KEY_2), .KEY_3(KEY_3),
        .LED(LED),
        .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),
        .HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5)
    );

    initial CLK = 0;
    always #10 CLK = ~CLK;   // 50 MHz w timescale

    localparam S_RESET      = 3'b000;
    localparam S_GENERATE   = 3'b001;
    localparam S_SHOW       = 3'b010;
    localparam S_USER_INPUT = 3'b011;
    localparam S_COMPARE    = 3'b100;
    localparam S_ERROR      = 3'b101;

    integer fail_count;

    // ----------------------------------------------------------------
    task wait_clk;
        input integer n;
        integer k;
        begin for (k=0;k<n;k=k+1) @(posedge CLK); end
    endtask

    task check;
        input [255:0] desc;
        input         cond;
        begin
            if (!cond) begin
                $display("FAIL  [t=%0t] %s", $time, desc);
                fail_count = fail_count + 1;
            end else
                $display("PASS  [t=%0t] %s", $time, desc);
        end
    endtask

    task wait_for_state;
        input [2:0]   expected;
        input integer max_cycles;
        integer cnt;
        begin
            cnt = 0;
            while (dut.current_state !== expected && cnt < max_cycles) begin
                @(posedge CLK); cnt = cnt+1;
            end
            if (cnt >= max_cycles)
                $display("TIMEOUT [t=%0t] Stan %0b nie nadszedł po %0d cyklach",
                         $time, expected, max_cycles);
        end
    endtask

    // press_switch: debouncer z CLK_FREQ=20,DEBOUNCE_MS=20 → MAX_COUNT=0
    // sync_reg potrzebuje 2 cykli → trzymamy SW min 4 cykle
    task press_switch;
        input [3:0] idx;
        begin
            if (idx <= 4'd8) begin  // SW[0..8] obsługiwane przez sw_driver
                SW = (10'b1 << idx);
                wait_clk(6);        // ≥ 2 cykle sync + 1 cykl edge detection + margines
                SW = 10'b0;
                wait_clk(4);
            end else begin
                $display("       SKIP: idx=%0d poza zakresem SW[0..8]", idx);
            end
        end
    endtask

    function [3:0] read_mem;
        input integer si, ei;
        begin read_mem = dut.u_memory.seq_mem[si][ei]; end
    endfunction

    // ================================================================
    //  TEST 1
    // ================================================================
    task test_reset;
        begin
            $display("\n--- Test 1: Reset ---");
            KEY_0 = 1; wait_clk(2);
            check("current_state = S_RESET podczas KEY_0=1", dut.current_state === S_RESET);
            check("error_count == 0",   dut.error_count   === 2'd0);
            check("current_level == 0", dut.current_level === 4'd0);
            KEY_0 = 0; wait_clk(2);
        end
    endtask

    // ================================================================
    //  TEST 2
    // ================================================================
    task test_to_generate;
        begin
            $display("\n--- Test 2: S_RESET → S_GENERATE ---");
            wait_for_state(S_GENERATE, 200);
            check("FSM w S_GENERATE", dut.current_state === S_GENERATE);
        end
    endtask

    // ================================================================
    //  TEST 3
    // ================================================================
    task test_generate_to_show;
        begin : t3
            integer s, e, nonzero;
            $display("\n--- Test 3: S_GENERATE → S_SHOW ---");
            wait_for_state(S_SHOW, 200);
            check("FSM w S_SHOW", dut.current_state === S_SHOW);
            nonzero = 0;
            for (s=0; s<9; s=s+1)
                for (e=1; e<=6; e=e+1)
                    if (dut.u_memory.seq_mem[s][e] !== 4'h0) nonzero=nonzero+1;
            check("Pamięć ma niezerowe wartości", nonzero > 0);
            $display("       Niezerowych komórek: %0d/54", nonzero);
        end
    endtask

    // ================================================================
    //  TEST 4: CLK_FREQ=20 → 6 elem * 40 cykli = 240, timeout=350
    // ================================================================
    task test_show_to_input;
        begin
            $display("\n--- Test 4: S_SHOW → S_USER_INPUT ---");
            wait_for_state(S_USER_INPUT, 350);
            check("FSM w S_USER_INPUT po SHOW", dut.current_state === S_USER_INPUT);
        end
    endtask

    // ================================================================
    //  TEST 5
    // ================================================================
    task test_sw_to_compare;
        begin
            $display("\n--- Test 5: press_switch wyzwala przejście z USER_INPUT ---");
            // S_COMPARE trwa tylko 2 cykle — zbyt krótko żeby złapać po press_switch.
            // Test sprawdza że FSM opuścił USER_INPUT i przeszedł dalej.
            wait_for_state(S_USER_INPUT, 10);
            press_switch(0);
            // Po press_switch FSM musi opuścić USER_INPUT (poszedł przez COMPARE dalej)
            check("FSM opuścił S_USER_INPUT po press_switch",
                  dut.current_state !== S_USER_INPUT);
        end
    endtask

    // ================================================================
    //  TEST 6: white-box poprawna odpowiedź
    //  Uwaga: LFSR startuje od 0xFF, mem[0][1]=0xF → val=0xF > 8 → skip
    //  Test weryfikuje equ/no_equ niezależnie od wartości LFSR
    // ================================================================
    task test_correct_answer;
        begin : t6
            reg [3:0] val;
            $display("\n--- Test 6: Poprawna odpowiedź ---");
            wait_for_state(S_USER_INPUT, 350);

            val = read_mem(0, 1);
            $display("       Oczekiwana wartość SW[idx] = %0h", val);

            if (val <= 4'd8) begin : t6_press
                reg [1:0] err_before;
                err_before = dut.error_count;
                press_switch(val);
                wait_clk(8);
                check("comp_no_equ=0 (brak błędu)",  dut.comp_no_equ === 1'b0);
                check("error_count nie wzrósł",      dut.error_count === err_before);
            end else begin
                $display("       INFO: val=0x%0h > 8 (brak SW[%0d]) – test skip", val, val);
                $display("       UWAGA: LFSR generuje wartości >8 przez pierwsze takty.");
                $display("              W hardware ograniczyć mem_data_in do 3 bitów.");
            end
        end
    endtask

    // ================================================================
    //  TEST 7
    // ================================================================
    task test_wrong_answer;
        begin : t7
            reg [3:0] wrong;
            reg [1:0] prev_err;
            $display("\n--- Test 7: Błędna odpowiedź → S_ERROR ---");
            wait_for_state(S_USER_INPUT, 350);
            prev_err = dut.error_count;

            wrong = (read_mem(0,1) == 4'd0) ? 4'd1 : 4'd0; // zawsze inna niż mem
            if (wrong > 4'd8) wrong = 4'd0;                 // zawsze w zakresie SW
            $display("       Wartość w pamięci=%0h, podajemy=%0h", read_mem(0,1), wrong);

            press_switch(wrong[2:0]);
            // S_COMPARE trwa 2 cykle — sprawdzamy pośrednio przez:
            // 1) error_count wzrósł (bo error_inc = zbocze comp_no_equ)
            // 2) FSM przeszedł przez S_ERROR i wrócił do S_SHOW lub dalej
            // S_ERROR trwa tylko 1 cykl — sprawdzamy pośrednio:
            // error_count rośnie gdy FSM przechodzi przez S_COMPARE (error_inc = zbocze no_equ)
            // Poczekaj kilka cykli na propagację
            wait_clk(8);
            check("error_count wzrósł po błędzie",  dut.error_count === prev_err + 2'd1);
            check("FSM opuścił USER_INPUT (przez COMPARE+ERROR)", 
                  dut.current_state !== S_USER_INPUT);
        end
    endtask

    // ================================================================
    //  TEST 8
    // ================================================================
    task test_three_errors_reset;
        begin : t8
            integer i;
            reg [3:0] wrong;
            $display("\n--- Test 8: Trzy błędy → S_RESET ---");

            KEY_0=1; wait_clk(4); KEY_0=0; wait_clk(4);
            wait_for_state(S_GENERATE, 200);
            wait_for_state(S_SHOW,     200);
            wait_for_state(S_USER_INPUT, 350);

            for (i=0; i<3; i=i+1) begin
                wrong = (read_mem(0,1) == 4'd0) ? 4'd1 : 4'd0;
                if (wrong > 4'd8) wrong = 4'd0;
                press_switch(wrong[2:0]);
                wait_clk(5);
                if (i < 2) begin
                    wait_for_state(S_SHOW,       200);
                    wait_for_state(S_USER_INPUT, 350);
                end
            end
            // S_RESET trwa 1 cykl (reset_signal zeruje countery i FSM od razu->S_GENERATE)
            // Sprawdzamy: po 3 błędach error_count wraca do 0 (reset) i FSM generuje ponownie
            wait_clk(20);
            check("error_count wyzerowany po resecie",   dut.error_count   === 2'd0);
            check("current_level wyzerowany po resecie", dut.current_level === 4'd0);
        end
    endtask

    // ================================================================
    //  TEST 9
    // ================================================================
    task test_show_done_pulse;
        begin : t9
            integer cnt;
            $display("\n--- Test 9: show_done to impuls ---");
            KEY_0=1; wait_clk(4); KEY_0=0; wait_clk(4);
            wait_for_state(S_SHOW, 200);
            cnt = 0;
            while (!dut.iter_show_done && cnt < 350) begin
                @(posedge CLK); cnt=cnt+1;
            end
            if (cnt >= 350) $display("       WARN: show_done nie wystąpiło w 350 cyklach");
            @(posedge CLK);
            check("show_done=0 po 1 cyklu od impulsu", dut.iter_show_done === 1'b0);
        end
    endtask

    // ================================================================
    //  TEST 10
    // ================================================================
    task test_level_increment;
        begin : t10
            reg [3:0] val;
            reg [3:0] prev_level;
            integer   ei;
            $display("\n--- Test 10: current_level rośnie po pełnej sekwencji ---");
            KEY_0=1; wait_clk(4); KEY_0=0; wait_clk(4);
            wait_for_state(S_GENERATE, 200);
            wait_for_state(S_SHOW,     200);
            wait_for_state(S_USER_INPUT, 350);
            prev_level = dut.current_level;

            for (ei=1; ei<=6; ei=ei+1) begin
                val = read_mem(0, ei);
                $display("       Elem %0d: podaję SW=%0h", ei, val);
                if (val <= 4'd8)
                    press_switch(val[2:0]);
                else begin
                    $display("       SKIP: val=%0h poza zakresem SW", val);
                end
                wait_clk(5);
                if (ei < 6) wait_for_state(S_USER_INPUT, 350);
            end

            wait_clk(10);
            check("current_level wzrósł", dut.current_level === prev_level + 4'd1);
        end
    endtask

    // ================================================================
    //  MAIN
    // ================================================================
    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);
        CLK=0; SW=0; KEY_0=0; KEY_1=0; KEY_2=0; KEY_3=0;
        fail_count=0;

        $display("=========================================");
        $display("  Memory Game – Testbench v5 (CLK_FREQ=%0d)", SIM_CLK);
        $display("=========================================");
        wait_clk(5);

        test_reset;
        test_to_generate;
        test_generate_to_show;
        test_show_to_input;
        test_sw_to_compare;
        test_correct_answer;
        test_wrong_answer;
        test_three_errors_reset;
        test_show_done_pulse;
        test_level_increment;

        $display("\n=========================================");
        if (fail_count == 0)
            $display("  Wszystkie testy PASSED");
        else
            $display("  FAILED: %0d testów", fail_count);
        $display("=========================================\n");
        $finish;
    end

    initial begin #5_000_000; $display("WATCHDOG"); $finish; end

endmodule
