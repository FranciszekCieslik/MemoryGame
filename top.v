module top(
input wire CLK,
input wire [9:0] SW,
input wire KEY_0,
output [9:0] LED,
output [6:0] HEX0,
output [6:0] HEX1
);

wire [2:0] state;
wire [3:0] len_seq;
wire [3:0] wdata;
wire [1:0] state_ctrl;
// === rand_reg ===
wire rg_en;
wire rg_rst_n;
wire rg_start;
wire rg_we;
wire rg_done;
// === seq_memory ===
wire sq_mem_rstn;
wire sq_mem_re;
wire [3:0]  sq_mem_raddr;      // adres rundy do odczytu (0..8)
wire [3:0]  sq_mem_len_rdata;  // odczytana długość sekwencji dla danej rundy 
wire [3:0]  sq_mem_rdata;       // odczytany element sekwencji (sekwencyjny) 
wire last_element;
// === iterator ===
wire it_rst_n;
wire it_start;
wire it_mode;
wire [3:0]  it_out;
wire it_done;
wire it_valid;
wire [5:0]  it;
// === led_driver ===
wire led_ready;
wire led_rst_n;
wire led_next_elem;
// === sw_driver ===
wire [3:0] sw_idx;
wire sw_pressed;
// === input counter ===
wire in_cnt_rstn;
wire in_cnt_is_max;
// === comparator ===
wire comp_no_equ;
wire comp_equ;
wire comp_en;
// == lvl and error counters ==
wire last_lvl;
wire max_error; 
wire [3:0] lvl_cnt_out;
wire [1:0] error_cnt_out;
wire error_cnt_rstn;
wire lvl_cnt_rstn;
wire lvl_cnt_inc;

fsm u_fsm(
.clk(CLK),
.c(state_ctrl),
.CURRRENT_STATE(state)
);

master_controller u_master_controller(
.clk(CLK),
.CURRRENT_STATE(state),
.STATE_CONTROL(state_ctrl),
.rg_en(rg_en), 
.rg_rst_n(rg_rst_n),
.rg_start(rg_start),
.rg_done(rg_done),
.it_start(it_start),
.it_mode(it_mode),
.it_done(it_done),
.led_ready(led_ready),
.sw_pressed(sw_pressed),
.comp_no_equ(comp_no_equ),
.comp_equ(comp_equ),
.last_element(last_element),
.max_error(max_error),
.sq_mem_rstn(sq_mem_rstn),
.it_rst_n(it_rst_n),
.led_rst_n(led_rst_n),
.in_cnt_rstn(in_cnt_rstn),
.error_cnt_rstn(error_cnt_rstn),
.lvl_cnt_rstn(lvl_cnt_rstn),
.lvl_cnt_inc(lvl_cnt_inc)
);

rand_gen u_rand_gen(
    .clk(CLK),
    .en(rg_en),
    .rst_n(rg_rst_n),
    .start(rg_start),        // impuls 1-taktowy od FSM
	 
    .len_seq(len_seq),
    .we(rg_we),           // impuls zapisu: wysyłany dla każdego elementu
    .wdata(wdata),        // aktualnie wygenerowany element (4 bity)
    .done(rg_done)          // impuls 1-taktowy: cała sekwencja gotowa
);

seq_memory u_seq_memory(
    .clk(CLK),
    .rst_n(sq_mem_rstn),
    // port zapisu (Rand Gen)
    .we(rg_we),         // impuls zapisu pojedynczego elementu (4 bity)
    .done(rg_done),       // impuls końca generowania sekwencji (z rand_gen)
    .len_seq(len_seq),    // ostateczna ilość elementów w sekwencji
    .wdata(wdata),      // 4-bitowy element przesyłany strumieniowo
    // port odczytu 
    .re(sq_mem_re),         // impuls/sygnał odczytu 
    .raddr(sq_mem_raddr),      // adres rundy do odczytu (0..8)
    .len_rdata(sq_mem_len_rdata),  // odczytana długość sekwencji dla danej rundy 
    .rdata(sq_mem_rdata),      // odczytany element sekwencji (sekwencyjny) 
    .last_element(last_element)
);


iterator u_iterator(
    .clk(CLK),
    .rst_n(it_rst_n),
    .start(it_start),         // impuls uruchamiający
    .mode(it_mode),          // 0: iteracja, 1: szybki skok (it)
    .it(it),            // który globalny element zwrócić (dla mode=1)
    .next_elem(led_next_elem),     // NOWE: żądanie kolejnego elementu z drivera LED

    // Połączenia z pamięcią seq_memory
    .re(sq_mem_re),            // sygnał odczytu dla pamięci
    .raddr(sq_mem_raddr),         // adres rundy (0..8)
    .len_rdata(sq_mem_len_rdata),     // długość sekwencji z pamięci
    .rdata(sq_mem_rdata),         // dane z pamięci

    // Wyjścia iteratora
    .out(it_out),           // aktualnie czytany element
    .valid(it_valid),         // HIGH gdy dane na wyjściu 'out' są ważne
    .done(it_done)           // impuls końca pracy
);

led_driver #(
    .LED_ON_TIME(200_000_000), // czas świecenia (cykle)
    .WAIT_TIME(100_000_000)  // czas przerwy (cykle)
) u_led_driver(
    .clk(CLK),
    .rst_n(led_rst_n),
    .in(it_out),         // podpięte pod 'out' z iteratora
    .valid(it_valid),      // podpięte pod 'valid' z iteratora
    .next_elem(led_next_elem),  // żądanie kolejnego elementu do iteratora
    .LED(LED),
    .ready(led_ready)       // HIGH gdy driver jest bezczynny i gotowy
);

sw_driver #(
    .CLK_FREQ(50_000_000),
    .DEBOUNCE_MS(20),
    .SW_NUM(10)
) u_sw_driver(
    .SW(SW), 
    .clk(CLK),
    .pressed(sw_pressed),
    .sw_idx(sw_idx)
);

counter #(
    .MODULO(36)
) input_counter(
    .clk(CLK),
    .rstn(in_cnt_rstn),
    .inc(sw_pressed),
    .mod_en(1'b1),
    .out(it),
    .is_max(in_cnt_is_max)
);

assign comp_en = sw_pressed;

comparator #(
    .bit_num(3'd4)
) comp(
.clk(CLK),
.en(comp_en),
.usr_in(sw_idx),
.mem_in(it_out),
.no_equ(comp_no_equ),
.equ(comp_equ)
);

counter #(
    .MODULO(3)
) error_counter(
    .clk(CLK),
    .rstn(error_cnt_rstn),
    .inc(comp_no_equ),
    .mod_en(1'b1),
    .out(error_cnt_out),
    .is_max(max_error)
);

counter #(
    .MODULO(9)
) lvl_counter(
    .clk(CLK),
    .rstn(lvl_cnt_rstn),
    .inc(lvl_cnt_inc),
    .mod_en(1'b1),
    .out(lvl_cnt_out),
    .is_max(last_lvl)
);

_7seg_driver lvl_7seg(
.in(lvl_cnt_out), 
.seg(HEX1)
);

_7seg_driver error_7seg(
.in({2'b00,error_cnt_out}), 
.seg(HEX0)
);

endmodule