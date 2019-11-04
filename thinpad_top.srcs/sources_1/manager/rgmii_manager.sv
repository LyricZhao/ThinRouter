/*
把 top 里面的 RGMII 接口接过来，通过某个库转化成 AXI-S 接口
然后交给 io_manager 处理
*/

`timescale 1ns / 1ps

module rgmii_manager(
    input   wire    clk_125M,           // RGMII 和 FIFO 的 125M 时钟
    input   wire    clk_internal,       // 处理内部同步逻辑用的时钟
    input   wire    clk_ref,            // 给 IDELAYCTRL (这个模块在eth_mac里面) 用的 200M 时钟
    input   wire    rst_n,              // PLL分频稳定后为1，后级电路复位，也加入了用户的按键

    input   wire    clk_btn,            // 硬件 clk 按键
    input   wire    [3:0] btn,          // 硬件按钮

    output  wire    [15:0] led_out,     // 硬件 led 指示灯
    output  wire    [7:0]  digit0_out,  // 硬件低位数码管
    output  wire    [7:0]  digit1_out,  // 硬件高位数码管

    input   wire    [3:0] eth_rgmii_rd,
    input   wire    eth_rgmii_rx_ctl,
    input   wire    eth_rgmii_rxc,
    output  wire    [3:0] eth_rgmii_td,
    output  wire    eth_rgmii_tx_ctl,
    output  wire    eth_rgmii_txc
);

// LED
wire [15:0] led;        // 16 个指示灯
wire [7:0]  digit0;     // 右边低位数码管
wire [7:0]  digit1;     // 左边高位数码管

// AXI-S 接口
wire [7:0] axis_rx_data;
wire axis_rx_valid;
wire axis_rx_last;
wire axis_rx_ready;
wire [7:0] axis_tx_data;
wire axis_tx_valid;
wire axis_tx_last;
wire axis_tx_ready;

io_manager io_manager_inst (
    .clk_fifo(clk_125M),
    .clk_internal(clk_internal),

    .rst_n(rst_n),
    .clk_btn(clk_btn),
    .btn(btn),
    .led_out(led_out),
    .digit0_out(digit0_out),
    .digit1_out(digit1_out),

    .rx_data(axis_rx_data),
    .rx_valid(axis_rx_valid),
    .rx_ready(axis_rx_ready),
    .rx_last(axis_rx_last),
    .tx_data(axis_tx_data),
    .tx_valid(axis_tx_valid),
    .tx_ready(axis_tx_ready),
    .tx_last(axis_tx_last)
);

eth_mac_fifo_block trimac_fifo_block (
    .gtx_clk                      (clk_125M),

    .glbl_rstn                    (rst_n),
    .rx_axi_rstn                  (rst_n),
    .tx_axi_rstn                  (rst_n),

    // Reference clock for IDELAYCTRL's
    .refclk                       (clk_ref),

    // Receiver Statistics Interface
    //---------------------------------------
    // .rx_mac_aclk                  (fifo_clock),
    // .rx_reset                     (rx_reset),
    // .rx_statistics_vector         (rx_statistics_vector),
    // .rx_statistics_valid          (rx_statistics_valid),

    // Receiver (AXI-S) Interface
    //----------------------------------------
    .rx_fifo_clock                (clk_125M),
    .rx_fifo_resetn               (rst_n),
    .rx_axis_fifo_tdata           (axis_rx_data),
    .rx_axis_fifo_tvalid          (axis_rx_valid),
    .rx_axis_fifo_tready          (axis_rx_ready),
    .rx_axis_fifo_tlast           (axis_rx_last),

    // Transmitter Statistics Interface
    //------------------------------------------
    // .tx_mac_aclk                  (tx_mac_aclk),
    // .tx_reset                     (tx_reset),
    .tx_ifg_delay                 (8'b0),
    // .tx_statistics_vector         (tx_statistics_vector),
    // .tx_statistics_valid          (tx_statistics_valid),

    // Transmitter (AXI-S) Interface
    //-------------------------------------------
    .tx_fifo_clock                (clk_125M),
    .tx_fifo_resetn               (rst_n),
    .tx_axis_fifo_tdata           (axis_tx_data),
    .tx_axis_fifo_tvalid          (axis_tx_valid),
    .tx_axis_fifo_tready          (axis_tx_ready),
    .tx_axis_fifo_tlast           (axis_tx_last),

    // MAC Control Interface
    //------------------------
    .pause_req                    (1'b0),
    .pause_val                    (16'b0),

    // RGMII Interface
    //------------------
    .rgmii_txd                    (eth_rgmii_td),
    .rgmii_tx_ctl                 (eth_rgmii_tx_ctl),
    .rgmii_txc                    (eth_rgmii_txc),
    .rgmii_rxd                    (eth_rgmii_rd),
    .rgmii_rx_ctl                 (eth_rgmii_rx_ctl),
    .rgmii_rxc                    (eth_rgmii_rxc),

    // RGMII Inband Status Registers
    //--------------------------------
    // .inband_link_status           (inband_link_status),
    // .inband_clock_speed           (inband_clock_speed),
    // .inband_duplex_status         (inband_duplex_status),

    // 这是干嘛的？
    // Configuration Vectors
    //-----------------------
    .rx_configuration_vector      (80'b10100000101110),
    .tx_configuration_vector      (80'b10000000000110)
);

endmodule