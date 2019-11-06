/*
MEM/WB模块：
    只是把访存阶段的结果向回写阶段传递
*/

`include "cpu_defs.vh"

module mem_wb(
	input  logic            clk,
	input  logic            rst,

	input  reg_addr_t       mem_wd,
	input  logic            mem_wreg,
	input  word_t			mem_wdata,
    input  word_t           mem_hi,
    input  word_t           mem_lo,
    input  logic            mem_whilo,

	output reg_addr_t       wb_wd,
	output logic            wb_wreg,
	output word_t			wb_wdata,
    output word_t           wb_hi,
    output word_t           wb_lo,
    output logic            wb_whilo
);

always_ff @(posedge clk) begin
    if (rst == 1'b1) begin
        wb_wd <= `NOP_REG_ADDR;
        wb_wreg <= 1'b0;
        wb_wdata <= `ZeroWord;
        {wb_hi, wb_lo} <= {`ZeroWord, `ZeroWord};
        wb_whilo <= 1'b0;
    end else begin
        wb_wd <= mem_wd;
        wb_wreg <= mem_wreg;
        wb_wdata <= mem_wdata;
        {wb_hi, wb_lo} <= {mem_hi, mem_lo};
        wb_whilo <= mem_whilo;
    end
end

endmodule