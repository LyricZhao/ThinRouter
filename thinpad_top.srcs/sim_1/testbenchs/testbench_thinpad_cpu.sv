`timescale 1ns / 1ps

`include "cpu_defs.vh"

module testbench_thinpad_cpu();

wire clk_50M, clk_11M0592, clk_125M, clk_125M_90deg;

reg clock_btn = 0;          // BTN5手动时钟按钮开关，带消抖电路，按下时为1
reg reset_btn = 0;          // BTN6手动复位按钮开关，带消抖电路，按下时为1

reg[3:0]  touch_btn;        // BTN1~BTN4，按钮开关，按下时为1
reg[31:0] dip_sw;           // 32位拨码开关，拨到“ON”时为1

wire[15:0] leds;            // 16位LED，输出时1点亮
wire[7:0]  dpy0;            // 数码管低位信号，包括小数点，输出1点亮
wire[7:0]  dpy1;            // 数码管高位信号，包括小数点，输出1点亮

wire txd;                   // 直连串口发送端
wire rxd;                   // 直连串口接收端

wire[31:0] base_ram_data;   // BaseRAM数据，低8位与CPLD串口控制器共享
wire[19:0] base_ram_addr;   // BaseRAM地址
wire[3:0] base_ram_be_n;    // BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire base_ram_ce_n;         // BaseRAM片选，低有效
wire base_ram_oe_n;         // BaseRAM读使能，低有效
wire base_ram_we_n;         // BaseRAM写使能，低有效

wire[31:0] ext_ram_data;    // ExtRAM数据
wire[19:0] ext_ram_addr;    // ExtRAM地址
wire[3:0] ext_ram_be_n;     // ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire ext_ram_ce_n;          // ExtRAM片选，低有效
wire ext_ram_oe_n;          // ExtRAM读使能，低有效
wire ext_ram_we_n;          // ExtRAM写使能，低有效

wire [22:0]flash_a;         // Flash地址，a0仅在8bit模式有效，16bit模式无意义
wire [15:0]flash_d;         // Flash数据
wire flash_rp_n;            // Flash复位信号，低有效
wire flash_vpen;            // Flash写保护信号，低电平时不能擦除、烧写
wire flash_ce_n;            // Flash片选信号，低有效
wire flash_oe_n;            // Flash读使能信号，低有效
wire flash_we_n;            // Flash写使能信号，低有效
wire flash_byte_n;          // Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

wire uart_rdn;              // 读串口信号，低有效
wire uart_wrn;              // 写串口信号，低有效
wire uart_dataready;        // 串口数据准备好
wire uart_tbre;             // 发送数据标志
wire uart_tsre;             // 数据发送完毕标志

thinpad_top dut(
    .clk_50M(clk_50M),
    .clk_11M0592(clk_11M0592),
    .clock_btn(clock_btn),
    .reset_btn(reset_btn),
    .touch_btn(touch_btn),
    .dip_sw(dip_sw),
    .leds(leds),
    .dpy1(dpy1),
    .dpy0(dpy0),
    .txd(txd),
    .rxd(rxd),
    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_be_n(base_ram_be_n),
    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),
    .ext_ram_be_n(ext_ram_be_n),
    .flash_d(flash_d),
    .flash_a(flash_a),
    .flash_rp_n(flash_rp_n),
    .flash_vpen(flash_vpen),
    .flash_oe_n(flash_oe_n),
    .flash_ce_n(flash_ce_n),
    .flash_byte_n(flash_byte_n),
    .flash_we_n(flash_we_n)
);

// 需要把这个放到Simulation Source里面
parameter base_ram_init_file = "kernel.bin";
parameter term_file = "cpu_sv_test.mem";

// CPLD 串口仿真模型
cpld_model cpld(
    .clk_uart(clk_11M0592),
    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .data(base_ram_data[7:0])
);

// 时钟源
clock osc(
    .clk_11M0592(clk_11M0592),
    .clk_50M(clk_50M),
    .clk_125M(clk_125M),
    .clk_125M_90deg(clk_125M_90deg)
);

// BaseRAM 仿真模型
sram_model base1(
            .DataIO(base_ram_data[15:0]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[0]),
            .UB_n(base_ram_be_n[1]));
sram_model base2(
            .DataIO(base_ram_data[31:16]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[2]),
            .UB_n(base_ram_be_n[3]));

// ExtRAM 仿真模型
sram_model ext1(
            .DataIO(ext_ram_data[15:0]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[0]),
            .UB_n(ext_ram_be_n[1]));

sram_model ext2(
            .DataIO(ext_ram_data[31:16]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[2]),
            .UB_n(ext_ram_be_n[3]));

// 初始按一下 reset
initial begin
    reset_btn = 1;
    #4000;
    reset_btn = 0;
end

// 从文件加载 BaseRAM
initial begin
    word_t tmp_array[0:1048575];
    integer file_id, file_size;
    file_id = $fopen(base_ram_init_file, "rb");
    if (!file_id) begin 
        file_size = 0;
        $display("Failed to open BaseRAM init file");
    end else begin
        file_size = $fread(tmp_array, file_id);
        file_size /= 4;
        $fclose(file_id);
    end
    $display("BaseRAM Init Size(words): %d", file_size);
    for (integer i = 0; i < file_size; i ++) begin
        base1.mem_array0[i] = tmp_array[i][24+:8];
        base1.mem_array1[i] = tmp_array[i][16+:8];
        base2.mem_array0[i] = tmp_array[i][8+:8];
        base2.mem_array1[i] = tmp_array[i][0+:8];
    end
end

initial begin
    byte term_array[0:1048575];
    integer file_id, file_size;
    // 开始加载监控程序命令
    file_id = $fopen(term_file, "rb");
    if (!file_id) begin
        file_size = 0;
        $display("Failed to open term file");
    end else begin
        file_size = $fread(term_array, file_id);
        $fclose(file_id);
    end
    $display("term size(bytes): %d", file_size);
    #1000000;
    for (integer i = 0; i < file_size; i ++) begin
        #1000;
        cpld.pc_send_byte(term_array[i]);
    end
end

endmodule
