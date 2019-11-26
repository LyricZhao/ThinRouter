/*
ctrl模块：
    接受流水线暂停请求和控制流水线暂停
*/

`include "cpu_defs.vh"

module ctrl(
    input  logic        rst,
	
    input  logic        stallreq_from_id,   // 从id来的暂停请求
    input  logic        stallreq_from_ex,   // 从ex来的暂停请求
    input  logic        stallreq_from_mem,  // 从mem来的暂停请求

    output stall_t      stall               // 给几个模块的暂停信号
);

always_comb begin
    if (rst == 1) begin
        stall <= '{default: '0};
    end else begin
        stall.pc <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.ifetch <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.id <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.ex <= stallreq_from_mem || stallreq_from_ex;
        stall.mem <= 0;
        stall.wb <= 0;
    end
end

endmodule