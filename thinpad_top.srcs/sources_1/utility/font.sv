/*
字体
给定字符和横纵坐标（字体宽 8，高 16），取得对应 1/0

同步信号：
虽然出入数据有延迟，同步信号与出入数据一定是一一匹配的
*/

module font #(
    parameter type SYNC_TYPE
)(
    input logic clk,
    
    input logic [6:0] char,
    input logic [2:0] x,
    input logic [3:0] y,
    input SYNC_TYPE sync_in,

    output logic result,
    output SYNC_TYPE sync_out
);

logic [7:0] mem_out;
assign result = mem_out[x];
xpm_memory_sprom #(
    .ADDR_WIDTH_A(11),
    .MEMORY_INIT_FILE("font.mem"),
    .MEMORY_SIZE(16384),
    .READ_DATA_WIDTH_A(8),
    .READ_LATENCY(1)
) memory_inst (
    .addra({char, y}),
    .clka(clk),
    .douta(mem_out),
    .ena(1),
    .rsta(0)
);

always_ff @(posedge clk) begin
    sync_out <= sync_in;
end

endmodule