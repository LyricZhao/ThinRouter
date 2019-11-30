/*
EX/MEM模块：
    把执行阶段算出来的结果在传递到流水线访存
*/

`include "cpu_defs.vh"

module ex_mem(
    input  logic                clk,
    input  logic                rst,
	
    input  stall_t              stall,                  // 流水线暂停状态

    input  reg_addr_t           ex_wd,                  // ex要写的寄存器编号
    input  logic                ex_wreg,                // ex是否要写寄存器
    input  word_t               ex_wdata,               // ex要写入的数据
    input  word_t               ex_hi,                  // ex要写入的hi数据
    input  word_t               ex_lo,                  // ex要写入的lo数据
    input  logic                ex_whilo,               // ex是否要写hilo寄存器

    input  aluop_t              ex_aluop,               // ex传入的aluop
    input  word_t               ex_mem_addr,            // ex要写入内存的地址
    input  word_t               ex_reg2,                // ex要写入内存的值

    input  logic                ex_cp0_reg_we,          // ex是否要写CP0
    input  reg_addr_t           ex_cp0_reg_write_addr,  // ex要写的CP0的地址
    input  word_t               ex_cp0_reg_data,        // ex要写的数据

    input  logic                flush,                  // 流水线清除

    input  word_t               ex_except_type,         // 异常类型
    input  addr_t               ex_current_inst_addr,   // 执行阶段的指令地址
    input  logic                ex_in_delayslot,        // 执行阶段是否在延迟槽中

    output reg_addr_t           mem_wd,                 // 传给mem要写的寄存器编号
    output logic                mem_wreg,               // 传给mem是否要写寄存器
    output word_t               mem_wdata,              // 传给mem要写的数据

    output word_t               mem_hi,                 // 传给mem的hi数据
    output word_t               mem_lo,                 // 传给mem的lo数据
    output logic                mem_whilo,              // 传给mem是否要写hilo寄存器

    output aluop_t              mem_aluop,              // 传给mem的aluop
    output word_t               mem_mem_addr,           // 传给mem要写入内存的地址
    output word_t               mem_reg2,               // 传给mem要写入内存的值

    output logic                mem_cp0_reg_we,         // 传给mem是否要写CP0
    output reg_addr_t           mem_cp0_reg_write_addr, // 传给mem要写的CP0的地址
    output word_t               mem_cp0_reg_data,       // 传给mem要写的数据

    output word_t               mem_except_type,        // 异常类型
    output addr_t               mem_current_inst_addr,  // 执行阶段的指令地址
    output logic                mem_in_delayslot        // 执行阶段是否在延迟槽中
);

// 同步数据传递
always_ff @ (posedge clk) begin
    if (rst || (stall.ex && !stall.mem) || flush) begin
        {mem_wd, mem_wreg, mem_wdata, mem_hi, mem_lo, mem_whilo, mem_aluop, mem_mem_addr, mem_reg2, mem_cp0_reg_we, mem_cp0_reg_write_addr, mem_cp0_reg_data, mem_except_type, mem_in_delayslot, mem_current_inst_addr} <= 0;
    end else if (!stall.ex) begin
        mem_wd <= ex_wd;
        mem_wreg <= ex_wreg;
        mem_wdata <= ex_wdata;
        {mem_hi, mem_lo} <= {ex_hi, ex_lo};
        mem_whilo <= ex_whilo;
        mem_aluop <= ex_aluop;
        mem_mem_addr <= ex_mem_addr;
        mem_reg2 <= ex_reg2;
        mem_cp0_reg_we <= ex_cp0_reg_we;
        mem_cp0_reg_write_addr <= ex_cp0_reg_write_addr;
        mem_cp0_reg_data <= ex_cp0_reg_data;
        mem_except_type <= ex_except_type;
        mem_in_delayslot <= ex_in_delayslot;
        mem_current_inst_addr <= ex_current_inst_addr;
    end
end

endmodule