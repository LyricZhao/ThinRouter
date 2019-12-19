/*
BootRom:
    自启动模块
*/

`include "cpu_defs.vh"

module bootrom(
    input  logic                            clk,

    input  logic[`BOOTROM_ADDR_WITDH-1:0]   addr,
    output word_t                           data
);

// 只读 BootROM
xpm_memory_sprom #(
    .ADDR_WIDTH_A(`BOOTROM_ADDR_WITDH),
    .MEMORY_INIT_FILE("bootrom.mem"),
    .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(`BOOTROM_SIZE * `WORD_SIZE),
    .READ_DATA_WIDTH_A(`WORD_SIZE),
    .READ_LATENCY_A(1)
) xpm_bootrom (
    .addra(addr),
    .clka(clk),
    .douta(data),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(1'b1),

    .dbiterra(),
    .injectdbiterra(1'b0),
    .injectsbiterra(1'b0),
    .sbiterra(),
    .sleep(1'b0)
);

endmodule