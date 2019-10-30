/*
此模块用来将已经展开的包内容进行处理，
但是 IP 包的 Data 除外，它应当由 io_manager 直接转发

todo: 处理中间突然结束的包
todo: 处理错误格式的包

时序：
-   io_manager 开始收包，packet_arrive 置一拍 1
-   io_manager 在接收的同时告诉此模块已经收到了多少字节，
    收到的数据会同时传递给 frame_in
    （会比 io_manager 慢一拍）
-   此模块检查信息，能够在包读完之前知道当前这个包有多长，
    对于 IP 包，会提前计算头长度，让 io_manager 从那里开始自己直接转发
    -   发现是 IP 包后（且后面有 data 需要直接转发）：
        require_direct_fw 置 1
        direct_fw_offset 置 data 开始的位置
    -   io_manager 停在 direct_fw_offset 的位置
        rx_ready 置 0，等待此模块处理完
    -   此模块生成新的 header 在 frame_out
        其长度在 out_bytes （默认 20）
        out_ready 置 1
    -   io_manager 把新的 header 发走，然后继续读 fifo 直接转发
-   随时，此模块可能发现包不合法
    bad 置 1，io_manager 看到直接走丢包流程

工作流程：
读取至 18 字节，如果协议不是 ARP 或者 IP 则丢包（置 bad）
读取至 22 字节，检查是否是带有 data 的 IP 包
    如是则置 require_direct_fw
    如否则等 io_manager 读完整个包
读完后（或读到 data 前），查表
查完表输出结果

ARP 包网帧：
0   [367:320]   目标 MAC
6   [319:272]   来源 MAC
12  [271:256]   0x8100  VLAN
14  [255:240]   [251:240] 为 VLAN ID
16  [239:224]   0x0806  ARP
18  [223:208]   0x0001  以太网
20  [207:192]   0x8000  IPv4
22  [191:184]   0x06    硬件地址长度
23  [183:176]   0x04    协议地址长度
24  [175:160]   0x0001  ARP Request
26  [159:112]   来源 MAC
32  [111:80 ]   来源 IP
36  [ 79:32 ]   目标 MAC (全 0)
42  [ 31:0  ]   目标 IP
46

IP  包网帧：
0   [367:320]   目标 MAC
6   [319:272]   来源 MAC
12  [271:256]   0x8100  VLAN
14  [255:240]   [251:240] 为 VLAN ID
16  [239:224]   0x0800  IPv4
18  [223:216]   0x45    Protocol v4, header 大小 20B
19  [215:208]   0x00    DSF
20  [207:192]   IP 包长度
22  [191:176]   连续包识别码
24  [175:160]   [174]=DF, [173]=MF, [172:160]=Offset （用于分包）
26  [159:152]   TTL
27  [151:144]   IP 协议
28  [143:128]   Checksum
30  [127:96 ]   来源 IP
34  [ 95:64 ]   目标 IP
38
*/

`timescale 1ns / 1ps

`include "debug.vh"
`include "address.vh"

module packet_manager (
    input   wire    clk_internal,       // 父模块同步时钟
    input   wire    rst_n,              // rst_n 逻辑

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0] led_out,     // 硬件 led 指示灯
    output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    input   wire    packet_arrive,      // 开始收包，置一拍 1

    input   wire    [367:0] frame_in,   // 输入以太网帧
    input   byte    bytes_read,         // 已经读取的字符数

    output  bit     bad,                // 包不可用，该丢掉

    output  bit     [367:0] frame_out,  // 输出以太网帧
    output  bit     out_ready,          // 输出已处理完毕
    output  byte    out_bytes,          // 输出网帧大小（字节）

    output  bit     require_direct_fw,  // 要求父模块进行直接转发
    output  byte    direct_fw_offset,   // 从哪里开始直接转发
    output  int     fw_bytes            // 转发大小（字节）
);

`define BAD_EXIT(msg) \
    bad <= 1; \
    state <= Idle; \
    $display("%s", {"BAD PACKET: ", msg});

enum logic [2:0] {
    Idle,       // 空闲
    Receiving,  // 正在和 io_manager 同步接收包
    IpRunning,  // 正在用子模块处理生成新网帧
    ArpRunning, // 正在用子模块处理生成新网帧
    Test
} state;

enum logic {
    ARP,
    IPv4
} protocol;     // 目前读取的网帧采用的协议，在读取 18 字节后确定

bit arp_entry_valid;            // 让 arp_manager 写记录的信号，可能拉高不止一拍
wire [47:0] arp_mac_result;     // arp_manager 查询结果
wire [2:0]  arp_vlan_result;    // arp_manager 查询结果
wire arp_found;                 // 是否查询到了结果
// 处理 ARP 表
arp_manager arp_manager_inst (
    .clk_internal(clk_internal),
    .rst_n(rst_n),

    .valid(arp_entry_valid),
    .ip_input(frame_in[111:80]),
    .mac_input(frame_in[159:112]),
    .vlan_input(frame_in[242:240]),
    .mac_output(arp_mac_result),
    .vlan_output(arp_vlan_result),
    .found(arp_found)
);

always_ff @ (posedge clk_internal) begin
    if (~rst_n) begin
        // 复位
        state <= Idle;
        bad <= 0;
        out_ready <= 0;
        out_bytes <= 0;
        require_direct_fw <= 0;
        direct_fw_offset <= 0;

        // ARP 表的信号
        arp_entry_valid <= 0;

        // test
        // state <= Test;
        // out_bytes <= 46;
        // out_ready <= 1;
        // frame_out <= 368'h00E04C6806E2A888088888888100000008060001080006040002A888088888880606060600E04C6806E206060601;
    end else if (packet_arrive) begin
        // 开始接收数据包
        if (state != Idle) begin
            $display("ERROR: packet_manager packet_arrive = 1 while not idle!!");
        end else begin
            state <= Receiving;
            bad <= 0;
            out_ready <= 0;
            out_bytes <= 0;
            require_direct_fw <= 0;
            direct_fw_offset <= 0;
        end
    end else begin
        case(state)
            Idle: begin
                bad <= 0;
            end
            Receiving: begin
                case(bytes_read)
                    // 接受了 VLAN ID
                    16: begin
                        // 根据端口设置 frame_out 的 MAC
                        case(frame_in[251:240])
                            1: begin
                                frame_out[319:272] <= `ROUTER_MAC_1;
                            end
                            2: begin
                                frame_out[319:272] <= `ROUTER_MAC_2;
                            end
                            3: begin
                                frame_out[319:272] <= `ROUTER_MAC_3;
                            end
                            4: begin
                                frame_out[319:272] <= `ROUTER_MAC_4;
                            end
                        endcase
                        // todo 检查目标 MAC 和 VLAN ID 是否匹配
                    end
                    // 接受了协议编号
                    18: begin
                        // 检查协议是否为 ARP 或 IP
                        case(frame_in[239:224])
                            16'h0806: begin
                                if (btn[1]) begin
                                    `BAD_EXIT("User cancelled");
                                end else begin
                                    protocol <= ARP;
                                    // 如果目标 MAC 不是广播则丢包
                                    if (frame_in[367:320] != '1) begin
                                        `BAD_EXIT("Invalid Dst MAC for ARP");
                                    end
                                end
                            end
                            16'h0800: begin
                                if (btn[0]) begin
                                    `BAD_EXIT("User cancelled");
                                end else
                                    protocol <= IPv4;
                            end
                            default: begin
                                `DISPLAY_BITS(frame_in, 367, 0);
                                `BAD_EXIT("Unsupported protocol");
                            end
                        endcase
                    end
                    // 对于 IP 包接受了 IP 包长度
                    22: begin
                        // 检查是否是 IP 且具有 data 包
                        if (protocol == IPv4 && frame_in[207:192] > 20) begin
                            // 具有 data 包，则需要 io_manager 从 header 结束之后直接转发 data
                            require_direct_fw <= 1;
                            direct_fw_offset <= 38;
                            fw_bytes <= frame_in[207:192] - 20;
                        end
                    end
                    // 对于 IP 包接受了 TTL
                    27: begin
                        // 如果 TTL 为零则丢弃
                        if (protocol == IPv4 && frame_in[159:152] == '0) begin
                            `BAD_EXIT("TTL = 0");
                        end
                    end
                    // 对于 ARP 接受了来源 MAC 和 IP
                    36: begin
                        // 让 arp_manager 记录
                        if (protocol == ARP)
                            arp_entry_valid <= 1;
                    end
                    37: begin
                        if (protocol == ARP)
                            arp_entry_valid <= 0;
                    end
                    // IP header 结束
                    38: begin
                        // 如果是 IP 包，这里要开始处理
                        if (protocol == IPv4) begin
                            state <= IpRunning;
                            // [367:320]    目标 MAC    等待处理
                            // [319:272]    来源 MAC    已经在 16 处理
                            // VLAN
                            frame_out[271:252] <= frame_in[271:252];
                            // [251:240]    VLAN ID     需要后面查表
                            // IP header
                            frame_out[239:160] <= frame_in[239:160];
                            // TTL -= 1
                            frame_out[159:152] <= frame_in[159:152] - 1;
                            // IP header
                            frame_out[151:144] <= frame_in[151:144];
                            // IP header checksum
                            if (frame_in[143:136] == '1)
                                frame_out[143:136] <= 8'h1;
                            else
                                frame_out[143:136] <= frame_in[143:136] + 1;
                            // IP header src&dst IP
                            frame_out[135:64] <= frame_in[135:64];
                        end
                    end
                    // ARP 结束
                    46: begin
                        // 如果是 ARP 包，这里要开始处理
                        if (protocol == ARP) begin
                            state <= ArpRunning;
                            // 目标 MAC     直接回复发出者
                            frame_out[367:320] <= frame_in[319:272];
                            // [319:272]    来源 MAC    已经在 16 处理
                            // ARP 各种内容
                            frame_out[271:176] <= frame_in[271:176];
                            // ARP Reply
                            frame_out[175:160] <= 16'h2;
                            // [159:112]    来源 MAC    需要后面处理
                            frame_out[111:80] <= frame_in[31:0];
                            // 返回给 MAC 和 IP
                            frame_out[79:0] <= frame_in[159:80];
                        end else begin
                            // ？？？
                            // todo 添加一种硬件报错方法
                            `BAD_EXIT("???");
                        end
                    end
                endcase
            end
            // 正在处理 IP 包
            IpRunning: begin
                if (!arp_found) begin
                    // ARP 表没有找到匹配，不知道从哪里发走
                    `BAD_EXIT("No match found in ARP");
                    // todo 发 ARP 询问
                end else begin
                    frame_out[367:320] <= arp_mac_result;
                    frame_out[251:240] <= arp_vlan_result;
                    out_ready <= 1;
                    out_bytes <= 38;
                    state <= Idle;
                end
            end
            // 正在处理 ARP 包
            ArpRunning: begin
                // 检查 VLAN ID 与目标 IP 是否匹配，匹配则填上 MAC 结果
                case (frame_in[242:240])
                    1: begin
                        if (frame_in[31:0] == `ROUTER_IP_1)
                            frame_out[159:112] <= `ROUTER_MAC_1;
                        else
                            bad <= 1;
                    end
                    2: begin
                        if (frame_in[31:0] == `ROUTER_IP_2)
                            frame_out[159:112] <= `ROUTER_MAC_2;
                        else
                            bad <= 1;
                    end
                    3: begin
                        if (frame_in[31:0] == `ROUTER_IP_3)
                            frame_out[159:112] <= `ROUTER_MAC_3;
                        else
                            bad <= 1;
                    end
                    4: begin
                        if (frame_in[31:0] == `ROUTER_IP_4)
                            frame_out[159:112] <= `ROUTER_MAC_4;
                        else
                            bad <= 1;
                    end
                    default:    bad <= 1;
                endcase
                out_ready <= 1;
                out_bytes <= 46;
                state <= Idle;
            end
            default: begin
            end
        endcase
    end
end

endmodule