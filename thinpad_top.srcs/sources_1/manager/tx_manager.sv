/*
发送数据包

时序：
将 start 置 1 一拍，同时提供所有必要的输入（MAC 等），这些输入应当尽量保持，直到下一个 start
如果当前没有正在发送的数据包，就进入发送。否则需要等待一段时间再发送
如果此时 input_bad 为 1，则处理这个包的时候改为丢弃 fifo 内容，不发送任何数据

这些数据是通过 fifo 传输的：
IP 包
-   0   VLAN tag
-   4   IP header
-   14  TTL （已 -1）
-   16  IP checksum （已 +0x100，但可能有特殊情况需要处理）
        如果低 8 位是 0xff，会传一个信号，需要在这里进行处理
-   18  src IP
-   22  dst IP
-   26  payload
-   ?
ARP 包
-   0   VLAN tag
-   4   ARP info
-   12  ARP response （已经处理为 0x0002 ARP Response）
-   14  src MAC
-   20  src IP
-   24

发送的数据来源：
IP 包
-   0   dst MAC         input_dst_mac
-   6   src MAC         根据 input_vlan_id 推断
-   12  VLAN tag        fifo
-   16  IP header       fifo
    28  IP checksum     fifo （根据 input_ip_checksum_ff 可能额外处理）
-   38  IP payload      fifo
ARP 包
-   0   dst MAC         input_dst_mac
-   6   src MAC         根据 input_vlan_id 推断
-   12  VLAN tag        fifo
-   16  ARP info        fifo
    24  ARP reply       fifo
-   26  src MAC         根据 input_vlan_id 推断
-   32  src IP          根据 input_vlan_id 推断
-   36  dst MAC         fifo
-   42  dst IP          fifo
-   46
*/
`timescale 1ns / 1ps

`include "debug.vh"
`include "packet.vh"
`include "address.vh"

module tx_manager (
    input   wire    clk_125M,
    input   wire    rst_n,

    input   wire    [47:0]  input_dst_mac,
    input   wire    [2:0]   input_vlan_id,
    // 是 IP 包 / ARP 包
    input   wire    input_is_ip,
    // 如果 ip checksum 的低 8 位是 ff，则还需要再处理（不然就由 io_manager 流上处理了）
    input   wire    input_ip_checksum_ff,
    // 如果出现问题，需要直接丢掉 fifo 中数据，直到 fifo 传来 last
    input   wire    input_bad,

    // 告知 tx 开始发送
    input   wire    start,

    // fifo 中最高位表示 last，低 8 为数据
    input   wire    [8:0]   fifo_data,
    input   wire    fifo_empty,
    output  reg     fifo_rd_en,

    // todo
    input   wire    abort,

    output  reg     [7:0] tx_data,
    output  reg     tx_valid,
    output  reg     tx_last,
    // todo
    input  wire     tx_ready
);

reg [47:0] dst_mac;
reg [47:0] src_mac;
reg [31:0] src_ip;
reg [2:0]  vlan_id;
reg is_ip;
reg ip_checksum_ff;
reg bad;
reg working;
reg has_job_pending;
reg [5:0]  send_cnt;

// 给定 vlan_id，组合逻辑获取路由器对应接口的 MAC 和 IP
address router_address (
    .vlan_id,
    .mac(src_mac),
    .ip(src_ip)
);

task no_tx;
begin
    tx_data <= 'x;
    tx_valid <= 0;
    tx_last <= 0;
    fifo_rd_en <= 0;
end
endtask

task send;
input logic [7:0] data;
begin
    tx_data <= data;
    tx_valid <= 1;
    tx_last <= 0;
    fifo_rd_en <= 0;
end
endtask

task send_fifo;
begin
    {tx_last, tx_data} <= fifo_data;
    tx_valid <= 1;
    fifo_rd_en <= 1;
end
endtask

always_ff @(negedge clk_125M) begin
    if (!rst_n) begin
        working <= 0;
        has_job_pending <= 0;
        no_tx();
    end else begin
        if (working) begin
            if (fifo_empty) begin
                // 先简单处理，遇到 fifo 空了就暂停处理
                no_tx();
            end else begin
                if (bad) begin
                    // 丢弃 fifo
                    tx_data <= 'x;
                    tx_valid <= 0;
                    tx_last <= 0;
                    fifo_rd_en <= 1;
                end else if (is_ip) begin
                    // IP 包
                    case (send_cnt)
                        0 : send(dst_mac[40 +: 8]);
                        1 : send(dst_mac[32 +: 8]);
                        2 : send(dst_mac[24 +: 8]);
                        3 : send(dst_mac[16 +: 8]);
                        4 : send(dst_mac[ 8 +: 8]);
                        5 : send(dst_mac[ 0 +: 8]);
                        6 : send(src_mac[40 +: 8]);
                        7 : send(src_mac[32 +: 8]);
                        8 : send(src_mac[24 +: 8]);
                        9 : send(src_mac[16 +: 8]);
                        10: send(src_mac[ 8 +: 8]);
                        11: send(src_mac[ 0 +: 8]);
                        // IP Checksum 对于低 8 位为 FF 的情况要特殊处理
                        // 其余情况，以及 TTL-1 应当在 io_manager 写入 fifo 之时就处理了
                        28, 29: begin
                            tx_data <= ip_checksum_ff ? fifo_data[7:0] + 1 : fifo_data[7:0];
                            tx_valid <= 1;
                            tx_last <= 0;
                            fifo_rd_en <= 1;
                        end
                        default: begin
                            send_fifo();
                        end
                    endcase
                end else begin
                    // ARP 包
                    case (send_cnt)
                        0 : send(dst_mac[40 +: 8]);
                        1 : send(dst_mac[32 +: 8]);
                        2 : send(dst_mac[24 +: 8]);
                        3 : send(dst_mac[16 +: 8]);
                        4 : send(dst_mac[ 8 +: 8]);
                        5 : send(dst_mac[ 0 +: 8]);
                        6 : send(src_mac[40 +: 8]);
                        7 : send(src_mac[32 +: 8]);
                        8 : send(src_mac[24 +: 8]);
                        9 : send(src_mac[16 +: 8]);
                        10: send(src_mac[ 8 +: 8]);
                        11: send(src_mac[ 0 +: 8]);
                        // io_manager 会将 ARP 请求的 src MAC & IP 写入 fifo，而 dst MAC & IP 则丢弃
                        // 返回 ARP 回复的时候，此模块手动插入路由器的 MAC & IP
                        26: send(src_mac[40 +: 8]);
                        27: send(src_mac[32 +: 8]);
                        28: send(src_mac[24 +: 8]);
                        29: send(src_mac[16 +: 8]);
                        30: send(src_mac[ 8 +: 8]);
                        31: send(src_mac[ 0 +: 8]);
                        32: send(src_ip [24 +: 8]);
                        33: send(src_ip [16 +: 8]);
                        34: send(src_ip [ 8 +: 8]);
                        35: send(src_ip [ 0 +: 8]);
                        default: begin
                            send_fifo();
                        end
                    endcase
                end
                // 是否发完
                if (fifo_data[8]) begin
                    working <= 0;
                    send_cnt <= 0;
                end else begin
                    working <= 1;
                    if (send_cnt == '1) begin
                        send_cnt <= '1;
                    end else begin
                        send_cnt <= send_cnt + 1;
                    end
                end
            end
            
            // 可能来了下一个发送
            if (start) begin
                has_job_pending <= 1;
            end
        end else begin  // !working
            if (has_job_pending || start) begin
                has_job_pending <= 0;
                working <= 1;
                dst_mac <= input_dst_mac;
                vlan_id <= input_vlan_id;
                is_ip <= input_is_ip;
                ip_checksum_ff <= input_ip_checksum_ff;
                bad <= input_bad;
                send_cnt <= 0;
            end else begin  
                working <= 0;
            end
            no_tx();
        end
    end
end

endmodule