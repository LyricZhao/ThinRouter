
`include "constants_cpu.vh"

module naive_sopc(

	input wire clk,
	input wire rst
	
);

    wire[`InstAddrBus] inst_addr;
    wire[`InstBus] inst;
    wire rom_ce;


    cpu_top cpu_top0(
        .clk(clk),
        .rst(rst),

        .rom_addr_o(inst_addr),
        .rom_data_i(inst),
        .rom_ce_o(rom_ce)

    );

    inst_rom inst_rom0(
        .addr(inst_addr),
        .inst(inst),
        .ce(rom_ce)	
    );


endmodule