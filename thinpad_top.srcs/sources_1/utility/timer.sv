/*
硬件计时器

接入 10M0592 时钟，输出毫秒计时和秒计时
*/

`timescale 1ns / 1ps

module timer #(
    parameter FREQ = 11_059_200,    // 默认 11M0592 时钟
    parameter OUTPUT_WIDTH = 16     // 最多 65535s
) (
    input  logic clk,
    input  logic rst_n,
    output logic [9:0] millisecond,
    output logic [OUTPUT_WIDTH-1:0] second
);

// 每毫秒的 clk 数量
localparam MS_FREQ = FREQ / 1000;
reg [$clog2(MS_FREQ):0]    cnt = '0;

// 异步清零
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        millisecond <= '0;
        second <= '0;
        cnt <= '0;
    end else begin
        if (cnt == MS_FREQ - 1) begin
            cnt <= 0;
            if (millisecond == 999) begin
                millisecond <= 0;
                second <= second + 1;
            end else begin
                millisecond <= millisecond + 1;
            end
        end else begin
            cnt <= cnt + 1;
        end
    end
end

endmodule