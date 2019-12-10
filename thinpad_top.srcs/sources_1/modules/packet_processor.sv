`include "address.vh"
`include "debug.vh"
`include "types.vh"

module packet_processor (
    input  logic clk,                   // 125M 时钟
    input  logic rst_n,                 // 初始化
    input  logic add_arp,               // 添加 ARP 项
    input  logic add_routing,           // 添加路由项
    input  logic process_arp,           // 查询 ARP
    input  logic process_ip,            // 处理 IP 包
    input  logic reset,                 // 手动清除 done bad 标志

    input  ip_t  ip_input,              // 输入 IP
    input  logic [5:0] mask_input,      // 掩码长度（用于插入路由）
    input  ip_t  nexthop_input,         // 输入 nexthop
    input  mac_t mac_input,             // 输入 MAC
    input  logic [4:0] metric_input,    // 输入 metric
    input  logic [2:0] vlan_input,      // 输入 VLAN
    output logic done,                  // 处理完成
    output logic bad,                   // 查不到
    output logic [47:0] mac_output,     // 目标 MAC
    output logic [2:0]  vlan_output     // 目标 VLAN
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

enum reg [2:0] {
    Idle,               // 空闲
    AddArp,             // 添加 ARP 项
    AddRouting,         // 添加路由项
    ProcessArp,         // 查询 ARP 表
    ProcessRouting      // 查询路由表
} state;

// 组合逻辑分析 ip_input 是否属于 1~4 子网，0 则不属于
logic [2:0] subnet;
always_comb begin
    case (ip_input[8 +: 24])
        `SUBNET_1: subnet = 1;
        `SUBNET_2: subnet = 2;
        `SUBNET_3: subnet = 3;
        `SUBNET_4: subnet = 4;
        default:   subnet = 0;
    endcase
end

// 路由表
reg  ip_lookup;
wire ip_complete;
wire [31:0] ip_nexthop;
wire ip_found = ip_nexthop != '0;
routing_table routing_table_inst (
    .clk_125M(clk),
    .rst_n,
    .second('0),
    
    .ip_query(ip_input),
    .query_valid(ip_lookup),
    .nexthop_result(ip_nexthop),
    .query_ready(ip_complete),

    .insert_fifo_data(fifo_out),
    .insert_fifo_empty(fifo_empty),
    .insert_fifo_read_valid(fifo_read_valid),

    .overflow()
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

always_ff @ (negedge clk) begin
    // 将模块输入连接到 fifo 的输入，由后面的逻辑控制 wr_en 即可
    fifo_in.prefix <= ip_input;
    fifo_in.nexthop <= nexthop_input;
    fifo_in.mask <= mask_input;
    fifo_in.metric <= metric_input;
    fifo_in.from_vlan <= vlan_input;

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
                        if (subnet == 0) begin
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