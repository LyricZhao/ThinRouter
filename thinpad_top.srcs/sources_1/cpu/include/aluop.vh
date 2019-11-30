/*
ALU操作码相关的定义
*/

`ifndef _ALUOP_VH_
`define _ALUOP_VH_

`define ALUOP_WIDTH 8

typedef enum logic[`ALUOP_WIDTH-1:0] {
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
    EXE_JR_OP,      // 跳到寄存器中的地址
    EXE_JALR_OP,    // 跳到寄存器中的地址并把返回地址放到31号寄存器
    EXE_J_OP,       // 跳到一个立即数地址
    EXE_JAL_OP,     // 跳到一个立即数地址并把返回地址放到31号寄存器
    EXE_BEQ_OP,     // 如果两个数相同就把PC加offset进另一个分支
    EXE_BGTZ_OP,    // 如果寄存器>0就把PC加offset进另一个分支
    EXE_BLEZ_OP,    // 如果寄存器<=0就把PC加offset进另一个分支    
    EXE_BNE_OP,     // 如果两个数不相同就把PC加offset进另一个分支
    EXE_BGEZ_OP,    // 如果寄存器>=0就把PC加offset进另一个分支    
    EXE_BGEZAL_OP,  // 如果寄存器>=0就把PC加offset进另一个分支并把返回地址放到31号寄存器
    EXE_BLTZ_OP,    // 如果寄存器>0就把PC加offset进另一个分支    
    EXE_BLTZAL_OP,  // 如果寄存器>0就把PC加offset进另一个分支并把返回地址放到31号寄存器
    EXE_LB_OP,      // 从地址中加载字节到寄存器（符号扩展）
    EXE_LBU_OP,     // 从地址中加载字节到寄存器（零扩展）
    EXE_LH_OP,      // 从地址中加载半字到寄存器（符号扩展）
    EXE_LHU_OP,     // 从地址中加载半字到寄存器（零扩展）
    EXE_LW_OP,      // 从地址中加载字到寄存器（符号扩展）
    EXE_SB_OP,      // 存字节到地址
    EXE_SH_OP,      // 存半字到地址
    EXE_SW_OP,      // 存字到地址
    EXE_MFC0_OP,    // 获取某个CP0寄存器的值
    EXE_MTC0_OP,    // 写入某个CP0寄存器的值
    EXE_SYSCALL_OP, // 系统调用
    EXE_TEQ_OP,     // 等于发生自陷
    EXE_TEQI_OP,    // 等于立即数发生自陷
    EXE_TGE_OP,     // 大于等于发生自陷
    EXE_TGEI_OP,    // 大于等于立即数发生自陷
    EXE_TGEIU_OP,   // 大于等于立即数（零扩展）发生自陷
    EXE_TGEU_OP,    // 大于等于发生自陷
    EXE_TLT_OP,     // 小于发生自陷
    EXE_TLTI_OP,    // 小于立即数发生自陷
    EXE_TLTIU_OP,   // 小于立即数（零扩展）发生自陷
    EXE_TLTU_OP,    // 小于发生自陷
    EXE_TNE_OP,     // 不等于发生自陷
    EXE_TNEI_OP,    // 不等于立即数发生自陷
    EXE_ERET_OP     // 异常返回
} aluop_t;

`endif