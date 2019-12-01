`timescale 1ns / 1ps

`include "cpu_defs.vh"

// TODO: 代码对齐
module bus_ctrl(
    input  logic rst_n,

    // CPU控制
    input  logic  cpu_ram_ce,
    input  logic  cpu_ram_we,
    input  addr_t cpu_ram_addr,
    input  word_t cpu_ram_data_w,
    input  sel_t  cpu_ram_sel,

    output int_t  cpu_int,
    output word_t cpu_ram_data_r,

    // CPLD串口控制器信号
    input  logic uart_dataready,     // 串口数据准备好
    input  logic uart_tbre,          // 发送数据标志
    input  logic uart_tsre,          // 数据发送完毕标志
    output logic uart_rdn,           // 读串口信号，低有效
    output logic uart_wrn,           // 写串口信号，低有效

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

// CPU中断控制
assign cpu_int = {3'b0, uart_dataready, 2'b0}; // UART是IP4

// 一直开着两个RAM
assign base_ram_ce_n = 0;
assign ext_ram_ce_n = 0;

logic base_ram_we, ext_ram_we;
word_t base_ram_wdata, ext_ram_wdata;

assign base_ram_data = base_ram_we ? base_ram_wdata : 32'bz;
assign ext_ram_data = ext_ram_we ? ext_ram_wdata : 32'bz;

`define DISABLE_BASE    base_ram_we <= 0; \
                        base_ram_we_n <= 1; \
                        base_ram_oe_n <= 1; \
                        base_ram_addr <= 0

`define DISABLE_EXT     ext_ram_we <= 0; \
                        ext_ram_we_n <= 1; \
                        ext_ram_oe_n <= 1; \
                        ext_ram_addr <= 0

`define DISABLE_UART    uart_rdn <= 1; \
                        uart_wrn <= 1

`define ENABLE_BASE(wen, on, we, addr, ben, wd, rdr)    base_ram_we_n <= wen; \
                                                        base_ram_oe_n <= on; \
                                                        base_ram_we <= we; \
                                                        base_ram_addr <= addr; \
                                                        base_ram_be_n <= ben; \
                                                        base_ram_wdata <= wd; \
                                                        cpu_ram_data_r <= rdr

`define ENABLE_EXT(wen, on, we, addr, ben, wd, rdr)     ext_ram_we_n <= wen; \
                                                        ext_ram_oe_n <= on; \
                                                        ext_ram_we <= we; \
                                                        ext_ram_addr <= addr; \
                                                        ext_ram_be_n <= ben; \
                                                        ext_ram_wdata <= wd; \
                                                        cpu_ram_data_r <= rdr

`define ENABLE_UART(rdn, wrn, we, wd, rdr)              uart_rdn <= rdn; \
                                                        uart_wrn <= wrn; \
                                                        base_ram_we <= we; \
                                                        base_ram_wdata[7:0] <= wd; \
                                                        cpu_ram_data_r <= rdr

always_comb begin
    if (~rst_n) begin
        cpu_ram_data_r <= 0;
        `DISABLE_BASE;
        `DISABLE_EXT;
        `DISABLE_UART;
    end else begin
        cpu_ram_data_r <= 0;
        `DISABLE_BASE;
        `DISABLE_EXT;
        `DISABLE_UART;
        if (cpu_ram_ce) begin
            if (`IN_RANGE(cpu_ram_addr, `BASE_START, `BASE_END)) begin
                if (cpu_ram_we) begin
                    `ENABLE_BASE(0, 1, 1, cpu_ram_addr[21:2], ~cpu_ram_sel, cpu_ram_data_w, 0);
                end else begin
                    `ENABLE_BASE(1, 0, 0, cpu_ram_addr[21:2], ~cpu_ram_sel, 0, base_ram_data);
                end
            end else if (`IN_RANGE(cpu_ram_addr, `EXT_START, `EXT_END)) begin
                if (cpu_ram_we) begin
                    `ENABLE_EXT(0, 1, 1, cpu_ram_addr[21:2], ~cpu_ram_sel, cpu_ram_data_w, 0);
                end else begin
                    `ENABLE_EXT(1, 0, 0, cpu_ram_addr[21:2], ~cpu_ram_sel, 0, ext_ram_data);
                end
            end else if (`EQ(cpu_ram_addr, `UART_RW)) begin
                if (cpu_ram_we) begin
                    `ENABLE_UART(1, 0, 1, cpu_ram_data_w[7:0], 0);
                end else begin
                    `ENABLE_UART(0, 1, 0, 0, {24'b0, base_ram_data[7:0]});
                end
            end else if (`EQ(cpu_ram_addr, `UART_STAT)) begin // 只读
                cpu_ram_data_r <= {30'b0, uart_dataready, uart_tsre & uart_tbre};
            end
        end
    end
end

endmodule