`timescale 1ns/1ps

`include "cpu_defs.vh"

module testbench_cpu();

logic clk_50M;
logic rst;

initial begin
    clk_50M = 0;
    forever #10 clk_50M = ~clk_50M;
end
 
inst_addr_t inst_addr;
word_t inst;
logic rom_ce;

logic top_ram_ce_o;
word_t top_ram_data_i;
word_t top_ram_addr_o;
word_t top_ram_data_o;
logic top_ram_we_o;
logic[3:0] top_ram_sel_o;
// TODO: 把cpu_top放到thinpad_top里面
cpu_top cpu_top_inst(
    .clk(clk_50M),
    .rst(rst),

    .rom_addr_o(inst_addr),
    .rom_data_i(inst),
    .rom_ce_o(rom_ce),

    .ram_data_i(top_ram_data_i),
    .ram_addr_o(top_ram_addr_o),
    .ram_data_o(top_ram_data_o),
    .ram_we_o(top_ram_we_o),
    .ram_sel_o(top_ram_sel_o),
    .ram_ce_o(top_ram_ce_o)
);

inst_rom #("cpu_load_test.mem") inst_rom0(
    .addr(inst_addr),
    .inst(inst),
    .ce(rom_ce)
);

data_ram data_ram0(
    .clk(clk_50M),
    .ce(top_ram_ce_o),
    .we(top_ram_we_o),
    .addr(top_ram_addr_o),
    .sel(top_ram_sel_o),
    .data_i(top_ram_data_o),
    .data_o(top_ram_data_i)
);

initial begin
    rst = 1;
    #195 rst = 0;
end

endmodule