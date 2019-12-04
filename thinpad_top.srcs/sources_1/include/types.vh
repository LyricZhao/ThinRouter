typedef logic [31:0] ip_t;
typedef logic [47:0] mac_t;

typedef struct unpacked {
    ip_t addr;
    ip_t len;
    ip_t nexthop;
    ip_t metric;
} rip_entry_t;