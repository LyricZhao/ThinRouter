/*
InstROM:
    一个简单的指令储存器
*/

`include "constants_cpu.vh"

module inst_rom(
	input wire ce,
	input wire[`InstAddrBus] addr,
	output reg[`InstBus] inst
);

reg[`InstBus] inst_mem[0:`InstMemNum-1];

// TODO：下面的逻辑主要面向仿真，拆出到Testbench，并编写随机化生成脚本
initial $readmemh ("inst_rom.data", inst_mem);
initial $display("insert done");

always_comb begin
    if (ce == 1'b0)
    begin
        inst <= `ZeroWord;
    end else begin
        inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
    end
end

endmodule