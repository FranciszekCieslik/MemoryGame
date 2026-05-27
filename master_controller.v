module master_controller(
    input wire clk,
    input      [2:0] CURRRENT_STATE,
    output reg [1:0] STATE_CONTROL,

    output reg       rg_en, 
    output reg       rg_rst_n,
    output reg       rg_start,

    input  wire      rg_done,
    output reg       it_start,
    output reg       it_mode,

    input wire       it_done,
    input wire       led_ready,
    input wire       sw_pressed,
    input wire       comp_no_equ,
    input wire       comp_equ,
    input wire       last_element,
    input wire       max_error,

    output reg       sq_mem_rstn,
    output reg       it_rst_n,
    output reg       led_rst_n,
    output reg       in_cnt_rstn,
    output reg       error_cnt_rstn,
    output reg       lvl_cnt_rstn,
    output reg       lvl_cnt_inc
);

    localparam S_RESET      = 3'b000;
    localparam S_GENERATE   = 3'b001;
    localparam S_SHOW       = 3'b010;
    localparam S_USER_INPUT = 3'b011;
    localparam S_COMPARE    = 3'b100;
    localparam S_ERROR      = 3'b101;

    reg prev_gen;
    always @(posedge clk) prev_gen <= (CURRRENT_STATE == S_GENERATE);
    wire gen_entry = (CURRRENT_STATE == S_GENERATE) && !prev_gen;

    // Blok całkowicie kombinatoryczny - brak latchy dzięki wartościom domyślnym
    always @(*) begin
        // --- WARTOŚCI DOMYŚLNE ---
        // Każdy rejestr modyfikowany wewnątrz bloku musi mieć przypisaną wartość startową
        STATE_CONTROL   = 2'b00;
        rg_en           = 1'b0;
        rg_rst_n        = 1'b1; // Aktywne niskim (zakładam domyślnie 1 - brak resetu)
        it_start        = 1'b0;
        it_mode         = 1'b0;
        sq_mem_rstn     = 1'b1;
        it_rst_n        = 1'b1;
        led_rst_n       = 1'b1;
        in_cnt_rstn     = 1'b1;
        error_cnt_rstn  = 1'b1;
        lvl_cnt_rstn    = 1'b1;
        lvl_cnt_inc     = 1'b0;

        case (CURRRENT_STATE)

            S_RESET: begin
                sq_mem_rstn    = 1'b0;
                it_rst_n       = 1'b0;
                led_rst_n      = 1'b0;
                in_cnt_rstn    = 1'b0;
                error_cnt_rstn = 1'b0;
                lvl_cnt_rstn   = 1'b0;
                STATE_CONTROL  = 2'b01; // Przejdź do GENERATE
            end

            S_GENERATE: begin
                rg_en    = 1'b1;
                rg_rst_n = 1'b0; // Wyzwolenie resetu generatora? (Jeśli tak było w oryginale)
                it_start = 1'b0;
                it_mode  = 1'b0;
                if (rg_done) begin
                    STATE_CONTROL = 2'b01;
                end else begin
                    STATE_CONTROL = 2'b00; // Zostań w stanie
                end
            end

            S_SHOW: begin
                in_cnt_rstn = 1'b1; 
                it_start    = 1'b1;
                it_mode     = 1'b0;
                if (it_done && led_ready) begin
                    STATE_CONTROL = 2'b01;
                end else begin
                    STATE_CONTROL = 2'b00;
                end
            end

            S_USER_INPUT: begin
                it_mode = 1'b1;
                if (sw_pressed) begin
                   STATE_CONTROL = 2'b01;
                end else begin
                    STATE_CONTROL = 2'b00;
                end
            end
            
            S_COMPARE: begin
                if (comp_equ && last_element) begin
                    lvl_cnt_inc   = 1'b1;
                    STATE_CONTROL = 2'b01; // Wróć do generowania
                end else if (comp_no_equ) begin
                    STATE_CONTROL = 2'b10; // Wystąpił błąd
                end else begin
                    STATE_CONTROL = 2'b11; // Wróć do wyboru użytkownika
                end
            end
            
            S_ERROR: begin
                if (max_error)
                    STATE_CONTROL = 2'b10; // Koniec gry, resetuj
                else
                    STATE_CONTROL = 2'b01; // Przejdź do SHOW
            end
            
            default: begin
                STATE_CONTROL = 2'b00;
            end

        endcase
    end

endmodule