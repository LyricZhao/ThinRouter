/*
这个模块用来给定 IP 查询 MAC 和 VLAN ID

目前先写的非常简单，只能记 4 个，组合逻辑完成
*/

module arp_manager (
    input   wire    clk_internal,       // 父模块同步时钟
    input   wire    rst_n,              // rst_n 逻辑

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0]  led_out,    // 硬件 led 指示灯
    output  wire    [7:0]   digit0_out, // 硬件低位数码管
    output  wire    [7:0]   digit1_out, // 硬件高位数码管

    input   wire    valid,              // 拉高一拍，记录当前的 IP 和 MAC
    input   wire    [31:0]  ip_input,   // 插入或查询的 IP
    input   wire    [47:0]  mac_input,  // 插入的 MAC
    input   wire    [3:0]   vlan_input, // 插入的 VLAN ID
    output  wire    [47:0]  mac_output, // 查询得到的 MAC
    output  wire    [3:0]   vlan_output // 查询得到的 VLAN ID
);

bit [1:0]   write_head;
bit [31:0]  ip_entries[3:0];
bit [47:0]  mac_entries[3:0];
bit [3:0]   vlan_entries[3:0];

assign mac_output = 
    (ip_input == ip_entries[0] ? mac_entries[0] : 48'h0) |
    (ip_input == ip_entries[1] ? mac_entries[1] : 48'h0) |
    (ip_input == ip_entries[2] ? mac_entries[2] : 48'h0) |
    (ip_input == ip_entries[3] ? mac_entries[3] : 48'h0);

assign vlan_output = 
    (ip_input == ip_entries[0] ? vlan_entries[0] : 3'h0) |
    (ip_input == ip_entries[1] ? vlan_entries[1] : 3'h0) |
    (ip_input == ip_entries[2] ? vlan_entries[2] : 3'h0) |
    (ip_input == ip_entries[3] ? vlan_entries[3] : 3'h0);

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
    end else if (valid) begin
        // 记录当前得到的 IP MAC VLAN
        ip_entries[write_head] <= ip_input;
        mac_entries[write_head] <= mac_input;
        vlan_entries[write_head] <= vlan_input;
        write_head <= write_head + 1;
    end
end

endmodule