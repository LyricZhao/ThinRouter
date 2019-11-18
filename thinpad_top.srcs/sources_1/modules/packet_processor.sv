`include "address.vh"
`include "debug.vh"

module packet_processor (
    input  wire  clk,                   // 125M 时钟
    input  wire  rst_n,                 // 初始化
    input  wire  add_arp,               // 添加 ARP 项
    input  wire  add_routing,           // 添加路由项
    input  wire  process_arp,           // 查询 ARP
    input  wire  process_ip,            // 处理 IP 包

    input  wire  [31:0] ip_input,       // 输入 IP
    input  wire  [7:0]  mask_input,     // 掩码长度（用于插入路由）
    input  wire  [31:0] nexthop_input,  // 输入 nexthop
    input  wire  [47:0] mac_input,      // 输入 MAC
    input  wire  [2:0]  vlan_input,     // 输入 VLAN
    output logic done,                  // 处理完成
    output logic bad,                   // 查不到
    output logic [47:0] mac_output,     // 目标 MAC
    output logic [2:0]  vlan_output     // 目标 VLAN
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
logic ip_lookup;
logic ip_insert;
wire  ip_complete;
wire  [31:0] ip_nexthop;
wire  ip_found = ip_nexthop != '0;
routing_table routing_table_inst (
    .clk,
    .rst(!rst_n),

    .lookup_valid(ip_lookup),
    .insert_valid(ip_insert),

    .lookup_insert_addr(ip_input),
    .insert_nexthop(nexthop_input),
    .insert_mask_len(mask_input),

    .lookup_insert_ready(ip_complete),
    .lookup_output_nexthop(ip_nexthop)
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
    ip_insert <= 0;
    done <= 0;
    bad <= 0;
    state <= Idle;
end
endtask

always_ff @ (negedge clk) begin
    if (~rst_n) begin
        reset_module();
    end else begin
        case (state)
            Idle: begin
                case ({add_arp, add_routing, process_arp, process_ip})
                    4'b0000: begin
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        ip_insert <= 0;
                        arp_query_nexthop <= 0;
                        state <= Idle;
                    end
                    4'b1000: begin
                        // 开始添加 ARP
                        arp_add_entry <= 1;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        ip_insert <= 0;
                        arp_query_nexthop <= 0;
                        state <= AddArp;
                    end
                    4'b0100: begin
                        // 开始添加路由
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        ip_insert <= 1;
                        arp_query_nexthop <= 0;
                        state <= AddRouting;
                    end
                    4'b0010: begin
                        // 开始查询 ARP 表
                        arp_add_entry <= 0;
                        arp_query <= 1;
                        ip_lookup <= 0;
                        ip_insert <= 0;
                        arp_query_nexthop <= 0;
                        state <= ProcessArp;
                    end
                    4'b0001: begin
                        // 开始处理 IP 包
                        if (subnet == 0) begin
                            // 不是直连，需要查路由表
                            arp_add_entry <= 0;
                            arp_query <= 0;
                            ip_lookup <= 1;
                            ip_insert <= 0;
                            arp_query_nexthop <= 1;
                            state <= ProcessRouting;
                        end else begin
                            // 直连，直接查 ARP
                            arp_add_entry <= 0;
                            arp_query <= 1;
                            ip_lookup <= 0;
                            ip_insert <= 0;
                            arp_query_nexthop <= 0;
                            state <= ProcessArp;
                        end
                    end
                    default: begin
                        arp_add_entry <= 0;
                        arp_query <= 0;
                        ip_lookup <= 0;
                        ip_insert <= 0;
                        arp_query_nexthop <= 0;
                        state <= Idle;
                        $display("ERROR!");
                    end
                endcase
                done <= 0;
                bad <= 0;
            end
            AddArp: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                ip_insert <= 0;
                done <= arp_done;
                bad <= 0;
                if (arp_done) begin
                    $display("ARP entry added\n");
                    state <= Idle;
                end else begin
                    state <= AddArp;
                end
            end
            AddRouting: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                ip_insert <= 0;
                done <= ip_complete;
                bad <= 0;
                if (ip_complete) begin
                    $display("Routing entry added\n");
                    state <= Idle;
                end else begin
                    state <= AddRouting;
                end
            end
            ProcessArp: begin
                arp_add_entry <= 0;
                arp_query <= 0;
                ip_lookup <= 0;
                ip_insert <= 0;
                done <= arp_done;
                bad <= arp_done && !arp_found;
                if (arp_done) begin
                    $display("ARP complete\n");
                    state <= Idle;
                end else begin
                    state <= ProcessArp;
                end
            end
            ProcessRouting: begin
                arp_add_entry <= 0;
                ip_lookup <= 0;
                ip_insert <= 0;
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