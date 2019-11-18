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
    input   wire    [31:0]  ip_insert,  // 插入的 IP
    input   wire    [31:0]  ip_query,   // 查询的 IP
    input   wire    [47:0]  mac_input,  // 插入的 MAC
    input   wire    [2:0]   vlan_input, // 插入的 VLAN ID
    output  wire    [47:0]  mac_output, // 查询得到的 MAC
    output  wire    [2:0]   vlan_output,// 查询得到的 VLAN ID
    output  wire    done,               // 表示查询结束
    output  wire    found               // 表示查到了结果
);

reg  [$clog2(ENTRY_COUNT)-1:0]  write_head;

reg  [31:0] ip_entries[ENTRY_COUNT-1:0];
reg  [47:0] mac_entries[ENTRY_COUNT-1:0];
reg  [2:0]  vlan_entries[ENTRY_COUNT-1:0];

wire match [2*ENTRY_COUNT-1:0];
wire [47:0] mac_entries_match[2*ENTRY_COUNT-1:0];
wire [2:0]  vlan_entries_match[2*ENTRY_COUNT-1:0];

// 用满二叉树的形式来连接，使得 match[0] 为所有的或
genvar i;
generate for (i = 0; i < ENTRY_COUNT; i++) begin
    assign mac_entries_match[ENTRY_COUNT+i] = match[ENTRY_COUNT+i] ? mac_entries[i] : '0;
    assign vlan_entries_match[ENTRY_COUNT+i] = match[ENTRY_COUNT+i] ? vlan_entries[i] : '0;
    assign match[ENTRY_COUNT+i] = ip_query == ip_entries[i];
end
endgenerate
generate for (i = 1; i < ENTRY_COUNT; i++) begin
    assign mac_entries_match[i] = mac_entries_match[2*i+1] | mac_entries_match[2*i];
    assign vlan_entries_match[i] = vlan_entries_match[2*i+1] | vlan_entries_match[2*i];
    assign match[i] = match[2*i+1] | match[2*i];
end
endgenerate
assign done = 1;
assign found = match[1];
assign mac_output = mac_entries_match[1];
assign vlan_output = vlan_entries_match[1];

always_ff @ (posedge clk) begin
    if (!rst_n) begin
        // 初始化
        write_head <= '0;
        // 在 synthesis 中，for loop 会被展开
        for (int i = 0; i < ENTRY_COUNT; i++) begin
            ip_entries[i] <= '0;
            mac_entries[i] <= '0;
            vlan_entries[i] <= '0;
        end
    end else if (write && !match[1]) begin
        // 记录当前得到的 IP MAC VLAN
        // 如果已经存在记录则无视
        $display("ARP table saving entry:");
        $write("\tIP:\t");
        `DISPLAY_IP(ip_insert);
        $write("\tMAC:\t");
        `DISPLAY_MAC(mac_input);
        $display("\tVLAN ID:\t%d", vlan_input);
        $display("");
        
        ip_entries[write_head] <= ip_insert;
        mac_entries[write_head] <= mac_input;
        vlan_entries[write_head] <= vlan_input;
        write_head <= write_head + 1;
    end
end

endmodule