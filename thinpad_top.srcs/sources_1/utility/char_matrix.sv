/*
78x32 的 ASCII (0-127) 字符矩阵
时钟1，按输入顺序输入字符，支持换行等
时钟2，给定位置获取字符

输入控制字符:
0x00: clear screen
0x0A: \r
0x0D: \n
0x7F: backspace

读取需要一拍的时间

同步信号：
虽然出入数据有延迟，同步信号与出入数据一定是一一匹配的
*/
module char_matrix #(
    parameter type SYNC_TYPE
)(
    // 写入的时钟
    input logic clk_write,
    // 写入字符，可以是控制字符
    input logic [6:0] char_write,
    // 写入
    input logic write_en,

    // 读取的时钟
    input logic clk_read,
    // 读取字符横坐标
    input logic [6:0] x_read,
    // 读取字符纵坐标
    input logic [4:0] y_read,
    // 读取时的 vga 同步数据
    input SYNC_TYPE sync_in,
    // 读取到的字符
    output logic [6:0] char_read,
    // 得到读取字符时的 vga 同步数据
    output SYNC_TYPE sync_out,

    input logic rst_n
);

// 下一个字符写入的横坐标
logic [6:0] x_write;
// 下一个字符写入的纵坐标
logic [4:0] y_write;
// 行的长度
logic [6:0] line_length [31:0];
// 屏幕已满，正在滚动
logic rolling;
// 滚动行数
logic [4:0] line_roll;
// 实际读取纵坐标
logic [4:0] y_read_real = y_read + line_roll;
// 读取出来的字符
logic [6:0] char_mem_out;

assign char_read = x_read < line_length[y_read] ? char_mem_out : '0;
always_ff @ (posedge clk_read)
    sync_out <= sync_in;

xpm_memory_sdpram #(
    .ADDR_WIDTH_A(12),
    .ADDR_WIDTH_B(12),
    .CLOCKING_MODE("independent_clock"),
    .MEMORY_SIZE(78 * 32 * 7),
    .READ_DATA_WIDTH_B(7),
    .READ_LATENCY_B(1),
    .USE_MEM_INIT(0),
    .WRITE_DATA_WIDTH_A(7)
) memory_inst (
    .addra({x_write, y_write}),
    .addrb({x_read, y_read_real}),
    .clka(clk_write),
    .clkb(clk_read),
    .dina(char_write),
    .doutb(char_mem_out),
    .ena(1),
    .enb(1),
    .wea(write_en)
);

always_ff @ (posedge clk_write) begin
    if (!rst_n) begin
        line_length <= '{default: 0};
        x_write <= 0;
        y_write <= 0;
        rolling <= 0;
        line_roll <= 0;
    end else if (write_en) begin
        case (char_write)
            // clear screen
            7'h00: begin
                line_length <= '{default: 0};
                x_write <= 0;
                y_write <= 0;
                rolling <= 0;
                line_roll <= 0;
            end
            // \r
            7'h0a: begin
                line_length[y_write] <= 0;
                x_write <= 0;
            end
            // \n
            7'h0d: begin
                line_length[y_write + 1'b1] <= 0;
                x_write <= 0;
                y_write <= y_write + 1'b1;
                if (y_write == 31) begin
                    rolling <= 1;
                    line_roll <= 1;
                end else if (rolling) begin
                    line_roll <= line_roll + 1'b1;
                end
            end
            // backspace
            7'h7f: begin
                x_write <= line_length[y_write - 1'b1] - 1'b1;
                y_write <= y_write - 1'b1;
                if (rolling) begin
                    line_roll <= line_roll - 1'b1;
                end
            end
            // 可见字符
            default: begin
                if (x_write == 77) begin
                    x_write <= 0;
                    line_length[y_write] <= 78;
                    line_length[y_write + 1'b1] <= 0;
                    y_write <= y_write + 1'b1;
                    if (y_write == 31) begin
                        rolling <= 1;
                        line_roll <= 1;
                    end else if (rolling) begin
                        line_roll <= line_roll + 1'b1;
                    end
                end else begin
                    x_write <= line_length[y_write];
                    line_length[y_write] <= line_length[y_write] + 1;
                end
            end
        endcase
    end
end

endmodule