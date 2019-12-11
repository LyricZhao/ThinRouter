#include "router_hal.h"

// configure this to match the output of `ip a`
const char *interfaces[N_IFACE_ON_BOARD] = {
    "eth0",
    "eth1",
    "eth2",
    "eth3",
};
