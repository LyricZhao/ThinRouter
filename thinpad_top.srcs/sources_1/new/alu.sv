`timescale 1ns / 1ps

module alu(
    input clk,
    input rst,
    input wire [3:0] op_code,
    input wire [15:0] data,

    output wire [15:0] leds
);

localparam  INPUT_DA = 2'b00,
            INPUT_DB = 2'b01,
            INPUT_OP = 2'b10,
            OUTPUT_S = 2'b11;

logic [1:0] state = INPUT_DA;

shortint data_a, data_b;
reg [15:0] flags;

enum Op_Type { ADD, SUB, AND, OR, XOR, NOT, SLL, SRL, SRA, ROL } ;

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
            return
        end

        SRL: begin
        end

        SRA: begin
        end

        ROL: begin
        end
    endcase
endfunction

always @(posedge rst) begin
    state <= INPUT_DA;
    leds <= 16'b0;
end

always @(posedge clk) begin
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

        /*  */
        OUTPUT_S: begin
            leds <= flags;
        end
    endcase
    state <= state + 1;
end