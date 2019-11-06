/*
EX/MEM模块：
    把执行阶段算出来的结果在传递到流水线访存
*/

`include "cpu_defs.vh"

module ex_mem(
    input logic                 clk,
    input logic                 rst,
	
    input stall_t               stall,      // 流水线暂停状态

    input reg_addr_t            ex_wd,      // ex要写的寄存器编号
    input logic                 ex_wreg,    // ex是否要写寄存器
    input word_t                ex_wdata,   // ex要写入的数据
    input word_t                ex_hi,      // ex要写入的hi数据
    input word_t                ex_lo,      // ex要写入的lo数据
    input logic                 ex_whilo,   // ex是否要写hilo寄存器

    output reg_addr_t           mem_wd,     // 传给mem要写的寄存器编号
    output logic                mem_wreg,   // 传给mem是否要写寄存器
    output word_t               mem_wdata,  // 传给mem要写的数据

    output word_t               mem_hi,     // 传给mem的hi数据
    output word_t               mem_lo,     // 传给mem的lo数据
    output logic                mem_whilo   // 传给mem是否要写hilo寄存器
);

// 同步数据传递
always_ff @ (posedge clk) begin
    if ((rst == 1'b1) || (stall[3] == 1'b1 && stall[4] == 1'b0)) begin
        mem_wd <= `NOP_REG_ADDR;
        mem_wreg <= 1'b0;
        {mem_wdata, mem_hi, mem_lo} <= {`ZeroWord, `ZeroWord, `ZeroWord};
        mem_whilo <= 1'b0;
    end else if (stall[3] == 1'b0) begin
        mem_wd <= ex_wd;
        mem_wreg <= ex_wreg;
        mem_wdata <= ex_wdata;
        {mem_hi, mem_lo} <= {ex_hi, ex_lo};
        mem_whilo <= ex_whilo;
    end
end

endmodule