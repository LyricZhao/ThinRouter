/*
涂轶翔：
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出
*/

`include "debug.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_io,             // IO 时钟
    input   wire    clk_internal,       // 内部处理逻辑用的时钟

    // top 中的 reset 按钮
    input   wire    rst,

    // 目前先接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  bit     rx_ready,           // 是否允许数据进入
    input   wire    rx_last,            // 数据传入结束
    output  bit     [7:0] tx_data,      // 数据出口
    output  bit     tx_valid,           // 数据出口正在传输
    input   wire    tx_ready,           // 外面是否准备接收：当前不处理外部不 ready 的逻辑 （TODO）
    output  bit     tx_last             // 数据传出结束
);

bit packet_arrive;
bit [367:0] frame_in;
byte bytes_read;
wire bad;
wire [367:0] frame_out;
wire out_ready;
byte out_bytes;
wire require_direct_fw;
byte direct_fw_offset;
int fw_bytes;

packet_manager packet_manager_inst (
    .clk(clk_internal),
    .rst(rst),

    .packet_arrive(packet_arrive),

    .frame_in(frame_in),
    .bytes_read(bytes_read),

    .bad(bad),

    .frame_out(frame_out),
    .out_ready(out_ready),
    .out_bytes(out_bytes),

    .require_direct_fw(require_direct_fw),
    .direct_fw_offset(direct_fw_offset),
    .fw_bytes(fw_bytes)
);

enum {
    Idle,       // 空闲
    Reading,    // 正在接收
    Waiting,    // 等待 packet_manager 处理完
    Sending,    // 发送 packet_manager 处理后的新网帧
    Forwarding  // 连接 rx tx 转发 IP 包的 data
} state;

byte bytes_sent;
int bytes_forwarded;

// 控制 rx_ready 信号
always_comb 
case (state)
    Idle, Reading: 
        rx_ready = 1;
    Waiting, Sending: 
        rx_ready = 0;
    Forwarding:
        rx_ready = tx_ready;
endcase

always_ff @ (posedge clk_io or posedge rst) begin
    // 初始化
    if (rst) begin
        packet_arrive <= 0;
        bytes_read <= 0;
        bytes_sent <= 0;
        bytes_forwarded <= 0;
        state <= Idle;
        tx_last <= 0;
        tx_valid <= 0;
    end else begin
        case(state)
            Idle: begin
                tx_last <= 0;
                tx_valid <= 0;
                if (rx_valid) begin
                    state <= Reading;
                    frame_in[367 -: 8] <= rx_data;
                    bytes_read <= 1;
                    packet_arrive <= 1;
                    bytes_sent <= 0;
                    bytes_forwarded <= 0;
                end
            end
            Reading: begin
                // 持续接收数据
                packet_arrive <= 0;
                if (rx_valid) begin
                    frame_in[367 - bytes_read * 8 -: 8] <= rx_data;
                    bytes_read <= bytes_read + 1;
                    // 收到 last 后，或到达 data 部分时，暂停等待处理
                    if (rx_last || (require_direct_fw && bytes_read + 1 == direct_fw_offset)) begin
                        $write("frame_in ready\n\t");
                        `DISPLAY_BITS(frame_in, 367, 360 - bytes_read * 8);
                        state <= Waiting;
                    end
                end
            end
            Waiting: begin
                // packet_manager 处理完后转 Sending
                if (out_ready) begin
                    $write("frame_out ready, sending...\n\t");
                    state <= Sending;
                end
            end
            Sending: begin
                if (tx_ready) begin
                    $write("%2x ", frame_out[367 - bytes_sent * 8 -: 8]); 
                    tx_data <= frame_out[367 - bytes_sent * 8 -: 8];
                    tx_valid <= 1;
                    bytes_sent <= bytes_sent + 1;
                    if (bytes_sent + 1 == out_bytes) begin
                        // packet_manager 的部分转发完成（还可能有 data）
                        if (require_direct_fw) begin
                            $write("\nforwarding...\n\t");
                            state <= Forwarding;
                        end else begin
                            $display("LAST");
                            tx_last <= 1;
                            state <= Idle;
                        end
                    end
                end
            end
            Forwarding: begin
                if (rx_valid) begin
                    bytes_forwarded <= bytes_forwarded + 1;
                    // 只当长度小于 header 给定的 data 长度时转发
                    if (bytes_forwarded < fw_bytes) begin
                        $write("%2x ", rx_data);
                        tx_data <= rx_data;
                        tx_valid <= 1;
                    end else begin
                        tx_valid <= 0;
                    end
                    // data 包转发完毕（或 rx_last）发 last（但是 rx 中可能还存在 trailer）
                    if (bytes_forwarded + 1 == fw_bytes) begin
                        tx_last <= 1;
                        $display("LAST");
                    end
                    if (rx_last) begin
                        tx_last <= 1;
                        state <= Idle;
                    end
                end else
                    tx_valid <= 0;
                    tx_last <= 0;
            end
        endcase
    end
end

endmodule