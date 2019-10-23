/*
涂轶翔：
处理 ARP 包的子模块，由 io_manager 管理
输入：ARP 包的各种信息
输出：整个 ARP 包的数据（从高位到低位），或者表示找不到

时序：
- 使用和 io_manager 同步的时钟
- io_manager 首先给此模块一拍 start_process
- 此模块 done 置 0，开始查表
- 查表结束，done 置 1，result_good 表示是否查到
- io_manager 读取 frame_out 进行输出

io_manager 只能在此模块 done=1 时给一拍 start_process
*/

`timescale 1ns / 1ps

`include "debug.sv"

module arp_packet_manager(
    input   wire    clk,                    // 内部时钟
    input   wire    rst,                    // 重置信号

    input   wire    [47:0]  sender_mac,     // 来源 MAC
    input   wire    [31:0]  sender_ip,      // 来源 IP
    input   wire    [31:0]  target_ip,      // 待查询 IP

    input   wire    start_process,          // 通知此模块开始处理，每次置 1 一拍
    
    output  wire    [223:0] frame_out,      // 输出
    output  wire    done,                   // 查询结束
    output  wire    result_good             // 查询结束，是否有查到
);

/*********
 * ARP 表
 ********/
wire [47:0] lookup_mac;             // 查询结果 MAC
wire [1:0]  lookup_port;            // 查询结果 VLAN ID
wire        lookup_ip_valid;        // 进行查询的按钮
wire        lookup_mac_found;       // 得到 MAC 地址结果
wire        lookup_mac_not_found;   // 得到无结果
enum {
    Idle,                           // 空闲
    Searching                       // 正在查表
} state;                            // 当前状态

assign done = state == Idle;
assign result_good = lookup_mac_found;

arp_table arp_table_inst(
    .clk(clk),
    .rst(rst),
    .lookup_ip(target_ip),
    .lookup_mac(lookup_mac),
    .lookup_port(lookup_port),
    .lookup_ip_valid(lookup_ip_valid),
    .lookup_mac_found(lookup_mac_found),
    .lookup_mac_not_found(lookup_mac_not_found)
);

// ARP 包结构
// 一些固定的数据
assign frame_out[223 -: 64] = 64'h0001080006040002;
// 查询的 MAC
assign frame_out[159 -: 48] = lookup_mac;
// 查询的 IP
assign frame_out[111 -: 32] = target_ip;
// 请求来源 MAC
assign frame_out[79 -: 48] = sender_mac;
// 请求来源 IP
assign frame_out[31 -: 0] = sender_ip;

always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
        state <= Idle;
    end else begin
        if (start_process) begin
            // 开始匹配 IP 地址
            if (state != Idle)
                $display("ERROR: ARP start_process = 1 while last process is running!!");
            else begin
                lookup_ip_valid <= 1;
                state <= Searching;
            end
        end else begin
            lookup_ip_valid <= 0;
            if (state == Searching) begin
                if (lookup_mac_not_found) begin
                    // 没有找到任何结果，放弃
                    $display("ARP table cannot find:");
                    $write("\tIP:  ");
                    DISPLAY_IP(target_ip);
                    state <= Idle;
                end else if (lookup_mac_found) begin
                    // 找到结果
                    $display("ARP found:");
                    $write("\tIP:  ");
                    DISPLAY_IP(target_ip);
                    $write("\tMAC: ");
                    DISPLAY_MAC(lookup_mac);
                    state <= Idle;
                end
            end
        end
    end
end

endmodule