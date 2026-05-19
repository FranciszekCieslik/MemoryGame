module seq_memory (
    input  wire        clk,
    input  wire        rst_n,
    // port zapisu (Rand Gen)
    input  wire        we,
    input  wire [6:0]  waddr,     // 0..89
    input  wire [3:0]  wdata,     // indeks LED 0..9
    // port zapisu długości
    input  wire        len_we,
    input  wire [3:0]  len_waddr, // 0..8 (runda)
    input  wire [3:0]  len_wdata, // 1..10
    // port odczytu (Iterator / Comparator)
    input  wire [6:0]  raddr,
    output reg  [3:0]  rdata,
    // port odczytu długości
    input  wire [3:0]  len_raddr,
    output reg  [3:0]  len_rdata
);
    reg [3:0] seq_mem [0:89];
    reg [3:0] len_mem [0:8];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 90; i = i + 1)
                seq_mem[i] <= 4'd0;
            for (i = 0; i < 9; i = i + 1)
                len_mem[i] <= 4'd0;
        end else begin
            if (we)      seq_mem[waddr]     <= wdata;
            if (len_we)  len_mem[len_waddr] <= len_wdata;
        end
    end

    // odczyt asynchroniczny
    always @(*) begin
        rdata     = seq_mem[raddr];
        len_rdata = len_mem[len_raddr];
    end
endmodule