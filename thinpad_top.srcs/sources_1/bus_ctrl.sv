`timescale 1ns / 1ps

`include "cpu_defs.vh"

module bus_ctrl(
    input  logic                    clk,
    input  logic                    clk_50M,
    input  logic                    clk_125M,
    input  logic                    clk_200M,
    input  logic                    rst_n,

    // 错误信号
    output logic                    read_error,         // 出现非法读内存后锁存 1
    output logic                    write_error,        // 出现非法写内存后锁存 1

    // CPU控制
    input  logic                    cpu_ram_ce,         // CPU是否读写RAM
    input  logic                    cpu_ram_we,         // CPU是否写入
    input  addr_t                   cpu_ram_addr,       // CPU要访问的地址
    input  word_t                   cpu_ram_data_w,     // CPU要写入的数据
    input  sel_t                    cpu_ram_sel,        // CPU的字节使能

    output int_t                    cpu_int,            // 传给CPU的中断
    output word_t                   cpu_ram_data_r,     // CPU从RAM中读出的数据

    // CPLD串口控制器信号
    input  logic                    uart_dataready,     // 串口数据准备好
    input  logic                    uart_tbre,          // 发送数据标志
    input  logic                    uart_tsre,          // 数据发送完毕标志
    output logic                    uart_rdn,           // 读串口信号，低有效
    output logic                    uart_wrn,           // 写串口信号，低有效

    // BaseRAM信号
    inout  logic[31:0]              base_ram_data,      // BaseRAM数据，低8位与CPLD串口控制器共享
    output logic[19:0]              base_ram_addr,      // BaseRAM地址
    output logic[3:0]               base_ram_be_n,      // BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic                    base_ram_ce_n,      // BaseRAM片选，低有效
    output logic                    base_ram_oe_n,      // BaseRAM读使能，低有效
    output logic                    base_ram_we_n,      // BaseRAM写使能，低有效

    // ExtRAM信号
    inout  logic[31:0]              ext_ram_data,       // ExtRAM数据
    output logic[19:0]              ext_ram_addr,       // ExtRAM地址
    output logic[3:0]               ext_ram_be_n,       // ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic                    ext_ram_ce_n,       // ExtRAM片选，低有效
    output logic                    ext_ram_oe_n,       // ExtRAM读使能，低有效
    output logic                    ext_ram_we_n,       // ExtRAM写使能，低有效

    // 直连串口信号
    output logic                    txd,                // 直连串口发送端
    input  logic                    rxd,                // 直连串口接收端

    // Flash存储器信号，参考 JS28F640 芯片手册
    output logic[22:0]              flash_a,            // Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  logic[15:0]              flash_d,            // Flash数据
    output logic                    flash_rp_n,         // Flash复位信号，低有效
    output logic                    flash_vpen,         // Flash写保护信号，低电平时不能擦除、烧写
    output logic                    flash_ce_n,         // Flash片选信号，低有效
    output logic                    flash_oe_n,         // Flash读使能信号，低有效
    output logic                    flash_we_n,         // Flash写使能信号，低有效
    output logic                    flash_byte_n,       // Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    // USB+SD 控制器信号，参考 CH376T 芯片手册
    output logic                    ch376t_sdi,
    output logic                    ch376t_sck,
    output logic                    ch376t_cs_n,
    output logic                    ch376t_rst,
    input  logic                    ch376t_int_n,
    input  logic                    ch376t_sdo,

    // Router连接
    input  logic[71:0]              router_mem_data,
    output logic[15:0]              router_mem_addr,
    input  logic[15:0]              router_data_out,
    input  logic                    router_data_empty,
    output logic                    router_data_read_valid,
    input  logic[15:0]              routing_entry_pointer,

    // 图像输出信号
    output logic[2:0]               video_red,          // 红色像素，3位
    output logic[2:0]               video_green,        // 绿色像素，3位
    output logic[1:0]               video_blue,         // 蓝色像素，2位
    output logic                    video_hsync,        // 行同步（水平同步）信号
    output logic                    video_vsync,        // 场同步（垂直同步）信号
    output logic                    video_clk,          // 像素时钟输出
    output logic                    video_de            // 行数据有效信号，用于区分消隐区
);

// 屏幕同步显示
display display_inst(
    .clk_write(clk),
    .clk_50M(clk_50M),
    .rst_n(rst_n),

    .char_write(cpu_ram_data_w[6:0]),
    .write_en(~uart_wrn),

    .* // VGA
);

// BootROM
logic[`BOOTROM_ADDR_WITDH-1:0] bootrom_addr;
word_t bootrom_data;

bootrom bootrom_inst(
    .clk(clk_200M),

    .addr(bootrom_addr),
    .data(bootrom_data)
);

// CPU中断控制
assign cpu_int = {3'b0, uart_dataready, 2'b0}; // UART是IP4

assign bootrom_addr = cpu_ram_addr[10:2];

assign base_ram_ce_n = 0;
assign base_ram_be_n = ~cpu_ram_sel;
assign base_ram_addr = cpu_ram_addr[21:2];
assign base_ram_data = base_ram_we_n ? 
                            (uart_wrn ? {32{1'bz}} : {{24{1'bz}}, cpu_ram_data_w[7:0]}) : 
                            cpu_ram_data_w;

assign ext_ram_ce_n = 0;
assign ext_ram_be_n = ~cpu_ram_sel;
assign ext_ram_addr = cpu_ram_addr[21:2];
assign ext_ram_data = ext_ram_we_n ? 'z : cpu_ram_data_w;

assign router_mem_addr = cpu_ram_addr[18:4];

`define DISALLOW_WRITE(label) \
    if (cpu_ram_we) begin \
        $fatal(0, {"ILLEGAL WRITE: Write on \"", label, "\"at %x"}, cpu_ram_addr); \
        write_error <= 1; \
    end

always_comb begin
    base_ram_we_n <= 1;
    base_ram_oe_n <= 1;

    ext_ram_we_n <= 1;
    ext_ram_oe_n <= 1;

    uart_rdn <= 1;
    uart_wrn <= 1;

    cpu_ram_data_r <= '0;

    router_data_read_valid <= 0;
    
    if (!rst_n) begin
        read_error <= 0;
        write_error <= 0;
    end else if (cpu_ram_ce) begin
        unique case (cpu_ram_addr) inside
            // BootROM (R/O)
            [32'h8000_0000 : 32'h800f_ffff]: begin
                `DISALLOW_WRITE("BootROM");
                cpu_ram_data_r <= bootrom_data;
            end
            // BaseRAM
            [32'h8010_0000 : 32'h803f_ffff]: begin
                if (cpu_ram_we) begin
                    base_ram_we_n <= 0;
                end else begin
                    base_ram_oe_n <= 0;
                    cpu_ram_data_r <= base_ram_data;
                end
            end
            // ExtRAM
            [32'h8040_0000 : 32'h807f_ffff]: begin
                if (cpu_ram_we) begin
                    ext_ram_we_n <= 0;
                end else begin
                    ext_ram_oe_n <= 0;
                    cpu_ram_data_r <= ext_ram_data;
                end
            end
            // 串口数据
            32'hbfd003f8: begin
                if (cpu_ram_we) begin
                    uart_wrn <= 0;
                end else begin
                    uart_rdn <= 0;
                    cpu_ram_data_r[7:0] <= base_ram_data[7:0];
                end
            end
            // 串口状态 (R/O)
            32'hbfd003fc: begin
                `DISALLOW_WRITE("URAT Status");
                cpu_ram_data_r[1] <= uart_dataready;
                cpu_ram_data_r[0] <= uart_tsre & uart_tbre;
            end
            // 路由器内存 (R/O)
            [32'hc000_0000 : 32'hc007_ffff]: begin
                `DISALLOW_WRITE("Router Memory");
                case (cpu_ram_addr[3:2])
                    0: cpu_ram_data_r <= router_mem_data[31:0];
                    1: cpu_ram_data_r <= router_mem_data[63:32];
                    2: cpu_ram_data_r <= {24'h0, router_mem_data[71:64]};
                    3: read_error <= 1;
                endcase
            end
            // 路由表指针 (R/O)
            32'hc008_0000: begin
                `DISALLOW_WRITE("Routing Entry Pointer");
                cpu_ram_data_r[15:0] <= routing_entry_pointer;
            end
            // 路由器读取数据 (R/O)
            // fifo rd_en 拉高一拍: 读取当前数据，fifo 出口更新下一条数据
            32'hc008_0001: begin
                `DISALLOW_WRITE("Router Data");
                router_data_read_valid <= 1;
                cpu_ram_data_r[15:0] <= router_data_out;
            end
            // 路由器读取数据状态 (R/O)
            // 最低位为 1 表示有数据可读
            32'hc008_0002: begin
                `DISALLOW_WRITE("Router Data Status");
                cpu_ram_data_r[0] <= !router_data_empty;
            end
            default: begin
                if (cpu_ram_we) begin
                    write_error <= 1;
                end
                read_error <= 1;
            end
        endcase
    end
end

endmodule