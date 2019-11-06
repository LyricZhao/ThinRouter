/*
ARP/IP 包的各种位置
目前不打算对奇怪的东西进行 check，直接原样丢出去
*/

// 目标 MAC
`define ETH_DST_MAC     -48 +: 48
// 来源 MAC
`define ETH_SRC_MAC     -96 +: 48
// VLAN ID
`define ETH_VLAN_ID     -128 +: 3
// 类型 ARP / ID
`define ETH_TYPE        -144 +: 16

// ARP Request / Reply
`define ARP_TYPE        -208 +: 16
// ARP 来源 MAC
`define ARP_SRC_MAC     -256 +: 48
// ARP 来源 IP
`define ARP_SRC_IP      -288 +: 32
// ARP 目标 MAC
`define ARP_DST_MAC     -336 +: 48
// ARP 目标 IP
`define ARP_DST_IP      -368 +: 32

// IP 包长度
`define IP_LENGTH       -176 +: 16
// IP TTL
`define IP_TTL          -216 +: 8
// IP header checksum
`define IP_CHECKSUM     -240 +: 16
// IP 来源 IP
`define IP_SRC_IP       -272 +: 32
// IP 目标 IP
`define IP_DST_IP       -304 +: 32