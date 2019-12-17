`ifndef _TYPES_VH_
`define _TYPES_VH_

typedef logic [31:0] ip_t;
typedef logic [47:0] mac_t;
typedef logic [15:0] time_t;

typedef struct packed {
    ip_t addr;
    ip_t len;
    ip_t nexthop;
    ip_t metric;
} rip_entry_t;

// nexthop 应该是 RIP 的来源，metric 没有 +1
// 由 packet_processor 存入 fifo 提供给路由表模块
typedef struct packed {
    ip_t  prefix;
    ip_t  nexthop;
    logic [5:0] mask;
    logic [4:0] metric;
    // 这个 RIP response 来自哪个接口（而不是 nexthop 的接口）
    logic [2:0] from_vlan;
} routing_entry_t;

typedef struct packed {
    mac_t dst_router_mac;
    ip_t  dst_router_ip;
    logic [1:0] port; // port 暗示源 IP 地址
} rip_task_t;

`endif