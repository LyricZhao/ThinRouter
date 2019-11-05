/*
PC(Program Counter)模块：
    每个时钟周期地址加4，ce是使能输出（？感觉没啥用）
    另外，之前在另一本书上见过最好用rst_n而非rst，这点后面再说，这里先保持
*/

`include "constants_cpu.vh"

module pc_reg(
	input wire clk,
	input wire rst,
	
	output reg[`InstAddrBus] pc,
	output reg ce
);

always_ff @ (posedge clk) begin
    if (ce == 1'b0) begin
        pc <= 32'h00000000;
    end else begin
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