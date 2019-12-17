/*
将rip协议的表项打包成一个完整的IP包，存入到FIFO中
*/

`timescale 1ns / 1ps
`include "constants.vh"

module rip_packer (
    input   wire    clk,
    input   wire    rst,

    input   logic    valid,
    input   logic    last,
    input   logic    [31:0] prefix,
    input   logic    [5:0]  mask,
    input   logic    [31:0] src_ip,
    input   logic    [31:0] dst_ip,
    input   logic    [31:0] nexthop,
    input   logic    [3:0]  metric,

    input   logic    outer_fifo_read_valid,

    output  logic    outer_fifo_empty,
    output  logic    [8:0]  outer_fifo_out
);

enum logic [3:0] {
    Receive, // 不断接受rip表项
    ComputeCheckSum1,
    ComputeCheckSum2,
    ComputeCheckSum3,
    ComputeCheckSum4,
    AssembleHeader, // 将rip表项组装
    AssembleBody,
    AssembleBody_R,
    AssembleBody_W,
    Finished
} state;

// 一共有多少条目
logic [4:0] entry_count;

logic [31:0] ip_checksum; // 理论上是16bit，这里为了处理进位的方便，用32bit暂存
logic [31:0] udp_checksum;

logic [31:0] mask32; // 把mask转化为32位
logic [31:0] rip_items_len; // rip表项的长度和（20*表项数）
logic [0:27][7:0] ip_udp_header; // ip和udp的包头

logic [31:0] ip_len; // ip包的长度（byte）
logic [31:0] udp_len; // udp包的长度（byte）
assign ip_len = rip_items_len + 32;
assign udp_len = rip_items_len + 12;

// 给头部固定部分赋值
// ip头部分
assign ip_udp_header[0]  = 8'h45;
assign ip_udp_header[1]  = 8'hc0; // 此字段参考样例.pcap文件设计
assign ip_udp_header[2]  = ip_len[15:8];
assign ip_udp_header[3]  = ip_len[7:0];
assign ip_udp_header[4]  = 8'h00;
assign ip_udp_header[5]  = 8'h00;
assign ip_udp_header[6]  = 8'h40; // 此字段参考样例.pcap文件设计
assign ip_udp_header[7]  = 8'h00;
assign ip_udp_header[8]  = 8'h01; // ttl=1
assign ip_udp_header[9]  = 8'h11; // 协议类型udp
assign ip_udp_header[10] = ip_checksum[15:8]; // 实际采用checksum的后16位
assign ip_udp_header[11] = ip_checksum[7:0];
assign {ip_udp_header[12], ip_udp_header[13], ip_udp_header[14], ip_udp_header[15]} = src_ip;
assign {ip_udp_header[16], ip_udp_header[17], ip_udp_header[18], ip_udp_header[19]} = dst_ip;
// udp头部分
assign ip_udp_header[20] = 8'h02; // udp端口520
assign ip_udp_header[21] = 8'h08;
assign ip_udp_header[22] = 8'h02;
assign ip_udp_header[23] = 8'h08;
assign ip_udp_header[24] = udp_len[15:8];
assign ip_udp_header[25] = udp_len[7:0];
assign ip_udp_header[26] = udp_checksum[15:8];
assign ip_udp_header[27] = udp_checksum[7:0];

logic [31:0] tmp_ip_checksum; // 用于计算IP checksum的中间变量
logic [31:0] tmp_udp_checksum; // 用于计算UDP checksum的中间变量

assign tmp_ip_checksum = {16'b0, ip_udp_header[0], ip_udp_header[1]}
                        + {16'b0, ip_udp_header[2], ip_udp_header[3]}
                        + {16'b0, ip_udp_header[4], ip_udp_header[5]}
                        + {16'b0, ip_udp_header[6], ip_udp_header[7]}
                        + {16'b0, ip_udp_header[8], ip_udp_header[9]} // 4,5,6,7项均为0，略去
                        + {16'b0, ip_udp_header[12],ip_udp_header[13]}
                        + {16'b0, ip_udp_header[14],ip_udp_header[15]}
                        + {16'b0, ip_udp_header[16],ip_udp_header[17]}
                        + {16'b0, ip_udp_header[18],ip_udp_header[19]};

assign tmp_udp_checksum = {32'h00000208} + {32'h00000208}
                        + {16'b0, ip_udp_header[24], ip_udp_header[25]}
                        + {16'b0, src_ip[31:16]} + {16'b0, src_ip[15:0]} // udp伪首部
                        + {16'b0, dst_ip[31:16]} + {16'b0, dst_ip[15:0]}
                        + {16'b0, 16'h0011} + {16'b0, udp_len[15:0]}
                        + {32'h00000202}; // !此处将rip包头也考虑了

always_comb begin // 把mask转为32位
    case (mask)
        6'b000000: begin mask32 <= 32'b00000000000000000000000000000000; end
        6'b000001: begin mask32 <= 32'b10000000000000000000000000000000; end
        6'b000010: begin mask32 <= 32'b11000000000000000000000000000000; end
        6'b000011: begin mask32 <= 32'b11100000000000000000000000000000; end
        6'b000100: begin mask32 <= 32'b11110000000000000000000000000000; end
        6'b000101: begin mask32 <= 32'b11111000000000000000000000000000; end
        6'b000110: begin mask32 <= 32'b11111100000000000000000000000000; end
        6'b000111: begin mask32 <= 32'b11111110000000000000000000000000; end
        6'b001000: begin mask32 <= 32'b11111111000000000000000000000000; end
        6'b001001: begin mask32 <= 32'b11111111100000000000000000000000; end
        6'b001010: begin mask32 <= 32'b11111111110000000000000000000000; end
        6'b001011: begin mask32 <= 32'b11111111111000000000000000000000; end
        6'b001100: begin mask32 <= 32'b11111111111100000000000000000000; end
        6'b001101: begin mask32 <= 32'b11111111111110000000000000000000; end
        6'b001110: begin mask32 <= 32'b11111111111111000000000000000000; end
        6'b001111: begin mask32 <= 32'b11111111111111100000000000000000; end
        6'b010000: begin mask32 <= 32'b11111111111111110000000000000000; end
        6'b010001: begin mask32 <= 32'b11111111111111111000000000000000; end
        6'b010010: begin mask32 <= 32'b11111111111111111100000000000000; end
        6'b010011: begin mask32 <= 32'b11111111111111111110000000000000; end
        6'b010100: begin mask32 <= 32'b11111111111111111111000000000000; end
        6'b010101: begin mask32 <= 32'b11111111111111111111100000000000; end
        6'b010110: begin mask32 <= 32'b11111111111111111111110000000000; end
        6'b010111: begin mask32 <= 32'b11111111111111111111111000000000; end
        6'b011000: begin mask32 <= 32'b11111111111111111111111100000000; end
        6'b011001: begin mask32 <= 32'b11111111111111111111111110000000; end
        6'b011010: begin mask32 <= 32'b11111111111111111111111111000000; end
        6'b011011: begin mask32 <= 32'b11111111111111111111111111100000; end
        6'b011100: begin mask32 <= 32'b11111111111111111111111111110000; end
        6'b011101: begin mask32 <= 32'b11111111111111111111111111111000; end
        6'b011110: begin mask32 <= 32'b11111111111111111111111111111100; end
        6'b011111: begin mask32 <= 32'b11111111111111111111111111111110; end
        6'b100000: begin mask32 <= 32'b11111111111111111111111111111111; end
        default: begin
            mask32 <= 0;
        end
    endcase
end

// 忽略
logic _inner_fifo_full;

logic inner_fifo_empty;
logic [`RIP_ENTRY_LEN-1:0] inner_fifo_in; /* 高至低位:|metric|nexthop|mask|IP|other| */
logic [`RIP_ENTRY_LEN-1:0] inner_fifo_out;
logic inner_fifo_read_valid;
logic inner_fifo_write_valid;


xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(64), // TODO
    .READ_DATA_WIDTH(`RIP_ENTRY_LEN),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH(`RIP_ENTRY_LEN)
) inner_fifo (
    .din(inner_fifo_in),
    .dout(inner_fifo_out),
    .empty(inner_fifo_empty),
    .full(_inner_fifo_full),
    .injectdbiterr('0),
    .injectsbiterr('0),
    .rd_en(inner_fifo_read_valid),
    .rst('0),
    .sleep('0),
    .wr_clk(clk),
    .wr_en(inner_fifo_write_valid)
);

// 忽略
logic _outer_fifo_full;
logic [8:0] outer_fifo_in;
logic outer_fifo_write_valid;

xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(1024), // TODO
    .READ_DATA_WIDTH(9), // 读是一个byte地读
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH(9)
) outer_fifo (
    .din(outer_fifo_in),
    .dout(outer_fifo_out),
    .empty(outer_fifo_empty),
    .full(_outer_fifo_full),
    .injectdbiterr('0),
    .injectsbiterr('0),
    .rd_en(outer_fifo_read_valid),
    .rst('0),
    .sleep('0),
    .wr_clk(clk),
    .wr_en(outer_fifo_write_valid)
);

logic [5:0] header_pointer; // 临时变量，用于作为数组下标打包头部
logic [5:0] body_pointer; // 临时变量，用于作为数组下标rip表项

always_ff @ (posedge clk) begin
    if (rst) begin
        state <= Receive;
        {ip_checksum, udp_checksum} <= 0;
        {inner_fifo_read_valid, inner_fifo_write_valid} <= 0;
        outer_fifo_write_valid <= 0;
        rip_items_len <= 0;
        entry_count <= 0;
    end else begin
        {inner_fifo_read_valid, inner_fifo_write_valid} <= 0;
        outer_fifo_write_valid <= 0;
        case (state)
            Receive: begin
                inner_fifo_write_valid <= 0;
                if (valid == 1'b1) begin
                    entry_count <= entry_count + 1;
                    inner_fifo_write_valid <= 1;
                    inner_fifo_in[32*1-1:32*0] <= 32'h00020000;
                    inner_fifo_in[32*2-1:32*1] <= prefix;
                    inner_fifo_in[32*3-1:32*2] <= mask32;
                    inner_fifo_in[32*4-1:32*3] <= nexthop;
                    inner_fifo_in[32*5-1:32*4] <= {12'b0, metric[3:0]};
                    // !maybe time-consuming
                    udp_checksum <= udp_checksum + {16'b0, prefix[15:0]} + {16'b0, prefix[31:16]}
                                    + {16'b0, mask32[15:0]} + {16'b0, mask32[31:16]}
                                    + {16'b0, nexthop[15:0]} + {16'b0, nexthop[31:16]}
                                    + {28'b0, metric[3:0]} + 32'h00000002;
                    rip_items_len <= rip_items_len + 20; // 一次加20，避免后面的乘法
                end
                if (last == 1'b1) begin
                    state <= ComputeCheckSum1; // 进入checksum的计算
                end
            end
            ComputeCheckSum1: begin // 把数据段中的和与头部和相加
                udp_checksum <= udp_checksum + tmp_udp_checksum;
                ip_checksum <= tmp_ip_checksum;
                state <= ComputeCheckSum2;
            end
            ComputeCheckSum2: begin // 加法回滚
                udp_checksum <= {16'b0, udp_checksum[31:16]} + {16'b0, udp_checksum[15:0]};
                ip_checksum <= {16'b0, ip_checksum[31:16]} + {16'b0, ip_checksum[15:0]};
                state <= ComputeCheckSum3;
            end
            ComputeCheckSum3: begin // 第2次加法回滚
                udp_checksum <= {16'b0, udp_checksum[31:16]} + {16'b0, udp_checksum[15:0]};
                ip_checksum <= {16'b0, ip_checksum[31:16]} + {16'b0, ip_checksum[15:0]};
                state <= ComputeCheckSum4;
            end
            ComputeCheckSum4: begin
                udp_checksum <= ~udp_checksum; // 取反
                ip_checksum <= ~ip_checksum; // 取反
                state <= AssembleHeader;
                header_pointer <= 0; // 初始化头部指针
            end
            AssembleHeader: begin
                outer_fifo_write_valid <= 1;
                case (header_pointer)
                    6'b000000: begin outer_fifo_in <= {1'b0, ip_udp_header[0] }; end
                    6'b000001: begin outer_fifo_in <= {1'b0, ip_udp_header[1] }; end
                    6'b000010: begin outer_fifo_in <= {1'b0, ip_udp_header[2] }; end
                    6'b000011: begin outer_fifo_in <= {1'b0, ip_udp_header[3] }; end
                    6'b000100: begin outer_fifo_in <= {1'b0, ip_udp_header[4] }; end
                    6'b000101: begin outer_fifo_in <= {1'b0, ip_udp_header[5] }; end
                    6'b000110: begin outer_fifo_in <= {1'b0, ip_udp_header[6] }; end
                    6'b000111: begin outer_fifo_in <= {1'b0, ip_udp_header[7] }; end
                    6'b001000: begin outer_fifo_in <= {1'b0, ip_udp_header[8] }; end
                    6'b001001: begin outer_fifo_in <= {1'b0, ip_udp_header[9] }; end
                    6'b001010: begin outer_fifo_in <= {1'b0, ip_udp_header[10]}; end
                    6'b001011: begin outer_fifo_in <= {1'b0, ip_udp_header[11]}; end
                    6'b001100: begin outer_fifo_in <= {1'b0, ip_udp_header[12]}; end
                    6'b001101: begin outer_fifo_in <= {1'b0, ip_udp_header[13]}; end
                    6'b001110: begin outer_fifo_in <= {1'b0, ip_udp_header[14]}; end
                    6'b001111: begin outer_fifo_in <= {1'b0, ip_udp_header[15]}; end
                    6'b010000: begin outer_fifo_in <= {1'b0, ip_udp_header[16]}; end
                    6'b010001: begin outer_fifo_in <= {1'b0, ip_udp_header[17]}; end
                    6'b010010: begin outer_fifo_in <= {1'b0, ip_udp_header[18]}; end
                    6'b010011: begin outer_fifo_in <= {1'b0, ip_udp_header[19]}; end
                    6'b010100: begin outer_fifo_in <= {1'b0, ip_udp_header[20]}; end
                    6'b010101: begin outer_fifo_in <= {1'b0, ip_udp_header[21]}; end
                    6'b010110: begin outer_fifo_in <= {1'b0, ip_udp_header[22]}; end
                    6'b010111: begin outer_fifo_in <= {1'b0, ip_udp_header[23]}; end
                    6'b011000: begin outer_fifo_in <= {1'b0, ip_udp_header[24]}; end
                    6'b011001: begin outer_fifo_in <= {1'b0, ip_udp_header[25]}; end
                    6'b011010: begin outer_fifo_in <= {1'b0, ip_udp_header[26]}; end
                    6'b011011: begin outer_fifo_in <= {1'b0, ip_udp_header[27]}; end
                    6'b011100: begin outer_fifo_in <= 9'h002; end // rip头
                    6'b011101: begin outer_fifo_in <= 9'h002; end
                    6'b011110: begin outer_fifo_in <= 9'h000; end
                    6'b011111: begin outer_fifo_in <= 9'h000; state <= AssembleBody; end
                endcase
                header_pointer <= header_pointer + 1;
            end
            AssembleBody: begin
                outer_fifo_write_valid <= 0;
                body_pointer <= 0;
                state <= AssembleBody_W;
            end
            AssembleBody_R: begin // 从inner fifo读表项
                inner_fifo_read_valid <= 0;
                entry_count <= entry_count - 1;
                state <= (entry_count == 1) ? Finished : AssembleBody;
            end
            AssembleBody_W: begin
                outer_fifo_write_valid <= 1;
                case (body_pointer)
                    5'b00000: begin outer_fifo_in <= {1'b0, inner_fifo_out[4*8-1:3*8]};   end
                    5'b00001: begin outer_fifo_in <= {1'b0, inner_fifo_out[3*8-1:2*8]};   end
                    5'b00010: begin outer_fifo_in <= {1'b0, inner_fifo_out[2*8-1:1*8]};   end
                    5'b00011: begin outer_fifo_in <= {1'b0, inner_fifo_out[1*8-1:0*8]};   end
                    5'b00100: begin outer_fifo_in <= {1'b0, inner_fifo_out[8*8-1:7*8]};   end
                    5'b00101: begin outer_fifo_in <= {1'b0, inner_fifo_out[7*8-1:6*8]};   end
                    5'b00110: begin outer_fifo_in <= {1'b0, inner_fifo_out[6*8-1:5*8]};   end
                    5'b00111: begin outer_fifo_in <= {1'b0, inner_fifo_out[5*8-1:4*8]};   end
                    5'b01000: begin outer_fifo_in <= {1'b0, inner_fifo_out[12*8-1:11*8]}; end
                    5'b01001: begin outer_fifo_in <= {1'b0, inner_fifo_out[11*8-1:10*8]}; end
                    5'b01010: begin outer_fifo_in <= {1'b0, inner_fifo_out[10*8-1:9*8]};  end
                    5'b01011: begin outer_fifo_in <= {1'b0, inner_fifo_out[9*8-1:8*8]};   end
                    5'b01100: begin outer_fifo_in <= {1'b0, inner_fifo_out[16*8-1:15*8]}; end
                    5'b01101: begin outer_fifo_in <= {1'b0, inner_fifo_out[15*8-1:14*8]}; end
                    5'b01110: begin outer_fifo_in <= {1'b0, inner_fifo_out[14*8-1:13*8]}; end
                    5'b01111: begin outer_fifo_in <= {1'b0, inner_fifo_out[13*8-1:12*8]}; end
                    5'b10000: begin outer_fifo_in <= {1'b0, inner_fifo_out[20*8-1:19*8]}; end
                    5'b10001: begin outer_fifo_in <= {1'b0, inner_fifo_out[19*8-1:18*8]}; end
                    5'b10010: begin outer_fifo_in <= {1'b0, inner_fifo_out[18*8-1:17*8]}; end
                    5'b10011: begin outer_fifo_in <= {entry_count == 1, inner_fifo_out[17*8-1:16*8]}; state <= AssembleBody_R; inner_fifo_read_valid <= 1; end
                endcase
                // $display("IP %h",outer_fifo_in[7:0]);
                body_pointer <= body_pointer + 1;
            end
            Finished: begin // 完毕
                rip_items_len <= 0;
                ip_checksum <= 0;
                udp_checksum <= 0;
                entry_count <= 0;
                state <= Receive;
            end
            default: begin end
        endcase
    end
end

endmodule