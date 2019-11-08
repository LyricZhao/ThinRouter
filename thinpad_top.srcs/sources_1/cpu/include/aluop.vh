/*
ALU操作码相关的定义
*/

`ifndef _ALUOP_VH_
`define _ALUOP_VH_

`define ALUOP_BUS 7:0

typedef enum logic[`ALUOP_BUS] {
    EXE_NOP_OP,     // 空指令
    EXE_OR_OP,      // 或
    EXE_AND_OP,     // 与
    EXE_XOR_OP,     // 异或
    EXE_NOR_OP,     // 同或
    EXE_SLL_OP,     // 逻辑左移
    EXE_SRL_OP,     // 逻辑右移
    EXE_SRA_OP,     // 算术右移
    EXE_MFHI_OP,    // HI的值写入寄存器
    EXE_MFLO_OP,    // LO的值写入寄存器
    EXE_MTHI_OP,    // 寄存器的值写入HI
    EXE_MTLO_OP,    // 寄存器的值写入LO
    EXE_MOVN_OP,    // 如果非0则移动
    EXE_MOVZ_OP,    // 如果是0则移动
    EXE_SLT_OP,     // 比较有符号数大小是否<
    EXE_SLTU_OP,    // 比较无符号数大小是否<
    EXE_ADD_OP,     // 有符号加
    EXE_ADDU_OP,    // 无符号加
    EXE_SUB_OP,     // 有符号减
    EXE_SUBU_OP,    // 无符号减
    EXE_MULT_OP,    // 两个有符号寄存器的值乘法到HILO寄存器
    EXE_MULTU_OP,   // 两个无符号寄存器的值乘法到HILO寄存器
    EXE_ADDI_OP,    // 加立即数
    EXE_ADDIU_OP,   // 无符号加立即数
    EXE_CLZ_OP,     // 前导零
    EXE_CLO_OP,     // 前导一
    EXE_MUL_OP,     // 两个有符号寄存器的值乘法到另一个寄存器
    EXE_JR_OP,
    EXE_JALR_OP,
    EXE_J_OP,
    EXE_JAL_OP,
    EXE_BEQ_OP,
    EXE_BGTZ_OP,
    EXE_BLEZ_OP,
    EXE_BNE_OP,
    EXE_BGEZ_OP,
    EXE_BGEZAL_OP,
    EXE_BLTZ_OP,
    EXE_BLTZAL_OP,
    EXE_LB_OP,
    EXE_LBU_OP,
    EXE_LH_OP,
    EXE_LHU_OP,
    EXE_LW_OP,
    EXE_SB_OP,
    EXE_SH_OP,
    EXE_SW_OP
} aluop_t;

`endif