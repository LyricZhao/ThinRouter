/*
涂轶翔：
通过自动机实现数据的处理，负责所有数据的输入输出，IO 使用 AXI-S 接口
接收数据后展开，然后交给 packet_manager 处理，处理后再输出

赵成钢：
*/

`timescale 1ns / 1ps

`include "debug.vh"

module io_manager (
    // 由父模块提供各种时钟
    input   wire    clk_io,             // IO 时钟
    input   wire    clk_internal,       // 内部处理逻辑用的时钟
    input   wire    rst_n,              // rstn 逻辑

    // top 硬件
    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0] led_out,     // 硬件 led 指示灯
    output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    output  wire    [7:0]  digit1_out,  // 硬件高位数码管

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

// packet_manager 的 led 信号
wire [15:0] pm_led;
wire [7:0]  pm_digit0;
wire [7:0]  pm_digit1;

// 接收数据用
bit  packet_arrive;     // 提供给 packet_manager 的一拍信号，表示收到一个新的包
bit  [367:0] frame_in;  // 将收到的数据包从高位往低位存储
byte bytes_read;        // 已经接受的字节数

// packet_manager 的输出
wire bad;               // packet_manager 在解析时随时可能置 1，此时应转丢包逻辑
wire [367:0] frame_out; // packet_manager 处理后的需要发走的包
wire out_ready;         // packet_manager 处理完成信号
byte out_bytes;         // packet_manager 处理完成后，表示需要从 frame_out 发送多少字节
wire require_direct_fw; // packet_manager 表示需要在接受了 direct_fw_offset 字节后暂停，后续的 IP 包 data 部分不走那里，直接转发
byte direct_fw_offset;  // 
int  fw_bytes;          // 需要直接转发的字节数

// 状态
enum logic[2:0] {
    Idle,               // 空闲，遇到 rx_valid 转下一条
    Reading,            // 正在接收，等待 packet_manager 的 require_direct_fw 或者 rx_last，转下一条
    Waiting,            // 等待 packet_manager 处理完，之后转下一条
    Sending,            // 发送 packet_manager 处理后的新网帧
    Forwarding,         // 连接 rx tx 转发 IP 包的 data
    Discarding          // 丢包（或者是丢弃掉 trailer），等到 rx_last 转 Idle
} state;

// 处理状态用到的变量
byte bytes_sent;        // Sending 下，已经从 packet_manager 的 frame_out 发送的字节数
int  bytes_forwarded;   // Forwarding 下，已经转发的字节数（只用于 IP 包的 data 部分）
bit  packet_ended;      // 当前处理的包已经 last

packet_manager packet_manager_inst (
    .clk_internal(clk_internal),

    .rst_n(rst_n),
    .clk_btn(clk_btn),
    .btn(btn),
    .led_out(pm_led),
    .digit0_out(pm_digit0),
    .digit1_out(pm_digit1),

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

// 驱动 rx_ready 信号
always_comb 
case (state)
    Idle, Reading, Discarding: 
        rx_ready = 1;
    Waiting, Sending: 
        rx_ready = 0;
    Forwarding:
        rx_ready = tx_ready;
endcase

always_ff @ (posedge clk_io) begin
    // 初始化
    if (~rst_n) begin
        // 收包变量
        packet_arrive <= 0;
        bytes_read <= 0;
        // 处理逻辑变量
        state <= Idle;
        bytes_sent <= 0;
        bytes_forwarded <= 0;
        packet_ended <= 0;
        // 输出信号
        tx_last <= 0;
        tx_valid <= 0;
    end else begin
        case(state)
            Idle: begin
                tx_last <= 0;
                tx_valid <= 0;
                if (rx_valid) begin
                    // 状态
                    state <= Reading;
                    packet_arrive <= 1;
                    // 记录当前收到的字节
                    frame_in[367 -: 8] <= rx_data;
                    bytes_read <= 1;
                    // 变量清零
                    bytes_sent <= 0;
                    bytes_forwarded <= 0;
                    packet_ended <= 0;
                end
            end

            Reading: begin
                // 持续接收数据
                packet_arrive <= 0;
                if (bad) begin
                    if (packet_ended || (rx_valid && rx_last)) begin
                        state <= Idle;
                    end else begin
                        $write("Discarding... ");
                        state <= Discarding;
                    end
                end else if (rx_valid) begin
                    frame_in[367 - bytes_read * 8 -: 8] <= rx_data;
                    bytes_read <= bytes_read + 1;
                    // 收到 last 后，暂停等待处理
                    if (rx_last) begin
                        packet_ended <= 1;
                        $write("frame_in completed\n\t");
                        `DISPLAY_BITS(frame_in, 367, 360 - bytes_read * 8);
                        state <= Waiting;
                    // 或者到达 IP 包 data 前了，也暂停等待处理
                    end else if (bytes_read == 45 || (require_direct_fw && bytes_read + 1 == direct_fw_offset)) begin
                        $write("IP header completed\n\t");
                        `DISPLAY_BITS(frame_in, 367, 360 - bytes_read * 8);
                        state <= Waiting;
                    end
                end
            end

            Waiting: begin
                // 此时 rx_ready 为 0
                if (bad) begin
                    if (packet_ended) begin
                        state <= Idle;
                    end else begin
                        $write("Discarding... ");
                        state <= Discarding;
                    end
                end else if (out_ready) begin
                    $write("frame_out ready, sending...\n\t");
                    state <= Sending;
                end
            end

            Sending: begin
                // 此时 rx_ready = 0，out_ready = 1，bad = 0
                if (tx_ready) begin
                    $write("%2x ", frame_out[367 - bytes_sent * 8 -: 8]); 
                    tx_data <= frame_out[367 - bytes_sent * 8 -: 8];
                    tx_valid <= 1;
                    bytes_sent <= bytes_sent + 1;
                    if (bytes_sent + 1 == out_bytes) begin
                        // packet_manager 的部分转发完成（还可能有 data）
                        if (require_direct_fw) begin
                            $write("\nand forwarding...\n\t");
                            state <= Forwarding;
                        end else begin
                            $display("LAST");
                            tx_last <= 1;
                            state <= Idle;
                        end
                    end
                end else begin
                    tx_valid <= 0;
                    tx_last <= 0;
                end
            end

            Forwarding: begin
                if (rx_valid) begin
                    if (bytes_forwarded == fw_bytes) begin
                        // 如果已经转发了应当转发的数量，剩下的应当丢弃
                        tx_valid <= 0;
                        if (rx_last) begin
                            state <= Idle;
                        end else
                            state <= Discarding;
                    end else begin
                        bytes_forwarded <= bytes_forwarded + 1;
                        $write("%2x ", rx_data);
                        tx_data <= rx_data;
                        tx_valid <= 1;
                        if (rx_last) begin
                            // 如果遇到 rx_last 则必须立即停止
                            $display("LAST (EOP)");
                            tx_last <= 1;
                            state <= Idle;
                        end else begin
                            // data 包转发完毕发 last，转 Discarding
                            if (bytes_forwarded + 1 == fw_bytes) begin
                                $display("LAST");
                                tx_last <= 1;
                                packet_ended <= 1;
                                state <= Discarding;
                            end
                        end
                    end
                end else begin
                    // 如果 rx_valid = 0
                    tx_valid <= 0;
                    tx_last <= 0;
                end
            end

            Discarding: begin
                if (rx_valid && rx_last) begin
                    $display("complete");
                    state <= Idle;
                end
            end

            default: begin
            end
        endcase
    end
end

/*************
 * debug 信号
 ************/

// assign led_out = pm_led;
// assign digit0_out = pm_digit0;
// assign digit1_out = pm_digit1;
bit debug_incoming_signal;
bit debug_discard_signal;
bit debug_send_signal;
always_ff @ (posedge clk_internal) begin
    debug_incoming_signal <= state == Reading;
    debug_discard_signal <= bad;
    debug_send_signal <= state == Sending;
end

// 收到数据包显示在 led
led_loop debug_incoming (
    .clk(debug_incoming_signal),
    .led(led_out)
);

// 正常发包显示在高位数码管
digit_loop debug_send (
    .clk(debug_send_signal),
    .digit(digit1_out)
);

// 丢包显示在低位数码管
digit_loop debug_discard (
    .clk(debug_discard_signal),
    .digit(digit0_out)
);

endmodule