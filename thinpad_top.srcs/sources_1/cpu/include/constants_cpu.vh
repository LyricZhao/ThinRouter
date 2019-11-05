/*
一些定义：
    TODO：拆成多个文件增强可读性
    TODO：尽可能都改成typedef增强可读性（还没改完）
*/

`ifndef _CPU_CONSTANTS_VH_
`define _CPU_CONSTANTS_VH_

`define ZeroWord            32'h00000000

/*
指令码和功能码：
    对于一条指令inst：
    inst[31:26]为指令码，如果是EXE_SPECIAL类型，继续判断后面，否则直接执行（ori, andi, lui, pref）
    inst[10:6]暂时默认为0，TODO：读一下手册
    inst[5:0]是功能码，可以是（or, and, xor, nor, sllv, srlv, srav, sync）

    如果inst[31:21]直接是0，根据inst[5:0]判断是（sll, srl, sra）中的一个
    见动手造CPU一书的121页

TODO: 改成enum，但是问题是现在有重复的
*/

`define EXE_NOP             6'b000000
`define EXE_SPECIAL         6'b000000

`define EXE_AND             6'b100100
`define EXE_OR              6'b100101
`define EXE_XOR             6'b100110
`define EXE_NOR             6'b100111
`define EXE_ANDI            6'b001100
`define EXE_ORI             6'b001101
`define EXE_XORI            6'b001110
`define EXE_LUI             6'b001111
`define EXE_ADDU            6'b100001
`define EXE_ADDIU           6'b001001

`define EXE_SLL             6'b000000
`define EXE_SLLV            6'b000100
`define EXE_SRL             6'b000010
`define EXE_SRLV            6'b000110
`define EXE_SRA             6'b000011
`define EXE_SRAV            6'b000111

`define EXE_MOVZ            6'b001010
`define EXE_MOVN            6'b001011
`define EXE_MFHI            6'b010000
`define EXE_MTHI            6'b010001
`define EXE_MFLO            6'b010010
`define EXE_MTLO            6'b010011

`define EXE_SYNC            6'b001111
`define EXE_PREF            6'b110011

typedef enum logic[`AluOpBus] {
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

// 指令ROM
`define InstAddrBus         31:0
`define InstBus             31:0
`define InstMemNum          131071
`define InstMemNumLog2      17

typedef logic[`InstAddrBus] inst_addr_t;
// typedef logic[`InstBus]     inst_t; 指令都是一个word用word_t

// 寄存器
`define RegAddrBus          4:0
`define RegBus              31:0
`define WordBus             31:0
`define DoubleWordBus       63:0
`define RegWidth            32
`define DoubleRegWidth      64
`define DoubleRegBus        63:0
`define RegNum              32
`define RegNumLog2          5
`define NOPRegAddr          5'b00000

typedef logic[`RegAddrBus]      reg_addr_t;
typedef logic[`WordBus]         word_t;
typedef logic[`DoubleWordBus]   dword_t;

`endif
