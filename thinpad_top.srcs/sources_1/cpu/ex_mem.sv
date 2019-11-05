/*
EX/MEM模块：
    把执行阶段算出来的结果在传递到流水线访存
*/

`include "constants_cpu.vh"

module ex_mem(
	input logic	                clk,
	input logic	                rst,
	
	input reg_addr_t            ex_wd,
	input logic                 ex_wreg,
	input word_t			    ex_wdata,
    input word_t                ex_hi,
    input word_t                ex_lo,
    input logic                 ex_whilo,

    output word_t               mem_hi,
    output word_t               mem_lo,
    output logic                mem_whilo

	output reg_addr_t           mem_wd,
	output logic                mem_wreg,
	output word_t			    mem_wdata,
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        mem_wd <= `NOPRegAddr;
        mem_wreg <= `WriteDisable;
        {mem_wdata, mem_hi, mem_lo} <= {`ZeroWord, `ZeroWord, `ZeroWord};
        mem_whilo <= 1'b0;
    end else begin
        mem_wd <= ex_wd;
        mem_wreg <= ex_wreg;
        mem_wdata <= ex_wdata;
        {mem_hi, mem_lo} <= {ex_hi, ex_lo};
        mem_whilo <= ex_whilo;
    end
end

endmodule