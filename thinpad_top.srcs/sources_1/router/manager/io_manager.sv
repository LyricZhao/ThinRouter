/*
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出
*/

`timescale 1ns / 1ps

`include "debug.vh"
`include "types.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_125M,
    input   wire    clk_200M,
    input   wire    rst_n,

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  logic   [15:0] led_out,     // 硬件 led 指示灯
    output  logic   [7:0]  digit0_out,  // 硬件低位数码管
    output  logic   [7:0]  digit1_out,  // 硬件高位数码管

    output  logic   [15:0] debug,

    // 目前先接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  wire    rx_ready,           // 是否允许数据进入
    input   wire    rx_last,            // 数据传入结束
    output  bit     [7:0] tx_data,      // 数据出口
    output  bit     tx_valid,           // 数据出口正在传输
    input   wire    tx_ready,           // 外面是否准备接收：当前不处理外部不 ready 的逻辑 （TODO）
    output  bit     tx_last             // 数据传出结束

    // ,
    // output  logic   [8:0] fifo_din,
    // output  logic   [8:0] fifo_wr_en,
    // output  logic   [5:0] read_cnt

);

reg  [8:0] fifo_din;
wire [8:0] fifo_dout;
wire fifo_empty;
wire fifo_full;
reg  fifo_rd_en;
wire fifo_rd_busy;
reg  fifo_rst;
reg  fifo_wr_en;
wire fifo_wr_busy;
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(9),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH(9)
) fifo (
    .din(fifo_din),
    .dout(fifo_dout),
    .empty(fifo_empty),
    .full(fifo_full),
    .injectdbiterr(0),
    .injectsbiterr(0),
    .rd_en(fifo_rd_en),
    .rd_rst_busy(fifo_rd_busy),
    .rst(fifo_rst),
    .sleep(0),
    .wr_clk(clk_125M),
    .wr_en(fifo_wr_en),
    .wr_rst_busy(fifo_wr_busy)
);

// 已经读了多少字节
logic [5:0] read_cnt;

// 包的信息
mac_t dst_mac;
mac_t src_mac;
logic [2:0] vlan_id;
logic ip_checksum_overflow; // checksum >= 0xfeff，则输出 checksum 高 8 位为 0，低 8 位 +1
logic ip_checksum_fe;       // checksum == 0xfe??
// 根据 vlan_id 得出的路由器 IP
ip_t  router_ip;
always_comb router_ip = Address::ip(vlan_id);
// 遇到无法处理的包则 bad 置 1
// 此后不再读内容，rx_last 时向 fifo 扔一个带 last 标志的字节，然后让 tx 清 fifo
enum logic [2:0] {
    // 
    PacketBad,
    PacketIP,
    PacketARPRequest,
    PacketARPResponse,
    PacketRIPDefault,
    PacketRIPRequest,
    PacketRIPResponse
} packet_type;

// 让 tx_manager 开始发送当前包的信号
logic tx_start;

////// 如果包的处理流程太慢，或者执行 RIP 流程，会暂停 rx_ready
// 正在处理 IP 包
enum logic [1:0] {
    // 开始处理时
    IPPacketProcessing,
    // read_cnt=58 而还没有处理完
    IPPacketStillProcessing,
    // 处理完或不是 IP 包
    IPPacketDone
} ip_packet_process_status;

// 正在处理接收到的 RIP 数据
enum logic {
    // 开始处理时
    RIPResponseProcessing,
    // 处理完成或者未在处理
    RIPResponseDone
} rip_response_process_status;

// 是否需要发送 RIP Response
// maybe todo 支持发送 >25 条
// 每个端口是否应该发送 RIP Response 了。会在接收到 RIP 请求时，或时间到时置 1
logic [1:0] rip_send_pending;
// 正在发送，则暂停 rx
logic rip_sending;

assign rx_ready = 
    (ip_packet_process_status != IPPacketStillProcessing) &&
    (rip_response_process_status == RIPResponseDone) &&
    !rip_sending;

////// RIP 处理
// 20 字节循环
logic [4:0] rip_read_cycle;
// 一个 RIP 条目是否正确（可能是 nexthop 为本路由器，或者格式错误）
logic rip_entry_valid;
// RIP 包的来源 IP
ip_t  rip_src_ip;

// 提供的信息
mac_t tx_dst_mac;
logic [2:0]  tx_vlan_id;

logic tx_bad;
logic [7:0] tx_man_data;
logic tx_man_valid;
logic tx_man_last;
always_comb case (packet_type)
    PacketBad, PacketRIPDefault, PacketRIPRequest, PacketRIPResponse: tx_bad = 1;
    default: tx_bad = 0;
endcase
tx_manager tx_manager_inst (
    .clk_125M,
    .rst_n,
    .input_dst_mac(tx_dst_mac),
    .input_vlan_id(tx_vlan_id),
    .input_is_ip(packet_type == PacketIP),
    .input_ip_checksum_overflow(ip_checksum_overflow),
    .input_bad(tx_bad),
    .start(tx_start),
    .fifo_data(fifo_dout),
    .fifo_empty,
    .fifo_rd_en,
    .tx_data(tx_man_data),
    .tx_valid(tx_man_valid),
    .tx_last(tx_man_last)
    // tx_ready
    // abort
);

// 需要处理的数据
ip_t  ip_input;
logic [5:0] mask_input;
logic [4:0] metric_input;
ip_t  nexthop_input;
mac_t mac_result;
logic [2:0] vlan_result;
logic [1:0] rip_port;
ip_t  rip_dst_ip;
mac_t rip_dst_mac;

// 处理信号
logic process_reset;
logic add_arp;
logic add_routing;
logic process_arp;
logic process_ip;
logic send_rip;
logic process_done;
logic process_bad;

// 输出信号
logic rip_tx_read_valid;
logic rip_tx_empty;
logic [8:0] rip_tx_data;

packet_processor packet_processor_inst (
    .clk(clk_125M),
    .rst_n,
    .debug,
    .reset(process_reset),
    .add_arp,
    .add_routing,
    .process_arp,
    .process_ip,
    .send_rip,
    .rip_port,
    .rip_dst_ip,
    .rip_dst_mac,

    .ip_input,
    .metric_input,
    .mask_input,
    .nexthop_input,
    .mac_input(src_mac),
    .vlan_input(vlan_id),
    .done(process_done),
    .bad(process_bad),
    .mac_output(mac_result),
    .vlan_output(vlan_result),

    .rip_tx_read_valid,
    .rip_tx_empty,
    .rip_tx_data
);

tx_dual tx_dual_inst (
    .clk(clk_125M),
    .rst_n,
    .tx_data(tx_man_data),
    .tx_valid(tx_man_valid),
    .tx_last(tx_man_last),
    .rip_data(rip_tx_data),
    .rip_empty(rip_tx_empty),
    .rip_read_valid(rip_tx_read_valid),
    .out_data(tx_data),
    .out_valid(tx_valid),
    .out_last(tx_last),
    .out_ready(tx_ready)
);

// 断言 rx_data 的数据，如果不一样则置 bad 为 1
task assert_rx;
input wire [7:0] expected;
begin
    if (rx_data != expected) begin
        $display("Assertion fails at rx_data == %02x (expected %02x)", rx_data, expected);
        packet_type <= PacketBad;
    end
end endtask

task fifo_write_none; begin
    fifo_din <= 'x;
    fifo_wr_en <= 0;
end endtask

task fifo_write_rx; begin
    fifo_din <= {rx_last, rx_data};
    fifo_wr_en <= 1;
end endtask

task fifo_write;
input wire [7:0] data;
begin
    fifo_din <= {rx_last, data};
    fifo_wr_en <= 1;
end endtask

function logic[3:0] count_left_ones;
input wire [7:0] data;
begin 
    casez (data)
        8'b0???????: count_left_ones = 0;
        8'b10??????: count_left_ones = 1;
        8'b110?????: count_left_ones = 2;
        8'b1110????: count_left_ones = 3;
        8'b11110???: count_left_ones = 4;
        8'b111110??: count_left_ones = 5;
        8'b1111110?: count_left_ones = 6;
        8'b11111110: count_left_ones = 7;
        8'b11111111: count_left_ones = 8;
    endcase
end endfunction

always_ff @(posedge clk_125M) begin
    // 默认值
    process_reset <= 0;
    add_arp <= 0;
    add_routing <= 0;
    process_arp <= 0;
    process_ip <= 0;
    send_rip <= 0;

    tx_start <= 0;
    tx_dst_mac <= '0;
    tx_vlan_id <= '0;

    fifo_din <= 'x;
    fifo_wr_en <= 0;

    rip_sending <= 0;
    rip_send_pending <= '0;

    ip_packet_process_status <= IPPacketDone;
    rip_response_process_status <= RIPResponseDone;

    if (!rst_n) begin
        // 复位
        read_cnt <= 0;
    end else begin
        // 处理 rx 输入
        if (rx_valid) begin
            // 前 18 个字节进行存储，并用来确定包的类型
            if (read_cnt < 18) begin
                case (read_cnt)
                    0 : dst_mac[40 +: 8] <= rx_data;
                    1 : dst_mac[32 +: 8] <= rx_data;
                    2 : dst_mac[24 +: 8] <= rx_data;
                    3 : dst_mac[16 +: 8] <= rx_data;
                    4 : dst_mac[ 8 +: 8] <= rx_data;
                    5 : dst_mac[ 0 +: 8] <= rx_data;
                    6 : src_mac[40 +: 8] <= rx_data;
                    7 : src_mac[32 +: 8] <= rx_data;
                    8 : src_mac[24 +: 8] <= rx_data;
                    9 : src_mac[16 +: 8] <= rx_data;
                    10: src_mac[ 8 +: 8] <= rx_data;
                    11: src_mac[ 0 +: 8] <= rx_data;
                    15: vlan_id <= rx_data[2:0];
                    // 0x0806 ARP or 0x0800 IPv4
                    16: packet_type <= rx_data == 8'h08 ? PacketIP : PacketBad;
                    17: begin
                        if (packet_type == PacketIP) case (rx_data) 
                            // IPv4 标签，可能是 RIP
                            // todo 可能有目标为本机的 RIP Responnse？
                            8'h00: packet_type <= dst_mac == Address::McastMAC ? PacketRIPDefault : PacketIP;
                            // ARP 标签
                            8'h06: packet_type <= PacketARPRequest;
                            default: packet_type <= PacketBad;
                        endcase
                    end
                endcase
                // 12-18 字节传入 fifo
                if (read_cnt >= 12) begin
                    fifo_din <= {rx_last, rx_data};
                    fifo_wr_en <= 1;
                end
            end else begin
            // 对于 18 字节之后，有各种处理流程
                // 处理 fifo 操作
                case (packet_type)
                    // ARP 请求，18 字节后，除目标 MAC IP 以外都入 fifo
                    PacketARPRequest: begin
                        if (read_cnt < 36 || read_cnt >= 46) begin
                            // 将 ARP Request 改为 ARP Reply
                            if (read_cnt == 25) begin
                                fifo_din <= {rx_last, 8'h02};
                            end else begin
                                fifo_din <= {rx_last, rx_data};
                            end
                            fifo_wr_en <= 1;
                        end
                    end
                    // IP 包
                    PacketIP: begin
                        case (read_cnt)
                            // TTL
                            26: begin
                                fifo_din[8] <= rx_last;
                                fifo_din[7:0] <= rx_data - 1;
                                fifo_wr_en <= 1;
                            end
                            // checksum 高 8 位
                            28: begin
                                fifo_din[8] <= rx_last;
                                fifo_din[7:0] <= rx_data + 1;
                                fifo_wr_en <= 1;
                            end
                            // 其他情况，18 字节后全部进 fifo，其中 TTL 和 checksum 需要处理
                            default: begin
                                fifo_din <= {rx_last, rx_data};
                                fifo_wr_en <= 1;
                            end
                        endcase
                    end
                    // Bad, RIP 包，不直接回复，不用 fifo
                    PacketRIPDefault, PacketRIPRequest, PacketRIPResponse, PacketBad: begin
                        // last 时 flush fifo
                        fifo_din[8] <= rx_last;
                        fifo_wr_en <= rx_last;
                    end
                endcase
                // 其他的处理流程
                case (packet_type)
                    PacketARPRequest: begin
                        // 46 字节后开始发送
                        tx_dst_mac <= src_mac;
                        tx_vlan_id <= vlan_id;
                        tx_start <= read_cnt == 46;
                        // 过程中检验
                        case (read_cnt)
                            18: assert_rx(8'h00);
                            19: assert_rx(8'h01);
                            20: assert_rx(8'h08);
                            21: assert_rx(8'h00);
                            22: assert_rx(8'h06);
                            23: assert_rx(8'h04);
                            24: assert_rx(8'h00);
                            // Request or Response
                            25: begin
                                case (rx_data)
                                    // Request
                                    8'h01: begin end
                                    // Response
                                    8'h02: packet_type <= PacketARPResponse;
                                    // bad
                                    default: packet_type <= PacketBad;
                                endcase
                            end
                            // 记录来源 IP，准备添加 ARP 条目
                            32: ip_input[24 +: 8] <= rx_data;
                            33: ip_input[16 +: 8] <= rx_data;
                            34: ip_input[ 8 +: 8] <= rx_data;
                            35: ip_input[ 0 +: 8] <= rx_data;
                            // 检查目标 IP 是否为路由器自己 IP
                            42: assert_rx(router_ip[24 +: 8]);
                            43: assert_rx(router_ip[16 +: 8]);
                            44: assert_rx(router_ip[ 8 +: 8]);
                            45: assert_rx(router_ip[ 0 +: 8]);
                        endcase
                        // 需要在 ARP 表中记录一下包的来源
                        add_arp <= read_cnt == 36;
                    end
                    PacketARPResponse: begin
                        // 过程中检验
                        case (read_cnt)
                            // 记录来源 IP，准备添加 ARP 条目
                            32: ip_input[24 +: 8] <= rx_data;
                            33: ip_input[16 +: 8] <= rx_data;
                            34: ip_input[ 8 +: 8] <= rx_data;
                            35: ip_input[ 0 +: 8] <= rx_data;
                            // 检查目标 IP 是否为路由器自己 IP
                            42: assert_rx(router_ip[24 +: 8]);
                            43: assert_rx(router_ip[16 +: 8]);
                            44: assert_rx(router_ip[ 8 +: 8]);
                            45: assert_rx(router_ip[ 0 +: 8]);
                        endcase
                        // 需要在 ARP 表中记录一下包的来源
                        add_arp <= read_cnt == 36;
                    end
                    // IP
                    PacketIP: begin
                        tx_dst_mac <= mac_result;
                        tx_vlan_id <= vlan_result;
                        case (read_cnt)
                            // TTL > 0
                            26: begin
                                if (rx_data == '0)
                                    packet_type <= PacketBad;
                            end
                            // checksum_overflow <= checksum >= 0xfeff
                            28: begin
                                ip_checksum_fe <= rx_data == 8'hfe;
                                ip_checksum_overflow <= rx_data == '1;
                            end
                            29: begin
                                if (ip_checksum_fe && rx_data == '1)
                                    ip_checksum_overflow <= 1;
                            end
                            // 记录目标 IP，准备查表
                            34: ip_input[24 +: 8] <= rx_data;
                            35: ip_input[16 +: 8] <= rx_data;
                            36: ip_input[ 8 +: 8] <= rx_data;
                            37: ip_input[ 0 +: 8] <= rx_data;
                        endcase
                        // 发送取决于 packet_processor 返回结果
                        if (read_cnt > 38 && process_done) begin
                            ip_packet_process_status <= IPPacketDone;
                            if (process_bad) begin
                                // flush tx
                                tx_start <= read_cnt >= 46;
                                packet_type <= PacketBad;
                                process_reset <= 0;
                            end else begin
                                // tx_start 置一拍后，packet_processor 重置，process_done = 0
                                tx_start <= 1;
                                process_reset <= 1;
                            end
                        end else begin
                            tx_start <= 0;
                            process_reset <= 0;
                        end
                        // 调用 packet_processor
                        process_ip <= read_cnt == 38;
                        // 38 时置 PROCESSING
                        if (read_cnt == 38) begin
                            ip_packet_process_status <= IPPacketProcessing;
                        end
                        // 58 还未处理完则置 STILL_PROCESSING，暂停 rx
                        if (read_cnt == 58 && !process_done && ip_packet_process_status == IPPacketProcessing) begin
                            ip_packet_process_status <= IPPacketStillProcessing;
                        end
                    end
                    // 在第 47 字节确定是 RIP Request 还是 Response
                    PacketRIPDefault: begin
                        rip_read_cycle <= 0;
                        case (read_cnt)
                            // UDP
                            27: assert_rx(8'h11);
                            // 记录源 IP 作为可能添加的条目的下一条
                            30: nexthop_input[24 +: 8] <= rx_data;
                            31: nexthop_input[16 +: 8] <= rx_data;
                            32: nexthop_input[ 8 +: 8] <= rx_data;
                            33: nexthop_input[ 0 +: 8] <= rx_data;
                            // 检查目标 IP
                            34: assert_rx(Address::McastIP[24 +: 8]);
                            35: assert_rx(Address::McastIP[16 +: 8]);
                            36: assert_rx(Address::McastIP[ 8 +: 8]);
                            37: assert_rx(Address::McastIP[ 0 +: 8]);
                            // 检查 UDP 头
                            38: assert_rx(8'h02);
                            39: assert_rx(8'h08);
                            40: assert_rx(8'h02);
                            41: assert_rx(8'h08);
                            // RIP Command
                            46: begin
                                case (rx_data)
                                    1: packet_type <= PacketRIPRequest;
                                    2: packet_type <= PacketRIPResponse;
                                    default: packet_type <= PacketBad;
                                endcase
                                // 丢掉 fifo 中的数据
                                tx_start <= 1;
                            end
                        endcase
                    end
                    PacketRIPResponse: begin
                        case (read_cnt)
                            // RIPv2
                            47: assert_rx(8'h02);
                            48: assert_rx(8'h00);
                            49: assert_rx(8'h00);
                            default: begin
                                case (rip_read_cycle)
                                    // 检验标签：family=2, route=0
                                    0 : rip_entry_valid <= (rx_data == 8'h00);
                                    1 : rip_entry_valid <= rip_entry_valid && (rx_data == 8'h02);
                                    2 : rip_entry_valid <= rip_entry_valid && (rx_data == 8'h00);
                                    3 : rip_entry_valid <= rip_entry_valid && (rx_data == 8'h00);
                                    // 记录 prefix 地址
                                    4 : ip_input[24 +: 8] <= rx_data;
                                    5 : ip_input[16 +: 8] <= rx_data;
                                    6 : ip_input[ 8 +: 8] <= rx_data;
                                    7 : ip_input[ 0 +: 8] <= rx_data;
                                    // 记录 mask
                                    8 : mask_input <= count_left_ones(rx_data);
                                    9 : mask_input <= mask_input == 8 ? (mask_input + count_left_ones(rx_data)) : mask_input;
                                    10: mask_input <= mask_input == 16 ? (mask_input + count_left_ones(rx_data)) : mask_input;
                                    11: mask_input <= mask_input == 24 ? (mask_input + count_left_ones(rx_data)) : mask_input;
                                    // todo 检验 nexthop 不能是本机
                                    // 12: nexthop_input[24 +: 8] <= rx_data;
                                    // 13: nexthop_input[16 +: 8] <= rx_data;
                                    // 14: nexthop_input[ 8 +: 8] <= rx_data;
                                    // 15: nexthop_input[ 0 +: 8] <= rx_data;
                                    // 记录 metric，metric_input[4] 为 metric >= 16
                                    16: metric_input[4] <= (rx_data != 0);
                                    17: metric_input[4] <= (metric_input[4] || rx_data != 0);
                                    18: metric_input[4] <= (metric_input[4] || rx_data != 0);
                                    19: metric_input <= {(metric_input[4] || rx_data[7:4] != 0), rx_data[3:0]};
                                endcase
                                if (rip_read_cycle == 19) begin
                                    rip_read_cycle <= 0;
                                    add_routing <= rip_entry_valid;
                                end else begin
                                    rip_read_cycle <= rip_read_cycle + 1;
                                end
                            end
                        endcase
                    end
                    // todo 回复 RIP 请求
                    PacketRIPRequest: begin
                        rip_dst_mac <= src_mac;
                        rip_dst_ip <= nexthop_input;
                        rip_port <= vlan_id[1:0];
                        send_rip <= 1;
                        packet_type <= PacketBad;
                    end
                    // Bad
                    PacketBad: begin
                        // 这里用 46 因为 bad 最晚在 45 被设置
                        tx_start <= read_cnt == 46;
                    end
                endcase
            end
            

            if (rx_last) begin
                read_cnt <= 0;
            end else if (read_cnt == '1) begin
                read_cnt <= '1;
            end else begin
                read_cnt <= read_cnt + 1;
            end
        end else begin
            // !rx_valid
            fifo_din <= 'x;
            fifo_wr_en <= 0;
        end
    end
end

// always_ff @(negedge clk_125M) begin
//     if (tx_start) $display("START at read_cnt=%0d", read_cnt);
// end

// 正常发包显示在高位数码管
digit_loop debug_send (
    .rst_n(rst_n),
    .clk(tx_start),
    .digit_out(digit1_out)
);

// 丢包显示在低位数码管
digit_loop debug_discard (
    .rst_n(rst_n),
    .clk(packet_type == PacketBad),
    .digit_out(digit0_out)
);

always_comb begin
    // led_out[0] = packet_type == PacketBad;
    // led_out[1] = packet_type == PacketIP;
    // led_out[2] = packet_type == PacketARPRequest;
    // led_out[3] = packet_type == PacketARPResponse;
    // led_out[4] = packet_type == PacketRIPDefault;
    // led_out[5] = packet_type == PacketRIPRequest;
    // led_out[6] = packet_type == PacketRIPResponse;
    // led_out[15] = rx_ready;
    // led_out[14] = ip_packet_process_status == IPPacketProcessing;
    // led_out[14] = ip_packet_process_status == IPPacketStillProcessing;
end

endmodule