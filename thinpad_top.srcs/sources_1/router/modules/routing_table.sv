`timescale 1ns / 1ps
`include "debug.vh"
`include "types.vh"

module routing_table #(
    // 节点数量。每个节点 72 bits，每条路由项占用两个节点
    parameter NODE_POOL_SIZE = 32768
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

    // 遍历任务也从 fifo 进来
    input  rip_task_t enum_task_in,
    input  logic enum_task_empty,
    output logic enum_task_read_valid,

    output mac_t enum_dst_mac,
    output ip_t  enum_dst_ip,
    output logic [3:0] enum_send_to_port,

    output ip_t  enum_prefix,
    output ip_t  enum_nexthop,
    output logic [5:0] enum_mask,
    output logic [4:0] enum_metric,
    output logic enum_valid,
    output logic enum_last,

    // todo 路由表满，此后只可以查询和修改
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
    .WRITE_DATA_WIDTH_A(72),
    .WRITE_MODE_A("write_first")
) memory_pool (
    .addra({memory_addr[15], memory_addr[$clog2(NODE_POOL_SIZE)-2:0]}),
    .clka(clk_125M),
    .dina(memory_in),
    .douta(memory_out),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(1'b1),
    .wea(memory_write_en),

    .dbiterra(),
    .injectdbiterra(1'b0),
    .injectsbiterra(1'b0),
    .sbiterra(),
    .sleep(1'b0)
);

// 正在进行什么模式，通过同步逻辑控制
enum logic [2:0] {
    // 空闲
    ModeIdle,
    ModeCoolDown,
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
enum logic [3:0] {
    // 定位到 entry_to_insert.prefix 的位置，转其他状态
    Insert,
    InsertSituationPre1,
    InsertSituation1,
    InsertSituation2,
    InsertSituationPre3,
    InsertSituation3,
    // 在 nexthop_write_addr 上插入 entry_to_insert，确保检查过 metric<16
    InsertNewNexthop,
    // 给定了 nexthop 节点的地址，对其进行更新。如果删除了节点，后面还要回来从父节点上删去
    InsertEditNexthop,
    // 删除 parent prefix 节点的 next0
    InsertRemoveLeafFromParent,
    // 删除 parent prefix 节点的 next0，然后转到
    InsertRemoveLeafFromParent2,
    InsertReplaceNexthop,
    InsertReplaceNext0
} insert_state;

enum logic [2:0] {
    EnumNexthop,
    EnumParent,
    EnumSkipParent
} enum_state;

logic [1:0] work_cooldown;

// 具体逻辑可能会用到
pointer_t insert_pointer_buffer;

// 锁存的 port
logic [1:0] enum_latched_port;
// 已经完成了多少
pointer_t enum_completed;
// 本次完成了多少，到 25 需要停止
logic [4:0] enum_got;

// 利用 trie 树中查找这个 IP 地址
// 用同步逻辑控制，空闲时置 0，否则置 IP 地址，组合逻辑开始查找
ip_t ip_target;
// 目前找到的最长匹配叶子节点地址，当查询结束时，如果此地址为 0，说明无匹配
pointer_t best_match;

// Insert 过程中，entry_to_insert.prefix 和 memory_out.branch.prefix 之间的公共 mask 长度
// 不会超过 entry_to_insert.mask
logic [5:0] _tmp, insert_shared_mask;
always_comb begin
    _tmp = Common::leading0(entry_to_insert.prefix ^ memory_out.branch.prefix);
    insert_shared_mask = _tmp > entry_to_insert.mask ? entry_to_insert.mask : _tmp;
end

// 匹配 IP 地址和一个前缀，返回是否匹配
`define Match(addr, prefix, mask) ((((addr) ^ (prefix)) & Common::get_mask(mask)) == 0)

// 结束匹配，如果存在最佳匹配，则查找其地址，同时转 QueryResultFetching；否则直接转 ModeIdle
`define Query_Complete                      \
    if (best_match[15]) begin               \
        memory_addr <= best_match;          \
        query_state <= QueryResultFetching; \
    end else begin                          \
        memory_addr <= '0;                  \
        nexthop_result <= 0;                \
        work_mode <= ModeIdle;              \
    end

// 将当前节点复制到下一个空位里面（branch_write_addr 暂时不 +1）
`define Move_Node                                                           \
    $display("moving node from %x to %x", memory_addr, branch_write_addr);  \
    insert_pointer_buffer <= memory_addr;                                   \
    memory_addr <= branch_write_addr;                                       \
    memory_in <= memory_out;                                                \
    memory_write_en <= 1;

// 打印一个节点的内容
`define Display_Node(node, addr)                                    \
    if (node.branch.is_nexthop) begin                               \
        $display("Nexthop at %x", addr);                            \
        $display("\tPort:\t%d", node.nexthop.port);                 \
        $display("\tMetric:\t%d", node.nexthop.metric);             \
        $write("\tNexthop:\t"); `DISPLAY_IP(node.nexthop.nexthop);  \
        $display("\tUpdate Time:\t%d", node.nexthop.update_time);   \
        $display("\tParent:\t%x", node.nexthop.parent);             \
    end else if (node.branch.is_prefix) begin                       \
        $display("Prefix node at %x", addr);                        \
        $display("\tMask:\t%d", node.branch.mask);                  \
        $write("\tPrefix:\t"); `DISPLAY_IP(node.branch.prefix);     \
        if (node.branch.next0[15] == 0) begin                       \
            $display("\tNext0:\tNone");                             \
        end else begin                                              \
            $display("\tNext0:\t%x", node.branch.next0);            \
        end                                                         \
        if (node.branch.next1[15] == 1) begin                       \
            $display("\tNext1:\tNone");                             \
        end else begin                                              \
            $display("\tNext1:\t%x", node.branch.next1);            \
        end                                                         \
    end else begin                                                  \
        $display("Branch node at %x", addr);                        \
        $display("\tMask:\t%d", node.branch.mask);                  \
        $write("\tPrefix:\t"); `DISPLAY_IP(node.branch.prefix);     \
        if (node.branch.next0[15] == 1) begin                       \
            $display("\tNext0:\tNone");                             \
        end else begin                                              \
            $display("\tNext0:\t%x", node.branch.next0);            \
        end                                                         \
        if (node.branch.next1[15] == 1) begin                       \
            $display("\tNext1:\tNone");                             \
        end else begin                                              \
            $display("\tNext1:\t%x", node.branch.next1);            \
        end                                                         \
    end                                                             \
    $display("");

// 在 query 过程中，用组合逻辑将从内存中读取到的数据分析出下一步访问的地址
// todo 在 ready 时立刻来 query，可能导致内存地址未归零
always_ff @ (posedge clk_125M) begin
    // 默认值
    memory_in <= 'x;
    memory_write_en <= 0;

    insert_fifo_read_valid <= 0;
    enum_task_read_valid <= 0;
    enum_valid <= 0;
    enum_last <= 0;

    if (!rst_n) begin
        branch_write_addr <= 1;
        nexthop_write_addr <= 16'h8000;
        work_mode <= ModeIdle;
        ip_target <= '0;
        enum_completed <= 16'h8000;
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
                end else if (work_cooldown > 0) begin
                    work_cooldown <= work_cooldown - 1;
                end else if (!insert_fifo_empty) begin
                    // 没有查询任务时，从 fifo 中取出需要插入的条目
                    $write("Insert: ");
                    `DISPLAY_IP(insert_fifo_data.prefix);
                    work_mode <= ModeInsert;
                    entry_to_insert <= insert_fifo_data;
                    insert_fifo_read_valid <= 1;
                    query_ready <= 0;
                    work_cooldown <= 2;
                end else if (!enum_task_empty) begin
                    // 执行遍历任务
                    work_mode <= ModeEnumerate;
                    query_ready <= 0;
                    work_cooldown <= 2;
                    enum_dst_mac <= enum_task_in.dst_router_mac;
                    enum_dst_ip <= enum_task_in.dst_router_ip;
                    enum_send_to_port <= Common::one_hot4(enum_task_in.port);
                    enum_got <= 0;
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
        memory_addr <= '0;
    end else begin
        $display("%d", insert_state);
        `Display_Node(memory_out, memory_addr);
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
                            // 插入的更短，则需要插入一个节点来连接
                                $display("insert shorter prefix");
                                if (entry_to_insert.metric[4] == 1) begin
                                // 插入的是之前不存在的条目，如果 metric=16 则直接退出
                                    $display("invalid metric, discarded");
                                    work_mode <= ModeIdle;
                                end else if (insert_shared_mask == entry_to_insert.mask) begin
                                // 插入的 mask 更短，但是当前节点完全匹配
                                    if (memory_out.branch.next0[15] == 0) begin
                                    // 当前节点并没有 next0，则可以直接修改 mask 并添加 next0
                                        memory_in <= memory_out;
                                        memory_in.branch.mask = entry_to_insert.mask;
                                        memory_in.branch.next0 <= nexthop_write_addr;
                                        memory_write_en <= 1;
                                        insert_pointer_buffer <= memory_addr;
                                        insert_state <= InsertNewNexthop;
                                    end else begin
                                        // 当前节点直接写到下一个空位里面
                                        `Move_Node;
                                        // 在下一拍再将此节点变为一个 prefix
                                        insert_state <= InsertSituationPre1;
                                    end
                                end else begin
                                // 需要当前节点分割成两部分，一部分是插入节点的 prefix，另一部分是原节点
                                    // todo 当前节点如果存在空分支可以修剪
                                    // 当前节点直接写到下一个空位里面
                                    `Move_Node;
                                    if (memory_out.branch.next0[15] == 0) begin
                                        insert_state <= InsertSituation3;
                                    end else begin
                                        insert_state <= InsertSituationPre3;
                                    end
                                end
                            end else if (insert_shared_mask == memory_out.branch.mask && insert_shared_mask == entry_to_insert.mask) begin
                            // 和当前节点一样，则替换叶子节点
                                $display("insert same prefix");
                                if (memory_out.branch.next0[15] != 1) begin
                                    $display("previous prefix is deleted");
                                    // 插入的是之前不存在的条目，如果 metric=16 则直接退出
                                    if (entry_to_insert.metric[4] == 1) begin
                                        $display("invalid metric, discarded");
                                        work_mode <= ModeIdle;
                                    end else begin
                                        // 原节点已经被删除，直接添加新的叶子节点
                                        memory_write_en <= 1;
                                        memory_in <= memory_out;
                                        memory_in.branch.next0 <= nexthop_write_addr;
                                        insert_state <= InsertNewNexthop;
                                    end
                                end else begin
                                    // 替换原叶子节点
                                    memory_addr <= memory_out.branch.next0;
                                    insert_state <= InsertEditNexthop;
                                end
                            end else begin
                            // 插入的更长
                                $display("insert longer prefix");
                                if (memory_out.branch.next1[15] != 0) begin
                                // 没有对应的分支，则需要添加新的分支
                                    if (entry_to_insert.metric[4] == 1) begin
                                        $display("invalid metric, discarded");
                                        work_mode <= ModeIdle;
                                    end else begin
                                        // 首先修改当前节点的 next1 指向 branch_write_addr
                                        memory_write_en <= 1;
                                        memory_in <= memory_out;
                                        memory_in.branch.next1 <= branch_write_addr;
                                        // 下一步再说
                                        insert_state <= InsertSituation2;
                                    end
                                end else begin
                                    // 直接进入对应分支
                                    memory_addr <= memory_out.branch.next1;
                                end
                            end
                        end else begin
                        // 如果是一个分叉节点
                            $display("Current is branch node");
                            // 对比插入的 prefix 和节点的 mask 长度
                            if (insert_shared_mask < memory_out.branch.mask ||
                                (insert_shared_mask == memory_out.branch.mask && insert_shared_mask == entry_to_insert.mask)) begin
                            // 插入的更短或同样长，则需要将当前节点接到后面
                                $display("insert shorter/equal prefix");
                                if (entry_to_insert.metric[4] == 1) begin
                                // 插入的是之前不存在的条目，如果 metric=16 则直接退出
                                    $display("invalid metric, discarded");
                                    work_mode <= ModeIdle;
                                end else if (insert_shared_mask == entry_to_insert.mask) begin
                                // 插入的 mask 更短，但是当前节点完全匹配，只需要插入一个 prefix 节点
                                    // 当前节点直接写到下一个空位里面
                                    `Move_Node;
                                    // 在下一拍再修改此节点，
                                    insert_state <= InsertSituation1;
                                end else begin
                                // 需要当前节点分割成两部分，一部分是插入节点的 prefix，另一部分是原节点
                                    // todo 当前节点如果存在空分支可以修剪
                                    // 当前节点直接写到下一个空位里面
                                    `Move_Node;
                                    insert_state <= InsertSituation3;
                                end
                            end else begin
                            // 插入的更长
                                $display("insert longer prefix");
                                if (entry_to_insert.prefix[31 - memory_out.branch.mask] == 0) begin
                                // 插入 prefix 的下一位是 0
                                    if (memory_out.branch.next0[15] != 0) begin
                                    // 不存在这个分支，需要创建
                                        // 插入的是之前不存在的条目，如果 metric=16 则直接退出
                                        if (entry_to_insert.metric[4] == 1) begin
                                            $display("invalid metric, discarded");
                                            work_mode <= ModeIdle;
                                        end else begin
                                            $display("update next0 for branch node at %x", memory_addr);
                                            memory_in <= memory_out;
                                            memory_in.branch.next0 <= branch_write_addr;
                                            memory_write_en <= 1;
                                            insert_state <= InsertSituation2;
                                        end
                                    end else begin
                                        memory_addr <= memory_out.branch.next0;
                                    end
                                end else begin
                                // 插入 prefix 的下一位是 1    
                                    if (memory_out.branch.next1[15] != 0) begin
                                    // 不存在这个分支，需要创建
                                        // 插入的是之前不存在的条目，如果 metric=16 则直接退出
                                        if (entry_to_insert.metric[4] == 1) begin
                                            $display("invalid metric, discarded");
                                            work_mode <= ModeIdle;
                                        end else begin
                                            $display("update next1 for branch node at %x", memory_addr);
                                            memory_in <= memory_out;
                                            memory_in.branch.next1 <= branch_write_addr;
                                            memory_write_en <= 1;
                                            insert_state <= InsertSituation2;
                                        end
                                    end else begin
                                        memory_addr <= memory_out.branch.next1;
                                    end
                                end
                            end
                        end
                    end
                    InsertSituationPre1: begin
                        // 前往原本的 nexthop
                        if (!memory_out.nexthop.is_nexthop) begin
                            memory_addr <= memory_out.branch.next0;
                        end else begin
                            memory_in <= memory_out;
                            memory_in.nexthop.parent <= branch_write_addr;
                            memory_write_en <= 1;
                            insert_state <= InsertSituation1;
                        end
                    end
                    InsertSituation1: begin
                        // 回来更新当前节点的 mask, next0 （指向即将添加的块）和 next1（指向被挤走的块）
                        if (!memory_out.branch.is_nexthop) begin
                            memory_addr <= insert_pointer_buffer;
                            memory_write_en <= 1;

                            memory_in <= memory_out;
                            memory_in.branch.mask <= insert_shared_mask;
                            memory_in.branch.next0 <= nexthop_write_addr;
                            memory_in.branch.next1 <= branch_write_addr;

                            branch_write_addr <= branch_write_addr + 1;
                            insert_state <= InsertNewNexthop;
                        end
                    end
                    InsertSituation2: begin
                        // 为 entry_to_insert 在最后添加一个 prefix 和一个 nexthop
                        $display("inserting new prefix node at %x", branch_write_addr);
                        memory_addr <= branch_write_addr;
                        memory_write_en <= 1;
                        memory_in.branch <= '{
                            is_nexthop: 1'b0,
                            is_prefix: 1'b1,
                            mask: entry_to_insert.mask,
                            prefix: entry_to_insert.prefix,
                            next0: nexthop_write_addr,
                            next1: 16'h8000
                        };

                        branch_write_addr <= branch_write_addr + 1;
                        insert_pointer_buffer <= branch_write_addr;
                        insert_state <= InsertNewNexthop;
                    end
                    InsertSituationPre3: begin
                        // 前往原本的 nexthop
                        if (!memory_out.nexthop.is_nexthop) begin
                            memory_addr <= memory_out.branch.next0;
                        end else begin
                            memory_in <= memory_out;
                            memory_in.nexthop.parent <= branch_write_addr;
                            memory_write_en <= 1;
                            insert_state <= InsertSituation3;
                        end
                    end
                    InsertSituation3: begin
                        if (memory_out.branch.is_nexthop) begin
                            memory_addr <= branch_write_addr;
                        end else begin
                            assert (entry_to_insert.prefix[31 - insert_shared_mask] != memory_out.branch.prefix[31 - insert_shared_mask])
                                else $fatal(1, "%m: split error");
                            $display("split node at mask len %0d", insert_shared_mask);
                            // 当前节点根据 insert_shared_mask 进行分开
                            if (entry_to_insert.prefix[31 - insert_shared_mask] == 1) begin
                            // 原本节点放到 next0
                                memory_in.branch <= '{
                                    is_nexthop: 1'b0,
                                    is_prefix: 1'b0,
                                    mask: insert_shared_mask,
                                    prefix: entry_to_insert.prefix,
                                    next0: branch_write_addr,
                                    next1: branch_write_addr + 1
                                };
                            end else begin
                            // 原本节点放到 next1
                                memory_in.branch <= '{
                                    is_nexthop: 1'b0,
                                    is_prefix: 1'b0,
                                    mask: insert_shared_mask,
                                    prefix: entry_to_insert.prefix,
                                    next0: branch_write_addr + 1,
                                    next1: branch_write_addr
                                };
                            end
                            // 写入当前节点
                            memory_addr <= insert_pointer_buffer;
                            memory_write_en <= 1;
                            // 然后再添加 insert 条目
                            branch_write_addr <= branch_write_addr + 1;
                            insert_state <= InsertSituation2;
                        end
                    end
                    InsertNewNexthop: begin
                        // 插入一个新的 nexthop，然后工作结束
                        $display("inserting new nexthop node at %x", nexthop_write_addr);
                        memory_addr <= nexthop_write_addr;
                        memory_write_en <= 1;
                        memory_in.nexthop <= '{
                            is_nexthop: 1'b1,
                            port: entry_to_insert.from_vlan[1:0],
                            metric: entry_to_insert.metric + 1,
                            nexthop: entry_to_insert.nexthop,
                            update_time: second,
                            parent: insert_pointer_buffer
                        };
                        nexthop_write_addr <= nexthop_write_addr + 1;
                        work_mode <= ModeIdle;
                    end
                    InsertEditNexthop: begin
                        // 首先等待 nexthop 节点被读取
                        if (memory_out.branch.is_nexthop) begin
                            $display("read nexthop node at %x", memory_addr);
                            if (entry_to_insert.metric[4] == 1) begin
                                // 删除路由？
                                if (memory_out.nexthop.port == entry_to_insert.from_vlan[1:0]) begin
                                // 如果消息来源就是之前提供路由的端口，则真的删除
                                    $display("removing nexthop node");
                                    nexthop_write_addr <= memory_addr;
                                    insert_pointer_buffer <= memory_addr;
                                    memory_addr <= memory_out.nexthop.parent;
                                    if (memory_addr + 1 == nexthop_write_addr) begin
                                    // 如果当前已经是最后一个 nexthop 节点，则将其删除
                                        insert_state <= InsertRemoveLeafFromParent;
                                    end else begin
                                    // 此处需要用最后一个 nexthop 节点来代替此节点
                                        insert_state <= InsertRemoveLeafFromParent2;
                                    end
                                    nexthop_write_addr <= nexthop_write_addr - 1;
                                end else begin
                                // 如果消息来源不是路由 nexthop 的端口，说明这是一个 poison reverse，忽略
                                    work_mode <= ModeIdle;
                                end
                            end else if (entry_to_insert.metric + 1 < memory_out.nexthop.metric) begin
                                // 更好的路由，替换
                                memory_write_en <= 1;
                                memory_in.nexthop <= '{
                                    is_nexthop: 1'b1,
                                    port: entry_to_insert.from_vlan[1:0],
                                    metric: entry_to_insert.metric + 1,
                                    nexthop: entry_to_insert.nexthop,
                                    update_time: second,
                                    parent: memory_out.nexthop.parent
                                };
                                work_mode <= ModeIdle;
                            end else begin
                                // 更差的路由，退出
                                work_mode <= ModeIdle;
                            end
                        end
                    end
                    InsertRemoveLeafFromParent: begin
                        // 等待读取到 prefix 节点
                        if (!memory_out.branch.is_nexthop) begin
                            $display("delete next0 from prefix node at %x", memory_addr);
                            memory_in <= memory_out;
                            memory_in.branch.next0[15] <= 0;
                            memory_write_en <= 1;
                            work_mode <= ModeIdle;
                        end
                    end
                    InsertRemoveLeafFromParent2: begin
                        // 等待读取到 prefix 节点
                        if (!memory_out.branch.is_nexthop) begin
                            $display("delete next0 from prefix node at %x", memory_addr);
                            memory_in <= memory_out;
                            memory_in.branch.next0[15] <= 0;
                            memory_write_en <= 1;
                            insert_state <= InsertReplaceNexthop;
                        end
                    end
                    InsertReplaceNexthop: begin
                        memory_addr <= nexthop_write_addr;
                        if (memory_out.nexthop.is_nexthop) begin
                            memory_in <= memory_out;
                            memory_addr <= insert_pointer_buffer;
                            memory_write_en <= 1;
                            insert_state <= InsertReplaceNext0;
                        end
                    end
                    InsertReplaceNext0: begin
                        if (memory_out.nexthop.is_nexthop) begin
                        // 还没有加载出来 parent
                            memory_addr <= memory_out.nexthop.parent;
                        end else begin
                        // 替换 next0
                            memory_in <= memory_out;
                            memory_in.branch.next0 <= insert_pointer_buffer;
                            memory_write_en <= 1;
                            work_mode <= ModeIdle;
                        end
                    end
                endcase
            end
            ModeEnumerate: begin
                case (enum_state)
                    EnumNexthop: begin
                        if (enum_completed >= nexthop_write_addr) begin
                        // 已经全部读完
                            // 清除当前任务
                            enum_task_read_valid <= 1;
                            work_mode <= ModeIdle;
                            // 如果没有读到任何一条，就不发送了
                            if (enum_got > 0) begin
                                enum_last <= 1;
                            end
                        end else if (enum_got == 25) begin
                        // 读够了 25 条，发送，然后休息
                            work_mode <= ModeIdle;
                            enum_last <= 1;
                        end else begin
                            if (!memory_out.nexthop.is_nexthop) begin
                                memory_addr <= enum_completed;
                            end else begin
                                enum_completed <= enum_completed + 1;
                                memory_addr <= memory_out.nexthop.parent;
                                enum_nexthop <= memory_out.nexthop.nexthop;
                                enum_metric <= memory_out.nexthop.metric;
                                if (memory_out.nexthop.port == enum_latched_port) begin
                                // 当前处理的端口与写入的是一个端口，跳过
                                    enum_state <= EnumSkipParent;
                                end else begin
                                    enum_state <= EnumParent;
                                    enum_got <= enum_got + 1;
                                end
                            end
                        end
                    end
                    EnumParent: begin
                        if (!memory_out.nexthop.is_nexthop) begin
                            assert (memory_out.branch.is_prefix)
                                else $fatal(1, "Parent is not prefix");
                            enum_prefix <= memory_out.branch.prefix;
                            enum_mask <= memory_out.branch.mask;
                            enum_valid <= 1;
                            memory_addr <= enum_completed;
                            enum_state <= EnumNexthop;
                        end
                    end
                    EnumSkipParent: begin
                        if (!memory_out.nexthop.is_nexthop) begin
                            assert (memory_out.branch.is_prefix)
                                else $fatal(1, "Parent is not prefix");
                            memory_addr <= enum_completed;
                            enum_state <= EnumNexthop;
                        end
                    end
                endcase
            end
        endcase
    end
end


always_ff @ (negedge clk_125M) begin
    if (memory_write_en) begin
        $display("Writing:");
        `Display_Node(memory_in, memory_addr);
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