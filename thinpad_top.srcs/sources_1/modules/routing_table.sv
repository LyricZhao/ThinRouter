`timescale 1ns / 1ps
`include "types.vh"

module routing_table #(
    // 节点数量。每个节点 72 bits，每条路由项占用两个节点
    parameter NODE_POOL_SIZE = 65536
) (
    // 125M 时钟
    input  logic clk_125M,
    // 复位信号（彻底复位，清空条目）
    input  logic rst_n,
    // 计时信号（秒）
    input  time_t second,

    // 需要查询的 IP 地址
    input  ip_t  ip_query,
    // 进行查询，同步置 1
    input  logic query_valid,
    // 查询结果，0 表示无连接
    output ip_t  nexthop_result,
    // 可以查询
    output logic query_ready,

    // 需要插入的 IP 地址
    input  ip_t  ip_insert,
    // 插入的 mask
    input  logic [4:0] mask_insert,
    // 插入的 nexthop
    input  ip_t  nexthop_insert,
    // 插入的 metric
    input  logic [4:0] metric_insert,
    // 插入的 vlan port
    input  logic [2:0] vlan_port_insert,
    // 进行插入，同步置 1
    input  logic insert_valid,
    // 可以插入
    output logic insert_ready,

    // 路由表满，此后只可以查询和修改
    output logic overflow
);

// BRAM 至多能存 65536 节点
typedef logic [15:0] pointer_t;

// 分支节点
typedef struct packed {
    /*
    分叉：
        11001/5 - 0（作为 next 0）
                - 1（作为 next 1）
    前缀：
        11001/5 匹配一路由项（作为 next 0）
                继续向后匹配（作为 next 1）
    */
    // 这个节点是前缀，即 next0 对应一个路由项，而 next1 继续向后匹配
    logic is_prefix;
    // 匹配长度，对于分叉则是公共长度
    logic [5:0] mask;
    // 匹配的 IP 地址，匹配长度后面的位为 don't care
    ip_t match;
    // next 0
    pointer_t next0;
    // next 1
    pointer_t next1;
} branch_t;

// 存储下一跳的节点（71 bits）
typedef struct packed {
    // 来源 port 的低 2 位
    logic [1:0] port;
    // RIP metric
    logic [4:0] metric;
    // nexthop
    ip_t nexthop;
    // 最后更新时间
    time_t update_time;
    // 节点的父亲，可能是 0
    pointer_t parent;
} nexthop_t;

// 节点，加上一位标签（72 bits）
typedef struct packed {
    // 是 nexthop_t
    logic is_nexthop;
    union packed {
        branch_t branch;
        nexthop_t nexthop;
    } data;
} node_t;

endmodule