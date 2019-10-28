/*
涂轶翔：
处理 IP 包的子模块，由 io_manager 管理
输入：IP 包的各种信息
输出：IP 包头的数据，或者表示找不到

todo
*/

`timescale 1ns / 1ps

`include "debug.sv"

module ip_packet_manager(
    input   wire    clk,                    // 内部时钟
    input   wire    rst_n,                  // 重置信号

    input   wire    [15:0]  data_size,      // IP 数据大小
    input   wire    [31:0]  fragment_data,  // IP 头信息
    input   wire    [7:0]   ttl,            // IP 头信息
    input   wire    [7:0]   protocol,       // IP 头信息
    input   wire    [31:0]  src_ip,         // IP 头信息
    input   wire    [31:0]  dst_ip,         // IP 头信息
    input   wire    [4447:0]data,           // IP 数据

    input   wire    start_process,          // 通知此模块开始处理，每次置 1 一拍
    
    output  wire    [159:0] frame_out,      // 输出
    output  wire    done,                   // 处理完毕
    output  wire    result_good             // 查到地址，可以转发
);

enum {
    Idle,
    Searching
} state;

always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
        state <= Idle;
    end else begin
    end
end

endmodule