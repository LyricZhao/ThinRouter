/*
ID/EX模块：
    把ID的输出连接到EX执行阶段
*/

`include "cpu_defs.vh"

module id_ex(
    input  logic            clk,
    input  logic            rst,

    input  stall_t          stall,                  // 暂停状态

    input  aluop_t          id_aluop,               // id要执行的alu操作
    input  word_t           id_reg1,                // id拿到的源操作数1
    input  word_t           id_reg2,                // id拿到的源操作数2
    input  reg_addr_t       id_wd,                  // id要写入的寄存器编号
    input  logic            id_wreg,                // id是否要写入寄存器

    input  inst_addr_t      id_return_addr,         // id传来的要返回的地址
    input  logic            id_in_delayslot_i,      // id是否在延迟槽（用来更新ex_in_delayslot）
    input  logic            id_next_in_delayslot,   // 下一条是否在延迟槽（用来更新id_in_delayslot_o）

    input  word_t           id_inst,                // 来自ID模块的指令码

    output aluop_t          ex_aluop,               // 传给ex要执行的alu操作
    output word_t           ex_reg1,                // 传给ex源操作数1
    output word_t           ex_reg2,                // 传给ex源操作数2
    output reg_addr_t       ex_wd,                  // 传给ex要写入的寄存器编号
    output logic            ex_wreg,                // 传给ex是否要写入寄存器

    output inst_addr_t      ex_return_addr,         // 传给ex要返回的地址
    output logic            ex_in_delayslot,        // 传给ex该指令是否在延迟槽
    output logic            id_in_delayslot_o,      // 传给ex下一条指令是否在延迟槽

    output word_t           ex_inst                 // 把来自ID模块的指令码传给EX

);

// 同步写入
always_ff @ (posedge clk) begin
    if (rst == 1) begin
        ex_aluop <= EXE_NOP_OP;
        ex_wd    <= `NOP_REG_ADDR;
        {ex_reg1, ex_reg2, ex_wreg, ex_return_addr, ex_in_delayslot, id_in_delayslot_o, ex_inst} <= 0;
    end else if (stall[2] == 1 && stall[3] == 0) begin // id暂停ex阶段没暂停就给ex空指令
        ex_aluop <= EXE_NOP_OP;
        ex_wd    <= `NOP_REG_ADDR;
        {ex_reg1, ex_reg2, ex_wreg, ex_return_addr, ex_in_delayslot, ex_inst} <= 0; // 注意这里不能清空id_in_delayslot_o，id暂停了但是是否在延迟槽状态保持，ex没暂停一定不是在延迟槽
    end else if (stall[2] == 0) begin
        ex_aluop <= id_aluop;
        ex_reg1  <= id_reg1;
        ex_reg2  <= id_reg2;
        ex_wd    <= id_wd;
        ex_wreg  <= id_wreg;
        ex_inst  <= id_inst;
        ex_return_addr <= id_return_addr;
        ex_in_delayslot <= id_in_delayslot_i;
        id_in_delayslot_o <= id_next_in_delayslot; // 用下一条是否在延迟槽更新id的状态，这样下个时钟周期这个变量正好可以表示当前的id状态
    end
end

endmodule