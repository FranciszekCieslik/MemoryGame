module fsm_controller(
    input wire clk,
    input wire rst,
    input wire [2:0] current_state,
    output reg [1:0] c,
    output reg reset_signal,
    output reg lfsr_en,
    output reg mem_we,
    input wire [2:0] input_number,
    input wire [3:0] current_level,
    input wire [1:0] error_count,
    input wire iter_show_done,
    input wire sw_pressed,
    input wire comp_equ,
    input wire comp_no_equ
);

localparam S_RESET      = 3'b000;
localparam S_GENERATE   = 3'b001;
localparam S_SHOW       = 3'b010;
localparam S_USER_INPUT = 3'b011;
localparam S_COMPARE    = 3'b100;
localparam S_ERROR      = 3'b101;

reg [5:0] gen_counter;
wire gen_done = (gen_counter == 6'd54);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        gen_counter <= 6'b000000;
    end else if (current_state == S_GENERATE && !gen_done) begin
        gen_counter <= gen_counter + 6'd1;
    end else if (current_state == S_RESET) begin
        gen_counter <= 6'b000000;
    end
end

// FIX: blok kombinacyjny używa przypisań blokujących (=), nie nieblokujących (<=)
always @(*) begin
    c            = 2'b00;
    reset_signal = 1'b0;
    lfsr_en      = 1'b0;
    mem_we       = 1'b0;

    case (current_state)
        S_RESET: begin
            reset_signal = 1'b1;
            if (input_number == 3'd0 && error_count == 2'd0 && current_level == 4'd0)
                c = 2'b01;
        end

        S_GENERATE: begin
            if (!gen_done) begin
                lfsr_en = 1'b1;
                mem_we  = 1'b1;
            end else begin
                c = 2'b01;
            end
        end

        S_SHOW: begin
            if (iter_show_done)
                c = 2'b01;
        end

        S_USER_INPUT: begin
            if (sw_pressed)
                c = 2'b01;
        end

        // FIX: usunięto błędne 'c = 2'b00' które nadpisywało prawidłową wartość c
        //      gdy comp_equ == 1. Teraz logika jest rozłączna.
        S_COMPARE: begin
            if (comp_no_equ) begin
                c = 2'b10;                    // błąd → S_ERROR
            end else if (comp_equ) begin
                if (input_number == 3'd5)
                    c = 2'b01;                // koniec sekwencji → S_SHOW (nowy poziom)
                else
                    c = 2'b11;                // kolejny element → S_USER_INPUT
            end
            // else c = 2'b00 (domyślne) — czekamy na wynik
        end

        // FIX: S_ERROR sprawdza error_count — daje kolejną szansę zamiast
        //      bezwarunkowo resetować grę (poprzednio zawsze c=2'b10)
        S_ERROR: begin
            if (error_count == 2'd3)  // FIX: == 3 (po 3 błędach counter osiąga 3 przy MODULO=4)
                c = 2'b10;   // 3 błędy → S_RESET
            else
                c = 2'b01;   // zostały próby → S_SHOW (pokaż sekwencję ponownie)
        end

        default: c = 2'b00;
    endcase
end

endmodule