/*
将rip协议的表项打包成一个完整的IP包，存入到FIFO中
*/

`timescale 1ns / 1ps
`include "debug.vh"

module rip_packer (
    input   wire    clk_125M,
    input   wire    clk,
    input   wire    rst,

    input   logic    valid,
    input   logic    last,
    input   logic    [31:0] prefix,
    input   logic    [5:0]  mask,
    input   logic    [31:0] src_ip,
    input   logic    [31:0] dst_ip,
    input   logic    [31:0] nexthop,
    input   logic    [3:0]  metric,

    output  logic    finished // 打包完成
);

// 忽略
logic _fifo_full;

xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(64),
    .READ_DATA_WIDTH($bits(routing_entry_t)),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH($bits(routing_entry_t))
) inner_fifo (
    .din(fifo_in),
    .dout(fifo_out),
    .empty(fifo_empty),
    .full(_fifo_full),
    .injectdbiterr(0),
    .injectsbiterr(0),
    .rd_en(fifo_read_valid),
    .rst(0),
    .sleep(0),
    .wr_clk(clk),
    .wr_en(fifo_write_valid)
);


endmodule