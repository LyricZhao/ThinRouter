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
    input  word_t       cp0_ebase_i,        // CP0的EBase寄存器

    output addr_t       new_pc,             // 新PC地址
    output logic        flush,              // 是否清除流水线

    output stall_t      stall               // 给几个模块的暂停信号
);

always_comb begin
    if (rst == 1) begin
        stall <= '{default: '0};
        {flush, new_pc} <= 0;
    end else if (except_type_i) begin
        flush <= 1;
        stall <= '{default: '0};
        case (except_type_i) // 所有的异常处理都在0x80001180
            32'h00000001: begin
                new_pc <= cp0_ebase_i + 32'h180;  // interrupt
            end
            32'h00000004: begin
                new_pc <= cp0_ebase_i + 32'h180;  // AdEL
            end
            32'h00000005: begin
                new_pc <= cp0_ebase_i + 32'h180;  // AdES
            end
            32'h00000008: begin
                new_pc <= cp0_ebase_i + 32'h180;  // syscall
            end
            32'h0000000a: begin
                new_pc <= cp0_ebase_i + 32'h180;  // invalid instruction
            end
            32'h0000000d: begin
                new_pc <= cp0_ebase_i + 32'h180;  // break
            end
            32'h0000000c: begin
                new_pc <= cp0_ebase_i + 32'h180;  // overflow
            end
            32'h0000000e: begin
                // $display("%x", cp0_epc_i);
                new_pc <= cp0_epc_i;              // eret
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