/*
ID(Decode)模块：
    对指令进行译码，得到最终运算的类型、子类型和两个源操作数
*/

`include "cpu_defs.vh"

module id(
    input  logic                    rst,
    input  inst_addr_t              pc_i,
    input  word_t                   inst_i,

    input  word_t                   reg1_data_i,
    input  word_t                   reg2_data_i,

    // 执行阶段传来的前传数据（解决相邻指令的冲突）
    input  logic                    ex_wreg_i,      // 执行阶段是否写目的寄存器
    input  word_t                   ex_wdata_i,     // 需写入的数据
    input  reg_addr_t               ex_wd_i,        // 需写入的寄存器

    // 访存阶段传来的前传数据（解决相隔1条指令的冲突）
    input  logic                    mem_wreg_i,     // 访存阶段是否写目的寄存器
    input  word_t                   mem_wdata_i,    // 需写入的数据
    input  reg_addr_t               mem_wd_i,       // 需写入的寄存器

    output reg_addr_t               reg1_addr_o,    // 要读的寄存器1的编号
    output reg_addr_t               reg2_addr_o,    // 要读的寄存器2的编号

    output aluop_t                  aluop_o,
    output word_t                   reg1_o,         // 寄存器或者立即数的值（源操作数1）
    output word_t                   reg2_o,         // 寄存器或者立即数的值（源操作数2）
    output reg_addr_t               wd_o,           // 需要被写入的寄存器编号
    output logic                    wreg_o          // 是否需要写入
);

logic[5:0] op1; assign op1 = inst_i[31:26];
logic[4:0] op2; assign op2 = inst_i[10:6];
logic[5:0] op3; assign op3 = inst_i[5:0];
logic[4:0] op4; assign op4 = inst_i[20:16];

word_t imm;

logic reg1_read_o; // 是否读寄存器1
logic reg2_read_o; // 是否读寄存器2

`define INST_KIND_1_COMMON(exe,w,r1,r2)         aluop_o <= exe; \
                                                wreg_o <= w; \
                                                reg1_read_o <= r1; \
                                                reg2_read_o <= r2

`define INST_KIND_2_COMMON(exe,immi,w,r1,r2)    aluop_o <= exe; \
                                                imm <= immi; \
                                                wreg_o <= w; \
                                                reg1_read_o <= r1; \
                                                reg2_read_o <= r2; \
                                                wd_o <= inst_i[20:16]

`define INST_KIND_3_COMMON(exe,w,r1,r2)         aluop_o <= exe; \
                                                wreg_o <= w; \
                                                reg1_read_o <= r1; \
                                                reg2_read_o <= r2; \
                                                imm[4:0] <= inst_i[10:6]

always_comb begin
    if (rst == 1'b1) begin
        aluop_o     <= EXE_NOP_OP;
        wd_o        <= `NOP_REG_ADDR;
        wreg_o      <= 1'b0;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= `NOP_REG_ADDR;
        reg2_addr_o <= `NOP_REG_ADDR;
        imm <= 32'h0;
    end else begin
        aluop_o     <= EXE_NOP_OP;
        wd_o        <= inst_i[15:11];
        wreg_o      <= 1'b0;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= inst_i[25:21];
        reg2_addr_o <= inst_i[20:16];
        imm <= `ZeroWord;
        // 下面这部分判断详情见造CPU一书的121页
        if (inst_i[31:21] != 11'b00000000000) begin
            case (op1) // 指令码
                `EXE_SPECIAL_INST: begin
                    case (op2)
                        5'b00000: begin // op2暂时默认为0
                            case (op3) //                             ALUOP         是否写入寄存器            是否读取寄存器1/2
                                `EXE_OR:    begin `INST_KIND_1_COMMON(EXE_OR_OP,    1,                      1, 1);  end
                                `EXE_AND:   begin `INST_KIND_1_COMMON(EXE_AND_OP,   1,                      1, 1);  end
                                `EXE_XOR:   begin `INST_KIND_1_COMMON(EXE_XOR_OP,   1,                      1, 1);  end
                                `EXE_NOR:   begin `INST_KIND_1_COMMON(EXE_NOR_OP,   1,                      1, 1);  end
                                `EXE_SLLV:  begin `INST_KIND_1_COMMON(EXE_SLL_OP,   1,                      1, 1);  end
                                `EXE_SRLV:  begin `INST_KIND_1_COMMON(EXE_SRL_OP,   1,                      1, 1);  end
                                `EXE_SRAV:  begin `INST_KIND_1_COMMON(EXE_SRA_OP,   1,                      1, 1);  end
                                `EXE_SYNC:  begin `INST_KIND_1_COMMON(EXE_NOP_OP,   1,                      1, 1);  end
                                `EXE_SLT:   begin `INST_KIND_1_COMMON(EXE_SLT_OP,   1,                      1, 1);  end
                                `EXE_SLTU:  begin `INST_KIND_1_COMMON(EXE_SLTU_OP,  1,                      1, 1);  end
                                `EXE_ADD:   begin `INST_KIND_1_COMMON(EXE_ADD_OP,   1,                      1, 1);  end
                                `EXE_ADDU:  begin `INST_KIND_1_COMMON(EXE_ADDU_OP,  1,                      1, 1);  end
                                `EXE_SUB:   begin `INST_KIND_1_COMMON(EXE_SUB_OP,   1,                      1, 1);  end
                                `EXE_SUBU:  begin `INST_KIND_1_COMMON(EXE_SUBU_OP,  1,                      1, 1);  end
                                `EXE_MULT:  begin `INST_KIND_1_COMMON(EXE_MULT_OP,  0,                      1, 1);  end
                                `EXE_MULTU: begin `INST_KIND_1_COMMON(EXE_MULTU_OP, 0,                      1, 1);  end
                                `EXE_MFHI:  begin `INST_KIND_1_COMMON(EXE_MFHI_OP,  1,                      0, 0);  end
                                `EXE_MFLO:  begin `INST_KIND_1_COMMON(EXE_MFLO_OP,  1,                      0, 0);  end
                                `EXE_MTHI:  begin `INST_KIND_1_COMMON(EXE_MTHI_OP,  0,                      1, 0);  end
                                `EXE_MTLO:  begin `INST_KIND_1_COMMON(EXE_MTLO_OP,  0,                      1, 0);  end
                                `EXE_MOVN:  begin `INST_KIND_1_COMMON(EXE_MOVN_OP,  (reg2_o != `ZeroWord),  1, 1);  end
                                `EXE_MOVZ:  begin `INST_KIND_1_COMMON(EXE_MOVZ_OP,  (reg2_o == `ZeroWord),  1, 1);  end
                                default: begin end
                            endcase
                        end
                        default: begin end
                    endcase
                end //                                ALUOP         立即数                             是否写入寄存器/是否读1/2
                `EXE_ORI:   begin `INST_KIND_2_COMMON(EXE_OR_OP,    {16'h0, inst_i[15:0]},            1, 1, 0);   end
                `EXE_ANDI:  begin `INST_KIND_2_COMMON(EXE_AND_OP,   {16'h0, inst_i[15:0]},            1, 1, 0);   end
                `EXE_XORI:  begin `INST_KIND_2_COMMON(EXE_XOR_OP,   {16'h0, inst_i[15:0]},            1, 1, 0);   end
                `EXE_LUI:   begin `INST_KIND_2_COMMON(EXE_OR_OP,    {inst_i[15:0], 16'h0},            1, 1, 0);   end
                `EXE_PREF:  begin `INST_KIND_2_COMMON(EXE_NOP_OP,   0,                                0, 0, 0);   end
                `EXE_SLTI:  begin `INST_KIND_2_COMMON(EXE_SLT_OP,   {{16{inst_i[15]}}, inst_i[15:0]}, 1, 1, 0);   end
                `EXE_SLTIU: begin `INST_KIND_2_COMMON(EXE_SLTU_OP,  {{16{inst_i[15]}}, inst_i[15:0]}, 1, 1, 0);   end
                `EXE_ADDI:  begin `INST_KIND_2_COMMON(EXE_ADDI_OP,  {{16{inst_i[15]}}, inst_i[15:0]}, 1, 1, 0);   end
                `EXE_ADDIU: begin `INST_KIND_2_COMMON(EXE_ADDIU_OP, {{16{inst_i[15]}}, inst_i[15:0]}, 1, 1, 0);   end
                `EXE_SPECIAL2_INST: begin
                    case (op3) //                              ALUOP        是否写入寄存器/是否读1/2
                        `EXE_CLZ:    begin `INST_KIND_1_COMMON(EXE_CLZ_OP,  1, 1, 0);  end
                        `EXE_CLO:    begin `INST_KIND_1_COMMON(EXE_CLO_OP,  1, 1, 0);  end
                        `EXE_MUL:    begin `INST_KIND_1_COMMON(EXE_MUL_OP,  1, 1, 1);  end
                        default: begin end
                    endcase
                end
                default: begin end
            endcase
        end else begin
            case (op3) //                             ALUOP       是否写入寄存器/是否读1/2
                `EXE_SLL:   begin `INST_KIND_3_COMMON(EXE_SLL_OP, 1, 0, 1);     end
                `EXE_SRL:   begin `INST_KIND_3_COMMON(EXE_SRL_OP, 1, 0, 1);     end
                `EXE_SRA:   begin `INST_KIND_3_COMMON(EXE_SRA_OP, 1, 0, 1);     end
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