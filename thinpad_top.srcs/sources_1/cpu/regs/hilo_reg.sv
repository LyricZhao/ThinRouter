/*
hilo_reg:
    实现了HI, LO两个特殊寄存器
*/

`include "cpu_defs.vh"

module hilo_reg(
    input  logic    clk,
    input  logic    rst,
       
    input  logic    we,     // 是否写hilo寄存器
    input  word_t   hi_i,   // 要写入的hi的值
    input  word_t   lo_i,   // 要写入的lo的值
	
    output word_t   hi_o,   // 保存的hi值
    output word_t   lo_o    // 保存的lo值
);

always_ff @(posedge clk) begin
    if (rst) begin
        {hi_o, lo_o} <= 0;
    end else if (we) begin
        {hi_o, lo_o} <= {hi_i, lo_i};
    end
end

endmodule