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

function shortint alu_result();
    
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