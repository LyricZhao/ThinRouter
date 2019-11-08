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

    input aluop_t               ex_aluop,   // ex传入的aluop
    input word_t                ex_mem_addr,// ex要写入内存的地址
    input word_t                ex_reg2,    // ex要写入内存的值

    output reg_addr_t           mem_wd,     // 传给mem要写的寄存器编号
    output logic                mem_wreg,   // 传给mem是否要写寄存器
    output word_t               mem_wdata,  // 传给mem要写的数据

    output word_t               mem_hi,     // 传给mem的hi数据
    output word_t               mem_lo,     // 传给mem的lo数据
    output logic                mem_whilo,  // 传给mem是否要写hilo寄存器

    output aluop_t              mem_aluop,  // 传给mem的aluop
    output word_t               mem_mem_addr,//传给mem要写入内存的地址
    output word_t               mem_reg2    // 传给mem要写入内存的值
);

// 同步数据传递
always_ff @ (posedge clk) begin
    if ((rst == 1) || (stall[3] == 1 && stall[4] == 0)) begin
        mem_wd <= `NOP_REG_ADDR;
        {mem_wreg, mem_wdata, mem_hi, mem_lo, mem_whilo, mem_aluop, mem_mem_addr, mem_reg2} <= 0;
    end else if (stall[3] == 0) begin
        mem_wd <= ex_wd;
        mem_wreg <= ex_wreg;
        mem_wdata <= ex_wdata;
        {mem_hi, mem_lo} <= {ex_hi, ex_lo};
        mem_whilo <= ex_whilo;
        mem_aluop <= ex_aluop;
        mem_mem_addr <= ex_mem_addr;
        mem_reg2 <= ex_reg2;
    end
end

endmodule