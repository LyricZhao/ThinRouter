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
    // 包长度，padding 0 不计入，也不进入 fifo
    input   wire    [15:0] input_packet_size,

    // 告知 tx 开始发送
    input   wire    start,

    input   wire    [7:0]   fifo_data,
    output  reg     fifo_rd_en,

    // todo
    input   wire    abort,

    output  reg     [7:0] tx_data,
    output  reg     tx_valid,
    output  reg     tx_last,
    // todo
    input  wire    tx_ready
);

reg [47:0] dst_mac;
reg [47:0] src_mac;
reg [31:0] src_ip;
reg [2:0]  vlan_id;
reg is_ip;
reg ip_checksum_ff;
reg working;
reg [15:0]  send_cnt;
reg [15:0]  packet_size;

wire is_last = send_cnt + 1 == packet_size;

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
    tx_last <= is_last;
    fifo_rd_en <= 0;
end
endtask

task send_fifo;
begin
    tx_data <= fifo_data;
    tx_valid <= 1;
    tx_last <= is_last;
    fifo_rd_en <= 1;
end
endtask

always_comb begin
    case (vlan_id)
        1: {src_mac, src_ip} = {`ROUTER_MAC_1, `ROUTER_IP_1};
        2: {src_mac, src_ip} = {`ROUTER_MAC_2, `ROUTER_IP_2};
        3: {src_mac, src_ip} = {`ROUTER_MAC_3, `ROUTER_IP_3};
        4: {src_mac, src_ip} = {`ROUTER_MAC_4, `ROUTER_IP_4};
        default: {src_mac, src_ip} = 'x;
    endcase
end

always_ff @(negedge clk_125M) begin
    if (!rst_n) begin
        working <= 0;
        no_tx();
    end else begin
        if (working) begin
            if (is_ip) begin
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
                        tx_data <= ip_checksum_ff ? fifo_data + 1 : fifo_data;
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
            if (is_last) begin
                working <= 0;
                send_cnt <= 0;
            end else begin
                working <= 1;
                send_cnt <= send_cnt + 1;
            end
        end else begin
            if (start) begin
                working <= 1;
                dst_mac <= input_dst_mac;
                vlan_id <= input_vlan_id;
                is_ip <= input_is_ip;
                ip_checksum_ff <= input_ip_checksum_ff;
                send_cnt <= 0;
                packet_size <= input_packet_size;
            end else begin  
                working <= 0;
            end
            no_tx();
        end
    end
end

endmodule