`timescale 1ns / 1ps

module alu(
    input wire clk,
    input wire rst,
    input wire [15:0] data,

    output logic [15:0] leds
);

enum logic [2:0] { INPUT_DA, INPUT_DB, INPUT_OP, OUTPUT_S } StateType;
enum logic [3:0] { ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA, ROL } OpType;

wire [3:0] op_code;
assign op_code = data[3:0];

logic [1:0] state = INPUT_DA;
shortint data_a, data_b;
logic [15:0] flags = 16'h0;

function shortint alu_result();
    case(op_code)
        ADD: begin
            return data_a + data_b;
        end

        SUB: begin
            return data_a - data_b;
        end

        AND: begin
            return data_a & data_b;
        end

        OR: begin
            return data_a | data_b;
        end

        XOR: begin
            return data_a ^ data_b;
        end

        NOT: begin
            return ~ data_a;
        end

        SLL: begin
            return data_a << data_b;
        end

        SRL: begin
            return data_a >> data_b;
        end

        SRA: begin
            return data_a >>> data_b;
        end

        /* note: 0 <= data_b <= 32 */
        ROL: begin
            return (data_a << data_b) | (data_a >> (32 - data_b));
        end
    endcase
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= INPUT_DA;
        leds <= 16'h0;
    end
    else begin
        case(state)
            /* Input data A */
            INPUT_DA: begin
                data_a <= data;
            end

            /* Input data B */
            INPUT_DB: begin
                data_b <= data;
            end

            /* Input OP code */
            INPUT_OP: begin
                leds <= alu_result();
            end

            /* Output flags */
            OUTPUT_S: begin
                leds <= flags;
            end
        endcase
        state <= state + 1;
    end
end

endmodule