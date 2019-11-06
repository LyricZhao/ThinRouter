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
    input   wire    clk_fifo,           // FIFO 时钟
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

endmodule