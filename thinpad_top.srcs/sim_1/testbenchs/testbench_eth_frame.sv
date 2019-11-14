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

wire [7:0] rx_data;
wire rx_valid;
wire rx_pause;
reg  [7:0] tx_data = '0;
reg  tx_valid = 0;
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
