/*
把 top 里面的 RGMII 接口接过来，通过某个库转化成 AXI-S 接口
然后交给 io_manager 处理
*/

`timescale 1ns / 1ps

module rgmii_manager(
    input   wire    clk_125M,           // RGMII 和 FIFO 的 125M 时钟
    input   wire    clk_125M_90deg,     // 125M 时钟加 1/4 相位
    input   wire    rst_n,              // PLL分频稳定后为1，后级电路复位，也加入了用户的按键

    // input   wire    clk_btn,            // 硬件 clk 按键
    // input   wire    [3:0] btn,          // 硬件按钮

    // output  wire    [15:0] led_out,     // 硬件 led 指示灯
    // output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    // output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    input   wire    [3:0] eth_rgmii_rd,
    input   wire    eth_rgmii_rx_ctl,
    input   wire    eth_rgmii_rxc,
    output  logic   [3:0] eth_rgmii_td,
    output  logic   eth_rgmii_tx_ctl,
    output  logic   eth_rgmii_txc,

    output reg  [8:0] rx_fifo_din,  
    output wire [8:0] rx_fifo_dout, 
    output wire rx_fifo_empty,      
    output wire rx_fifo_full,       
    output reg  rx_fifo_out_en,     
    output wire rx_fifo_out_busy,   
    output reg  rx_fifo_in_en,      
    output wire rx_fifo_in_busy,    
    output reg  rx_fifo_rst,
    output reg  [1:0] eth_rx_state
);

assign eth_rgmii_txc = clk_125M_90deg;

// 使用一个 async fifo 来将 rxc 时钟域的数据传给 clk_125M 时钟域
// 使用 fwft fifo 模式，因此基本没什么延迟
reg  [8:0] rx_fifo_din;    // 下降沿时，将这一拍的数据写在此处，下一拍上升沿传给 fifo
wire [8:0] rx_fifo_dout;   // 最高位表示 enable，包与包之间必定间隔空数据
wire rx_fifo_empty;        // 队列空
wire rx_fifo_full;         // 队列满
reg  rx_fifo_out_en;       // 激活输出
wire rx_fifo_out_busy;     // 队列输出端口正在复位
reg  rx_fifo_in_en;        // 激活输入
wire rx_fifo_in_busy;      // 队列输入端口正在复位
reg  rx_fifo_rst = 0;      // 复位信号，要求必须在 wr_clk 稳定时同步复位
wire rx_fifo_busy = rx_fifo_out_busy | rx_fifo_in_busy;
xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(9),
    .READ_MODE("fwft"),
    .WRITE_DATA_WIDTH(9)
)
rgmii_rx_fifo (
    .din(rx_fifo_din),
    .dout(rx_fifo_dout),
    .empty(rx_fifo_empty),
    .full(rx_fifo_full),
    .rd_clk(clk_125M),
    .rd_en(rx_fifo_out_en),
    .rd_rst_busy(rx_fifo_out_busy),
    .rst(rx_fifo_rst),
    .wr_clk(eth_rgmii_rxc),
    .wr_en(rx_fifo_in_en),
    .wr_rst_busy(rx_fifo_in_busy)  
);

// 输入端的状态
enum reg[1:0] {
    EthRxReset,     // 复位状态
    EthRxStarting,  // 刚进行了复位，等待 !rx_busy && !eth_rx_ctl
    EthRxWaiting,   // 等待数据到来
    EthRxReading    // 正常接收数据
} eth_rx_state;
// 上升沿时，把 eth_rd 数据放在这里，最高位表示正沿 ctl
reg [4:0] eth_rx_buff;

// 将 rgmii rx 端数据传给 fifo
// todo 处理 full
always_ff @(eth_rgmii_rxc) begin
    if (~rst_n) begin
        eth_rx_state <= EthRxReset;
        eth_rx_buff <= 'x;
        rx_fifo_rst <= 0;
        rx_fifo_in_en <= 0;
    end else begin
        rx_fifo_in_en <= eth_rx_state == EthRxReading;
        rx_fifo_rst <= eth_rx_state == EthRxReset;
        case (eth_rx_state)
            // 之前按下了 rst，此时给 fifo 复位信号，待 fifo 接收到后进入 Starting 状态
            EthRxReset: begin
                eth_rx_buff <= 'x;
                if (rx_fifo_busy) begin
                    eth_rx_state <= EthRxStarting;
                end else begin
                    eth_rx_state <= EthRxReset;
                end
            end
            // 在上升沿将复位信号归零，保证这一拍 fifo 收到了信号
            // 刚刚复位，等待 fifo 准备。如果此时有一个包正在传，则将其丢掉
            EthRxStarting: begin
                eth_rx_buff <= 'x;
                if (eth_rgmii_rxc && !rx_fifo_busy && !eth_rgmii_rx_ctl) begin
                    eth_rx_state <= EthRxWaiting;
                end else begin
                    eth_rx_state <= EthRxStarting;
                end
            end
            // 等待数据
            EthRxWaiting: begin
                eth_rx_buff <= {eth_rgmii_rx_ctl, eth_rgmii_rd};
                if (eth_rgmii_rxc && eth_rgmii_rx_ctl) begin
                    // 上升沿接到数据，下降沿时由 Reading 状态处理数据
                    eth_rx_state <= EthRxReading;
                end else begin
                    eth_rx_state <= EthRxWaiting;
                end
            end
            // 传输数据
            EthRxReading: begin
                if (eth_rgmii_rxc) begin
                    // 上升沿，wr_en 拉高，前一拍的数据已经在下降沿放到 rx_fifo_din 里了
                    // 只用记录当前新数据
                    eth_rx_buff <= {eth_rgmii_rx_ctl, eth_rgmii_rd};
                end else begin
                    // 下降沿，前一拍的数据
                    eth_rx_buff <= 'x;
                    if (!eth_rx_buff[4] || !eth_rgmii_rx_ctl) begin
                        // ctl 在上下沿不全是 1，包结束，发一个空字节
                        rx_fifo_din <= '0;
                    end else begin
                        // 正常记录数据
                        rx_fifo_din <= {1'b1, eth_rgmii_rd, eth_rx_buff[3:0]};
                    end
                end
                // 传输结束
                if (eth_rgmii_rxc && !rx_fifo_din[8] && !eth_rgmii_rx_ctl) begin
                    eth_rx_state <= EthRxWaiting;
                end else begin
                    eth_rx_state <= EthRxReading;
                end
            end
        endcase
    end
end

// 在 clk_125M 时钟域数据出 fifo
enum {
    FifoOutStarting,
    FifoOutSending
} fifo_out_state;

string packet = "";
always_ff @(posedge clk_125M) begin
    if (~rst_n) begin
        fifo_out_state <= FifoOutStarting;
        rx_fifo_out_en <= 0;
    end else begin
        case (fifo_out_state)
            // 等待 fifo 准备
            FifoOutStarting: begin
                if (!rx_fifo_busy) begin
                    fifo_out_state <= FifoOutSending;
                end
            end
            // 正常取出数据
            FifoOutSending: begin
                if (rx_fifo_empty) begin
                    // 无数据
                    rx_fifo_out_en <= 0;
                end else begin
                    rx_fifo_out_en <= 1;
                    if (rx_fifo_dout[8]) begin
                        // 正常的包数据
                        $sformat(packet, "%s %02x", packet, rx_fifo_dout[7:0]);
                    end else begin
                        // 包结束
                        $display(packet);
                        packet = "";
                    end
                end
            end
        endcase
    end
end

endmodule