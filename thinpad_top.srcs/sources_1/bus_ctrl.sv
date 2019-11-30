`timescale 1ns / 1ps

`include "cpu_defs.vh"

module bus_ctrl(
    input  logic rst_n,

    // CPU控制
    input  logic  cpu_inst_ce,
    input  addr_t cpu_inst_addr,
    output word_t cpu_inst_data,

    input  logic  cpu_
    

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

logic base_is_writing;
logic ext_is_writing;
logic [31:0] base_bus_data_to_write;
logic [31:0] ext_bus_data_to_write;

assign base_ram_data = base_is_writing ? base_bus_data_to_write : 32'bz;
assign ext_ram_data = ext_is_writing ? ext_bus_data_to_write : 32'bz;

always_comb begin
    if (~rst_n) begin
        inst <= 0;
        cpu_ram_data_i <= 0;
        base_is_writing <= 0;
        base_ram_ce_n <= 1;
        base_ram_we_n <= 1;
        base_ram_oe_n <= 1;
        base_ram_addr <= 0;
        ext_is_writing <= 0;
        ext_ram_ce_n <= 1;
        ext_ram_we_n <= 1;
        ext_ram_oe_n <= 1;
        ext_ram_addr <= 0;
        uart_rdn <= 1;
        uart_wrn <= 1;
    end else begin
        inst <= 0;
        cpu_ram_data_i <= 0;
        base_is_writing <= 0;
        base_ram_ce_n <= 1;
        base_ram_we_n <= 1;
        base_ram_oe_n <= 1;
        base_ram_addr <= 0;
        ext_is_writing <= 0;
        ext_ram_ce_n <= 1;
        ext_ram_we_n <= 1;
        ext_ram_oe_n <= 1;
        ext_ram_addr <= 0;
        uart_rdn <= 1;
        uart_wrn <= 1;
        if (cpu_ram_ce_o) begin // 访存的优先级大于取指的优先级
            if (cpu_ram_addr_o >= 32'h80000000 && cpu_ram_addr_o <= 32'h803fffff) begin// 访问baseram
                base_ram_ce_n <= 0;
                if (cpu_ram_we_o) begin // 如果是写状态
                    base_ram_we_n <= 0; // 可写
                    base_ram_oe_n <= 1; // 不可读
                    base_is_writing <= 1;
                    base_ram_addr <= cpu_ram_addr_o[19+2:0+2];
                    base_ram_be_n <= ~cpu_ram_sel_o; // 真值相反
                    base_bus_data_to_write <= cpu_ram_data_o;
                end else begin // 如果是读状态
                    base_ram_we_n <= 1;
                    base_ram_oe_n <= 0;
                    base_is_writing <= 0;
                    base_ram_addr <= cpu_ram_addr_o[19+2:0+2];
                    base_ram_be_n <= ~cpu_ram_sel_o; // 真值相反       
                    cpu_ram_data_i <= base_ram_data;
                end
            end else if (cpu_ram_addr_o >= 32'h80400000 && cpu_ram_addr_o <= 32'h807fffff) begin // 访问extram
                ext_ram_ce_n <= 0;
                if (cpu_ram_we_o) begin // 如果是写状态
                    ext_ram_we_n <= 0;            
                    ext_ram_oe_n <= 1;
                    ext_is_writing <= 1;
                    ext_ram_addr <= cpu_ram_addr_o[19+2:0+2];
                    ext_ram_be_n <= ~cpu_ram_sel_o; // 真值相反
                    ext_bus_data_to_write <= cpu_ram_data_o;
                end else begin // 如果是读状态
                    ext_ram_we_n <= 1;
                    ext_ram_oe_n <= 0;
                    ext_is_writing <= 0;
                    ext_ram_addr <= cpu_ram_addr_o[19+2:0+2];
                    ext_ram_be_n <= ~cpu_ram_sel_o; // 真值相反       
                    cpu_ram_data_i <= ext_ram_data;
                end
            end else if (cpu_ram_addr_o == 32'hbfd003f8) begin // 访问串口
                if (cpu_ram_we_o) begin // 如果是写状态
                    uart_rdn <= 1;
                    uart_wrn <= 0;
                    base_is_writing <= 1;
                    base_bus_data_to_write[7:0] <= cpu_ram_data_o[7:0];
                end else begin
                    uart_rdn <= 0;
                    uart_wrn <= 1;
                    base_is_writing <= 0;
                    cpu_ram_data_i <= {24'b0, base_ram_data[7:0]};
                end
            end else if (cpu_ram_addr_o == 32'hbfd003fc) begin
                cpu_ram_data_i <= {30'b0, uart_dataready, uart_tsre & uart_tbre};
            end
        end else if (rom_ce) begin // 指令是只读的
            if (inst_addr >= 32'h80000000 && inst_addr <= 32'h803FFFFF) begin // 访问baseram
                base_ram_ce_n <= 0;
                // 取指只能是读状态
                base_ram_we_n <= 1;
                base_ram_oe_n <= 0;
                base_is_writing <= 0;
                base_ram_addr <= inst_addr[19+2:0+2];
                base_ram_be_n <= 4'b0000; // 永远可以选择
                inst <= base_ram_data;
            end else if (inst_addr >= 32'h80400000 && inst_addr <= 32'h807FFFFF) begin // 访问extram
                ext_ram_ce_n <= 0;
                // 取指只能是读状态
                ext_ram_we_n <= 1;
                ext_ram_oe_n <= 0;
                ext_is_writing <= 0;
                ext_ram_addr <= inst_addr[19+2:0+2];
                ext_ram_be_n <= 4'b0000; // 永远可以选择
                inst <= ext_ram_data;
            end
        end
    end
end