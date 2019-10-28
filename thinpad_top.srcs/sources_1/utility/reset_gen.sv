/*
赵成钢：
通过分频的稳定信号locked和用户的按键生成rst_n信号
*/

module reset_gen (
    input logic clk,
    input logic locked,     // 分频器是否稳定
    input logic reset_btn,  // 用户按键
    
    output logic rst_n
);

always_ff @(posedge clk) begin
    if (locked == 1 && reset_btn == 0) begin
        rst_n <= 1;
    end else begin
        rst_n <= 0;
    end
end

endmodule