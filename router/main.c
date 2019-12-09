# include <stdint.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>

# include "include/rip_pack.h"
# include "include/routing_table.h"
# include "hal/include/router_hal.h"

extern uint8_t validateIPChecksum(uint8_t *packet, size_t len);
extern void update(uint8_t insert, RoutingTableEntry entry);
extern uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index);
extern uint8_t forward(uint8_t *packet, size_t len);
extern uint8_t disassemble(const uint8_t *packet, uint32_t len, RipPacket *output);
extern uint32_t assemble(const RipPacket *rip, uint8_t *buffer);

int main(int argc, char *argv[]) {
    return 0;
}