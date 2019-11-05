/*
ID(Decode)模块：
    对指令进行译码，得到最终运算的类型、子类型和两个源操作数
*/

`include "constants_cpu.vh"

module id(
	input wire                      rst,
	input wire[`InstAddrBus]        pc_i,
	input wire[`InstBus]            inst_i,

	input wire[`RegBus]             reg1_data_i,
	input wire[`RegBus]             reg2_data_i,

	output reg[`RegAddrBus]         reg1_addr_o,    // 要读的寄存器1的编号
	output reg[`RegAddrBus]         reg2_addr_o,    // 要读的寄存器2的编号

	output aluop_t                  aluop_o,
	output reg[`RegBus]             reg1_o,         // 寄存器或者立即数的值（源操作数1）
	output reg[`RegBus]             reg2_o,         // 寄存器或者立即数的值（源操作数2）
	output reg[`RegAddrBus]         wd_o,           // 需要被写入的寄存器编号
	output reg                      wreg_o,         // 是否需要写入

    // 执行阶段传来的前传数据（解决相邻指令的冲突）
    input wire                      ex_wreg_i,      // 执行阶段是否写目的寄存器
    input wire[`RegBus]             ex_wdata_i,     // 需写入的数据
    input wire[`RegAddrBus]         ex_wd_i,        // 需写入的寄存器

    // 访存阶段传来的前传数据（解决相隔1条指令的冲突）
    input wire                      mem_wreg_i,     // 访存阶段是否写目的寄存器
    input wire[`RegBus]             mem_wdata_i,    // 需写入的数据
    input wire[`RegAddrBus]         mem_wd_i        // 需写入的寄存器
);

wire[5:0] op1 = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];

reg[`RegBus] imm;

reg reg1_read_o; // 是否读寄存器1
reg reg2_read_o; // 是否读寄存器2

`define INST_KIND_1_COMMON  wreg_o <= 1'b1; \
                            reg1_read_o <= 1'b1; \
                            reg2_read_o <= 1'b1; \
                            wd_o <= inst_i[15:11]

`define INST_KIND_2_COMMON  wreg_o <= 1'b1; \
                            reg1_read_o <= 1'b1; \
                            reg2_read_o <= 1'b0; \
                            wd_o <= inst_i[20:16]

`define INST_KIND_3_COMMON  wreg_o <= 1'b1; \
                            reg1_read_o <= 1'b0; \
                            reg2_read_o <= 1'b1; \
                            imm[4:0] <= inst_i[10:6]; \
                            wd_o <= inst_i[15:11]

always_comb begin
    if (rst == 1'b1) begin
        aluop_o     <= EXE_NOP_OP;
        wd_o        <= `NOPRegAddr;
        wreg_o      <= `WriteDisable;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= `NOPRegAddr;
        reg2_addr_o <= `NOPRegAddr;
        imm <= 32'h0;
    end else begin
        aluop_o     <= EXE_NOP_OP;
        wd_o        <= inst_i[15:11];
        wreg_o      <= `WriteDisable;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= inst_i[25:21];
        reg2_addr_o <= inst_i[20:16];
        imm <= `ZeroWord;
        // 下面这部分判断详情见造CPU一书的121页
        if (inst_i[31:21] != 11'b00000000000) begin
            case (op1) // 指令码
                `EXE_SPECIAL: begin
                    case (op2)
                        5'b00000: begin // op2暂时默认为0
                            case (op3) // 功能码：or, and, xor, nor, sllv, srlv, srav, sync
                                `EXE_OR: begin
                                    aluop_o <= EXE_OR_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_AND: begin
                                    aluop_o <= EXE_AND_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_XOR: begin
                                    aluop_o <= EXE_XOR_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_NOR: begin
                                    aluop_o <= EXE_NOR_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_SLLV: begin
                                    aluop_o <= EXE_SLL_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_SRLV: begin
                                    aluop_o <= EXE_SRL_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_SRAV: begin
                                    aluop_o <= EXE_SRA_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                `EXE_SYNC: begin
                                    aluop_o <= EXE_NOP_OP;
                                    `INST_KIND_1_COMMON;
                                end
                                default: begin end
                            endcase
                        end
                        default: begin end
                    endcase
                end

                // ori, andi, xori, lui, pref
                `EXE_ORI: begin
                    aluop_o <= EXE_OR_OP;
                    imm <= {16'h0, inst_i[15:0]};
                    `INST_KIND_2_COMMON;
                end
                `EXE_ANDI: begin
                    aluop_o <= EXE_AND_OP;
                    imm <= {16'h0, inst_i[15:0]};
                    `INST_KIND_2_COMMON;
                end
                `EXE_XORI: begin
                    aluop_o <= EXE_XOR_OP;
                    imm <= {16'h0, inst_i[15:0]};
                    `INST_KIND_2_COMMON;
                end
                `EXE_LUI: begin
                    aluop_o <= EXE_OR_OP;
                    imm <= {inst_i[15:0], 16'h0};
                    `INST_KIND_2_COMMON;
                end
                `EXE_PREF: begin
                    aluop_o <= EXE_NOP_OP;
                    wreg_o <= 1'b0;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b0;
                end
                default: begin end
            endcase
        end else begin // sll, srl, sra
            case (op3)
                `EXE_SLL: begin
                    aluop_o <= EXE_SLL_OP;
                    `INST_KIND_3_COMMON;
                end
                `EXE_SRL: begin
                    aluop_o <= EXE_SRL_OP;
                    `INST_KIND_3_COMMON;
                end
                `EXE_SRA: begin
                    aluop_o <= EXE_SRA_OP;
                    `INST_KIND_3_COMMON;
                end
                default: begin end
            endcase
        end
    end
end

always_comb begin
    if (rst == 1'b1) begin
        reg1_o <= `ZeroWord;
    end else if ((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin    // 如果要读的寄存器1与EX阶段要写的寄存器相同，则直接读入要写的值（先看近的指令）
        reg1_o <= ex_wdata_i;
    end else if ((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin  // 如果要读的寄存器1与MEM阶段要写的寄存器相同，则直接读入要写的值（相隔1条指令）
        reg1_o <= mem_wdata_i;
    end else if (reg1_read_o == 1'b1) begin
        reg1_o <= reg1_data_i;
    end else if (reg1_read_o == 1'b0) begin
        reg1_o <= imm;
    end else begin
        reg1_o <= `ZeroWord;
    end
end

always_comb begin
    if (rst == 1'b1) begin
        reg2_o <= `ZeroWord;
    end else if ((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin    // 如果要读的寄存器2与EX阶段要写的寄存器相同，则直接读入要写的值（先看近的指令）
        reg2_o <= ex_wdata_i;
    end else if ((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin  // 如果要读的寄存器2与MEM阶段要写的寄存器相同，则直接读入要写的值（相隔1条指令）
        reg2_o <= mem_wdata_i;
    end else if (reg2_read_o == 1'b1) begin
        reg2_o <= reg2_data_i;
    end else if (reg2_read_o == 1'b0) begin
        reg2_o <= imm;
    end else begin
        reg2_o <= `ZeroWord;
    end
end

endmodule