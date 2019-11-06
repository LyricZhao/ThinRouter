/*
MEM模块：
    访存阶段，现在还涉及不到RAM，只是把执行阶段的结果向回写阶段传递
*/

`include "cpu_defs.vh"

module mem(
    input  logic            rst,

    input  reg_addr_t       wd_i,
    input  logic            wreg_i,
    input  word_t           wdata_i,
    input  word_t           hi_i,
    input  word_t           lo_i,
    input  logic            whilo_i,

    output reg_addr_t       wd_o,
    output logic            wreg_o,
    output word_t           wdata_o,
    output word_t           hi_o,
    output word_t           lo_o,
    output logic            whilo_o
);

always_comb begin
    if (rst == 1'b1) begin
        wd_o <= `NOP_REG_ADDR;
        wreg_o <= 1'b0;
        wdata_o <= `ZeroWord;
        {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
        whilo_o <= 1'b0;
    end else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
        {hi_o, lo_o} <= {hi_i, lo_i};
        whilo_o <= whilo_i;
    end
end

endmodule