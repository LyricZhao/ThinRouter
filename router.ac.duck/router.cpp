# define max_entries 827088ul

# include "router.h"

unsigned n_nodes;
unsigned trie_childs[max_entries * 32][2];
unsigned trie_nexthop[max_entries * 32];

void init(int n, int q, const RoutingTableEntry *a) {
    RoutingTableEntry *routing_table = (RoutingTableEntry*) a;
    for (int i = 0; i < n; ++ i) {
        unsigned bit, current = 0;
        unsigned addr = routing_table[i].addr, length = routing_table[i].len;
        for (unsigned j = 0; j < length; ++ j) {
            bit = (addr >> (31ul - j)) & 1ul;
            if (!trie_childs[current][bit]) {
                trie_childs[current][bit] = ++ n_nodes;
                trie_nexthop[n_nodes] = trie_nexthop[current];
            }
            current = trie_childs[current][bit];
        }
        trie_nexthop[current] = routing_table[i].nexthop;
    }
}

unsigned query(unsigned addr) {
    unsigned current = 0, bit, nexthop = trie_nexthop[0];
    for (unsigned i = 0; i < 32; ++ i) {
        bit = (addr >> (31ul - i)) & 1ul;
        if (trie_childs[current][bit]) {
            current = trie_childs[current][bit];
            nexthop = trie_nexthop[current];
        } else break;
    }
    return nexthop;
}