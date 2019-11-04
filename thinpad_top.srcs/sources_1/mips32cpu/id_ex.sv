/*
ID/EX模块：
    把ID的输出连接到EX执行阶段
*/

`include "constants_cpu.vh"

// To Check: 少了alusel的两个信号
module id_ex(
	input wire                    clk,
	input wire                    rst,

	input wire[`AluOpBus]         id_aluop,
	input wire[`RegBus]           id_reg1,
	input wire[`RegBus]           id_reg2,
	input wire[`RegAddrBus]       id_wd,
	input wire                    id_wreg,	
	
	output reg[`AluOpBus]         ex_aluop,
	output reg[`RegBus]           ex_reg1,
	output reg[`RegBus]           ex_reg2,
	output reg[`RegAddrBus]       ex_wd,
	output reg                    ex_wreg
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        ex_aluop <= `EXE_NOP_OP;
        ex_reg1  <= `ZeroWord;
        ex_reg2  <= `ZeroWord;
        ex_wd    <= `NOPRegAddr;
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