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
    input  addr_t       target_addr,        // 要跳到的位置

    input  logic        flush,              // 流水线清除信号（有异常发生）
    input  addr_t       new_pc,             // 异常处理入口地址
	
    output addr_t       pc,                 // 程序计数器
    output logic        ce                  // 指令RAM的使能
);

always_ff @ (posedge clk) begin
    if (rst) begin
        pc <= `INIT_PC - 4;
        ce <= 0;
    end else begin
        ce <= 1;
        if (flush) begin
            pc <= new_pc;
        end else if (!stall.pc) begin
            pc <= jump_flag ? target_addr : (pc + 4);
        end
    end
end

endmodule