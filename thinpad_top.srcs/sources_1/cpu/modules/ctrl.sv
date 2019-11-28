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

    input  word_t       except_type_i,      // 异常类型
    input  word_t       cp0_epc_i,          // CP0的EPC寄存器

    output addr_t       new_pc,             // 新PC地址
    output logic        flush,              // 是否清除流水线

    output stall_t      stall               // 给几个模块的暂停信号
);

always_comb begin
    if (rst == 1) begin
        stall <= '{default: '0};
    end else if (except_type_i) begin
        flush <= 1;
        stall <= '{default: '0};
        case (except_type_i) // TODO: 这里的地址写什么
            32'h1: begin
                new_pc <= 32'h20;
            end
            32'h8: begin
                new_pc <= 32'h40;
            end
            32'ha: begin
                new_pc <= 32'h40;
            end
            32'hd: begin
                new_pc <= 32'h40;
            end
            32'hc: begin
                new_pc <= 32'h40;
            end
            32'he: begin
                new_pc <= cp0_epc_i; // 异常返回
            end
            default: begin end
        endcase
    end else begin
        stall.pc <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.ifetch <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.id <= stallreq_from_mem || stallreq_from_ex || stallreq_from_id;
        stall.ex <= stallreq_from_mem || stallreq_from_ex;
        stall.mem <= 0;
        stall.wb <= 0;
        flush <= 0;
    end
end

endmodule