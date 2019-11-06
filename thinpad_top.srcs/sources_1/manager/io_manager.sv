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
    input   wire    clk_fifo,           // FIFO 时钟
    //input   wire    clk_internal,       // 内部处理逻辑用的时钟
    input   wire    rst_n,              // rstn 逻辑

    // top 硬件
    //input   wire    clk_btn,            // 硬件 clk 按键
    //input   wire    [3:0] btn,          // 硬件按钮
//
    //output  wire    [15:0] led_out,     // 硬件 led 指示灯
    //output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    //output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    // 目前先接上 eth_mac_fifo_block
    input   wire    [7:0] rx_data,      // 数据入口
    input   wire    rx_valid,           // 数据入口正在传输
    output  bit     rx_ready,           // 是否允许数据进入
    input   wire    rx_last,            // 数据传入结束
    output  bit     [7:0] tx_data,      // 数据出口
    output  bit     tx_valid,           // 数据出口正在传输
    input   wire    tx_ready,           // 外面是否准备接收：当前不处理外部不 ready 的逻辑 （TODO）
    output  bit     tx_last,            // 数据传出结束

    output wire [4:0] debug_state,
    output wire [15:0] debug_countdown,
    output wire [5:0] debug_current,
    output wire [5:0] debug_tx,
    output wire [5:0] debug_last,
    output wire [6:0] debug_case
);

reg [511:0] buffer;

reg [5:0] current_pos;
reg [5:0] tx_pos;
reg [5:0] last_pos;
reg [15:0] rx_countdown;

wire [47:0] target_mac = 48'haaaaaaaaaaaa;
wire [2:0] target_vlan;
wire process_complete = start_process;
reg process_bad;
reg reset_process;
reg start_process;

reg process_started;

enum logic [1:0] {
    IP,
    ARP,
    Other
} packet_type;

enum logic [4:0] { 
    Idle,
    Load_Unprocessed_Packet,
    Load_Processing_Packet,
    // Detrailer_Processing_Packet,
    Discard_Packet,
    // Processing_Loaded_Packet, // impossible
    Send_Load_Packet,
    Send_Detrailer_Packet,
    Send_Packet,
    Send_Load_Another_Unprocessed,
    Send_Load_Another_Processing,
    Send_Load_Another_Processed,
    Send_Discard_Another
    //Send_Detrailer_Another,
} state;

// tx_pos - 1
wire [5:0] tx_pos_minus_one = tx_pos - 1;
// 接收完成，还没 last（last 时会设 countdown 为 ffff）
wire rx_complete = rx_countdown == 0;
// 接下来接收的 rx 会是新一个包的开始
wire rx_new = rx_countdown == '1;
// 有缓存的数据可以发送
wire tx_available = tx_pos != last_pos;
// 可以发送的数据仅剩一字节（后面可能还有一个数据包准备发送）
wire tx_one_left = tx_pos_minus_one == last_pos;
// 正在转发 payload，且 payload 未接收完
wire direct_forward = last_pos == 0 && !rx_complete && !rx_new;
// 所有包都已经处理完毕（其实只能有一个包）
wire all_processed = current_pos == 0;
// 应当移动 buffer
wire shifting = rx_valid && !rx_complete;
// rx_countdown 只剩一个字节
wire last_byte = rx_countdown == 1;

task tx_none; begin
    tx_valid <= 0;
    tx_last <= 0;
    if (shifting) begin
        tx_pos <= tx_pos + 1;
        last_pos <= last_pos + 1;
    end
end
endtask

task tx_default; begin
    tx_data <= buffer[8 * tx_pos_minus_one +: 8];
    tx_valid <= 1;
    tx_last <= tx_one_left;
    if (!shifting) begin
        tx_pos <= tx_pos_minus_one;
    end
end
endtask

task tx_no_last; begin
    tx_data <= buffer[8 * tx_pos_minus_one +: 8];
    tx_valid <= 1;
    tx_last <= 0;
    if (!shifting) begin
        tx_pos <= tx_pos_minus_one;
    end
end
endtask

task rx_default; begin
    buffer <= {buffer[0 +: 504], rx_data};
    current_pos <= current_pos + 1;
    last_pos <= last_pos + 1;
    rx_countdown <= rx_countdown - 1;
end
endtask

task rx_keep_pos; begin
    buffer <= {buffer[0 +: 504], rx_data};
    rx_countdown <= rx_countdown - 1;
end
endtask

// 此时的 ARP 帧应该对齐 buffer 末尾
task process_arp; begin
    case (buffer[368`ETH_VLAN_ID])
        1: begin
            if (buffer[368`ARP_DST_IP] == `ROUTER_IP_1) begin
                buffer[368`ETH_DST_MAC] = buffer[368`ETH_SRC_MAC];
                buffer[368`ETH_SRC_MAC] = `ROUTER_MAC_1;
                buffer[368`ARP_DST_MAC] = buffer[368`ARP_SRC_MAC];
                buffer[368`ARP_DST_IP] = buffer[368`ARP_SRC_IP];
                buffer[368`ARP_SRC_MAC] = `ROUTER_MAC_1;
                buffer[368`ARP_SRC_IP] = `ROUTER_IP_1;
            end else begin
                process_bad <= 1;
            end
        end
        2: begin
            if (buffer[368`ARP_DST_IP] == `ROUTER_IP_2) begin
                buffer[368`ETH_DST_MAC] = buffer[368`ETH_SRC_MAC];
                buffer[368`ETH_SRC_MAC] = `ROUTER_MAC_2;
                buffer[368`ARP_DST_MAC] = buffer[368`ARP_SRC_MAC];
                buffer[368`ARP_DST_IP] = buffer[368`ARP_SRC_IP];
                buffer[368`ARP_SRC_MAC] = `ROUTER_MAC_2;
                buffer[368`ARP_SRC_IP] = `ROUTER_IP_2;
            end else begin
                process_bad <= 1;
            end
        end
        3: begin
            if (buffer[368`ARP_DST_IP] == `ROUTER_IP_3) begin
                buffer[368`ETH_DST_MAC] = buffer[368`ETH_SRC_MAC];
                buffer[368`ETH_SRC_MAC] = `ROUTER_MAC_3;
                buffer[368`ARP_DST_MAC] = buffer[368`ARP_SRC_MAC];
                buffer[368`ARP_DST_IP] = buffer[368`ARP_SRC_IP];
                buffer[368`ARP_SRC_MAC] = `ROUTER_MAC_3;
                buffer[368`ARP_SRC_IP] = `ROUTER_IP_3;
            end else begin
                process_bad <= 1;
            end
        end
        4: begin
            if (buffer[368`ARP_DST_IP] == `ROUTER_IP_4) begin
                buffer[368`ETH_DST_MAC] = buffer[368`ETH_SRC_MAC];
                buffer[368`ETH_SRC_MAC] = `ROUTER_MAC_4;
                buffer[368`ARP_DST_MAC] = buffer[368`ARP_SRC_MAC];
                buffer[368`ARP_DST_IP] = buffer[368`ARP_SRC_IP];
                buffer[368`ARP_SRC_MAC] = `ROUTER_MAC_4;
                buffer[368`ARP_SRC_IP] = `ROUTER_IP_4;
            end else begin
                process_bad <= 1;
            end
        end
        default: begin
            process_bad <= 1;
        end
    endcase
end
endtask

// 预处理 IP 帧，此时帧应该对齐 buffer 末尾
task preprocess_ip; begin
    if (buffer[304`IP_TTL] != 0 && (
        (buffer[304`ETH_DST_MAC] == `ROUTER_MAC_1 &&
         buffer[304`ETH_VLAN_ID] == 1) ||
        (buffer[304`ETH_DST_MAC] == `ROUTER_MAC_2 &&
         buffer[304`ETH_VLAN_ID] == 2) ||
        (buffer[304`ETH_DST_MAC] == `ROUTER_MAC_3 &&
         buffer[304`ETH_VLAN_ID] == 3) ||
        (buffer[304`ETH_DST_MAC] == `ROUTER_MAC_4 &&
         buffer[304`ETH_VLAN_ID] == 4)
    )) begin
        buffer[304`IP_TTL] = buffer[304`IP_TTL] - 1;
        if (buffer[304`IP_CHECKSUM] >= 16'hfeff) begin
            buffer[304`IP_CHECKSUM] = buffer[304`IP_CHECKSUM] + 16'h101;
        end else begin
            buffer[304`IP_CHECKSUM] = buffer[304`IP_CHECKSUM] + 16'h100;
        end
    end else begin
        process_bad <= 1;
    end
end
endtask

// 用处理结果修改帧（IP 包）
task apply_ip_process; begin
    $display("%t applying", $realtime);
    buffer[(8 * current_pos)`ETH_DST_MAC] = target_mac;
    buffer[(8 * current_pos)`ETH_VLAN_ID] = target_vlan;
end
endtask

assign rx_ready = tx_ready;

task get_idle; begin
    current_pos <= 0;
    last_pos <= 0;
    tx_pos <= 0;
    reset_process <= 1;
    start_process <= 0;
    process_bad <= 0;
    rx_countdown <= '1;
    state <= Idle;
end
endtask

always_ff @(posedge clk_fifo) begin
    if (!rst_n) begin
        // reset
        get_idle();
        tx_valid <= 0;
        tx_last <= 0;
    end else begin
        unique casez ({state,
            rx_valid, rx_last, tx_ready,
            last_byte, process_complete, process_bad,
            tx_available
        })
            /******************************
             * Idle
             * 空闲，遇到包转 LUP
             *****************************/
            {Idle, 7'b00?_???_?}: begin
                tx_none();
            end
            {Idle, 7'b10?_???_?}: begin
                tx_none();
                rx_default();
                state <= Load_Unprocessed_Packet;
            end
            /******************************
             * Load Unprocessed Packet
             * 加载包，到一定长度开始处理
             * rx 一定不会 last 或 complete
             *****************************/
            {Load_Unprocessed_Packet, 7'b00?_???_0}: begin
                tx_none();
            end
            {Load_Unprocessed_Packet, 7'b10?_???_0}: begin
                case (current_pos)
                    // 22: 确定了包的大小
                    22: begin
                        tx_none();
                        buffer <= {buffer[0 +: 504], rx_data};
                        current_pos <= current_pos + 1;
                        last_pos <= last_pos + 1;
                        case (buffer[32 +: 16])
                            16'h0806: begin
                                packet_type <= ARP;
                                rx_countdown <= 37;
                            end
                            16'h0800: begin
                                packet_type <= IP;
                                if (buffer[0 +: 16] > 42) begin
                                    rx_countdown <= buffer[0 +: 16] - 5;
                                end else begin
                                    rx_countdown <= 37;
                                end
                            end
                            default: begin
                                packet_type <= Other;
                                rx_countdown <= 37;
                            end
                        endcase
                    end
                    // 开始处理 IP 包
                    38: begin
                        if (packet_type == IP) begin
                            preprocess_ip();
                            // todo process
                            start_process <= 1;
                            reset_process <= 0;
                            state <= Load_Processing_Packet;
                        end
                        tx_none();
                        rx_default();
                    end
                    // 处理 ARP 包
                    46: begin
                        tx_valid <= 0;
                        tx_last <= 0;
                        tx_pos <= tx_pos + 1;
                        if (packet_type == ARP) begin
                            process_arp();
                            rx_keep_pos();
                            current_pos = 0;
                            last_pos = 0;
                            state <= Send_Load_Packet;
                        end else begin
                            // 不是 ARP 就是无法处理的包，丢弃
                            state <= Discard_Packet;
                        end
                    end
                    default: begin
                        tx_none();
                        rx_default();
                    end
                endcase
            end
            /******************************
             * Load Processing Packet
             * 加载包，且在处理
             * rx 一定不会 last 或 complete
             *****************************/
            {Load_Processing_Packet, 7'b00?_000_0}: begin
                start_process <= 0;
                tx_none();
            end
            {Load_Processing_Packet, 7'b?0?_0?1_0}: begin
                // 坏包
                start_process <= 0;
                tx_none();
                state <= Discard_Packet;
            end
            {Load_Processing_Packet, 7'b?0?_010_0}: begin
                // 处理完成
                start_process <= 0;
                reset_process <= 1;
                apply_ip_process();
                current_pos = 0;
                last_pos = 0;
                tx_none();
                state <= Send_Load_Packet;
                if (rx_valid)
                    rx_keep_pos();
            end
            {Load_Processing_Packet, 7'b10?_000_0}: begin
                // 继续加载，继续处理
                start_process <= 0;
                tx_none();
                rx_default();
            end
            /******************************
             * Discard Packet
             * 丢包，忽略一切，直到 rx_last
             *****************************/
            {Discard_Packet, 7'b?0?_????}: begin
                tx_none();
            end
            {Discard_Packet, 7'b11?_????}: begin
                get_idle();
            end
            /******************************
             * Send Load Packet
             * 发送包且该包未接收完
             * 接收完转 SDP
             *****************************/
            {Send_Load_Packet, 7'b001_???0},
            {Send_Load_Packet, 7'b000_????}: begin
                // 无可发送数据 或 tx_ready = 0
                tx_none();
            end
            {Send_Load_Packet, 7'b001_???1}: begin
                // 从缓冲区里面发送已处理的数据，同时等待更多输入
                tx_data <= buffer[8 * tx_pos_minus_one +: 8];
                tx_valid <= 1;
                tx_last <= 0;
                tx_pos <= tx_pos - 1;
            end
            {Send_Load_Packet, 7'b10?_???1}: begin
                // 从缓冲区里面发送已处理的数据，同时有新数据进入
                rx_keep_pos();
                tx_no_last();
                if (last_byte) begin
                    state <= Send_Detrailer_Packet;
                end
            end
            {Send_Load_Packet, 7'b10?_???0}: begin
                // 缓冲区已空，接一个发一个
                tx_data <= rx_data;
                tx_valid <= 1;
                tx_last <= last_byte;
                if (last_byte) begin
                    // 没有该发的了，丢弃 trailer
                    state <= Discard_Packet;
                end
            end
            /******************************
             * Send Detrailer Packet
             * 从缓冲区发送
             * 同时丢弃输入直到 rx_last
             *****************************/
            {Send_Detrailer_Packet, 7'b000_????}: begin
                // tx_ready = 0
                tx_none();
            end
            {Send_Detrailer_Packet, 7'b??1_????}: begin
                tx_default();
                if (tx_one_left) begin
                    if (rx_valid && rx_last) begin
                        // 发完同时 last
                        get_idle();
                    end else begin
                        // 发完，剩余 Trailer
                        state <= Discard_Packet;
                    end
                end else if (rx_valid && rx_last) begin
                    // last 但未发完
                    rx_countdown <= '1;
                    current_pos <= 0;
                    last_pos <= 0;
                    state <= Send_Packet;
                end
            end
            /******************************
             * Send Packet
             * 从缓冲区发送
             * 同时等待新的包进入
             *****************************/
            {Send_Packet, 7'b000_???_?}: begin
                tx_none();
            end
            {Send_Packet, 7'b001_???_?}: begin
                tx_default();
                if (tx_one_left) begin
                    // 发完了
                    get_idle();
                end
            end
            {Send_Packet, 7'b101_???_?}: begin
                tx_default();
                rx_default();
                if (tx_one_left) begin
                    // 发完了
                    state <= Load_Unprocessed_Packet;
                end else begin
                    state <= Send_Load_Another_Unprocessed;
                end
            end
            /******************************
             * Send Load Another Unprocessed
             * 从缓冲区发送前一个包
             * 同时收取后一个未处理包
             *****************************/
            {Send_Load_Another_Unprocessed, 7'b000_000_1}: begin
                tx_none();
            end
            {Send_Load_Another_Unprocessed, 7'b001_000_1}: begin
                tx_default();
                if (tx_one_left) begin
                    // 前一个包发送完毕
                    state <= Load_Unprocessed_Packet;
                end
            end
            {Send_Load_Another_Unprocessed, 7'b101_000_1}: begin
                tx_default();
                case (current_pos)
                    // 22: 确定了包的大小
                    22: begin
                        buffer <= {buffer[0 +: 504], rx_data};
                        current_pos <= current_pos + 1;
                        last_pos <= last_pos + 1;
                        case (buffer[32 +: 16])
                            16'h0806: begin
                                packet_type <= ARP;
                                rx_countdown <= 37;
                            end
                            16'h0800: begin
                                packet_type <= IP;
                                if (buffer[0 +: 16] > 42) begin
                                    rx_countdown <= buffer[0 +: 16] - 5;
                                end else begin
                                    rx_countdown <= 37;
                                end
                            end
                            default: begin
                                packet_type <= Other;
                                rx_countdown <= 37;
                            end
                        endcase
                        if (tx_one_left) begin
                            state <= Load_Unprocessed_Packet;
                        end
                    end
                    // 开始处理 IP 包
                    38: begin
                        if (packet_type == IP) begin
                            preprocess_ip();
                            // todo process
                            start_process <= 1;
                            reset_process <= 0;
                            if (tx_one_left) begin
                                state <= Load_Processing_Packet;
                            end else begin
                                state <= Send_Load_Another_Processing;
                            end
                        end else begin
                            if (tx_one_left) begin
                                state <= Load_Unprocessed_Packet;
                            end
                        end
                        rx_default();
                    end
                    // 处理 ARP 包
                    46: begin
                        if (packet_type == ARP) begin
                            process_arp();
                            rx_keep_pos();
                            current_pos <= 0;
                            last_pos <= last_pos + 1;
                            if (tx_one_left) begin
                                state <= Send_Load_Packet;
                            end else begin
                                state <= Send_Load_Another_Processed;
                            end
                        end else begin
                            // 不是 ARP 就是无法处理的包，丢弃
                            if (tx_one_left) begin
                                state <= Discard_Packet;
                            end else begin
                                state <= Send_Discard_Another;
                            end
                        end
                    end
                    default: begin
                        rx_default();
                        if (tx_one_left) begin
                            state <= Load_Unprocessed_Packet;
                        end
                    end
                endcase
            end
            /******************************
             * Send Load Another Processing
             * 从缓冲区发送前一个包
             * 同时收取后一个处理中的包
             * rx 一定不会 last 或 complete
             *****************************/
            {Send_Load_Another_Processing, 7'b000_0??_1}: begin
                // tx_ready = 0
                start_process <= 0;
                tx_none();
                if (process_bad) begin
                    state <= Send_Discard_Another;
                end
            end
            {Send_Load_Another_Processing, 7'b?01_000_1}: begin
                // 处理中
                start_process <= 0;
                tx_default();
                if (rx_valid) begin
                    rx_default();
                end
                if (tx_one_left) begin
                    // 发送完
                    state <= Load_Processing_Packet;
                end
            end
            {Send_Load_Another_Processing, 7'b?01_0?1_1}: begin
                // bad
                start_process <= 0;
                tx_default();
                if (tx_one_left) begin
                    // 发送完
                    state <= Discard_Packet;
                end else begin
                    state <= Send_Discard_Another;
                end
            end
            {Send_Load_Another_Processing, 7'b?01_010_1}: begin
                // 处理完毕
                start_process <= 0;
                reset_process <= 1;
                apply_ip_process();
                tx_default();
                if (tx_one_left) begin
                    // 发送完
                    current_pos = 0;
                    last_pos = 0;
                    state <= Send_Load_Packet;
                    if (rx_valid)
                        rx_keep_pos();
                end else begin
                    current_pos <= 0;
                    state <= Send_Load_Another_Processed;
                    if (rx_valid) begin
                        rx_keep_pos();
                        last_pos <= last_pos + 1;
                    end
                end
            end
            /******************************
             * Send Load Another Processed
             * 前一个包还未发完，当前包处理完
             *****************************/
            {Send_Load_Another_Processed, 7'b000_???_1}: begin
                // tx_ready = 0
                tx_none();
            end
            {Send_Load_Another_Processed, 7'b001_???_1}: begin
                // 从缓冲区里面发送已处理的数据，同时等待更多输入
                tx_default();
                if (tx_one_left) begin
                    state <= Send_Load_Packet;
                end
            end
            {Send_Load_Another_Processed, 7'b10?_0??_1}: begin
                // 从缓冲区里面发送已处理的数据，同时有新数据进入
                rx_keep_pos();
                tx_default();
                if (tx_one_left) begin
                    state <= Send_Load_Packet;
                    last_pos <= 0;
                end else begin
                    last_pos <= last_pos + 1;
                end
            end
            /******************************
             * Send Discard Another
             * 前一个包还未发完，当前包要丢掉
             *****************************/
            {Send_Discard_Another, 7'b000_???_?}: begin
                tx_none();
            end
            {Send_Discard_Another, 7'b?01_???_?}: begin
                tx_default();
                if (tx_one_left) begin
                    state <= Discard_Packet;
                end
            end
            default: begin
                $display("!!!%x %d%d%d%d%d%d%d", state,
            rx_valid, rx_last, tx_ready,
            last_byte, process_complete, process_bad,
            tx_available);
            end
        endcase
    end
end


assign debug_state = state;
assign debug_countdown = rx_countdown;
assign debug_current = current_pos;
assign debug_tx = tx_pos;
assign debug_last = last_pos;
assign debug_case = {
    rx_valid, rx_last, tx_ready,
    last_byte, process_complete, process_bad,
    tx_available
};

endmodule