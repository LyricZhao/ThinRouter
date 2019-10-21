/*
涂轶翔：
把 top 里面的 RGMII 接口接过来，通过某个库转化成 AXI-S 接口
然后交给 io_manager 处理
*/

module rgmii_manager(
    input   wire    clk_125M,
    input   wire    clk_200M,
    input   wire    [3:0] eth_rgmii_rd,
    input   wire    eth_rgmii_rx_ctl,
    input   wire    eth_rgmii_rxc,
    output  wire    [3:0] eth_rgmii_td,
    output  wire    eth_rgmii_tx_ctl,
    output  wire    eth_rgmii_txc,
    output  wire    eth_rst_n
);

wire gtx_resetn;

wire [7:0] axis_rx_data;
wire axis_rx_valid;
wire axis_rx_last;
wire axis_rx_ready;
wire [7:0] axis_tx_data;
wire axis_tx_valid;
wire axis_tx_last;
wire axis_tx_ready;

// 在第一个时钟上升沿，将 resetn 从 0 变为 1
gtx_reset gtx_reset_inst(
    .clk(clk_125M),
    .gtx_resetn(gtx_resetn)
);

io_manager io_manager_inst (
    .clk_io(clk_125M),
    .clk_internal(clk_200M),
    .rx_data(axis_rx_data),
    .rx_valid(axis_rx_valid),
    .rx_ready(axis_rx_ready),
    .rx_last(axis_rx_last),
    .tx_data(axis_tx_data),
    .tx_valid(axis_tx_valid),
    .tx_ready(axis_tx_ready),
    .tx_last(axis_tx_last),
    .gtx_resetn(gtx_resetn)
);

eth_mac_fifo_block trimac_fifo_block (
    .gtx_clk                      (clk_125M),

    .glbl_rstn                    (eth_rst_n),
    .rx_axi_rstn                  (eth_rst_n),
    .tx_axi_rstn                  (eth_rst_n),

    // Reference clock for IDELAYCTRL's
    .refclk                       (clk_200M),

    // Receiver Statistics Interface
    //---------------------------------------
    // .rx_mac_aclk                  (fifo_clock),
    // .rx_reset                     (rx_reset),
    // .rx_statistics_vector         (rx_statistics_vector),
    // .rx_statistics_valid          (rx_statistics_valid),

    // Receiver (AXI-S) Interface
    //----------------------------------------
    .rx_fifo_clock                (clk_125M),
    .rx_fifo_resetn               (gtx_resetn),
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
    .tx_fifo_resetn               (gtx_resetn),
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