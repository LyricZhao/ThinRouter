`timescale 1ns / 1ps

module alu(
    input wire clock_btn,
    input wire reset_btn,
    input wire [15:0] dip_sw,

    output logic [15:0] led_bits
);

enum logic [1:0] { INPUT_DA, INPUT_DB, OUTPUT_S } StateType;
enum logic [3:0] { NOP, ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA, ROL } OpType;

logic overflow_flag = 0;
logic [1:0] input_state = 0;
shortint A, B, add_result, sub_result;

assign add_result = A + B;
assign sub_result = A - B;

always @(posedge clock_btn or posedge reset_btn) begin
    if (reset_btn) begin
        input_state <= 0;
    end else if (clock_btn) begin
        case (input_state)
            INPUT_DA: begin
                A <= dip_sw[15:0];
            end
            INPUT_DB: begin
                B <= dip_sw[15:0];
            end
            default: begin end
        endcase
        input_state <= input_state + 1;
    end
end

wire [3:0] op_code;
assign op_code = dip_sw[3:0];

always @(reset_btn, input_state, dip_sw) begin
    if (reset_btn) begin
        led_bits <= 16'b0;
    end else begin
        case (input_state)
            INPUT_DB: begin
                case (op_code)
                    ADD: begin
                        led_bits <= add_result;
                        overflow_flag <= ((A > 0) && (B > 0) && (add_result < 0)) || ((A < 0) && (B < 0) && (add_result > 0));
                    end
                    SUB: begin
                        led_bits <= sub_result;
                        overflow_flag <= ((A < 0) && (B > 0) && (sub_result > 0)) || ((A > 0) && (B < 0) && (sub_result < 0));
                    end
                    AND: begin led_bits <= A & B; overflow_flag <= 0;  end
                    OR:  begin led_bits <= A | B; overflow_flag <= 0;  end
                    XOR: begin led_bits <= A ^ B; overflow_flag <= 0;  end
                    NOT: begin led_bits <=   ~ A; overflow_flag <= 0;  end
                    SLL: begin led_bits <= A << B; overflow_flag <= 0; end
                    SRL: begin led_bits <= A >> B; overflow_flag <= 0; end
                    SRA: begin led_bits <= A >>> B; overflow_flag <= 0; end
                    ROL: begin led_bits <= (A << B) | (A >> (16 - B)); overflow_flag <= 0; end
                    default: begin end
                endcase
            end
            OUTPUT_S: begin
                led_bits <= overflow_flag;
            end
            default: begin end
        endcase
    end
end

endmodule