/*
EX模块：
    执行阶段，这里实际是一个ALU
*/

`include "cpu_defs.vh"

module ex(
	input  logic	        rst,

	input  aluop_t          aluop_i,
	input  word_t           reg1_i,
	input  word_t           reg2_i,
	input  reg_addr_t       wd_i,
	input  logic            wreg_i,

    input  word_t           hi_i,
    input  word_t           lo_i,

    input  word_t           wb_hi_i,
    input  word_t           wb_lo_i,
    input  logic            wb_whilo_i,

    input  word_t           mem_hi_i,
    input  word_t           mem_lo_i,
    input  logic            mem_whilo_i,

    output reg_addr_t       wd_o,
	output logic            wreg_o,
	output word_t			wdata_o,

    output word_t           hi_o,
    output word_t           lo_o,
    output logic            whilo_o
);

// 最新的hi, lo寄存器的值
word_t hi, lo;

always_comb begin
    if (rst == 1'b1) begin
        wdata_o <= `ZeroWord;
    end else begin
        case (aluop_i)
            EXE_OR_OP: begin
                wdata_o <= reg1_i | reg2_i;
            end
            EXE_AND_OP: begin
                wdata_o <= reg1_i & reg2_i;
            end
            EXE_XOR_OP: begin
                wdata_o <= reg1_i ^ reg2_i;
            end
            EXE_NOR_OP: begin
                wdata_o <= ~(reg1_i | reg2_i);
            end
            EXE_SLL_OP: begin // 逻辑左移
                wdata_o <= reg2_i << reg1_i[4:0];
            end
            EXE_SRL_OP: begin // 逻辑右移
                wdata_o <= reg2_i >> reg1_i[4:0];
            end
            EXE_SRA_OP: begin // 算术右移
                wdata_o <= reg2_i >>> reg1_i[4:0];
            end
            EXE_MFHI_OP: begin
                wdata_o <= hi;
            end
            EXE_MFLO_OP: begin
                wdata_o <= lo;
            end
            EXE_MOVZ_OP: begin
                wdata_o <= reg1_i;
            end
            EXE_MOVN_OP: begin
                wdata_o <= reg1_i;
            end
            default: begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end
end

always_comb begin
    if (rst == 1'b1) begin
        {hi, lo} <= {`ZeroWord, `ZeroWord};
    end else if (mem_whilo_i == 1'b1) begin
        {hi, lo} <= {mem_hi_i, mem_lo_i};
    end else if (wb_whilo_i == 1'b1) begin
        {hi, lo} <= {wb_hi_i, wb_lo_i};
    end else begin
        {hi, lo} <= {hi_i, lo_i};
    end
end

// 将要写入的hi, lo的值
always_comb begin
    if (rst == 1'b1) begin
        whilo_o <= 1'b0;
        {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
    end else begin
        case (aluop_i)
            EXE_MTHI_OP: begin
                whilo_o <= 1'b1;
                {hi_o, lo_o} <= {reg1_i, lo};
            end
            EXE_MTLO_OP: begin
                whilo_o <= 1'b1;
                {hi_o, lo_o} <= {hi, reg1_i};
            end
            default: begin
                whilo_o <= 1'b0;
                {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
            end
        endcase
    end
end

always_comb begin
    wd_o <= wd_i;	 	 	
    wreg_o <= wreg_i;
end

endmodule