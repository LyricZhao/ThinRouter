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

extern uint8_t validateIPChecksum(uint8_t *packet, size_t len);
extern void update(uint8_t insert, RoutingTableEntry entry);
extern uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index);
extern uint8_t forward(uint8_t *packet, size_t len);
extern uint8_t disassemble(const uint8_t *packet, uint32_t len, RipPacket *output);
extern uint32_t assemble(const RipPacket *rip, uint8_t *buffer);

// buffer
uint8_t packet[2048];
uint8_t output[2048];

in_addr_t addrs[N_IFACE_ON_BOARD] = {0x0100000a, 0x0101000a, 0x0102000a,
                                     0x0103000a};

int main(int argc, char *argv[]) {
    // 0a. 初始化
    int res = HAL_Init(debug_flag, addrs);
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
            .nexthop = 0      // big endian, means direct
        };
        update(1, entry);
    }

  uint64_t last_time = 0;
  while (1) {
      uint64_t time = HAL_GetTicks();
      if (time > last_time + 30 * 1000) {
          printf("30s Timer\n");
          last_time = time;
      }

      int mask = (1 << N_IFACE_ON_BOARD) - 1;
      macaddr_t src_mac, dst_mac;
      int if_index;

      res = HAL_ReceiveIPPacket(mask, packet, sizeof(packet), src_mac, dst_mac, 1000, &if_index);
      if (res == HAL_ERR_EOF) {
          break;
      } else if (res < 0) {
          return res;
      } else if (res == 0) {
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

      // 2. 看目标地址是不是路由本身
      uint8_t dst_is_me = 0;
      for (int i = 0; i < N_IFACE_ON_BOARD; ++ i) {
          if (memcmp(&dst_addr, &addrs[i], sizeof(in_addr_t)) == 0) {
              dst_is_me = 1;
              break;
          }
      }

      if (dst_is_me) {
          // 3a.1
          RipPacket rip;
          if (disassemble(packet, res, &rip)) {
              if (rip.command == 1) {
                  // 3a.3 request, ref. RFC2453 3.9.1
                  // only need to respond to whole table requests in the lab
                  RipPacket resp;
                  // TODO: fill resp
                  // assemble
                  // IP
                  output[0] = 0x45;
                  // ...
                  // UDP
                  // port = 520
                  output[20] = 0x02;
                  output[21] = 0x08;
                  // ...
                  // RIP
                  uint32_t rip_len = assemble(&resp, &output[20 + 8]);
                  // checksum calculation for ip and udp
                  // if you don't want to calculate udp checksum, set it to zero
                  // send it back
                  HAL_SendIPPacket(if_index, output, rip_len + 20 + 8, src_mac);
              } else {
                  // 3a.2 response, ref. RFC2453 3.9.2
                  // update routing table
                  // new metric = ?
                  // update metric, if_index, nexthop
                  // what is missing from RoutingTableEntry?
                  // TODO: use query and update
                  // triggered updates? ref. RFC2453 3.10.1
              }
          }
      } else {
          // 3b.1 dst is not me
          // forward
          // beware of endianness
          uint32_t nexthop, dest_if;
          if (query(dst_addr, &nexthop, &dest_if)) {
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
                  // TODO: you might want to check ttl=0 case
                  HAL_SendIPPacket(dest_if, output, res, dest_mac);
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