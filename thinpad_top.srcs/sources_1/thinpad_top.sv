/*
赵成钢：
把文件换成SystemVerilog，里面的PLL_Example也换成了新的
*/

`timescale 1ns / 1ps

module thinpad_top(
    input logic clk_50M,             // 50MHz 时钟输入
    input logic clk_11M0592,         // 11.0592MHz 时钟输入

    input logic clock_btn,           // BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input logic reset_btn,           // BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  logic[3:0]  touch_btn,    // BTN1~BTN4，按钮开关，按下时为1
    input  logic[31:0] dip_sw,       // 32位拨码开关，拨到“ON”时为1
    output logic[15:0] leds,         // 16位LED，输出时1点亮
    output logic[7:0]  dpy0,         // 数码管低位信号，包括小数点，输出1点亮
    output logic[7:0]  dpy1,         // 数码管高位信号，包括小数点，输出1点亮

    // CPLD串口控制器信号
    output logic uart_rdn,           // 读串口信号，低有效
    output logic uart_wrn,           // 写串口信号，低有效
    input  logic uart_dataready,     // 串口数据准备好
    input  logic uart_tbre,          // 发送数据标志
    input  logic uart_tsre,          // 数据发送完毕标志

    // BaseRAM信号
    inout  logic[31:0] base_ram_data,// BaseRAM数据，低8位与CPLD串口控制器共享
    output logic[19:0] base_ram_addr,// BaseRAM地址
    output logic[3:0] base_ram_be_n, // BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic base_ram_ce_n,      // BaseRAM片选，低有效
    output logic base_ram_oe_n,      // BaseRAM读使能，低有效
    output logic base_ram_we_n,      // BaseRAM写使能，低有效

    // ExtRAM信号
    inout  logic[31:0] ext_ram_data,  // ExtRAM数据
    output logic[19:0] ext_ram_addr, // ExtRAM地址
    output logic[3:0] ext_ram_be_n,  // ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic ext_ram_ce_n,       // ExtRAM片选，低有效
    output logic ext_ram_oe_n,       // ExtRAM读使能，低有效
    output logic ext_ram_we_n,       // ExtRAM写使能，低有效

    // 直连串口信号
    output logic txd,                // 直连串口发送端
    input  logic rxd,                // 直连串口接收端

    // Flash存储器信号，参考 JS28F640 芯片手册
    output logic [22:0]flash_a,      // Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  logic [15:0]flash_d,      // Flash数据
    output logic flash_rp_n,         // Flash复位信号，低有效
    output logic flash_vpen,         // Flash写保护信号，低电平时不能擦除、烧写
    output logic flash_ce_n,         // Flash片选信号，低有效
    output logic flash_oe_n,         // Flash读使能信号，低有效
    output logic flash_we_n,         // Flash写使能信号，低有效
    output logic flash_byte_n,       // Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    // USB+SD 控制器信号，参考 CH376T 芯片手册
    output logic ch376t_sdi,
    output logic ch376t_sck,
    output logic ch376t_cs_n,
    output logic ch376t_rst,
    input  logic ch376t_int_n,
    input  logic ch376t_sdo,

    // 网络交换机信号，参考 KSZ8795 芯片手册及 RGMII 规范
    input  logic [3:0] eth_rgmii_rd,
    input  logic eth_rgmii_rx_ctl,
    input  logic eth_rgmii_rxc,
    output logic [3:0] eth_rgmii_td,
    output logic eth_rgmii_tx_ctl,
    output logic eth_rgmii_txc,
    output logic eth_rst_n,
    input  logic eth_int_n,

    input  logic eth_spi_miso,
    output logic eth_spi_mosi,
    output logic eth_spi_sck,
    output logic eth_spi_ss_n,

    // 图像输出信号
    output logic[2:0] video_red,     // 红色像素，3位
    output logic[2:0] video_green,   // 绿色像素，3位
    output logic[1:0] video_blue,    // 蓝色像素，2位
    output logic video_hsync,        // 行同步（水平同步）信号
    output logic video_vsync,        // 场同步（垂直同步）信号
    output logic video_clk,          // 像素时钟输出
    output logic video_de            // 行数据有效信号，用于区分消隐区
);

// PLL分频

logic locked, clk_10M, clk_20M, clk_125M, clk_200M;
pll clock_gen 
(
    // Clock out ports
    .clk_out1(clk_10M),               // 时钟输出1
    .clk_out2(clk_20M),               // 时钟输出2
    .clk_out3(clk_125M),              // 时钟输出3
    .clk_out4(clk_200M),              // 时钟输出4
    .reset(reset_btn),                // PLL 复位输入，这里是用户按键
    .locked(locked),                  // 锁定输出，"1"表示时钟稳定，可作为后级电路复位
    .clk_in1(clk_50M)                 // 外部时钟输入
);

// 生成rst_n信号，SystemVerilog那本书上说最好用rst_n来控制复位

wire rst_n;

reset_gen reset_gen_inst(
    .clk(clk_50M),
    .locked(locked),
    .reset_btn(reset_btn),

    .rst_n(rst_n)
);

// 这里应该是KSZ8795芯片的一些设置，初始化用

eth_conf conf(
    .clk(clk_50M),
    .rst_in_n(rst_n),

    .eth_spi_miso(eth_spi_miso),
    .eth_spi_mosi(eth_spi_mosi),
    .eth_spi_sck(eth_spi_sck),
    .eth_spi_ss_n(eth_spi_ss_n),

    .done()
);

/**********************
 *      路由模块      *
 *********************/

rgmii_manager rgmii_manager_inst (
    .clk_rgmii(clk_125M),
    .clk_internal(clk_125M),
    .clk_ref(clk_200M),
    .rst_n(rst_n),

    .clk(clock_btn),
    .btn(touch_btn),
    .led_out(leds),
    .digit0_out(dpy0),
    .digit1_out(dpy1),

    .eth_rgmii_rd(eth_rgmii_rd),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl),
    .eth_rgmii_rxc(eth_rgmii_rxc),
    .eth_rgmii_td(eth_rgmii_td),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl),
    .eth_rgmii_txc(eth_rgmii_txc),
);

endmodule
