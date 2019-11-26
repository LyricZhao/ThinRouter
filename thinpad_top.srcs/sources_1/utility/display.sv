/*
console 屏幕输出
*/
`timescale 1ns / 1ps

module display (
    input  logic clk_50M,
    input  logic clk_write,         // 写入字符的时钟
    input  logic [6:0] char_write,  // 写入字符
    input  logic write_en,          // 高电平同步写入
    input  logic rst_n,
    output logic[2:0] video_red,    // 红色像素，3位
    output logic[2:0] video_green,  // 绿色像素，3位
    output logic[1:0] video_blue,   // 蓝色像素，2位
    output logic video_hsync,       // 行同步（水平同步）信号
    output logic video_vsync,       // 场同步（垂直同步）信号
    output logic video_clk,         // 像素时钟输出
    output logic video_de           // 行数据有效信号，用于区分消隐区
);


// 写入字符
logic [6:0] char_write;
// 写入
logic write_en;

////// 扫描屏幕的信息
// 扫描坐标
logic [10:0] x_scan;
logic [9:0] y_scan;
// 读取字符横坐标
logic [6:0] x_read;
// 读取字符纵坐标
logic [5:0] y_read;
// 正在显示字符像素横坐标
logic [3:0] x_pix;
// 正在显示字符像素纵坐标
logic [4:0] y_pix;
// 是字符显示区域
wire valid = x_scan >= 11 && x_scan <= 788 && y_scan >= 13 && y_scan <= 586 && !x_pix[3] && !y_pix[4];

// 读取到的字符
logic [6:0] char_read;

// 传递给字符矩阵的同步数据
typedef struct packed {
    // 当前像素在显示字符的区域
    logic valid;
    // 屏幕扫描横坐标
    logic [10:0] x_scan;
    // 屏幕扫描纵坐标
    logic [9:0] y_scan;
    // 字符横坐标
    logic [2:0] x_pix;
    // 字符纵坐标
    logic [3:0] y_pix;
} char_matrix_sync_t;
char_matrix_sync_t char_matrix_sync_out;
// 字符矩阵
char_matrix #(
    .SYNC_TYPE(char_matrix_sync_t)
) char_matrix_inst (
    .clk_write,
    .char_write,
    .write_en,

    .clk_read(clk_50M),
    .x_read,
    .y_read,
    .char_read,

    .sync_in('{valid, x_scan, y_scan, x_pix[2:0], y_pix[3:0]}),
    .sync_out(char_matrix_sync_out),

    .rst_n
);

// 传递给字体模块的同步数据
typedef struct packed {
    // 当前像素在显示字符的区域
    logic valid;
    // 屏幕扫描横坐标
    logic [10:0] x_scan;
    // 屏幕扫描纵坐标
    logic [9:0] y_scan;
    logic [6:0] ch;
} font_sync_t;
font_sync_t font_sync_out;
// 根据字体，指定像素是否为白
logic font_result;
// 字体加载器
font #(
    .SYNC_TYPE(font_sync_t)
) font_inst (
    .clk(clk_50M),
    .char_in(char_read),
    .x(char_matrix_sync_out.x_pix),
    .y(char_matrix_sync_out.y_pix),
    .sync_in('{valid, char_matrix_sync_out.x_scan, char_matrix_sync_out.y_scan, char_read}),
    .result(font_result),
    .sync_out(font_sync_out)
);

// 循环累加
`define INCR(x, mod) \
    if (x == mod) \
        x <= 1; \
    else if (x == mod - 1) \
        x <= 0; \
    else \
        x <= x + 1'b1;

// 遍历每个像素
always_ff @ (posedge clk_50M) begin
    if (!rst_n) begin
        x_scan <= 0;
        y_scan <= 0;
        x_read <= 102;
        y_read <= 36;
        x_pix <= 8;
        y_pix <= 5;
    end else begin
        // 扫描至下一个像素
        `INCR(x_pix, 10)
        if (x_pix == 8) begin
            `INCR(x_read, 104)
        end
        `INCR(x_scan, 1040)
        if (x_scan == 1039) begin
            `INCR(y_scan, 666)
            `INCR(y_pix, 18)
            if (y_pix == 17) begin
                `INCR(y_read, 37);
            end
        end
    end
end

//图像输出演示，分辨率800x600@75Hz，像素时钟为50MHz
assign video_clk = clk_50M;
assign {video_red, video_green, video_blue} = (font_sync_out.valid && font_result) ? '1 : '0;
vga #(800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(clk_50M), 
    .hdata(font_sync_out.x_scan), //横坐标
    .vdata(font_sync_out.y_scan), //纵坐标
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);

endmodule