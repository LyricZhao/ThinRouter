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
    input   wire    rst_n,              // rstn 逻辑

    // top 硬件
    // input   wire    clk_btn,            // 硬件 clk 按键
    // input   wire    [3:0] btn,          // 硬件按钮

    // output  wire    [15:0] led_out,     // 硬件 led 指示灯
    // output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    // output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    // 目前先接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  bit     [7:0] tx_data,      // 数据出口
    output  bit     tx_valid            // 数据出口正在传输
);

bit [511:0] buffer = '0;
int read_count = 0;
int send_count = 0;

bit send_ok = 0;

int read_state = 0;
int send_state = 0;

always_ff @(posedge clk_125M) begin
    if (!rst_n) begin
        read_count <= 0;
        send_count <= 0;
        send_ok <= 0;
        read_state <= 0;
        send_state <= 0;
    end else begin
        case (read_state)
            0: begin
                if (rx_valid) begin
                    read_count <= 1;
                    read_state <= 1;
                end
            end
            1: begin
                if (read_count == 7) begin
                    read_count <= 0;
                    read_state <= 2;
                end else begin
                    read_count <= read_count + 1;
                end
            end
            2: begin
                if (read_count == 64) begin
                    
                end
            end
        endcase
    end
end

endmodule