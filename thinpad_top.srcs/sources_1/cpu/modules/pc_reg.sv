/*
PC(Program Counter)模块：
    每个时钟周期地址加4，ce是使能输出
    另外，之前在另一本书上见过最好用rst_n而非rst，这点后面再说，这里先保持
*/

`include "cpu_defs.vh"

module pc_reg(
    input  logic        clk,
    input  logic        rst,
    input  stall_t      stall,
	
    output inst_addr_t  pc,     // 程序计数器
    output logic        ce      // 指令rom的使能
);

always_ff @ (posedge clk) begin
    if (ce == 1'b0) begin
        pc <= 32'h00000000;
    end else if (stall[0] == 1'b0) begin
        pc <= pc + 4'h4;
    end
end

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        ce <= 1'b0;
    end else begin
        ce <= 1'b1;
    end
end

endmodule