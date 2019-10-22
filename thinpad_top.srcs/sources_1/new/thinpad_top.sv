`default_nettype none

module thinpad_top(
    input wire clk_50M,             // 50MHz 时钟输入
    input wire clk_11M0592,         // 11.0592MHz 时钟输入

    input wire clock_btn,           // BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,           // BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire[3:0]  touch_btn,    // BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,       // 32位拨码开关，拨到“ON”时为1
    output wire[15:0] leds,         // 16位LED，输出时1点亮
    output wire[7:0]  dpy0,         // 数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,         // 数码管高位信号，包括小数点，输出1点亮

    // CPLD串口控制器信号
    output wire uart_rdn,           // 读串口信号，低有效
    output wire uart_wrn,           // 写串口信号，低有效
    input wire uart_dataready,      // 串口数据准备好
    input wire uart_tbre,           // 发送数据标志
    input wire uart_tsre,           // 数据发送完毕标志

    // BaseRAM信号
    inout wire[31:0] base_ram_data,  // BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, // BaseRAM地址
    output wire[3:0] base_ram_be_n,  // BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       // BaseRAM片选，低有效
    output wire base_ram_oe_n,       // BaseRAM读使能，低有效
    output wire base_ram_we_n,       // BaseRAM写使能，低有效

    // ExtRAM信号
    inout wire[31:0] ext_ram_data,  // ExtRAM数据
    output wire[19:0] ext_ram_addr, // ExtRAM地址
    output wire[3:0] ext_ram_be_n,  // ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       // ExtRAM片选，低有效
    output wire ext_ram_oe_n,       // ExtRAM读使能，低有效
    output wire ext_ram_we_n,       // ExtRAM写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]flash_a,      // Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]flash_d,      // Flash数据
    output wire flash_rp_n,         // Flash复位信号，低有效
    output wire flash_vpen,         // Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         // Flash片选信号，低有效
    output wire flash_oe_n,         // Flash读使能信号，低有效
    output wire flash_we_n,         // Flash写使能信号，低有效
    output wire flash_byte_n,       // Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    // USB+SD 控制器信号，参考 CH376T 芯片手册
    output wire ch376t_sdi,
    output wire ch376t_sck,
    output wire ch376t_cs_n,
    output wire ch376t_rst,
    input  wire ch376t_int_n,
    input  wire ch376t_sdo,
    
    // 图像输出信号
    output wire[2:0] video_red,     // 红色像素，3位
    output wire[2:0] video_green,   // 绿色像素，3位
    output wire[1:0] video_blue,    // 蓝色像素，2位
    output wire video_hsync,        // 行同步（水平同步）信号
    output wire video_vsync,        // 场同步（垂直同步）信号
    output wire video_clk,          // 像素时钟输出
    output wire video_de            // 行数据有效信号，用于区分消隐区
);

/* Disable ExtRAM */
assign ext_ram_ce_n = 1'b1;
assign ext_ram_oe_n = 1'b1;
assign ext_ram_we_n = 1'b1;

/* States */
enum logic [2:0] { RECEIVE, ROCOVER, TRASMIT, WAIT, IDLE} state;

/* UART */
wire [7:0] uart_data;

/* Variables */
logic [3:0] counter;
logic [19:0] addr, addr_end;

/* Assigns */
assign uart_data = base_ram_data[7:0];

always @(posedge reset_btn) begin
    state <= IDLE;
    base_ram_ce_n <= 0;
    base_ram_oe_n <= 1;
    base_ram_we_n <= 1;
    uart_rdn <= 0;
    uart_wrn <= 1;
    counter <= 0;
    addr <= dip_sw[19:0];
    addr_end <= dip_sw[19:0] + 9;
end

always @(posedge clk_50M) begin
    case (state):
        RECEIVE: begin
            if (uart_dataready) begin
                base_ram_data <= {24'b0, uart_data};
                base_ram_we_n <= 0;
                uart_rdn <= 1;
                state <= RECOVER;
            end
        end

        RECOVER: begin
            if (addr == addr_end) begin
                addr <= addr_end - 9;
                base_ram_oe_n <= 0;
                base_ram_we_n <= 1;
                state <= TRASMIT;
            end else begin
                addr <= addr + 1;
                base_ram_we_n <= 1;
                uart_rdn <= 0;
                state <= RECEIVE;
            end
        end

        WAIT: begin
            if (uart_tsre) begin
                if (addr == addr_end) begin
                    state <= IDLE;
                end else begin
                    base_ram_oe_n <= 0;
                    addr <= addr + 1;
                    state <= TRASMIT;
                end
                uart_wrn <= 1;
            end
        end

        TRASMIT: begin
            uart_data <= base_ram_data[7:0];
            base_ram_oe_n <= 1;
            uart_wrn <= 0;
            state <= WAIT;
        end

        default: begin /* IDLE */ end
    endcase
end

endmodule
