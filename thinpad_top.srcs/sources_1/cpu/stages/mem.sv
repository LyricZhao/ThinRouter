/*
MEM模块：
    访存阶段，现在还涉及不到RAM，只是把执行阶段的结果向回写阶段传递
*/

`include "cpu_defs.vh"

module mem(
    input  logic            rst,

    input  reg_addr_t       wd_i,       // 要写入的寄存器编号
    input  logic            wreg_i,     // 是否要写入寄存器
    input  word_t           wdata_i,    // 要写入的数据
    input  word_t           hi_i,       // 要写入的hi值
    input  word_t           lo_i,       // 要写入的lo值
    input  logic            whilo_i,    // 是否要写入hilo寄存器
    input  aluop_t          aluop_i,    // aluop的值
    input  word_t           mem_addr_i, // 想要存入内存的地址
    input  word_t           reg2_i,     // 欲写入内存的值

    input  word_t           mem_data_i, // RAM读出来的数

    output reg_addr_t       wd_o,       // 要写入的寄存器编号
    output logic            wreg_o,     // 是否要写入寄存器
    output word_t           wdata_o,    // 要写入的数据
    output word_t           hi_o,       // 要写入的hi值
    output word_t           lo_o,       // 要写入的lo值
    output logic            whilo_o,    // 是否要写入hilo寄存器

    output word_t           mem_addr_o, // 送到RAM中的信号
    output logic            mem_we_o,   // 送到RAM中的信号
    output logic[3:0]       mem_sel_o,  // 送到RAM中的信号
    output word_t           mem_data_o, // 送到RAM中的信号
    output logic            mem_ce_o    // 送到RAM中的信号
);

always_comb begin
    if (rst == 1) begin
        wd_o <= `NOP_REG_ADDR;
        wreg_o <= 0;
        wdata_o <= 0;
        {hi_o, lo_o} <= 0;
        whilo_o <= 0;
    end else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
        {hi_o, lo_o} <= {hi_i, lo_i};
        whilo_o <= whilo_i;
    end
end

endmodule