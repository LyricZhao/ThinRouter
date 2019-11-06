/*
ALU操作码相关的定义
*/

`ifndef _ALUOP_VH_
`define _ALUOP_VH_

`define ALUOP_BUS 7:0

typedef enum logic[`ALUOP_BUS] {
    EXE_NOP_OP,
    EXE_OR_OP,
    EXE_AND_OP,
    EXE_XOR_OP,
    EXE_NOR_OP,
    EXE_SLL_OP,
    EXE_SRL_OP,
    EXE_SRA_OP,
    EXE_MFHI_OP,
    EXE_MFLO_OP,
    EXE_MTHI_OP,
    EXE_MTLO_OP,
    EXE_MOVN_OP,
    EXE_MOVZ_OP
} aluop_t;

`endif