module seven_seg (
input wire [3:0] in,
output reg [6:0] out
);

always @(*) begin
    case (in)
        4'b0000: out = 7'b1000000; // 0
        4'b0001: out = 7'b1111001; // 1
        4'b0010: out = 7'b0100100; // 2
        4'b0011: out = 7'b0110000; // 3
        4'b0100: out = 7'b0011001; // 4
        4'b0101: out = 7'b0010010; // 5
        4'b0110: out = 7'b0000010; // 6
        4'b0111: out = 7'b1111000; // 7
        4'b1000: out = 7'b0000000; // 8
        4'b1001: out = 7'b0010000; // 9
        4'b1110: out = 7'b0000111; // E
        4'b1101: out = 7'b1000111; // L
        default: out = 7'b1111111; // Blank for invalid input
    endcase
end
    
endmodule