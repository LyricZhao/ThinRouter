`timescale 1ns / 1ps

module alu(
    input wire clk,
    input wire rst,
    input wire [15:0] data,

    output logic [15:0] leds
);

enum logic [1:0] { INPUT_DA, INPUT_DB, INPUT_OP, OUTPUT_S } StateType;
enum logic [3:0] { NOP, ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA, ROL } OpType;

wire [3:0] op_code;
assign op_code = data[3:0];

logic [1:0] state = INPUT_DA;
shortint data_a, data_b;
logic [15:0] flags = 16'h0;

function shortint alu_result();
    case(op_code)
        ADD: begin
            // TODO: test flags[0] <= ((data_a + data_b) < data_a);
            shortint add_result = data_a + data_b;
            if ((data_a > 0) && (data_b > 0) && (add_result < 0) ||
                (data_a < 0) && (data_b < 0) && (add_result > 0)) begin
                flags[0] <= 1'b1;
            end else begin
                flags[0] <= 1'b0;
            end
            return add_result;
        end

        SUB: begin
            // TODO: flags[0] <= ((data_a - data_b) > data_a);
            shortint sub_result = data_a - data_b;
            if ((data_a < 0) && (data_b > 0) && (sub_result > 0) ||
                (data_a > 0) && (data_b < 0) && (sub_result < 0)) begin
                flags[0] <= 1'b1;
            end else begin
                flags[0] <= 1'b0;
            end
            return sub_result;
        end

        AND: begin
            flags[0] <= 1'b0;
            return data_a & data_b;
        end

        OR: begin
            flags[0] <= 1'b0;
            return data_a | data_b;
        end

        XOR: begin
            flags[0] <= 1'b0;
            return data_a ^ data_b;
        end

        NOT: begin
            flags[0] <= 1'b0;
            return ~ data_a;
        end

        SLL: begin
            flags[0] <= 1'b0;
            return data_a << data_b;
        end

        SRL: begin
            flags[0] <= 1'b0;
            return data_a >> data_b;
        end

        SRA: begin
            flags[0] <= 1'b0;
            return data_a >>> data_b;
        end

        /* note: 0 <= data_b <= 32 */
        ROL: begin
            flags[0] <= 1'b0;
            return (data_a << data_b) | (data_a >> (32 - data_b));
        end
    endcase
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= INPUT_DA;
        leds <= 16'h0;
        flags <= 16'h0;
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