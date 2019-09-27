# define max_entries 827088ul

# include "router.h"

# include <arpa/inet.h>
# include <iostream>

unsigned n_nodes;
unsigned trie_childs[max_entries * 32][2];
unsigned trie_nexthop[max_entries * 32];
bool trie_is_valid[max_entries * 32];

void init(int n, int q, const RoutingTableEntry *a) {
    RoutingTableEntry *routing_table = (RoutingTableEntry*) a;
    for (int i = 0; i < n; ++ i) {
        unsigned bit, current = 0;
        unsigned addr = htonl(routing_table[i].addr), length = routing_table[i].len;
        for (unsigned j = 0; j < length; ++ j) {
            bit = (addr >> (31ul - j)) & 1ul;
            if (!trie_childs[current][bit])
                trie_childs[current][bit] = ++ n_nodes;
            current = trie_childs[current][bit];
        }
        trie_is_valid[current] = true;
        trie_nexthop[current] = routing_table[i].nexthop;
    }
}

unsigned query(unsigned addr) {
    addr = htonl(addr);
    unsigned current = 0, bit, nexthop = trie_nexthop[0];
    for (unsigned i = 0; i < 32; ++ i) {
        bit = (addr >> (31ul - i)) & 1ul;
        if (trie_childs[current][bit]) {
            current = trie_childs[current][bit];
            if (trie_is_valid[current])
                nexthop = trie_nexthop[current];
        } else break;
    }
    return nexthop;
}

inline unsigned pack_ip(unsigned a0, unsigned a1, unsigned a2, unsigned a3) {
    unsigned val_le = (a0 << 24ul) | (a1 << 16ul) | (a2 << 8ul) | a3;
    return htonl(val_le);
}

inline void set_entry(RoutingTableEntry &entry, unsigned addr, unsigned char len, unsigned nexthop) {
    entry.addr = addr, entry.len = len, entry.nexthop = nexthop;
}

int main() {
    RoutingTableEntry routing_table[2];
    set_entry(routing_table[0], pack_ip(172, 16, 0, 0), 24, 1);
    set_entry(routing_table[1], pack_ip(172, 16, 2, 0), 16, 2);
    init(2, 1, routing_table);
    std:: cout << query(pack_ip(172, 16, 0, 2)) << std:: endl;
    return 0;
}