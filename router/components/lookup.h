# ifndef __LOOKUP_H__
# define __LOOKUP_H__

# include <arpa/inet.h>
# include <stdint.h>
# include <stdlib.h>

# include "../utilities/routing_table.h"

void update(uint8_t insert, RoutingTableEntry entry);
uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index);

# endif