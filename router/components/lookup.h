# ifndef __LOOKUP_H__
# define __LOOKUP_H__

# include <arpa/inet.h>
# include <stdint.h>
# include <stdlib.h>

# include "../include/routing_table.h"

extern "C" void update(uint8_t insert, RoutingTableEntry entry);
extern "C" uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index);

# endif