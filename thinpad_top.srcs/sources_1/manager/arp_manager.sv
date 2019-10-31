/*
这个模块用来给定 IP 查询 MAC 和 VLAN ID

目前先写的非常简单，只能记 4 个，组合逻辑完成

时序：
记录
    同步 clk_internal 时钟，提供 IP MAC VLAN 三个输入，valid 拉高
查询
    给 ip_input 输入，组合逻辑输出结果
*/

`include "debug.vh"

module arp_manager (
    input   wire    clk_internal,       // 父模块同步时钟
    input   wire    rst_n,              // rst_n 逻辑

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0]  led_out,    // 硬件 led 指示灯
    output  wire    [7:0]   digit0_out, // 硬件低位数码管
    output  wire    [7:0]   digit1_out, // 硬件高位数码管

    input   wire    valid,              // 拉高，记录当前的 IP 和 MAC
    input   wire    [31:0]  ip_input,   // 插入或查询的 IP
    input   wire    [47:0]  mac_input,  // 插入的 MAC
    input   wire    [2:0]   vlan_input, // 插入的 VLAN ID
    output  wire    [47:0]  mac_output, // 查询得到的 MAC
    output  wire    [2:0]   vlan_output,// 查询得到的 VLAN ID
    output  wire    found               // 表示查询到了结果
);

bit [1:0]   write_head;
bit [31:0]  ip_entries[3:0];
bit [47:0]  mac_entries[3:0];
bit [2:0]   vlan_entries[3:0];

assign {mac_output, vlan_output, found} = 
    (ip_input == ip_entries[0] ? {mac_entries[0], vlan_entries[0], 1'b1} : 52'h0) |
    (ip_input == ip_entries[1] ? {mac_entries[1], vlan_entries[1], 1'b1} : 52'h0) |
    (ip_input == ip_entries[2] ? {mac_entries[2], vlan_entries[2], 1'b1} : 52'h0) |
    (ip_input == ip_entries[3] ? {mac_entries[3], vlan_entries[3], 1'b1} : 52'h0);

always_ff @ (posedge clk_internal) begin
    if (~rst_n) begin
        // 初始化
        write_head <= '0;
        // 在 synthesis 中，for loop 会被展开
        for (int i = 0; i < 3; i++) begin
            ip_entries[i] <= '0;
            mac_entries[i] <= '0;
            vlan_entries[i] <= '0;
        end
    end else if (valid && !found) begin
        // 记录当前得到的 IP MAC VLAN
        // 如果已经存在记录则无视
        $display("ARP manager saving entry:");
        $write("\tIP:\t");
        `DISPLAY_IP(ip_input);
        $write("\tMAC:\t");
        `DISPLAY_MAC(mac_input);
        $display("\tVLAN ID:\t%d", vlan_input);
        
        ip_entries[write_head] <= ip_input;
        mac_entries[write_head] <= mac_input;
        vlan_entries[write_head] <= vlan_input;
        write_head <= write_head + 1;
    end
end

endmodule