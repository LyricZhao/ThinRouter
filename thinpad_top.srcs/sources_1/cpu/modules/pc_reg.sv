/*
PC(Program Counter)模块：
    每个时钟周期地址加4，ce是使能输出
    另外，之前在另一本书上见过最好用rst_n而非rst，这点后面再说，这里先保持
*/

`include "cpu_defs.vh"

module pc_reg(
    input  logic        clk,
    input  logic        rst,
    input  stall_t      stall,              // 流水线暂停状态

    input  logic        jump_flag,          // 是否跳转
    input  inst_addr_t  target_addr,        // 要跳到的位置
	
    output inst_addr_t  pc,                 // 程序计数器
    output logic        ce                  // 指令rom的使能
);

assign ce = ~rst;

always_ff @ (posedge clk) begin
    if (ce == 0) begin
        //pc <= `INIT_PC; // 指令初始化
        pc <= 32'h80000000 - 4; // 指令初始化
    end else if (stall[0] == 0) begin
        pc <= jump_flag ? target_addr : (pc + 4);
    end
end

endmodule