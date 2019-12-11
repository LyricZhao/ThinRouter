# include <stdint.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>

//# define ROUTER_DEBUG

# ifdef ROUTER_DEBUG
    # define ROUTER_BACKEND_MACOS // for debug
    int debug_flag = 1;
# else
    int debug_flag = 0;
# endif

# include "include/rip_pack.h"
# include "include/routing_table.h"
# include "hal/include/router_hal.h"

extern uint16_t getChecksum(uint8_t *packet);
extern uint8_t validateIPChecksum(uint8_t *packet, size_t len);
extern void update(uint8_t insert, RoutingTableEntry entry);
extern uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index, uint32_t *metric);
extern uint8_t forward(uint8_t *packet, size_t len);
extern uint8_t disassemble(const uint8_t *packet, uint32_t len, RipPacket *output);
extern uint32_t assemble(const RipPacket *rip, uint8_t *buffer);
extern void assemble_rip(uint32_t src_ip, uint32_t if_index, RipPacket *output, uint32_t *packet_num);
// buffer
uint8_t packet[2048];
uint8_t output[2048];
RipPacket rip_packets[5000];

in_addr_t addrs[N_IFACE_ON_BOARD] = {0x0100000a, 0x0101000a, 0x0102000a, 0x0103000a};
uint32_t mask_to_len(uint32_t mask) {
    // 把掩码转为掩码长度
    uint32_t result = 0;
    for (uint32_t i = 0; i < 32; i++) {
        if (((mask >> i) & 1) != 0) {
            result += 1;
        }
    }
    return result;
}

int main(int argc, char *argv[]) {
    // 0a. 初始化
    debug_flag = 1;
    int32_t res = HAL_Init(debug_flag, addrs);
    if (res < 0) {
        return res;
    }

    // 0b. 直连路由
    // 10.0.0.0/24 if 0
    // 10.0.1.0/24 if 1
    // 10.0.2.0/24 if 2
    // 10.0.3.0/24 if 3
    for (uint32_t i = 0; i < N_IFACE_ON_BOARD; i++) {
        RoutingTableEntry entry = {
            .addr = addrs[i] & 0x00FFFFFF, // big endian
            .len = 24,        // small endian
            .if_index = i,    // small endian
            .nexthop = 0,     // big endian, means direct
            .metric = 0
        };
        update(1, entry);
    }
    
    uint64_t last_time = 0;
    while (1) {
        uint64_t time = HAL_GetTicks();
        if (time > last_time + 30 * 1000) {
            // DONE
            // 把完整的路由表发给每个interface
            // 参考 RFC2453 3.8
            // 组播IP: 224.0.0.9, 组播MAC: 01:00:5e:00:00:09
            uint32_t _dst_addr = 0x090000e0;
            macaddr_t _dst_mac = {0x01, 0x00, 0x5e, 0x00, 0x00, 0x09}; // !猜测是大端序
            for (uint32_t if_index = 0; if_index < N_IFACE_ON_BOARD; if_index++) {
                uint32_t packet_num;
                assemble_rip(_dst_addr, if_index, rip_packets, &packet_num);
                for (int i = 0; i < packet_num; i++) {
                    RipPacket resp = rip_packets[i];
                    uint16_t rip_len = assemble(&resp, &output[20 + 8]);
                    // DONE: 填完response
                    // IP
                    output[0] = 0x45;
                    output[1] = 0;
                    output[2] = (rip_len + 28) >> 8; // rip_len高八位
                    output[3] = (rip_len + 28) & 255; // rip_len低八位
                    output[4] = output[5] = output[6] = output[7] = 0;
                    output[8] = 1; // ttl=1
                    output[9] = 0x11; // 协议类型udp
                    *((uint32_t*)(output+12)) = addrs[if_index]; // 源地址
                    *((uint32_t*)(output+16)) = _dst_addr; // 目的地址
                    *((uint16_t*)(output+10)) = getChecksum(output); // 获得校验和
                    // ...
                    // UDP
                    // port = 520
                    output[20] = 0x02; // 出入端口都是520
                    output[21] = 0x08;
                    output[22] = 0x02;
                    output[23] = 0x08;
                    output[24] = (rip_len + 8) >> 8; // rip_len高八位
                    output[25] = (rip_len + 8) & 255; // rip_len低八位
                    output[26] = 0x00; // udp校验和直接填0
                    output[27] = 0x00;
                    // ...
                    // RIP
                    
                    // checksum calculation for ip and udp
                    // if you don't want to calculate udp checksum, set it to zero
                    // send it back
                    HAL_SendIPPacket(if_index, output, rip_len + 20 + 8, _dst_mac);
                }
            }
            printf("30s Timer\n");
            last_time = time;
        }
        int32_t mask = (1 << N_IFACE_ON_BOARD) - 1;
        macaddr_t src_mac, dst_mac;
        int32_t if_index;

        res = HAL_ReceiveIPPacket(mask, packet, sizeof(packet), src_mac, dst_mac, 1000, &if_index);
        if (res == HAL_ERR_EOF) {
            break;
        } else if (res < 0) {
            return res;
        } else if (res == 0) { // timeout
            continue;
        } else if (res > sizeof(packet)) {
            continue;
        }

        // 1. 检查checksum
        if (!validateIPChecksum(packet, res)) {
            printf("Invalid IP Checksum\n");
            continue;
        }
        in_addr_t src_addr, dst_addr;
        uint32_t *p32 = (uint32_t *)(packet + 0x1e);
        src_addr = *p32; // 取出源地址，大端序
        dst_addr = *(p32 + 1); // 取出目的地址，大端序

        // 2. 看目标地址是不是路由器的直连口（是不是路由器本身）
        uint8_t dst_is_me = 0;
        for (int i = 0; i < N_IFACE_ON_BOARD; ++ i) {
            if (memcmp(&dst_addr, &addrs[i], sizeof(in_addr_t)) == 0) {
                dst_is_me = 1;
                break;
            }
        }

        // DONE
        // 处理组播地址224.0.0.9
        if (dst_addr == 0x090000e0) {
            dst_is_me = 1; // 对组播地址发消息等价于发给自己
        }
        if (dst_is_me) {
            // 3a.1
            RipPacket rip;
            if (disassemble(packet, res, &rip)) {
                if (rip.command == 1) {
                    // 3a.3 request, 参考 RFC2453 3.9.1
                    // 只需要回复整个路由表的请求
                    uint32_t packet_num;
                    assemble_rip(src_addr, if_index, rip_packets, &packet_num);
                    for (int i = 0; i < packet_num; i++) {
                        RipPacket resp = rip_packets[i];
                        uint16_t rip_len = assemble(&resp, &output[20 + 8]);
                        // DONE: 填完response
                        // IP
                        output[0] = 0x45;
                        output[1] = 0;
                        output[2] = (rip_len + 28) >> 8; // rip_len高八位
                        output[3] = (rip_len + 28) & 255; // rip_len低八位
                        output[4] = output[5] = output[6] = output[7] = 0;
                        output[8] = 1; // ttl=1
                        output[9] = 0x11; // 协议类型udp
                        *((uint32_t*)(output+12)) = dst_addr; // 源地址
                        *((uint32_t*)(output+16)) = src_addr; // 目的地址，交换源和目的地址，发回去
                        *((uint16_t*)(output+10)) = getChecksum(output); // 获得校验和
                        // ...
                        // UDP
                        // port = 520
                        output[20] = 0x02; // 出入端口都是520
                        output[21] = 0x08;
                        output[22] = 0x02;
                        output[23] = 0x08;
                        output[24] = (rip_len + 8) >> 8; // rip_len高八位
                        output[25] = (rip_len + 8) & 255; // rip_len低八位
                        output[26] = 0x00; // udp校验和直接填0
                        output[27] = 0x00;
                        // ...
                        // RIP
                        
                        // checksum calculation for ip and udp
                        // if you don't want to calculate udp checksum, set it to zero
                        // send it back
                        HAL_SendIPPacket(if_index, output, rip_len + 20 + 8, src_mac);
                    }

                } else {
                    // 3a.2 response, ref. RFC2453 3.9.2
                    // 更新路由表
                    // 更新 metric, if_index, nexthop
                    // what is missing from RoutingTableEntry?
                    // DONE: use query and update
                    for (int i = 0; i < rip.numEntries; i++) {
                        uint32_t nexthop;
                        uint32_t _if_index;
                        uint32_t metric;
                        uint8_t found = 0;
                        found = query(rip.entries[i].addr, &nexthop, &_if_index, &metric);
                        if (found == 0 || metric > rip.entries[i].metric + 1) {
                            RoutingTableEntry entry = {
                                .addr = rip.entries[i].addr,
                                .len = mask_to_len(rip.entries[i].mask),
                                .if_index = if_index,
                                .nexthop = src_addr,
                                .metric = rip.entries[i].metric + 1
                            };
                            update(1, entry); // 插入
                        }
                    }
                    // triggered updates? ref. RFC2453 3.10.1
                }
            }
        } else {
            // 3b.1 dst is not me
            // forward
            // beware of endianness
            uint32_t nexthop, dest_if, metric;
            if (query(dst_addr, &nexthop, &dest_if, &metric)) {
                // found
                macaddr_t dest_mac;
                // direct routing
                if (nexthop == 0) {
                    nexthop = dst_addr;
                }
                if (HAL_ArpGetMacAddress(dest_if, nexthop, dest_mac) == 0) {
                    // found
                    memcpy(output, packet, res);
                    // update ttl and checksum
                    forward(output, res);
                    // DONE: you might want to check ttl=0 case
                    if (output[8] == 0) {
                        // 如果ttl==0， 那么丢包
                    } else {
                        HAL_SendIPPacket(dest_if, output, res, dest_mac);
                    }
                } else {
                    // not found
                    // you can drop it
                    printf("ARP not found for %x\n", nexthop);
                }
            } else {
                // not found
                // optionally you can send ICMP Host Unreachable
                printf("IP not found for %x\n", src_addr);
            }
        }
    }
    return 0;
}