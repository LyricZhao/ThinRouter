`timescale 1ns/1ps

`include "constants_cpu.vh"

module testbench_cpu();

reg clk_50M;
reg rst;

initial begin
    clk_50M = 1'b0;
    forever #10 clk_50M = ~clk_50M;
end
 
wire[`InstAddrBus] inst_addr;
wire[`InstBus] inst;
wire rom_ce;

// TODO: 把cpu_top放到thinpad_top里面
cpu_top cpu_top_inst(
    .clk(clk_50M),
    .rst(rst),

    .rom_addr_o(inst_addr),
    .rom_data_i(inst),
    .rom_ce_o(rom_ce)
);

inst_rom #("cpu_inst_test.mem") inst_rom0(
    .addr(inst_addr),
    .inst(inst),
    .ce(rom_ce)
);

initial begin
    rst = `RstEnable;
    #195 rst= `RstDisable;
end

endmodule