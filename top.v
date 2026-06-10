module top #(
    parameter CLK_FREQ = 50_000_000
)(
input wire CLK,
input wire [9:0] SW,
input wire KEY_0,

output [9:0] LED,
output [6:0] HEX0,
output [6:0] HEX1,
output [6:0] HEX2,
output [6:0] HEX3,
output [6:0] HEX4,
output [6:0] HEX5
);

wire [3:0] last_sw;
wire [2:0] current_state;
wire [3:0] current_level;
wire [1:0] controller_signals;
wire [1:0] error_count;
wire reset_signal;
wire [2:0] input_number;
wire LED_ready;
wire [7:0] lfsr_out;

wire [3:0] lfsr_raw = lfsr_out[3:0];
wire [3:0] mem_data_in = (lfsr_raw > 4'd9) ? (lfsr_raw - 4'd10) : lfsr_raw;

wire [6:0] iter_mem_addr;
wire       iter_re;
wire [3:0] iter_out;
wire       iter_show_done;
wire [3:0] mem_data_out;
wire comp_no_equ;
wire comp_equ;
wire sw_pressed_raw;
wire [3:0] sw_idx_raw;

wire ctrl_lfsr_en;
wire ctrl_mem_we;

// ---------------------------------------------------------------
// EDGE DETECTION: sw_pressed (poziom → impuls)
// ---------------------------------------------------------------
reg sw_pressed_d;
always @(posedge CLK or posedge KEY_0)
    if (KEY_0) sw_pressed_d <= 1'b0;
    else       sw_pressed_d <= sw_pressed_raw;

wire sw_edge = sw_pressed_raw & ~sw_pressed_d;

reg [3:0] last_sw_reg;
always @(posedge CLK or posedge KEY_0)
    if (KEY_0)        last_sw_reg <= 4'b0;
    else if (sw_edge) last_sw_reg <= sw_idx_raw;

assign last_sw = last_sw_reg;

// ---------------------------------------------------------------
// EDGE DETECTION: comp_no_equ i comp_equ (poziom → impuls)
// ---------------------------------------------------------------
reg comp_no_equ_d;
always @(posedge CLK or posedge KEY_0)
    if (KEY_0) comp_no_equ_d <= 1'b0;
    else       comp_no_equ_d <= comp_no_equ;

wire error_inc = comp_no_equ & ~comp_no_equ_d;

reg comp_equ_d;
always @(posedge CLK or posedge KEY_0)
    if (KEY_0) comp_equ_d <= 1'b0;
    else       comp_equ_d <= comp_equ;

wire comp_equ_edge = comp_equ & ~comp_equ_d;

// input_counter inkrementuje PO weryfikacji (nie przy naciśnięciu)
wire input_inc = comp_equ_edge && (current_state == 3'b100);  // S_COMPARE

// level_counter inkrementuje przy ostatnim poprawnym elemencie
wire level_inc = comp_equ_edge && (input_number == 3'd5) && (current_state == 3'b100);

// ---------------------------------------------------------------
// Instancje modułów
// ---------------------------------------------------------------
seven_seg seg0(.in(current_level),        .out(HEX0));
seven_seg seg1(.in(4'b1101),              .out(HEX1)); // L
seven_seg seg2(.in({2'd0, error_count}),  .out(HEX2));
seven_seg seg3(.in(4'b1110),              .out(HEX3)); // E
seven_seg seg4(.in(last_sw),              .out(HEX4));
seven_seg seg5(.in({1'b0, current_state}),.out(HEX5));

sw_driver #(
    .CLK_FREQ(CLK_FREQ),
    .DEBOUNCE_MS(20)
) sw_drv (
    .clk(CLK),
    .pressed(sw_pressed_raw),
    .SW(SW),
    .sw_idx(sw_idx_raw)
);

led_driver #(
    .CLK_FREQ(CLK_FREQ)
) led_drv (
    .clk(CLK),
    .in((current_state == 3'b010) ? iter_out : 4'hF),
    .LED(LED[9:0]),
    .ready(LED_ready)
);

fsm u_fsm (
    .clk(CLK),
    .rst(KEY_0),
    .c(controller_signals),
    .CURRENT_STATE(current_state)
);

fsm_controller u_fsm_controller (
    .clk(CLK),
    .rst(KEY_0),
    .current_state(current_state),
    .c(controller_signals),
    .reset_signal(reset_signal),
    .lfsr_en(ctrl_lfsr_en),
    .mem_we(ctrl_mem_we),
    .input_number(input_number),
    .error_count(error_count),
    .current_level(current_level),
    .iter_show_done(iter_show_done),
    .sw_pressed(sw_edge),
    .comp_equ(comp_equ),
    .comp_no_equ(comp_no_equ)
);

counter #(.MODULO(6)) input_counter (
    .clk(CLK), .rst(reset_signal), .inc(input_inc),
    .out(input_number), .is_max()
);

counter #(.MODULO(4)) error_counter (
    .clk(CLK), .rst(reset_signal), .inc(error_inc),
    .out(error_count), .is_max()
);

counter #(.MODULO(9)) level_counter (
    .clk(CLK), .rst(reset_signal), .inc(level_inc),
    .out(current_level), .is_max()
);

lfsr #(.WIDTH(8), .TAPS(8'hB8)) u_lfsr (
    .clk(CLK),
    .rst_n(~reset_signal),
    .en(ctrl_lfsr_en),
    .out(lfsr_out)
);

memory u_memory (
    .clk(CLK),
    .rst(reset_signal),
    .we(ctrl_mem_we),
    .data_in(mem_data_in),
    .re(iter_re),
    .addr(iter_mem_addr),
    .data_out(mem_data_out)
);

iterator u_iterator (
    .clk(CLK),
    .rst(reset_signal),
    .current_state(current_state),
    .current_level(current_level),
    .input_number(input_number),
    .next_elem(LED_ready),
    .re(iter_re),
    .mem_addr(iter_mem_addr),
    .rdata(mem_data_out),
    .out(iter_out),
    .valid(),
    .show_done(iter_show_done)
);

comparator #(.bit_num(4)) comp (
    .clk(CLK),
    .en(current_state == 3'b100),
    .usr_in(last_sw),
    .mem_in(mem_data_out),
    .no_equ(comp_no_equ),
    .equ(comp_equ)
);

endmodule
