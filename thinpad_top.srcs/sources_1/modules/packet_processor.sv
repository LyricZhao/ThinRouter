`include "address.vh"
`include "debug.vh"

module packet_processor (
    input  wire  clk,               // 125M 时钟
    input  wire  rst_n,             // 初始化
    input  wire  reset_process,     // 结束任务
    input  wire  add_arp,           // 添加 ARP 项
    input  wire  add_routing,       // 添加路由项
    input  wire  process_ip,        // 处理 IP 包

    input  wire  [31:0] ip_input,   // 输入 IP
    input  wire  [31:0] nexthop,    // 输入 nexthop
    input  wire  [47:0] mac_input,  // 输入 MAC
    input  wire  [2:0]  vlan_input, // 输入 VLAN

    output logic done,              // 处理完成
    output logic bad,               // 查不到
    output logic [47:0] dst_mac,    // 目标 MAC
    output logic [2:0]  dst_vlan    // 目标 VLAN
);

enum {
    Idle,               // 空闲
    AddArp,             // 添加 ARP 项
    AddRouting,         // 添加路由项
    ProcessRouting,     // 查询路由表
    ProcessArp,         // 查询 ARP 表
    Done
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


logic arp_add_entry;
wire  arp_found;
simple_arp_table arp_table_inst (
    .clk_internal(clk),
    .rst_n,
    .valid(arp_add_entry),
    .ip_input,
    .mac_input,
    .vlan_input,
    .mac_output(dst_mac),
    .vlan_output(dst_vlan),
    .found(arp_found)
);

always_ff @ (posedge clk) begin
    if (~rst_n) begin
        done <= 0;
        bad <= 0;
        state <= Idle;
    end else if (reset_process) begin
        done <= 0;
        bad <= 0;
        state <= Idle;
    end else begin
        case (state)
            Idle: begin
                case ({add_arp, add_routing, process_ip})
                    3'b000: begin
                    end
                    3'b100: begin
                        // 开始添加 ARP
                        arp_add_entry <= 1;
                        state <= AddArp;
                    end
                    3'b010: begin
                        // 开始添加路由
                        // todo
                    end
                    3'b001: begin
                        // 开始处理 IP 包
                        if (subnet == 0) begin
                            // 不是直连，需要查路由表
                            // todo
                            // state <= ProcessRouting;
                            done <= 1;
                            bad <= 1;
                            state <= Done;
                            $display("Unimplemented! Non-subnet IP target\n");
                        end else begin
                            // 直连，直接查 ARP
                            if (arp_found) begin
                                done <= 1;
                                bad <= 0;
                            end else begin
                                done <= 1;
                                bad <= 1;
                                $display("Not found in ARP table\n");
                            end
                            state <= Done;
                        end
                    end
                    default: begin
                        $display("ERROR!");
                    end
                endcase
            end
            AddArp: begin
                arp_add_entry <= 0;
                state <= Done;
            end
        endcase
    end
end

endmodule