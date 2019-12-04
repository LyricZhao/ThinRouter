`timescale 1ns / 1ps
`include "types.vh"

module routing_table #(
    // 查询步长
    parameter STRIDE = 3,
    // 容量（包括因无效而移除的）
    parameter MAX_ENTRY = 1024,
    // 时间长度，默认 10 则用 10-bit 表示时间
    parameter TIME_WIDTH = 10
) (
    // 125M 时钟
    input  logic clk_125M,
    // 复位信号（彻底复位，清空条目）
    input  logic rst_n,
    // 计时信号（秒）
    input  logic [TIME_WIDTH-1:0] second,

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

// 每个节点中对应 2^STRIDE 个分支
localparam NODE_SIZE = 1 << STRIDE;
// 为了实现 MAX_ENTRY 条，实际上开 2*MAX_ENTRY 的空间
typedef logic[$clog2(MAX_ENTRY):0] pointer_t;

typedef struct packed {
    // 下一跳 IP 地址
    logic [31:0] nexthop;
    // 评分，最高位 1 表示不可达（无效条目）
    logic [4:0]  metric;
    // 信息来源于哪个接口
    logic [2:0]  vlan_port;
    // 最后更新时间
    logic [TIME_WIDTH-1:0]  update_time;
} nexthop_t;

// 参考 Tree Bitmap 论文
typedef struct packed {
    // 如果当前节点再往下恰只有一个 match 节点，则该节点不再生成子节点
    // 该节点的信息存放在此节点中（除非已满）
    logic single_out;
    // 内部哪些节点
    logic [NODE_SIZE-2:0] internal_bitmap;
    logic [NODE_SIZE-1:0] external_bitmap;
    pointer_t child;
    pointer_t nexthop;
} node_t;

endmodule