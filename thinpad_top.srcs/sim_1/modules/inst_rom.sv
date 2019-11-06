/*
InstROM:
    一个简单的指令储存器
*/

`include "cpu_defs.vh"

module inst_rom(
	input  logic            ce,
	input  inst_addr_t      addr,
	output word_t           inst
);

parameter inst_mem_file = "cpu_inst_test.mem";

word_t inst_mem[0:`INST_MEM_NUM-1];

initial begin
    for (int i = 0; i < `INST_MEM_NUM; i = i + 1)
        inst_mem[i] = `ZeroWord;
    $readmemh (inst_mem_file, inst_mem);
    $display("file loaded");
end

always_comb begin
    if (ce == 1'b0) begin
        inst <= `ZeroWord;
    end else begin
        inst <= inst_mem[addr[`INST_MEM_NUM_LOG2+1:2]];
    end
end

endmodule