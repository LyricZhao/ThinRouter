`timescale 1ns / 1ps
`include "debug.vh"
`include "types.vh"

module routing_table #(
    // 节点数量。每个节点 72 bits，每条路由项占用两个节点
    parameter NODE_POOL_SIZE = 64
) (
    // 125M 时钟
    input  logic clk_125M,
    // 复位信号（彻底复位，清空条目）
    input  logic rst_n,
    // 计时信号（秒）
    input  time_t second,

    output logic [7:0] digit0_out,
    output logic [7:0] digit1_out,
    output logic [15:0] debug,

    // 需要查询的 IP 地址
    input  ip_t  ip_query,
    // 进行查询，同步置 1
    input  logic query_valid,
    // 查询结果，0 表示无连接（会在查询逻辑处理完成时锁存）
    output ip_t  nexthop_result,
    // 可以查询 / 查询完成
    output logic query_ready,

    // fifo 中随时可能有等待添加的路由表项
    input  routing_entry_t insert_fifo_data,
    // fifo 是否为空
    input  logic insert_fifo_empty,
    // 从 fifo 中读取一条
    output logic insert_fifo_read_valid,

    // 路由表满，此后只可以查询和修改
    output logic overflow
);

// BRAM 至多能存 65536 节点
// 最高位是 1 的地址代表是 nexthop 节点
typedef logic [15:0] pointer_t;

// 分支节点
typedef struct packed {
    /*
    分叉：
        11001/5 - 0（作为 next 0），若存在一定是另一个分支节点
                - 1（作为 next 1），若存在一定是另一个分支节点
    前缀：
        11001/5 匹配一路由项（作为 next 0），若存在一定是一个叶子节点
                继续向后匹配（作为 next 1），若存在一定是一个分支节点
    */
    // 应当为 0
    logic is_nexthop;
    // 这个节点是前缀，即 next0 对应一个路由项，而 next1 继续向后匹配
    logic is_prefix;
    // 匹配长度，对于分叉则是公共长度（不能是 32）
    logic [5:0] mask;
    // 匹配的 IP 地址，匹配长度后面的位为 don't care
    ip_t prefix;
    // next 0；对于分叉节点，高位 1 表示不存在；对于前缀节点，高位 0 表示不存在
    pointer_t next0;
    // next 1；高位 1 表示不存在
    pointer_t next1;
} branch_t;

// 存储下一跳的节点
typedef struct packed {
    // 应当为 1
    logic is_nexthop;
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

// 节点
typedef union packed {
    branch_t branch;
    nexthop_t nexthop;
} node_t;

// 这些变量都是通过组合（锁存）逻辑进行驱动
pointer_t memory_addr;
node_t memory_in;
node_t memory_out;
logic memory_write_en;

// 下一个插入的节点应该放在什么地址
pointer_t branch_write_addr;
pointer_t nexthop_write_addr;

routing_entry_t entry_to_insert;

assign debug = memory_addr;

// 存储空间
xpm_memory_spram #(
    .ADDR_WIDTH_A($clog2(NODE_POOL_SIZE)),
    .MEMORY_INIT_FILE("routing_memory.mem"),
    .MEMORY_OPTIMIZATION("false"),
    .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(72 * NODE_POOL_SIZE),
    .READ_DATA_WIDTH_A(72),
    .READ_LATENCY_A(1),
    .WRITE_DATA_WIDTH_A(72)
) memory_pool (
    .addra({memory_addr[15], memory_addr[$clog2(NODE_POOL_SIZE)-2:0]}),
    .clka(clk_125M),
    .dina(memory_in),
    .douta(memory_out),
    .ena(1'b1),
    .rsta(1'b0),
    .wea(memory_write_en),

    .dbiterra(),
    .injectdbiterra(1'b0),
    .injectsbiterra(1'b0),
    .sbiterra(),
    .sleep(1'b0)
);

// 正在进行什么模式，通过同步逻辑控制
enum logic [1:0] {
    // 空闲
    ModeIdle,
    // 查询
    ModeQuery,
    // 插入
    ModeInsert,
    // 遍历
    ModeEnumerate
} work_mode;

// 查询过程的状态，组合逻辑
enum logic [1:0] {
    // 正在查询，此时查的节点一定是路径节点而非叶子节点
    Query,
    // 查询结束，进入此状态时，addr 为最佳匹配叶子节点，等待其数据到达 memory_out 后进入 QueryResultReady
    QueryResultFetching,
    // 查询得到结果，进入此状态时，memory_out 如果是根节点说明无匹配，否则为匹配的叶子节点
    QueryResultReady
} query_state;

// 插入过程的状态，组合逻辑
enum logic [2:0] {
    // 定位到 entry_to_insert.prefix 的位置，转其他状态
    Insert,
    // 给定了 nexthop 节点的地址，对其进行更新。如果删除了节点，后面还要回来从父节点上删去
    InsertEditNexthop
} insert_state;

// 利用 trie 树中查找这个 IP 地址
// 用同步逻辑控制，空闲时置 0，否则置 IP 地址，组合逻辑开始查找
ip_t ip_target;
// 目前找到的最长匹配叶子节点地址，当查询结束时，如果此地址为 0，说明无匹配
pointer_t best_match;

// 根据前缀长度生成 mask
function ip_t get_mask;
    input logic [5:0] len;
begin
    case (len)
        0 : get_mask = 32'h00000000;
        1 : get_mask = 32'h80000000;
        2 : get_mask = 32'hC0000000;
        3 : get_mask = 32'hE0000000;
        4 : get_mask = 32'hF0000000;
        5 : get_mask = 32'hF8000000;
        6 : get_mask = 32'hFC000000;
        7 : get_mask = 32'hFE000000;
        8 : get_mask = 32'hFF000000;
        9 : get_mask = 32'hFF800000;
        10: get_mask = 32'hFFC00000;
        11: get_mask = 32'hFFE00000;
        12: get_mask = 32'hFFF00000;
        13: get_mask = 32'hFFF80000;
        14: get_mask = 32'hFFFC0000;
        15: get_mask = 32'hFFFE0000;
        16: get_mask = 32'hFFFF0000;
        17: get_mask = 32'hFFFF8000;
        18: get_mask = 32'hFFFFC000;
        19: get_mask = 32'hFFFFE000;
        20: get_mask = 32'hFFFFF000;
        21: get_mask = 32'hFFFFF800;
        22: get_mask = 32'hFFFFFC00;
        23: get_mask = 32'hFFFFFE00;
        24: get_mask = 32'hFFFFFF00;
        25: get_mask = 32'hFFFFFF80;
        26: get_mask = 32'hFFFFFFC0;
        27: get_mask = 32'hFFFFFFE0;
        28: get_mask = 32'hFFFFFFF0;
        29: get_mask = 32'hFFFFFFF8;
        30: get_mask = 32'hFFFFFFFC;
        31: get_mask = 32'hFFFFFFFE;
        32: get_mask = 32'hFFFFFFFF;
        default: begin
            $fatal("invalid mask length");
            get_mask = '0;
        end
    endcase
end
endfunction

// 根据匹配生成 mask 长度
function logic [5:0] get_mask_len;
    input ip_t ip1;
    input ip_t ip2;
begin
    casez (ip1 ^ ip2)
        {1'b1, {31{1'bx}}}: get_mask_len = 0;
        {{1{1'b0}}, 1'b1, {30{1'bx}}}: get_mask_len = 1;
        {{2{1'b0}}, 1'b1, {29{1'bx}}}: get_mask_len = 2;
        {{3{1'b0}}, 1'b1, {28{1'bx}}}: get_mask_len = 3;
        {{4{1'b0}}, 1'b1, {27{1'bx}}}: get_mask_len = 4;
        {{5{1'b0}}, 1'b1, {26{1'bx}}}: get_mask_len = 5;
        {{6{1'b0}}, 1'b1, {25{1'bx}}}: get_mask_len = 6;
        {{7{1'b0}}, 1'b1, {24{1'bx}}}: get_mask_len = 7;
        {{8{1'b0}}, 1'b1, {23{1'bx}}}: get_mask_len = 8;
        {{9{1'b0}}, 1'b1, {22{1'bx}}}: get_mask_len = 9;
        {{10{1'b0}}, 1'b1, {21{1'bx}}}: get_mask_len = 10;
        {{11{1'b0}}, 1'b1, {20{1'bx}}}: get_mask_len = 11;
        {{12{1'b0}}, 1'b1, {19{1'bx}}}: get_mask_len = 12;
        {{13{1'b0}}, 1'b1, {18{1'bx}}}: get_mask_len = 13;
        {{14{1'b0}}, 1'b1, {17{1'bx}}}: get_mask_len = 14;
        {{15{1'b0}}, 1'b1, {16{1'bx}}}: get_mask_len = 15;
        {{16{1'b0}}, 1'b1, {15{1'bx}}}: get_mask_len = 16;
        {{17{1'b0}}, 1'b1, {14{1'bx}}}: get_mask_len = 17;
        {{18{1'b0}}, 1'b1, {13{1'bx}}}: get_mask_len = 18;
        {{19{1'b0}}, 1'b1, {12{1'bx}}}: get_mask_len = 19;
        {{20{1'b0}}, 1'b1, {11{1'bx}}}: get_mask_len = 20;
        {{21{1'b0}}, 1'b1, {10{1'bx}}}: get_mask_len = 21;
        {{22{1'b0}}, 1'b1, {9{1'bx}}}: get_mask_len = 22;
        {{23{1'b0}}, 1'b1, {8{1'bx}}}: get_mask_len = 23;
        {{24{1'b0}}, 1'b1, {7{1'bx}}}: get_mask_len = 24;
        {{25{1'b0}}, 1'b1, {6{1'bx}}}: get_mask_len = 25;
        {{26{1'b0}}, 1'b1, {5{1'bx}}}: get_mask_len = 26;
        {{27{1'b0}}, 1'b1, {4{1'bx}}}: get_mask_len = 27;
        {{28{1'b0}}, 1'b1, {3{1'bx}}}: get_mask_len = 28;
        {{29{1'b0}}, 1'b1, {2{1'bx}}}: get_mask_len = 29;
        {{30{1'b0}}, 1'b1, {1{1'bx}}}: get_mask_len = 30;
        {{31{1'b0}}, 1'b1}: get_mask_len = 31;
        {32{1'b1}}: get_mask_len = 32;
    endcase
end
endfunction

// Insert 过程中，entry_to_insert.prefix 和 memory_out.branch.prefix 之间的公共 mask 长度
// 不会超过 entry_to_insert.mask
logic [5:0] _tmp, insert_shared_mask;
always_comb begin
    _tmp = get_mask_len(entry_to_insert.prefix, memory_out.branch.prefix);
    insert_shared_mask = _tmp > entry_to_insert.mask ? entry_to_insert.mask : _tmp;
end

// 匹配 IP 地址和一个前缀，返回是否匹配
`define Match(addr, prefix, mask) ((((addr) ^ (prefix)) & get_mask(mask)) == 0)

// 结束匹配，如果存在最佳匹配，则查找其地址，同时转 QueryResultFetching；否则直接转 ModeIdle
`define Query_Complete                      \
    if (best_match[15]) begin               \
        memory_addr <= best_match;          \
        query_state <= QueryResultFetching; \
    end else begin                          \
        memory_addr <= 0;                   \
        nexthop_result <= 0;                \
        work_mode <= ModeIdle;              \
    end

// 在 query 过程中，用组合逻辑将从内存中读取到的数据分析出下一步访问的地址
// todo 在 ready 时立刻来 query，可能导致内存地址未归零
always_ff @ (posedge clk_125M or posedge query_ready) begin
    // 默认值
    memory_addr <= '0;
    memory_in <= 'x;
    memory_write_en <= 0;

    insert_fifo_read_valid <= 0;

    if (!rst_n) begin
        branch_write_addr <= 1;
        nexthop_write_addr <= 0;
        work_mode <= ModeIdle;
        ip_target <= '0;
    end else begin
        // 查询结束则置 ModeIdle
        if (work_mode == ModeQuery && query_ready) begin
            work_mode <= ModeIdle;
        end
        case (work_mode)
            ModeIdle: begin
                if (query_valid) begin
                    // 开始查询
                    $write("Query: ");
                    `DISPLAY_IP(ip_query);
                    work_mode <= ModeQuery;
                    ip_target <= ip_query;
                    query_ready <= 0;
                end else if (!insert_fifo_empty) begin
                    // 没有查询任务时，从 fifo 中取出需要插入的条目
                    $write("Insert: ");
                    `DISPLAY_IP(insert_fifo_data.prefix);
                    work_mode <= ModeInsert;
                    entry_to_insert <= insert_fifo_data;
                    insert_fifo_read_valid <= 1;
                    query_ready <= 0;
                end else begin
                    work_mode <= ModeIdle;
                    ip_target <= '0;
                    query_ready <= 1;
                end
            end
        endcase
    end

    if (!rst_n || work_mode == ModeIdle) begin
        // 复位
        query_state <= Query;
        insert_state <= Insert;
        best_match <= '0;
    end else begin
        $display("target: %x", ip_target);
        $display("addr: %x", memory_addr);
        $display("out:\n\tmask: %0d\n\tprefix: %x\n\tnext0: %x\n\tnext1: %x", 
            memory_out.branch.mask, memory_out.branch.prefix, memory_out.branch.next0, memory_out.branch.next1);
        $display("query_state: %d", query_state);
        case (work_mode)
            ModeQuery: begin
                case (query_state)
                    // 匹配，要求进入此状态前，memory_out 是根节点
                    Query: begin
                        // 此时 memory_out 一定是一个路径节点
                        if (`Match(ip_target, memory_out.branch.prefix, memory_out.branch.mask)) begin
                        // 如果匹配当前节点
                            $display("Match");
                            if (memory_out.branch.is_prefix) begin
                            // 如果当前节点是一个前缀节点，说明 next0 是一个可以匹配的前缀，将其记录
                                $display("Current is prefix node");
                                if (memory_out.branch.next0[15] != 0) begin
                                // 确认这个叶子节点没有被删除
                                    $display("Update best match");
                                    best_match = memory_out.branch.next0;
                                end
                                // 然后继续匹配
                                if (memory_out.branch.next1[15] != 1) begin
                                // 如果存在下一个匹配节点，则访问之
                                    $display("Goto next node: %x", memory_out.branch.next1);
                                    memory_addr <= memory_out.branch.next1;
                                    query_state <= Query;
                                end else begin
                                // 不存在下一个匹配节点，匹配结束
                                    $display("Search done");
                                    `Query_Complete;
                                end
                            end else begin
                            // 如果是一个分叉节点
                                $display("Current is branch node");
                                if (ip_target[31 - memory_out.branch.mask] == 0) begin
                                // 下一位是 0
                                    if (memory_out.branch.next0[15] != 1) begin
                                    // 存在这个分支，继续搜索
                                        $display("Goto next node: %x", memory_out.branch.next0);
                                        memory_addr <= memory_out.branch.next0;
                                        query_state <= Query;
                                    end else begin
                                    // 没有分支，搜索结束
                                        $display("Search done");
                                        `Query_Complete;
                                    end
                                end else begin
                                // 下一位是 1
                                    if (memory_out.branch.next1[15] != 1) begin
                                    // 存在这个分支，继续搜索
                                        $display("Goto next node: %x", memory_out.branch.next1);
                                        memory_addr <= memory_out.branch.next1;
                                        query_state <= Query;
                                    end else begin
                                    // 没有分支，搜索结束
                                        $display("Search done");
                                        `Query_Complete;
                                    end
                                end
                            end
                        end else begin
                        // 不匹配当前节点，搜索结束
                            $display("No match");
                            `Query_Complete;
                        end
                    end
                    // 找到了结果，等待内存读出来后转 ModeIdle
                    QueryResultFetching: begin
                        memory_addr <= best_match;
                        if (memory_out.branch.is_nexthop) begin
                            // 读出了叶子节点，输出并返回 ModeIdle
                            nexthop_result <= memory_out.nexthop.nexthop;
                            work_mode <= ModeIdle;
                        end else begin
                            query_state <= QueryResultFetching;
                        end
                    end
                endcase
            end
            ModeInsert: begin
                case (insert_state)
                    // 首先找到需要修改的匹配
                    Insert: begin
                        // 此时 memory_out 一定是一个路径节点
                        $display("shared mask len: %0d", insert_shared_mask);
                        if (memory_out.branch.is_prefix) begin
                        // 是前缀节点
                            $display("Current is prefix node");
                            // 对比插入的 prefix 和节点的 mask 长度
                            if (insert_shared_mask < memory_out.branch.mask) begin
                            // 插入的更短，则需要将当前节点接到后面
                                // 当前节点直接写到下一个空位里面，在下一拍再修改此节点
                            end else if (insert_shared_mask == memory_out.branch.mask) begin
                            // 和当前节点一样，则替换叶子节点
                                if (memory_out.branch.next0[15] != 1) begin
                                    // 原节点已经被删除，直接添加新的叶子节点
                                end else begin
                                    // 替换原叶子节点
                                end
                            end else begin
                            // 插入的更长
                                if (memory_out.branch.next1[15] != 0) begin
                                    // 没有对应的分支，则需要添加新的分支
                                end else begin
                                    // 直接进入对应分支
                                end
                            end
                        end else begin
                        // 如果是一个分叉节点
                            $display("Current is branch node");
                            // 对比插入的 prefix 和节点的 mask 长度
                            if (insert_shared_mask <= memory_out.branch.mask) begin
                            // 插入的更短或同样长，则需要将当前节点接到后面
                                // 当前节点直接写到下一个空位里面，在下一拍再修改此节点
                            end begin
                            // 插入的更长
                                if (entry_to_insert.prefix[31 - memory_out.branch.mask] == 0) begin
                                // 插入 prefix 的下一位是 0
                                    if (memory_out.branch.next0[15] != 0) begin
                                    // 不存在这个分支，需要创建
                                    end else begin
                                        memory_addr <= memory_out.branch.next0;
                                    end
                                end else begin
                                // 插入 prefix 的下一位是 1    
                                    if (memory_out.branch.next1[15] != 0) begin
                                    // 不存在这个分支，需要创建
                                    end else begin
                                        memory_addr <= memory_out.branch.next1;
                                    end
                                end
                            end
                        end
                    end
                endcase
            end
        endcase
    end
end

// always_ff @ (negedge clk_125M) begin
//     insert_fifo_read_valid <= !insert_fifo_empty;
//     if (!insert_fifo_empty) begin
//         $display("Add Route Queued");
//         $write("\tPrefix:\t");
//         `DISPLAY_IP(insert_fifo_data.prefix);
//         $write("\tNexthop:\t");
//         `DISPLAY_IP(insert_fifo_data.nexthop);
//     end
// end

endmodule