/*
涂轶翔：
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
针对数据包是 IP 还是 ARP 会分别交给 ip_packet_manager 和 arp_packet_manager 来处理
*/

`include "debug.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_io,             // IO 时钟
    input   wire    clk_internal,       // 内部处理逻辑用的时钟

    // 在第一个时钟周期从 0 变为 1 的信号
    input   wire    gtx_resetn,

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

typedef byte unsigned u8;

// 初始化用，先用 initial 驱动 (todo)
reg reset;
initial begin
    reset = 0;
    #10;
    reset = 1;
    #10;
    reset = 0;
end

/****************************
 * 数据包内容，不包括 preamble
 ***************************/
// DstMac       48b
bit [47:0]  dst_mac;        // 目标 MAC 地址
// SrcMac       48b
bit [47:0]  src_mac;        // 来源 MAC 地址
// VlanJunk     30b
// - protocol:          0x8100  VLAN
// - stuff:             14'     ignored
// VlanId        2b
bit [1:0]   vlan_id;        // VLAN 接口编号
// Protocol     16b
enum {
    IP, ARP
} protocol;                 // 协议


/*
 * 域的说明
 * 【除了 IP 数据部分】 其他部分读取后都是大端序
 * 即数据按字节接收，在对应的域中从 大下标 到 小下标 存储
 * Data Stream:     0F    49    2C    48   A3
 * Variable Index:  39:32 31:24 23:16 15:8 7:0
 */

/******************************************************************
 * ARP 包
 * ref: https://en.wikipedia.org/wiki/Address_Resolution_Protocol
 *****************************************************************/
// ArpJunk      64b
// - hardware type:     0x0001  Ethernet
// - protocol type:     0x0800  IPv4
// - hardware length:   0x06    MAC
// - protocol length:   0x04    IPv4
// - operation:         0x0001  Request
// ArpSenderMac 48b
bit [47:0]  arp_sender_mac; // 发出者 MAC 地址
// ArpSenderIp  32b
bit [31:0]  arp_sender_ip;  // 发出者 IP 地址
// ArpTargetMac 48b
// - target mac:        48'h0   ignored
// ArpTargetIp  32b
bit [31:0]  arp_target_ip;  // 查询的 IP 地址

/*****************************************
 * IPv4 包
 * ref:https://en.wikipedia.org/wiki/IPv4
 ****************************************/
// IpJunk1       4b
// - version:           0x4     IPv4
// IpHeaderSize  4b
bit [3:0]   ip_header_size; // IPv4 头长度（单位为 4 字节）
// IpJunk2       8b
// - DSCP:              0x00    ignored
// IpTotalSize  16b
bit [15:0]  ip_total_size;  // IPv4 总长度（包括 IPv4 头和数据）
// IpFragment   32b
// - ip_identification: 16'     TODO (maybe)
// - reserved flag:     1'0     ignored
// - don't fragment:    1'      TODO (maybe)
// - more fragments:    1'      TODO (maybe)
// - fragment offset:   13'     TODO (maybe)
bit [31:0]  ip_fragment;    // 和分包相关的数据，直接转发
// IpTtl         8b
bit [7:0]   ip_ttl;         // 剩余转发次数
// IpProtocol    8b
bit [7:0]   ip_protocol;    // IP 协议
// IpJunk3      16b
// - header checksum:   16'     TODO (maybe)
// IpSrcIp      32b
bit [31:0]  ip_src_ip;      // 来源 IP 地址
// IpDstIp      32b
bit [31:0]  ip_dst_ip;      // 目标 IP 地址
// IpOptions:   直到 header 大小消耗完
// - options:           very likely not to do
// IpData:      直到 IP 包大小消耗完
u8  ip_data [555:0];        // IP 数据，协议要求路由器至少能处理 576B 的包，即 20B 头文件和 556B 数据


// 读取数据包时，下一步将要解码什么字段
enum {
    DstMac,         // 48b
    SrcMac,         // 48b
    VlanJunk,       // 30b
    // VlanId,      //  2b
    Protocol,       // 16b
    ArpJunk,        // 64b
    ArpSenderMac,   // 48b
    ArpSenderIp,    // 32b
    ArpTargetMac,   // 48b
    ArpTargetIp,    // 32b
    ArpComplete,    // 等待 last
    IpJunk1,        //  4b
    // IpHeadSize,  //  4b
    IpJunk2,        //  8b
    IpTotalSize,    // 16b
    IpFragment,     // 32b
    IpTtl,          //  8b
    IpProtocol,     //  8b
    IpJunk3,        // 16b
    IpSrcIp,        // 32b
    IpDstIp,        // 32b
    IpOptions,      // (ip_header_size - 5) * 4 bytes
    IpData,         // ip_total_size - ip_header_size * 4
    IpComplete,     // 等待 last
    Discard         // 遇到错误，准备丢包
} decode_next;
// 下面该写入某个域的第几位
int read_offset;

initial begin
    // 让时间输出格式更好看
    $timeformat(-9, 2, " ns", 20);
end

function void handle_arp();
    // todo
    $display("Processing ARP packet...");
endfunction

function void handle_ip();
    $write("IP Data:\n\t");
    `DISPLAY_DATA(ip_data, ip_total_size - 4 * ip_header_size);
    // todo
    $display("Processing IP packet...");
endfunction

always_ff @ (posedge clk_io or posedge reset) begin
    // 初始化
    if (reset) begin
        $display("init");
        rx_ready <= 1;
        tx_data <= 0;
        tx_valid <= 0;
        tx_last <= 0;
        decode_next <= DstMac;
        read_offset <= 0;
    end else if (rx_valid) begin
        if (!rx_ready)
            $display("I AM NOT READY!!!");
        //$display("%0t: %x", $realtime, rx_data);

        if (rx_last) begin
            $display("(last)");
            case(decode_next)
                ArpComplete: begin
                    // todo: CRC checksum
                    handle_arp();
                    decode_next <= DstMac;
                end
                IpComplete: begin
                    // todo: CRC checksum
                    handle_ip();
                    decode_next <= DstMac;
                end
                Discard: begin
                    $display("packet over and discarded");
                    decode_next <= DstMac;
                end
                default: begin
                    // 突然收到 last，说明包不完整
                    $display("?? this packet fails.");
                end
            endcase
        end else begin
        // 处理输入
            case(decode_next)
                DstMac: begin
                    dst_mac[47 - read_offset -: 8] = rx_data;
                    if (read_offset == 40) begin
                        read_offset <= 0;
                        decode_next <= SrcMac;
                        $write("Destination MAC:\n\t");
                        `DISPLAY_MAC(dst_mac);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                SrcMac: begin
                    src_mac[47 - read_offset -: 8] = rx_data;
                    if (read_offset == 40) begin
                        read_offset <= 0;
                        decode_next <= VlanJunk;
                        $write("Source MAC:\n\t");
                        `DISPLAY_MAC(src_mac);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                VlanJunk: begin
                    if (read_offset == 24) begin
                        vlan_id = rx_data[1:0];
                        read_offset <= 0;
                        decode_next <= Protocol;
                        $display("VLAN ID:\n\t%x", vlan_id);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                Protocol: begin
                    if (read_offset == 0) begin
                        read_offset <= read_offset + 8;
                        // IP 和 ARP 的协议前八位都是 0x08，如果不是则丢包
                        if (rx_data != 8'h08) begin
                            $display("Invalid Protocol:\n\t[7:0]=%x", rx_data);
                            decode_next <= Discard;
                        end
                    end else begin
                        // 检查后八位
                        read_offset <= 0;
                        case (rx_data)
                            8'h06: begin
                                decode_next <= ArpJunk;
                                $display("ARP Packet");
                            end
                            8'h00: begin
                                decode_next <= IpJunk1;
                                $display("IPv4 Packet");
                            end
                            default: begin
                                decode_next <= Discard;
                                $display("Invalid Protocol:\n\t[15:8]=%x", rx_data);
                            end
                        endcase
                    end
                end
                ArpJunk: begin
                    if (read_offset == 56) begin
                        read_offset <= 0;
                        decode_next <= ArpSenderMac;
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                ArpSenderMac: begin
                    arp_sender_mac[47 - read_offset -: 8] = rx_data;
                    if (read_offset == 40) begin
                        read_offset <= 0;
                        decode_next <= ArpSenderIp;
                        $write("Sender MAC:\n\t");
                        `DISPLAY_MAC(arp_sender_mac);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                ArpSenderIp: begin
                    arp_sender_ip[31 - read_offset -: 8] = rx_data;
                    if (read_offset == 24) begin
                        read_offset <= 0;
                        decode_next <= ArpTargetMac;
                        $write("Sender IP:\n\t");
                        `DISPLAY_IP(arp_sender_ip);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                ArpTargetMac: begin
                    if (rx_data == 0) begin
                        if (read_offset == 40) begin
                            read_offset <= 0;
                            decode_next <= ArpTargetIp;
                        end else begin
                            read_offset <= read_offset + 8;
                        end
                    end else begin
                        $display("Invalid Target MAC:\n\t%x at %0d", rx_data, read_offset);
                        decode_next <= Discard;
                    end
                end
                ArpTargetIp: begin
                    arp_target_ip[31 - read_offset -: 8] = rx_data;
                    if (read_offset == 24) begin
                        read_offset <= 0;
                        $write("Target IP:\n\t");
                        `DISPLAY_IP(arp_target_ip);
                        decode_next <= ArpComplete;
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                ArpComplete: begin
                    //$display("ARP Completed, waiting for rx_last");
                end
                IpJunk1: begin
                    // 确保 IP 协议版本为 4，否则丢包
                    if (rx_data[7:4] == 4) begin
                        ip_header_size = rx_data[3:0];
                        if (rx_data[3:0] < 5) begin
                            // IP 头大小必须大于等于 5
                            $display("Invalid IP Header Size:\n\t%0dB", rx_data[3:0] * 4);
                            decode_next <= Discard;
                        end else begin
                            $display("IP Header Size:\n\t%0dB", ip_header_size * 4);
                            decode_next <= IpJunk2;
                        end
                    end else begin
                        $display("Invalid IP version:\n\t%0d", rx_data[3:0]);
                        decode_next <= Discard;
                    end
                end
                IpJunk2: begin
                    // 完全 ignore
                    decode_next <= IpTotalSize;
                end
                IpTotalSize: begin
                    ip_total_size[15 - read_offset -: 8] = rx_data;
                    if (read_offset == 8) begin
                        read_offset <= 0;
                        decode_next <= IpFragment;
                        $display("IP Total Size:\n\t%0dB", ip_total_size);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                IpFragment: begin
                    ip_fragment[31 - read_offset -: 8] = rx_data;
                    if (read_offset == 24) begin
                        read_offset <= 0;
                        decode_next <= IpTtl;
                        $display("IP Fragment Info:\n\tIdentification: 0x%4x\n\tDF: %d\n\tMF: %d\n\tOffset: %0dB", 
                            ip_fragment >> 16, ip_fragment[14], ip_fragment[13], (ip_fragment & 16'h1fff) * 8);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                IpTtl: begin
                    ip_ttl = rx_data;
                    if (rx_data == 0) begin
                        $display("TTL = 0, Discard");
                        decode_next <= Discard;
                    end else begin
                        $display("IP TTL:\n\t%0d", rx_data);
                        decode_next <= IpProtocol;
                    end
                end
                IpProtocol: begin
                    ip_protocol = rx_data;
                    case(rx_data)
                        1 : $display("IP Protocol:\n\tICMP (1)");
                        6 : $display("IP Protocol:\n\tTCP (6)");
                        17: $display("IP Protocol:\n\tUDP (17)");
                        default: $display("IP Protocol:\n\tUnknown (%0d)", rx_data);
                    endcase
                    decode_next <= IpJunk3;
                end
                IpJunk3: begin
                    if (read_offset == 8) begin
                        read_offset <= 0;
                        decode_next <= IpSrcIp;
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                IpSrcIp: begin
                    ip_src_ip[31 - read_offset -: 8] = rx_data;
                    if (read_offset == 24) begin
                        read_offset <= 0;
                        decode_next <= IpDstIp;
                        $write("Source IP:\n\t");
                        `DISPLAY_IP(ip_src_ip);
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                IpDstIp: begin
                    ip_dst_ip[31 - read_offset -: 8] = rx_data;
                    if (read_offset == 24) begin
                        read_offset <= 0;
                        $write("Destination IP:\n\t");
                        `DISPLAY_IP(ip_dst_ip);

                        if (ip_header_size > 5) begin
                            // 如果 IP 头长度大于默认值，说明存在 Options
                            decode_next <= IpOptions;
                        end else if (ip_total_size > 20) begin
                            // 如果 IP 还有长度放 Data
                            decode_next <= IpData;
                        end else begin
                            // 只有一个头，结束了
                            decode_next <= IpComplete;
                        end
                    end else begin
                        read_offset <= read_offset + 8;
                    end
                end
                IpOptions: begin
                    if (read_offset < ip_header_size * 4 - 21)
                        read_offset <= read_offset + 1;
                    else begin
                        if (ip_total_size > ip_header_size * 4) begin
                            // 还有 Data 部分
                            decode_next <= IpData;
                            read_offset <= 0;
                        end else begin
                            // 没有了
                            decode_next <= IpComplete;
                            read_offset <= 0;
                        end
                    end
                end
                IpData: begin
                    ip_data[read_offset] = rx_data;
                    if (read_offset < ip_total_size - 21)
                        read_offset <= read_offset + 1;
                    else begin
                        read_offset <= 0;
                        decode_next <= IpComplete;
                    end
                end
                IpComplete: begin
                    //$display("IP Completed, waiting for rx_last");
                end
            endcase
        end
    end
end

endmodule