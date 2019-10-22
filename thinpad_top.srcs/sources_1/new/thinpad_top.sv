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
    output logic uart_wrn,       // 写串口信号，低有效
    input logic uart_dataready,      // 串口数据准备好
    input logic uart_tbre,           // 发送数据标志
    input logic uart_tsre,           // 数据发送完毕标志

    // BaseRAM信号
    inout  logic[31:0] base_ram_data, // BaseRAM数据，低8位与CPLD串口控制器共享
    output logic[19:0] base_ram_addr, // BaseRAM地址
    output logic[3:0] base_ram_be_n,  // BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic base_ram_ce_n,       // BaseRAM片选，低有效
    output logic base_ram_oe_n,       // BaseRAM读使能，低有效
    output logic base_ram_we_n,       // BaseRAM写使能，低有效

    // ExtRAM信号
    inout  logic[31:0] ext_ram_data,  // ExtRAM数据
    output logic[19:0] ext_ram_addr, // ExtRAM地址
    output logic[3:0] ext_ram_be_n,  // ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output logic ext_ram_ce_n,       // ExtRAM片选，低有效
    output logic ext_ram_oe_n,       // ExtRAM读使能，低有效
    output logic ext_ram_we_n,       // ExtRAM写使能，低有效

    // 直连串口信号
    output logic txd,  // 直连串口发送端
    input  logic rxd,  // 直连串口接收端

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
    
    // 图像输出信号
    output logic[2:0] video_red,     // 红色像素，3位
    output logic[2:0] video_green,   // 绿色像素，3位
    output logic[1:0] video_blue,    // 蓝色像素，2位
    output logic video_hsync,        // 行同步（水平同步）信号
    output logic video_vsync,        // 场同步（垂直同步）信号
    output logic video_clk,          // 像素时钟输出
    output logic video_de            // 行数据有效信号，用于区分消隐区
);

/* Disable ExtRAM */
assign ext_ram_ce_n = 1'b1;
assign ext_ram_oe_n = 1'b1;
assign ext_ram_we_n = 1'b1;

/* States */
enum logic [2:0] { RECEIVE, RECOVER, TRANSMIT, IDLE, WAIT_TBRE, WAIT_TSRE, WAIT_READ, PULL_WRN} state;

/* UART */
wire [7:0] uart_data;

/* Variables */
logic is_writing;
logic [19:0] base_ram_addr_end;
logic [31:0] bus_data_to_write;

/* Assigns */
assign base_ram_data = is_writing ? bus_data_to_write : 32'bz;
assign uart_data = base_ram_data[7:0];

always @(posedge clk_11M0592) begin
    if (reset_btn) begin
        state <= RECEIVE;
        base_ram_ce_n <= 1;
        base_ram_oe_n <= 1;
        base_ram_we_n <= 1;
        base_ram_be_n = 4'b0;
        uart_rdn <= 0;
        uart_wrn <= 1;
        is_writing <= 0;
        base_ram_addr <= dip_sw[19:0];
        base_ram_addr_end <= dip_sw[19:0] + 9;
    end else begin
        case (state)
            RECEIVE: begin
                if (uart_dataready) begin
                    bus_data_to_write <= {24'b0, uart_data};
                    base_ram_oe_n <= 0;
                    base_ram_we_n <= 0;
                    base_ram_ce_n <= 0;
                    is_writing <= 1;
                    uart_rdn <= 1;
                    state <= RECOVER;
                end
            end

            RECOVER: begin
                if (base_ram_addr == base_ram_addr_end) begin
                    base_ram_addr <= base_ram_addr_end - 9;
                    base_ram_oe_n <= 0;
                    base_ram_we_n <= 1;
                    base_ram_ce_n <= 0;
                    is_writing <= 0;
                    state <= WAIT_READ;
                end else begin
                    base_ram_addr <= base_ram_addr + 1;
                    base_ram_oe_n <= 1;
                    base_ram_we_n <= 1;
                    base_ram_ce_n <= 1;
                    is_writing <= 0;
                    uart_rdn <= 0;
                    state <= RECEIVE;
                end
            end

            WAIT_TBRE: begin
                if (uart_tbre) begin
                    state <= WAIT_TSRE;
                end
            end

            WAIT_TSRE: begin
                if (uart_tsre) begin
                    if (base_ram_addr == base_ram_addr_end) begin
                        state <= IDLE;
                    end else begin
                        base_ram_oe_n <= 0;
                        base_ram_ce_n <= 0;
                        base_ram_be_n = 4'b0;
                        base_ram_addr <= base_ram_addr + 1;
                        state <= WAIT_READ;
                    end
                end
            end

            PULL_WRN: begin
                uart_wrn <= 1;
                is_writing <= 0;
                state <= WAIT_TBRE;
            end

            WAIT_READ: begin
                state <= TRANSMIT;
            end

            TRANSMIT: begin
                base_ram_be_n = 4'b1111;
                bus_data_to_write <= {24'b0, uart_data};
                base_ram_oe_n <= 1;
                base_ram_ce_n <= 1;
                uart_wrn <= 0;
                is_writing <= 1;
                state <= PULL_WRN;
            end

            default: begin
                /* IDLE */
            end
        endcase
    end
end

endmodule
