`include "debug.vh"
`include "types.vh"

module packet_processor (
    input  logic clk,                   // 125M 时钟
    input  logic rst_n,                 // 初始化
    input  logic add_arp,               // 添加 ARP 项
    input  logic add_routing,           // 添加路由项
    input  logic process_arp,           // 查询 ARP
    input  logic process_ip,            // 处理 IP 包
    input  logic send_rip,              // 发送 RIP 包
    input  logic reset,                 // 手动清除 done bad 标志

    output logic [15:0] debug,

    input  logic [1:0] rip_port,        // 在哪个端口发送 RIP 包
    input  ip_t  rip_dst_ip,            // RIP 目标
    input  mac_t rip_dst_mac,
    input  ip_t  ip_input,              // 输入 IP
    input  logic [5:0] mask_input,      // 掩码长度（用于插入路由）
    input  ip_t  nexthop_input,         // 输入 nexthop
    input  mac_t mac_input,             // 输入 MAC
    input  logic [4:0] metric_input,    // 输入 metric
    input  logic [2:0] vlan_input,      // 输入 VLAN
    output logic done,                  // 处理完成
    output logic bad,                   // 查不到
    output logic [47:0] mac_output,     // 目标 MAC
    output logic [2:0]  vlan_output,    // 目标 VLAN

    input  logic rip_tx_read_valid,
    output logic rip_tx_empty,
    output logic [8:0] rip_tx_data
);

////// 用一个 fifo 来处理添加路由：此模块放进 fifo 并立即返回 done，路由表会在没有查询任务的时候执行一个插入
// 存到 fifo 里面提供给路由表
routing_entry_t fifo_in;
logic fifo_write_valid;
// 忽略
logic _fifo_full;
// 连接到路由表，由路由表进行读取和控制
routing_entry_t fifo_out;
logic fifo_empty;
logic fifo_read_valid;
// 这个 fifo 的输出提供给路由表模块
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(64),
    .READ_DATA_WIDTH($bits(routing_entry_t)),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH($bits(routing_entry_t))
) routing_insert_fifo (
    .din(fifo_in),
    .dout(fifo_out),
    .empty(fifo_empty),
    .full(_fifo_full),
    .injectdbiterr(0),
    .injectsbiterr(0),
    .rd_en(fifo_read_valid),
    .rst(0),
    .sleep(0),
    .wr_clk(clk),
    .wr_en(fifo_write_valid)
);

time_t second;
timer #(
    .FREQ(25_000_000)
) timer_inst (
    .clk,
    .rst_n,
    .second
);

////// 用一个 fifo 来处理遍历路由表
rip_task_t timed_task_in;
rip_task_t task_out;
logic task_empty;
logic task_read_valid;
logic timed_rip;
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(64),
    .READ_DATA_WIDTH($bits(rip_task_t)),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH($bits(rip_task_t))
) enum_task_fifo (
    .din(send_rip ? {rip_dst_mac, rip_dst_ip, rip_port} : timed_task_in),
    .dout(task_out),
    .empty(task_empty),
    .full(_task_full),
    .injectdbiterr(0),
    .injectsbiterr(0),
    .rd_en(task_read_valid),
    .rst(0),
    .sleep(0),
    .wr_clk(clk),
    .wr_en(send_rip | timed_rip)
);

enum reg [2:0] {
    Idle,               // 空闲
    AddArp,             // 添加 ARP 项
    AddRouting,         // 添加路由项
    ProcessArp,         // 查询 ARP 表
    ProcessRouting      // 查询路由表
} state;

// 路由表
reg  ip_lookup;
wire ip_complete;
wire [31:0] ip_nexthop;
wire ip_found = ip_nexthop != '0;
mac_t enum_dst_mac;
ip_t  enum_dst_ip;
logic [1:0] enum_port;
ip_t  enum_prefix;
ip_t  enum_nexthop;
logic [5:0] enum_mask;
logic [4:0] enum_metric;
logic enum_valid;
logic enum_last;
routing_table routing_table_inst (
    .clk_125M(clk),
    .rst_n,
    .second,

    // .debug,
    
    .ip_query(ip_input),
    .query_valid(ip_lookup),
    .nexthop_result(ip_nexthop),
    .query_ready(ip_complete),

    .insert_fifo_data(fifo_out),
    .insert_fifo_empty(fifo_empty),
    .insert_fifo_read_valid(fifo_read_valid),

    .enum_task_in(task_out),
    .enum_task_empty(task_empty),
    .enum_task_read_valid(task_read_valid),

    .enum_dst_mac,
    .enum_dst_ip,
    .enum_port,
    .enum_prefix,
    .enum_nexthop,
    .enum_mask,
    .enum_metric,
    .enum_valid,
    .enum_last,

    .overflow()
);

rip_packer rip_packer_inst (
    .clk(clk),
    .rst(~rst_n),

    .valid(enum_valid),
    .last(enum_last),
    .prefix(enum_prefix),
    .mask(enum_mask),
    .port({enum_port == '0, enum_port}),
    .src_ip(Address::ip({enum_port == '0, enum_port})),
    .dst_ip(enum_dst_ip),
    .dst_mac(enum_dst_mac),
    .nexthop(enum_nexthop),
    .metric(enum_metric),
    .outer_fifo_read_valid(rip_tx_read_valid),
    .outer_fifo_empty(rip_tx_empty),
    .outer_fifo_out(rip_tx_data)
);

// ARP 表，目前用简陋版
reg  arp_add_entry;
reg  arp_query;
reg  arp_query_nexthop; // 正在查询的是 nexthop，用路由表的输出
wire arp_done;
wire arp_found;
simple_arp_table arp_table_inst (
    .clk,
    .rst_n,
    .write(arp_add_entry),
    .query(arp_query),
    .ip_insert(ip_input),
    .ip_query(arp_query_nexthop ? ip_nexthop : ip_input),
    .mac_input,
    .vlan_input,
    .mac_output(mac_output),
    .vlan_output(vlan_output),
    .done(arp_done),
    .found(arp_found)
);

task reset_module;
begin
    arp_add_entry <= 0;
    arp_query <= 0;
    arp_query_nexthop <= 0;
    ip_lookup <= 0;
    fifo_write_valid <= 0;
    done <= 0;
    bad <= 0;
    state <= Idle;
end
endtask

time_t second_latch;

always_ff @ (negedge clk) begin
    // 将模块输入连接到 fifo 的输入，由后面的逻辑控制 wr_en 即可
    fifo_in.prefix <= ip_input;
    fifo_in.nexthop <= nexthop_input;
    fifo_in.mask <= mask_input;
    fifo_in.metric <= metric_input;
    fifo_in.from_vlan <= vlan_input;

    second_latch <= second;
    // 每一整数秒对一个口发 RIP
    timed_rip <= second_latch != second;
    timed_task_in <= {Address::McastMAC, Address::McastIP, second[1:0]};

    if (~rst_n) begin
        reset_module();
    end else begin
        case (state)
            Idle: begin
                if (reset) begin
                    done <= 0;
                    bad <= 0;
                end
                case ({add_arp, add_routing, process_arp, process_ip})
                    4'b0000: begin
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        fifo_write_valid <= 0;
                        arp_query_nexthop <= 0;
                        state <= Idle;
                    end
                    4'b1000: begin
                        // 开始添加 ARP
                        arp_add_entry <= 1;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        fifo_write_valid <= 0;
                        done <= 0;
                        bad <= 0;
                        arp_query_nexthop <= 0;
                        state <= AddArp;
                    end
                    4'b0100: begin
                        // 开始添加路由
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        fifo_write_valid <= 1;
                        done <= 0;
                        bad <= 0;
                        arp_query_nexthop <= 0;
                        state <= AddRouting;
                    end
                    4'b0010: begin
                        // 开始查询 ARP 表
                        arp_add_entry <= 0;
                        arp_query <= 1;
                        ip_lookup <= 0;
                        fifo_write_valid <= 0;
                        done <= 0;
                        bad <= 0;
                        arp_query_nexthop <= 0;
                        state <= ProcessArp;
                    end
                    4'b0001: begin
                        // 开始处理 IP 包
                        done <= 0;
                        bad <= 0;
                        if (Address::port(ip_input) == 0) begin
                            // 不是直连，需要查路由表
                            arp_add_entry <= 0;
                            arp_query <= 0;
                            ip_lookup <= 1;
                            fifo_write_valid <= 0;
                            arp_query_nexthop <= 1;
                            state <= ProcessRouting;
                        end else begin
                            // 直连，直接查 ARP
                            arp_add_entry <= 0;
                            arp_query <= 1;
                            ip_lookup <= 0;
                            fifo_write_valid <= 0;
                            arp_query_nexthop <= 0;
                            state <= ProcessArp;
                        end
                    end
                    default: begin
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        fifo_write_valid <= 0;
                        arp_query_nexthop <= 0;
                        state <= Idle;
                        $display("ERROR!");
                    end
                endcase
            end
            AddArp: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                fifo_write_valid <= 0;
                done <= arp_done;
                bad <= 0;
                if (arp_done) begin
                    // $display("ARP entry added\n");
                    state <= Idle;
                end else begin
                    state <= AddArp;
                end
            end
            // 直接返回，由路由表慢慢处理
            AddRouting: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                fifo_write_valid <= 0;
                done <= 1;
                bad <= 0;
                state <= Idle;
            end
            ProcessArp: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                fifo_write_valid <= 0;
                done <= arp_done;
                bad <= arp_done && !arp_found;
                if (arp_done) begin
                    // $display("ARP complete\n");
                    arp_query_nexthop <= 0;
                    state <= Idle;
                end else begin
                    state <= ProcessArp;
                end
            end
            ProcessRouting: begin
                arp_add_entry <= 0;
                ip_lookup <= 0;
                fifo_write_valid <= 0;
                done <= ip_complete && !ip_found;
                bad <= ip_complete && !ip_found;
                if (ip_complete) begin
                    if (ip_found) begin
                        // 找到 nexthop
                        arp_query <= 1;
                        $display("Nexthop found, searching ARP table\n");
                        state <= ProcessArp;
                    end else begin
                        // 没有找到
                        arp_query <= 0;
                        $display("Not found in routing table\n");
                        state <= Idle;
                    end
                end else begin
                    arp_query <= 0;
                    state <= ProcessRouting;
                end
            end
            default: begin
                reset_module();
            end
        endcase
    end
end

endmodule