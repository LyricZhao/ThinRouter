/*
ctrl模块：
    接受流水线暂停请求和控制流水线暂停
*/

`include "cpu_defs.vh"

module ctrl(
    input  logic        rst,
	
    input  logic        stallreq_from_id,   // 从id来的暂停请求
    input  logic        stallreq_from_ex,   // 从ex来的暂停请求

    output stall_t      stall     // 给几个模块的暂停信号
);

always_comb begin
    if (rst == 1) begin
        stall <= 6'b000000;
    end else if (stallreq_from_ex) begin
        stall <= 6'b001111; // pc保持, 取值暂停, 译码暂停, 执行暂停
    end else if (stallreq_from_id) begin
        stall <= 6'b000111; // pc保持, 取值暂停, 译码暂停
    end else begin
        stall <= 6'b000000;
    end
end

endmodule