/*
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出
*/

`timescale 1ns / 1ps

`include "debug.vh"
`include "packet.vh"
`include "address.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_125M,
    input   wire    rst_n,

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0] led_out,     // 硬件 led 指示灯
    output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    // 目前先接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  bit     rx_ready,           // 是否允许数据进入
    input   wire    rx_last,            // 数据传入结束
    output  bit     [7:0] tx_data,      // 数据出口
    output  bit     tx_valid,           // 数据出口正在传输
    input   wire    tx_ready,           // 外面是否准备接收：当前不处理外部不 ready 的逻辑 （TODO）
    output  bit     tx_last             // 数据传出结束

);

// 目前在 fifo 中缓冲（但不在发送）的字节数
reg  [5:0] fifo_buffered_size;
// 正在发送的，fifo 中剩余的字节数
// 此变量大于 0 是进行从 fifo 发送的信号
reg  [5:0] fifo_remainder_size;
// 出现问题。写 fifo 照常进行，出 fifo 直接丢弃，直到当前包发完（即 remainder=0）
reg  fifo_canceled;

reg  [7:0] fifo_din;
wire [7:0] fifo_dout;
wire fifo_empty;
wire fifo_full;
reg  fifo_rd_en;
wire fifo_rd_busy;
reg  fifo_rst;
reg  fifo_wr_en;
wire fifo_wr_busy;
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(8),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH(8)
) fifo (
    .din(fifo_din),
    .dout(fifo_dout),
    .empty(fifo_empty),
    .full(fifo_full),
    .rd_en(fifo_rd_en),
    .rd_rst_busy(fifo_rd_busy),
    .rst(fifo_rst),
    .sleep(0),
    .wr_clk(clk_125M),
    .wr_en(fifo_wr_en),
    .wr_rst_busy(fifo_wr_busy)
);

reg is_ip;

endmodule