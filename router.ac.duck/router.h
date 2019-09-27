typedef struct {
    unsigned addr;
    unsigned char len;
    char pad[3];  // Padding for memory alignment
    unsigned nexthop;
} __attribute__((packed)) RoutingTableEntry;
