/*
这个模块用来给定 IP 查询 MAC 和 VLAN ID

组合逻辑出结果，参数 ENTRY_COUNT 默认为 8
只需 1 拍
*/

`include "debug.vh"

module simple_arp_table #(
    parameter ENTRY_COUNT = 8
) (
    input   wire    clk,                // 父模块同步时钟
    input   wire    rst_n,              // rst_n 逻辑

    // top 硬件
    // input   wire    clk_btn,            // 硬件 clk 按键
    // input   wire    [3:0] btn,          // 硬件按钮

    // output  wire    [15:0]  led_out,    // 硬件 led 指示灯
    // output  wire    [7:0]   digit0_out, // 硬件低位数码管
    // output  wire    [7:0]   digit1_out, // 硬件高位数码管

    input   wire    write,              // 拉高，记录当前的 IP 和 MAC
    input   wire    query,              // 拉高，查询当前的 IP
    input   wire    [31:0]  ip_input,   // 插入 / 查询的 IP
    input   wire    [47:0]  mac_input,  // 插入的 MAC
    input   wire    [2:0]   vlan_input, // 插入的 VLAN ID
    output  reg     [47:0]  mac_output, // 查询得到的 MAC
    output  reg     [2:0]   vlan_output,// 查询得到的 VLAN ID
    output  reg     done,               // 表示查询结束
    output  reg     found               // 表示查到了结果
);

reg  [$clog2(ENTRY_COUNT)-1:0]  write_head;

reg  [31:0] ip_entries[ENTRY_COUNT-1:0];
reg  [47:0] mac_entries[ENTRY_COUNT-1:0];
reg  [2:0]  vlan_entries[ENTRY_COUNT-1:0];

always_comb begin
    if (ip_input == '0) begin
        found = 0;
        mac_output = 'x;
        vlan_output = 'x;
    end else begin
        // found = 1;
        mac_output = 'x;
        vlan_output = 'x;
        found = 0;
        for (int i = 0; i < ENTRY_COUNT; i++) begin
            if (ip_input == ip_entries[i]) begin
                found = 1;
                mac_output = mac_entries[i];
                vlan_output = vlan_entries[i];
            end
        end
    end
end

reg cooling;
reg need_write;

always_ff @ (posedge clk) begin
    if (!rst_n) begin
        // 初始化
        done <= 1;
        cooling <= 0;
        write_head <= '0;
        // 在 synthesis 中，for loop 会被展开
        for (int i = 0; i < ENTRY_COUNT; i++) begin
            ip_entries[i] <= '0;
            mac_entries[i] <= '0;
            vlan_entries[i] <= '0;
        end
    end else if (write || query) begin
        cooling <= '1;
        need_write <= write;
        done <= 0;
    end else begin
        if (cooling > 0) begin
            cooling <= cooling - 1;
        end
        if (cooling == 1) begin
            done <= 1;
            if (need_write && !found) begin
                // 记录当前得到的 IP MAC VLAN
                // 如果已经存在记录则无视
                $display("ARP table saving entry:");
                $write("\tIP:\t");
                `DISPLAY_IP(ip_input);
                $write("\tMAC:\t");
                `DISPLAY_MAC(mac_input);
                $display("\tVLAN ID:\t%d", vlan_input);
                $display("");
                
                ip_entries[write_head] <= ip_input;
                mac_entries[write_head] <= mac_input;
                vlan_entries[write_head] <= vlan_input;
                write_head <= write_head + 1;
            end
        end
    end
end

endmodule