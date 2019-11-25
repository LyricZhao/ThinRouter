/*
MEM/WB模块：
    只是把访存阶段的结果向回写阶段传递
*/

`include "cpu_defs.vh"

module mem_wb(
    input  logic            clk,
    input  logic            rst,

    input  stall_t          stall,      // 流水线暂停情况

    input  reg_addr_t       mem_wd,     // mem要写入的寄存器编号
    input  logic            mem_wreg,   // mem是否要写入寄存器
    input  word_t           mem_wdata,  // mem要写入的数据
    input  word_t           mem_hi,     // mem要写入的hi值
    input  word_t           mem_lo,     // mem要写入的lo值
    input  logic            mem_whilo,  // mem是否要写入hilo寄存器

    output reg_addr_t       wb_wd,      // 传给wb要写入的寄存器编号
    output logic            wb_wreg,    // 传给wb是否要写入寄存器
    output word_t           wb_wdata,   // 传给wb要写入的数据
    output word_t           wb_hi,      // 传给wb要写入的hi值
    output word_t           wb_lo,      // 传给wb要写入的lo值
    output logic            wb_whilo    // 传给wb是否要写入hilo寄存器
);

// 同步传递
always_ff @(posedge clk) begin
    if (rst || (stall.mem && !stall.wb)) begin
        wb_wd <= `NOP_REG_ADDR;
        {wb_wreg, wb_wdata, wb_hi, wb_lo, wb_whilo} <= 0;
    end else if (stall.mem) begin
        wb_wd <= mem_wd;
        wb_wreg <= mem_wreg;
        wb_wdata <= mem_wdata;
        {wb_hi, wb_lo} <= {mem_hi, mem_lo};
        wb_whilo <= mem_whilo;
    end
end

endmodule