/*
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出
*/

`timescale 1ns / 1ps

`include "debug.vh"
`include "packet.vh"
`include "address.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_125M,
    input   wire    clk_62M5,
    input   wire    rst_n,

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0] led_out,     // 硬件 led 指示灯
    output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    output  wire    [7:0]  digit1_out,  // 硬件高位数码管

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
    .rd_en(fifo_rd_en),
    .rd_rst_busy(fifo_rd_busy),
    .rst(fifo_rst),
    .sleep(0),
    .wr_clk(clk_125M),
    .wr_en(fifo_wr_en),
    .wr_rst_busy(fifo_wr_busy)
);

// 遇到无法处理的包则 bad 置 1
// 此后不再读内容，rx_last 时向 fifo 扔一个带 last 标志的字节，然后让 tx 清 fifo
reg  bad;

// 已经读了多少字节
reg  [5:0]  read_cnt;

// 包的信息
reg  [47:0] dst_mac;
reg  [47:0] src_mac;
reg  [2:0]  vlan_id;
reg  is_ip;
reg  ip_checksum_overflow;  // checksum >= 0xfeff，则输出 checksum 高 8 位为 0，低 8 位 +1
reg  ip_checksum_fe;     // checksum == 0xfe??

// 让 tx_manager 开始发送当前包的信号
reg  tx_start;

////// 如果包的处理流程太慢，会暂停 rx_ready
// 正在处理 IP 包
enum logic [1:0] {
    // 开始处理时
    IP_PACKET_PROCESSING,
    // read_cnt=58 而还没有处理完
    IP_PACKET_STILL_PROCESSING,
    // 处理完或不是 IP 包
    IP_PACKET_DONE
} ip_packet_process_status;
assign rx_ready = (ip_packet_process_status != IP_PACKET_STILL_PROCESSING);

// 提供的信息
reg  [47:0] tx_dst_mac;
reg  [2:0]  tx_vlan_id;

// 根据 vlan_id 得出的路由器 MAC
wire [47:0] router_mac;
// 根据 vlan_id 得出的路由器 IP
wire [31:0] router_ip;
// 组合逻辑给出 router_mac 和 router_ip
address router_address (
    .vlan_id,
    .mac(router_mac),
    .ip(router_ip)
);

tx_manager tx_manager_inst (
    .clk_125M,
    .rst_n,
    .input_dst_mac(tx_dst_mac),
    .input_vlan_id(tx_vlan_id),
    .input_is_ip(is_ip),
    .input_ip_checksum_overflow(ip_checksum_overflow),
    .input_bad(bad),
    .start(tx_start),
    .fifo_data(fifo_dout),
    .fifo_empty,
    .fifo_rd_en,
    .tx_data,
    .tx_valid,
    .tx_last
    // tx_ready
    // abort
);

// 需要处理的数据
reg  [31:0] ip_input;
wire [47:0] mac_result;
wire [2:0]  vlan_result;

// 处理信号
reg  process_reset;
reg  add_arp;
reg  add_routing;
reg  process_arp;
reg  process_ip;
wire process_done;
wire process_bad;

packet_processor packet_processor_inst (
    .clk(clk_125M),
    .clk_62M5,
    .rst_n,
    .reset(process_reset),
    .add_arp,
    .add_routing,
    .process_arp,
    .process_ip,
    .ip_input,
    //.mask_input(),
    //.nexthop_input,
    .mac_input(src_mac),
    .vlan_input(vlan_id),
    .done(process_done),
    .bad(process_bad),
    .mac_output(mac_result),
    .vlan_output(vlan_result)
);

// 断言 rx_data 的数据，如果不一样则置 bad 为 1
task assert_rx;
input wire [7:0] expected;
begin
    if (rx_data != expected) begin
        $display("Assertion fails at rx_data == %02x (expected %02x)", rx_data, expected);
        bad <= 1;
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

always_ff @(posedge clk_125M) begin
    if (!rst_n) begin
        // 复位
        process_reset <= 0;
        add_arp <= 0;
        add_routing <= 0;
        process_arp <= 0;
        process_ip <= 0;

        read_cnt <= 0;
        tx_start <= 0;

        ip_packet_process_status <= IP_PACKET_DONE;
    end else begin
        // 处理 rx 输入
        if (rx_valid) begin
            // 对于 IP 和 ARP 都需要寄存的地方
            case (read_cnt)
                0 : begin
                    dst_mac[40 +: 8] <= rx_data;
                    bad <= 0;
                    is_ip <= 0;
                end
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
                // 0x8100: protocol VLAN
                12: assert_rx(8'h81);
                13: assert_rx(8'h00);
                15: vlan_id <= rx_data[2:0];
                // 0x0806 ARP or 0x0800 IPv4
                16: assert_rx(8'h08);
                17: begin
                    case (rx_data) 
                        8'h00: is_ip <= 1;
                        8'h06: is_ip <= 0;
                        default: bad <= 1;
                    endcase
                end
            endcase
            // 单独处理 IP 和 ARP 包的 fifo 操作
            casez ({bad, is_ip})
                // ARP 包
                2'b00: begin
                    // ARP 包中，12 字节后，除目标 MAC IP 以外都入 fifo
                    if (read_cnt >= 12 && (read_cnt < 36 || read_cnt >= 46)) begin
                        // 将 ARP Request 改为 ARP Reply
                        if (read_cnt == 25) begin
                            fifo_din <= {rx_last, 8'h02};
                        end else begin
                            fifo_din <= {rx_last, rx_data};
                        end
                        fifo_wr_en <= 1;
                    end else begin
                        fifo_din <= 'x;
                        fifo_wr_en <= 0;
                    end
                end
                // IP 包
                2'b01: begin
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
                        // 其他情况，12 字节后全部进 fifo，其中 TTL 和 checksum 需要处理
                        default: begin
                            if (read_cnt >= 12) begin
                                fifo_din <= {rx_last, rx_data};
                                fifo_wr_en <= 1;
                            end else begin
                                fifo_din <= 'x;
                                fifo_wr_en <= 0;
                            end
                        end
                    endcase
                end
                // 异常情况
                2'b1?: begin
                    if (rx_last) begin
                        fifo_din <= 9'b1_xxxx_xxxx;
                        fifo_wr_en <= 1;
                    end else begin
                        fifo_din <= 'x;
                        fifo_wr_en <= 0;
                    end
                end
            endcase
            // 其他 IP ARP 特定的处理流程
            casez ({bad, is_ip})
                // ARP
                2'b00: begin
                    // 46 字节后开始发送
                    tx_dst_mac <= src_mac;
                    tx_vlan_id <= vlan_id;
                    tx_start <= read_cnt == 46;
                    // 过程中检验
                    case (read_cnt)
                        // 检验目标 MAC 为广播
                        18: begin
                            if (dst_mac != '1 || rx_data != 8'h00) begin
                                bad <= 1;
                            end
                        end
                        // 检验其他 ARP 东西
                        19: assert_rx(8'h01);
                        20: assert_rx(8'h08);
                        21: assert_rx(8'h00);
                        22: assert_rx(8'h06);
                        23: assert_rx(8'h04);
                        24: assert_rx(8'h00);
                        25: assert_rx(8'h01);
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
                    add_routing <= 0;
                    process_arp <= 0;
                    process_ip <= 0;
                    process_reset <= 0;
                end
                // IP
                2'b01: begin
                    tx_dst_mac <= mac_result;
                    tx_vlan_id <= vlan_result;
                    case (read_cnt)
                        // TTL > 0
                        26: begin
                            if (rx_data == '0)
                                bad <= 1;
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
                        ip_packet_process_status <= IP_PACKET_DONE;
                        if (process_bad) begin
                            bad <= 1;
                            tx_start <= read_cnt >= 46;
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
                    add_arp <= 0;
                    add_routing <= 0;
                    process_arp <= 0;
                    process_ip <= read_cnt == 38;
                    // 38 时置 PROCESSING
                    if (read_cnt == 38) begin
                        ip_packet_process_status <= IP_PACKET_PROCESSING;
                    end
                    // 58 还未处理完则置 STILL_PROCESSING，暂停 rx
                    if (read_cnt == 58 && !process_done && ip_packet_process_status == IP_PACKET_PROCESSING) begin
                        ip_packet_process_status <= IP_PACKET_STILL_PROCESSING;
                    end
                end
                // Bad
                2'b1?: begin
                    // 这里用 46 因为 bad 最晚在 45 被设置
                    tx_start <= read_cnt == 46;
                end
            endcase

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
    .clk(bad),
    .digit_out(digit0_out)
);

endmodule