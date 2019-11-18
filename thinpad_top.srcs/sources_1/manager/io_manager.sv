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

    ,
    output  logic   [8:0] fifo_din,
    output  logic   [8:0] fifo_wr_en,
    output  logic   [5:0] read_cnt

);

assign rx_ready = 1;

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

// 包的信息
reg  [47:0] dst_mac;
reg  [47:0] src_mac;
reg  [2:0]  vlan_id;
reg  is_ip;
reg  ip_checksum_ff;
reg  [31:0] dst_ip;

// 已经读了多少字节
reg  [5:0]  read_cnt;

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

// 让 tx_manager 开始发送当前包的信号
reg  tx_start;

tx_manager tx_manager_inst (
    .clk_125M,
    .rst_n,
    .input_dst_mac(src_mac),
    .input_vlan_id(vlan_id),
    .input_is_ip(is_ip),
    .input_ip_checksum_ff(ip_checksum_ff),
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

// 断言 rx_data 的数据，如果不一样则置 bad 为 1
task assert_rx;
input wire [7:0] expected;
begin
    if (rx_data != expected) begin
        $display("Assertion fails at rx_data == %02x (expected %02x)", rx_data, expected);
        bad <= 1;
    end
end
endtask

task fifo_write_none;
begin
    fifo_din <= 'x;
    fifo_wr_en <= 0;
end
endtask

task fifo_write_rx;
begin
    fifo_din <= {rx_last, rx_data};
    fifo_wr_en <= 1;
end
endtask

task fifo_write;
input wire [7:0] data;
begin
    fifo_din <= {rx_last, data};
    fifo_wr_en <= 1;
end
endtask

always_ff @(posedge clk_125M) begin
    if (!rst_n) begin
        // 复位
        read_cnt <= 0;
        tx_start <= 0;
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
                        fifo_din <= {rx_last, rx_data};
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
                            if (rx_data == '0) // TTL = 0
                                bad <= 1;
                            fifo_din <= {rx_last, rx_data - 1};
                            fifo_wr_en <= 1;
                        end
                        // checksum 高 8 位
                        28: begin
                            fifo_din <= {rx_last, rx_data + 1};
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
                    case (read_cnt)
                        // 检查目标 IP 是否为路由器自己 IP
                        42: assert_rx(router_ip[24 +: 8]);
                        43: assert_rx(router_ip[16 +: 8]);
                        44: assert_rx(router_ip[ 8 +: 8]);
                        // 如果是正确的 IP 则开始发送
                        45: begin
                            assert_rx(router_ip[ 0 +: 8]);
                            tx_start <= 1;
                        end
                        default: begin
                            tx_start <= 0;
                        end
                    endcase
                end
                // IP
                2'b01: begin
                    case (read_cnt)
                        24: bad <= 1;
                    endcase
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

endmodule