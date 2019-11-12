`timescale 1ns / 1ps
`default_nettype none
module testbench_rgmii ();

wire [3:0] rgmii_rd;
wire rgmii_rx_ctl;
wire rgmii_rxc;
rgmii_model rgmii_model_inst (
    .rgmii_rd,
    .rgmii_rx_ctl,
    .rgmii_rxc
);

bit clk_125M;
bit clk_125M_90deg;
bit rst_n;
wire [3:0] eth_rgmii_td;
wire eth_rgmii_tx_ctl;
wire eth_rgmii_txc;

wire [8:0] rx_fifo_din;    // 下降沿时，将这一拍的数据写在此处，下一拍上升沿传给 fifo
wire [8:0] rx_fifo_dout;   // 最高位表示 enable，包与包之间必定间隔空数据
wire rx_fifo_empty;        // 队列空
wire rx_fifo_full;         // 队列满
wire rx_fifo_out_en;       // 激活输出
wire rx_fifo_out_busy;     // 队列输出端口正在复位
wire rx_fifo_in_en;        // 激活输入
wire rx_fifo_in_busy;      // 队列输入端口正在复位
wire rx_fifo_rst;      // 复位信号，要求必须在 wr_clk 稳定时同步复位
wire [1:0] eth_rx_state;
rgmii_manager rgmii_manager_inst (
    .clk_125M(clk_125M),
    .clk_125M_90deg(clk_125M_90deg),
    .rst_n(rst_n),
    .eth_rgmii_rd(rgmii_rd),
    .eth_rgmii_rx_ctl(rgmii_rx_ctl),
    .eth_rgmii_rxc(rgmii_rxc),
    .eth_rgmii_td(eth_rgmii_td),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl),
    .eth_rgmii_txc(eth_rgmii_txc),
    .*
);

initial begin
    #0.123;
    clk_125M = 0;
    forever clk_125M = #3.99 ~clk_125M;
end
initial begin
    #2.312;
    clk_125M_90deg = 0;
    forever clk_125M_90deg = #3.99 ~clk_125M_90deg;
end
initial begin
    rst_n = 0;
    rst_n = #1000 1;
end

endmodule
