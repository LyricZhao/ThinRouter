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

parameter inst_mem_file = "cpu_inst_test.mem";

reg[`InstBus] inst_mem[0:`InstMemNum-1];

initial begin
    for (int i = 0; i < `InstMemNum; i = i + 1)
        inst_mem[i] = 0;
    $readmemh (inst_mem_file, inst_mem);
    $display("file loaded");
end

always_comb begin
    if (ce == 1'b0) begin
        inst <= `ZeroWord;
    end else begin
        inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
    end
end

endmodule