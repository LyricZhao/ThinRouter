/*
涂轶翔：
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
针对数据包是 IP 还是 ARP 会分别交给 ip_packet_manager 和 arp_packet_manager 来处理
*/

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
// - protocol:          16'     IP or ARP

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
// IpJunk3      32b
// - ip_identification: 16'     TODO (maybe)
// - reserved flag:     1'0     ignored
// - don't fragment:    1'      TODO (maybe)
// - more fragments:    1'      TODO (maybe)
// - fragment offset:   13'     TODO (maybe)
// IpTtl         8b
bit [7:0]   ip_ttl;         // 剩余转发次数
// IpProtocol    8b
enum bit [7:0] {
    // (ref: https://en.wikipedia.org/wiki/List_of_IP_protocol_numbers)
    ICMP = 1,
    TCP  = 6,
    UDP  = 17
} ip_protocol;              // IP 协议
// IpJunk4      16b
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
    VlanId,         //  2b
    Protocol,       // 16b
    ArpJunk,        // 64b
    ArpSenderMac,   // 48b
    ArpSenderIp,    // 32b
    ArpTargetMac,   // 48b
    ArpTargetIp,    // 32b
    IpJunk1,        //  4b
    IpHeaderSize,   //  4b
    IpJunk2,        //  8b
    IpTotalSize,    // 16b
    IpJunk3,        // 32b
    IpTtl,          //  8b
    IpProtocol,     //  8b
    IpJunk4,        // 16b
    IpSrcIp,        // 32b
    IpDstIp,        // 32b
    IpOptions,      // (ip_header_size - 5) * 4 bytes
    IpData          // ip_total_size - ip_header_size * 4
} decode_next;
// 下面该写入某个域的第几位
int read_offset;

// Protocol
`define PROTOCOL_IPV4   16'h0800;
`define PROTOCOL_ARP    16'h0806;
`define PROTOCOL_VLAN   16'h8100;

initial begin
    // 让时间输出格式更好看
    $timeformat(-9, 2, " ns", 20);
end

// 初始化
always_ff @ (posedge gtx_resetn) begin
    rx_ready <= 1;
    tx_data <= 0;
    tx_valid <= 0;
    tx_last <= 0;
end

always_ff @ (posedge clk_io) begin
    if (rx_valid) begin
        if (!rx_ready)
            $display("I AM NOT READY!!!");
        $display("%0t: %x", $realtime, rx_data);
    end
end

endmodule