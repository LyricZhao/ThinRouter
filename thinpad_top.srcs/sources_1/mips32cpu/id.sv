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

	output reg[`AluOpBus]           aluop_o,
	output reg[`RegBus]             reg1_o,         // 寄存器或者立即数的值（源操作数1）
	output reg[`RegBus]             reg2_o,         // 寄存器或者立即数的值（源操作数2）
	output reg[`RegAddrBus]         wd_o,           // 需要被写入的寄存器编号
	output reg                      wreg_o,         // 是否需要写入

    input wire                      ex_wreg_i,      // 从执行阶段是否来数据
    input wire[`RegBus]             ex_wdata_i,     // 需写入的数据
    input wire[`RegAddrBus]         ex_wd_i,        // 需写入的寄存器

    input wire                      mem_wreg_i,     // 从访存阶段是否来数据
    input wire[`RegBus]             mem_wdata_i,
    input wire[`RegAddrBus]         mem_wd_i
);

wire[5:0] op1 = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];

reg[`RegBus] imm;

reg reg1_read_o; // 是否读寄存器1
reg reg2_read_o; // 是否读寄存器2

always_comb begin
    if (rst == 1'b1) begin
        aluop_o     <= `EXE_NOP_OP;
        wd_o        <= `NOPRegAddr;
        wreg_o      <= `WriteDisable;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= `NOPRegAddr;
        reg2_addr_o <= `NOPRegAddr;
        imm <= 32'h0;
    end else begin
        aluop_o     <= `EXE_NOP_OP;
        wd_o        <= inst_i[15:11];
        wreg_o      <= `WriteDisable;
        reg1_read_o <= 1'b0;
        reg2_read_o <= 1'b0;
        reg1_addr_o <= inst_i[25:21];
        reg2_addr_o <= inst_i[20:16];
        imm <= `ZeroWord;

        case (op1)
            `EXE_SPECIAL: begin // 6'b000000
                case (op2) // TO CHECK: 这个op2是啥
                    5'b00000: begin
                        case (op3)
                            `EXE_OR: begin
                                wreg_o <= 1'b1; // 将是否write back 的信号后传
                                aluop_o <= `EXE_OR_OP;
                                reg1_read_o <= 1'b1;
                                reg2_read_o <= 1'b1;
                                wd_o <= inst_i[15:11];
                            end
                            `EXE_AND: begin
                                wreg_o <= 1'b1; // 将是否write back 的信号后传
                                aluop_o <= `EXE_AND_OP;
                                reg1_read_o <= 1'b1;
                                reg2_read_o <= 1'b1;
                                wd_o <= inst_i[15:11];
                            end
                            `EXE_XOR: begin
                                wreg_o <= 1'b1; // 将是否write back 的信号后传
                                aluop_o <= `EXE_XOR_OP;
                                reg1_read_o <= 1'b1;
                                reg2_read_o <= 1'b1;
                                wd_o <= inst_i[15:11];
                            end
                            // `EXE_NOR: begin
                            //     wreg_o <= 1'b1; // 将是否write back 的信号后传
                            //     aluop_o <= `EXE_NOR_OP;
                            //     reg1_read_o <= 1'b1;
                            //     reg2_read_o <= 1'b1;
                            //     wd_o <= inst_i[15:11];
                            // end
                            `EXE_ADDU: begin
                                wreg_o <= 1'b1; // 将是否write back 的信号后传
                                aluop_o <= `EXE_ADDU_OP;
                                reg1_read_o <= 1'b1;
                                reg2_read_o <= 1'b1;
                                wd_o <= inst_i[15:11];
                            end
                            // `EXE_SRL: begin
                            //     wreg_o <= 1'b1; // 将是否write back 的信号后传
                            //     aluop_o <= `EXE_ADDU_OP;
                            //     reg1_read_o <= 1'b0;
                            //     reg2_read_o <= 1'b0;
                            //     reg1_addr_o <= inst_i[25:21];
                            //     reg2_addr_o <= inst_i[20:16];
                            //     wd_o <= inst_i[15:11];
                            // end
                        endcase
                    end
                    default: begin end
                endcase
            end

            `EXE_ADDIU: begin
                wreg_o <= 1'b1;
                aluop_o <= `EXE_ADDU_OP;
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                imm <= {{16{inst_i[15]}}, inst_i[15:0]};
                wd_o <= inst_i[20:16];
            end
            `EXE_ORI: begin
                wreg_o <= 1'b1;
                aluop_o <= `EXE_OR_OP;
                // TO CHECK: 书上还有一个alusel_o, instvalid
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                imm <= {16'h0, inst_i[15:0]};
                wd_o <= inst_i[20:16];
            end
            `EXE_ANDI: begin
                wreg_o <= 1'b1;
                aluop_o <= `EXE_AND_OP;
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                imm <= {16'h0, inst_i[15:0]};
                wd_o <= inst_i[20:16];
            end
            `EXE_XORI: begin
                wreg_o <= 1'b1;
                aluop_o <= `EXE_XOR_OP;
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                imm <= {16'h0, inst_i[15:0]};
                wd_o <= inst_i[20:16];
            end
            `EXE_LUI: begin
                wreg_o <= 1'b1;
                aluop_o <= `EXE_LUI_OP;
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;	  	
                imm <= {inst_i[15:0], 16'h0}; // 左移16位，低位补0
                wd_o <= inst_i[20:16];
            end
            default: begin end
        endcase		
    end
end

always_comb begin
    if (rst == 1'b1) begin
        reg1_o <= `ZeroWord;
    end else if ((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin    // 如果要读的寄存器1与EX阶段要写的寄存器相同，则直接读入要写的值
        reg1_o <= ex_wdata_i;
    end else if ((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin  // 如果要读的寄存器1与MEM阶段要写的寄存器相同，则直接读入要写的值
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
    end else if ((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin    // 如果要读的寄存器2与EX阶段要写的寄存器相同，则直接读入要写的值
        reg2_o <= ex_wdata_i;
    end else if ((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin  // 如果要读的寄存器2与MEM阶段要写的寄存器相同，则直接读入要写的值
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