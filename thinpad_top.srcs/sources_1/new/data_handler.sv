/*
涂轶翔：
通过自动机实现数据的处理
TODO 1: loopback，打印输入输出
*/

module data_handler(
    // 由父模块提供各种时钟
    input   wire    clk_io,             // IO 时钟
    input   wire    clk_internal,       // 内部处理逻辑用的时钟

    // 接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  wire    rx_ready,           // 是否允许数据进入
    input   wire    rx_last,            // 数据传入结束
    output  wire    [7:0] tx_data,      // 数据出口
    output  wire    tx_valid,           // 数据出口正在传输
    input   wire    tx_ready,           // 外面是否准备接收：当前不处理外部不 ready 的逻辑 （TODO）
    output  wire    tx_last             // 数据传出结束
);

typedef byte unsigned u8;

// 数据包内容，不包括 preamble
bit [47:0]  dst_mac;        // 目标 MAC 地址
bit [47:0]  src_mac;        // 来源 MAC 地址
// protocol:        0x8100  VLAN
// stuff:           14'     ignored
bit [1:0]   vlan_id;        // VLAN 接口编号

// ARP 包 (ref: https://en.wikipedia.org/wiki/Address_Resolution_Protocol)
// hardware type:   0x0001  Ethernet
// protocol type:   0x0800  IPv4
// hardware length: 0x06    MAC
// protocol length: 0x04    IPv4
// operation:       0x0001  Request
bit [47:0]  arp_sender_mac; // 发出者 MAC 地址
bit [31:0]  arp_sender_ip;  // 发出者 IP 地址
// target mac:      0x000000000000  ignored
bit [31:0]  arp_target_ip;  // 查询的 IP 地址

// IPv4 包（ref:https://en.wikipedia.org/wiki/IPv4)
// version:         0x4     IPv4
bit [3:0]   ip_header_size; // IPv4 头长度
// DSCP:            0x00    ignored
bit [15:0]  ip_total_size;  // IPv4 总长度（包括 IPv4 头和数据）
// ip_identification: 16'   TODO (maybe)
// reserved flag:   0b0     ignored
// don't fragment:  1'      TODO (maybe)
// more fragments:  1'      TODO (maybe)
// fragment offset: 13'     TODO (maybe)
bit [7:0]   ip_ttl;         // 剩余转发次数
enum bit [7:0] {
    // (ref: https://en.wikipedia.org/wiki/List_of_IP_protocol_numbers)
    ICMP = 1,
    TCP  = 6,
    UDP  = 17
} ip_protocol;              // IP 协议
// header checksum: 16'     TODO (maybe)
bit [31:0]  ip_src_ip;      // 来源 IP 地址
bit [31:0]  ip_dst_ip;      // 目标 IP 地址
// options:         depending on header size, very likely not to do
u8  ip_data [555:0];        // IP 数据，协议要求路由器至少能处理 576B 的包，即 20B 头文件和 556B 数据


// 读取数据包时，下一步将要解码什么字段
enum {
    DstMac
    // todo
} decode_next;

// Protocol
`define PROTOCOL_IPV4   16'h0800;
`define PROTOCOL_ARP    16'h0806;
`define PROTOCOL_VLAN   16'h8100;


// 第一步测试，直接自交
assign tx_data = rx_data;
assign tx_valid = rx_valid;
assign rx_ready = tx_ready;
assign tx_last = rx_last;

initial begin
    $timeformat(-9, 2, " ns", 20);
end

always_ff @ (posedge clk_io) begin
    if (rx_valid) begin
        
        $display("%t: %x", $realtime, rx_data);
    end
end

endmodule