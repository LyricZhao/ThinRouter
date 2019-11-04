/*
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出
*/

`timescale 1ns / 1ps

`include "debug.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_io,             // IO 时钟
    input   wire    clk_internal,       // 内部处理逻辑用的时钟
    input   wire    rst_n,              // rstn 逻辑

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

////// 接收
logic [367:0] frame_in;         // 接收的帧
logic [5:0]   rx_count;         // 已经接收了多少字节
logic [5:0]   rx_size;          // 帧的大小（不包括 IP 包 payload）

////// 处理（交给子模块）
wire  [367:0] frame_out;        // 发出的帧
wire          processing;       // 子模块正在处理帧
wire          frame_out_valid;  // 处理完成
wire          frame_bad;        // 被处理的帧有问题，应当丢弃
logic         process_start;    // 开始处理信号
logic         process_reset;    // 重置信号

////// 发出
logic [5:0]   tx_count;         // 已经发出的字节数
logic [5:0]   tx_size;          // 需要发出的字节数

////// 转发
logic [127:0] fw_buffer;        // 转发的缓冲（循环使用）
logic [3:0]   fw_rx_pointer;    // 接收时写入的位置
logic [3:0]   fw_tx_pointer;    // 发送时读取的位置
logic [15:0]  fw_size;          // 总共需要转发的字节数
logic [15:0]  fw_count;         // 已经转发的字节数

////// 状态
wire  Forwarding = fw_count != 0;
wire  Discarding = (rx_count == rx_size) && !Forwarding;

always_ff @(posedge clk_io) begin
    if (!rst_n) begin
        // reset
        rx_count <= 0;
        rx_size <= 46;
        process_start <= 0;
        process_reset <= 1;
        tx_count <= 0;
        tx_size <= 0;
        fw_rx_pointer <= 0;
        fw_tx_pointer <= 0;
        fw_size <= 0;
        fw_count <= 0;
    end else begin
    end
end

endmodule