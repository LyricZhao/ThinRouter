/*
把 RGMII 的接口封装成在 clk_125M 下的（不一定连续）输入和连续输出接口
*/

`timescale 1ns / 1ps

module rgmii_manager(
    input   wire    clk_125M,           // RGMII 和 FIFO 的 125M 时钟
    input   wire    clk_125M_90deg,     // 125M 时钟加 1/4 相位
    input   wire    rst_n,              // PLL分频稳定后为1，后级电路复位，也加入了用户的按键

    // RGMII 的 rx 端
    input   wire    [3:0] eth_rgmii_rd,
    input   wire    eth_rgmii_rx_ctl,
    input   wire    eth_rgmii_rxc,

    // 封装后的 rx 端
    output  logic   [7:0] rx_data,
    output  logic   rx_valid,
    output  logic   rx_pause,

    // RGMII 的 tx 端
    output  logic   [3:0] eth_rgmii_td,
    output  logic   eth_rgmii_tx_ctl,
    output  logic   eth_rgmii_txc,

    // 封装后的 tx 端
    input   wire    [7:0] tx_data,
    input   wire    tx_valid
);

assign eth_rgmii_txc = clk_125M_90deg;

// 上下沿的 rgmii ctl
wire rx_ctl_posedge;
wire rx_ctl_negedge;
reg  tx_ctl_posedge;
reg  tx_ctl_negedge;

// fifo 的接口
wire [8:0] rx_fifo_din;
wire [8:0] rx_fifo_dout;
wire rx_fifo_empty;         // 队列空
wire rx_fifo_full;          // 队列满
wire rx_fifo_out_en;        // 激活输出
wire rx_fifo_out_busy;      // 队列输出端口正在复位
wire rx_fifo_in_en;         // 激活输入
wire rx_fifo_in_busy;       // 队列输入端口正在复位
reg  rx_fifo_rst = 0;       // 复位信号，要求必须在 wr_clk 稳定时同步复位
reg  rx_fifo_ready = 0;     // fifo 可用：复位后等到 !busy 且无数据进入时置 1
reg  last_in_valid = 0;     // 上一拍的 rx 是否有效，如果有效且这一拍无效，则向 fifo 中插入一个空字段表示结束
reg  last_empty = 0;        // 上一拍是否 empty，在不 empty 的第一拍先不读取数据

always_latch begin
    if (rx_fifo_rst || rx_fifo_in_busy || rx_fifo_out_busy) begin
        rx_fifo_ready = 0;
    end else if (!rx_ctl_posedge && !rx_ctl_negedge && rst_n) begin
        rx_fifo_ready = 1;
    end
end

always_ff @(posedge eth_rgmii_rxc) begin
    last_in_valid <= rx_ctl_posedge && rx_ctl_negedge;
end

always_ff @(posedge clk_125M) begin
    last_empty <= rx_fifo_empty;
end

// maybe todo 添加 fifo 的 rst
assign rx_fifo_out_en = !rx_fifo_empty && !last_empty;
assign rx_data = rx_fifo_dout[7:0];
assign rx_valid = rx_fifo_out_en && rx_fifo_dout[8];
assign rx_pause = rx_fifo_empty && rx_fifo_dout[8];
// rx_fifo_din[7:0] 用 IDDR 映射
assign rx_fifo_din[8] = rx_ctl_posedge && rx_ctl_negedge;
assign rx_fifo_in_en = (rx_ctl_posedge && rx_ctl_negedge) || last_in_valid;
assign tx_ctl_posedge = tx_valid;
assign tx_ctl_negedge = tx_valid;

/****************************************
 * 将 rgmii 的上下沿数据映射到两倍位宽的变量中
 * rx_ctl_posedge
 * rx_ctl_negedge
 * [7:0] rx_fifo_din
 * tx_ctl_posedge
 * tx_ctl_negedge
 * [7:0] tx_data
 ***************************************/
// rgmii ctl 的映射
IDDR rx_ctl_iddr (
    .Q1(rx_ctl_posedge),
    .Q2(rx_ctl_negedge),
    .C(eth_rgmii_rxc),
    .CE(1),
    .D(eth_rgmii_rx_ctl),
    .R(~rst_n),
    .S(0)
);
ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE")
) tx_ctl_oddr (
    .Q(eth_rgmii_tx_ctl),
    .C(clk_125M),
    .CE(1),
    .D1(tx_ctl_posedge),
    .D2(tx_ctl_negedge),
    .R(~rst_n),
    .S(0)
);

// 将 4 位的 eth_rgmii_rd 转换为 8 位的 rx_fifo_din
// 将 8 位的 tx_data 转换为 4 位的 eth_rgmii_td
genvar i;
generate for (i = 0; i < 4; i++) begin
    IDDR rx_data_iddr (
        .Q1(rx_fifo_din[i]),
        .Q2(rx_fifo_din[i + 4]),
        .C(eth_rgmii_rxc),
        .CE(1),
        .D(eth_rgmii_rd[i]),
        .R(~rst_n),
        .S(0)
    );
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE")
    ) tx_data_oddr (
        .Q(eth_rgmii_td[i]),
        .C(clk_125M),
        .CE(1),
        .D1(tx_data[i]),
        .D2(tx_data[i + 4]),
        .R(~rst_n),
        .S(0)
    );
end
endgenerate

// 使用一个 async fifo 来将 rxc 时钟域的数据传给 clk_125M 时钟域
// 使用 fwft fifo 模式，因此基本没什么延迟

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

endmodule