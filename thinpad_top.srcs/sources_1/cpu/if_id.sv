/*
IF/ID模块：
    暂时保存取指(Fetch)阶段取得的指令和地址，在下一个时钟传递给译码(Decode)阶段
*/

`include "constants_cpu.vh"

module if_id(
	input wire clk,
	input wire rst,
	
	input wire[`InstAddrBus]      if_pc,
	input wire[`InstBus]          if_inst,
	output reg[`InstAddrBus]      id_pc,
	output reg[`InstBus]          id_inst
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
    end else begin
        id_pc <= if_pc;
        id_inst <= if_inst;
    end
end

endmodule