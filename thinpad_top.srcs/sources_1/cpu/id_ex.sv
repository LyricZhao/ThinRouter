/*
ID/EX模块：
    把ID的输出连接到EX执行阶段
*/

`include "cpu_defs.vh"

module id_ex(
	input  logic            clk,
	input  logic            rst,

	input  aluop_t          id_aluop,
	input  word_t           id_reg1,
	input  word_t           id_reg2,
	input  reg_addr_t       id_wd,
	input  logic            id_wreg,

	output aluop_t          ex_aluop,
	output word_t           ex_reg1,
	output word_t           ex_reg2,
	output reg_addr_t       ex_wd,
	output logic            ex_wreg
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        ex_aluop <= EXE_NOP_OP;
        ex_reg1  <= `ZeroWord;
        ex_reg2  <= `ZeroWord;
        ex_wd    <= `NOP_REG_ADDR;
        ex_wreg  <= 1'b0;
    end else begin
        ex_aluop <= id_aluop;
        ex_reg1  <= id_reg1;
        ex_reg2  <= id_reg2;
        ex_wd    <= id_wd;
        ex_wreg  <= id_wreg;
    end
end

endmodule