/*
hilo_reg:
    实现了HI, LO两个特殊寄存器
*/

`include "constants_cpu.vh"

module hilo_reg(
	input  logic    clk,
	input  logic    rst,
	
	input  logic    we,
	input  word_t	hi_i,
    input  word_t   lo_i,
	
	output word_t   hi_o,
    output word_t   lo_o
);

always_ff @(posedge clk) begin
    if (rst == 1'b1) begin
        {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
    end else if (we == 1'b1) begin
        {hi_o, lo_o} <= {hi_i, lo_i};
    end
end

endmodule