/*
EX/MEM模块：
    把执行阶段算出来的结果在传递到流水线访存
*/

`include "constants_cpu.vh"

module ex_mem(
	input wire	clk,
	input wire	rst,
	
	input wire[`RegAddrBus]       ex_wd,
	input wire                    ex_wreg,
	input wire[`RegBus]			  ex_wdata,

	output reg[`RegAddrBus]       mem_wd,
	output reg                    mem_wreg,
	output reg[`RegBus]			  mem_wdata
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        mem_wd <= `NOPRegAddr;
        mem_wreg <= `WriteDisable;
        mem_wdata <= `ZeroWord;
    end else begin
        mem_wd <= ex_wd;
        mem_wreg <= ex_wreg;
        mem_wdata <= ex_wdata;
    end
end

endmodule