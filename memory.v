module memory(
input wire clk,
input wire rst,
input wire we,
input wire [3:0] data_in,
input wire re,
input wire [6:0] addr,
output wire [3:0] data_out
);

reg [3:0] seq_mem [0:8][0:6];
reg [5:0] amount_of_elements;

integer seq_idx;
integer elem_idx;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        amount_of_elements <= 6'b000000;
        begin : reset_loop
            integer i, j;
            for (i = 0; i < 9; i = i + 1)
                for (j = 0; j < 7; j = j + 1)
                    seq_mem[i][j] <= 4'b0000;
        end
    end else begin
        if (we) begin
            if (amount_of_elements < 54) begin
                seq_idx  = amount_of_elements / 6;
                elem_idx = (amount_of_elements % 6) + 1;
                seq_mem[seq_idx][elem_idx] <= data_in;
                amount_of_elements         <= amount_of_elements + 1'b1;
            end
        end
    end
end

// Asynchroniczny odczyt: addr[6:3] → sekwencja (0..8), addr[2:0] → element (0..6)
assign data_out = re ? seq_mem[addr[6:3]][addr[2:0]] : 4'b0;

endmodule
