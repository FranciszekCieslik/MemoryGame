module iterator (
    input wire         clk,
    input wire         rst,
    input wire [2:0]   current_state,
    input wire [3:0]   current_level,  // 4 bity — poziomy 0..8
    input wire [2:0]   input_number,   // indeks 0..5

    input wire         next_elem,      // 'ready' z led_drivera

    // Interfejs do pamięci
    output wire        re,
    output wire [6:0]  mem_addr, 
    input wire  [3:0]  rdata,

    // Wyjścia
    output reg [3:0]   out,
    output reg         valid,
    output reg         show_done
);

    localparam S_SHOW    = 3'b010;
    localparam S_COMPARE = 3'b100;

    localparam SHOW_IDLE = 1'b0;
    localparam SHOW_PLAY = 1'b1;

    reg       show_state;
    reg [2:0] elem_counter;
    reg       wait_for_driver;

    assign re = (current_state == S_COMPARE);
    assign mem_addr =
        (current_state == S_COMPARE)
            ? {current_level[3:0], (input_number[2:0] + 3'd1)}
        : (current_state == S_SHOW && show_state == SHOW_PLAY)
            ? {current_level[3:0], elem_counter[2:0]}
        : 7'b0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            show_state      <= SHOW_IDLE;
            elem_counter    <= 3'd1;
            wait_for_driver <= 1'b0;
            out             <= 4'hF;
            valid           <= 1'b0;
            show_done       <= 1'b0;
        end else begin
            valid     <= 1'b0;
            show_done <= 1'b0;

            case (current_state)
                S_SHOW: begin
                    case (show_state)
                        SHOW_IDLE: begin
                            elem_counter    <= 3'd1;
                            wait_for_driver <= 1'b0;
                            show_state      <= SHOW_PLAY;
                        end
                        SHOW_PLAY: begin
                            if (!wait_for_driver) begin
                                out             <= rdata;
                                valid           <= 1'b1;
                                wait_for_driver <= 1'b1;
                            end else begin
                                out <= 4'hF;
                                if (next_elem) begin
                                    if (elem_counter < 3'd6) begin
                                        elem_counter    <= elem_counter + 3'd1;
                                        wait_for_driver <= 1'b0;
                                    end else begin
                                        show_done  <= 1'b1;
                                        show_state <= SHOW_IDLE;
                                    end
                                end
                            end
                        end
                    endcase
                end

                S_COMPARE: begin
                    show_state <= SHOW_IDLE;
                    out        <= rdata;
                    valid      <= 1'b1;
                end

                default: begin
                    show_state <= SHOW_IDLE;
                    out        <= 4'hF;
                end
            endcase
        end
    end
endmodule
