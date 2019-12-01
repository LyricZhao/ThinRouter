/*
cp0模块：
    0号协处理器

需要实现的（具体参见MIPS32文档）：
    EBASE:
        [31:30]: 10
        [29:12]: Exception Base （可写）
        [11:10]: 00
        [ 9: 0]: CPUNum （可写，这个用于多核处理器）

    CAUSE:
        [31,31]: BD（是否在延迟槽）
        [15:10]: IP（硬件中断）
        [ 6: 2]: Exception Code

    Status:
        [15:10]: IM（Interrupt Mask，是否屏蔽中断）
        [ 1: 1]: EXL（Exception Level）
        [ 0: 0]: IE（Interrupt Enable）
*/

`include "cpu_defs.vh"

module cp0(
    input  logic                    clk,
    input  logic                    rst,
	
    input  logic                    we_i,                   // 是否要写寄存器
    input  reg_addr_t               waddr_i,                // 要写的寄存器的编号
    input  reg_addr_t               raddr_i,                // 要读的寄存器的编号
    input  word_t                   data_i,                 // 要写入的值
    input  int_t                    int_i,                  // 外部硬件的中断

    input  word_t                   except_type_i,          // 最终的异常类型
    input  addr_t                   current_inst_addr_i,    // 当前指令地址
    input  logic                    in_delayslot_i,         // 是否在延迟槽

    output word_t                   data_o,                 // 读出的寄存器的值
    output word_t                   ebase_o,                // EBase寄存器
    output word_t                   status_o,               // Status寄存器
    output word_t                   cause_o,                // Cause寄存器
    output word_t                   epc_o                   // EPC寄存器
);

`define EPC_CAUSE_SET           if (in_delayslot_i) begin \
                                    epc_o <= current_inst_addr_i - 4; \
                                    cause_o[31] <= 1; \
                                end else begin \
                                    epc_o <= current_inst_addr_i; \
                                    cause_o[31] <= 0; \
                                end //

always @(posedge clk) begin
    if (rst) begin
        {cause_o, epc_o} <= 0;
        ebase_o  <= 32'h80001000;
        status_o <= 32'b10000000; // CU字段为0001表示CP0存在
    end else begin
        cause_o[15:10] <= int_i;

        if (we_i) begin
            case (waddr_i)
                `CP0_REG_STATUS: begin
                    status_o <= data_i;
                end
                `CP0_REG_EPC: begin
                    epc_o <= data_i;
                end
                `CP0_REG_CAUSE: begin
                    cause_o[9:8] <= data_i[9:8];
                    cause_o[23:22] <= data_i[23:22];
                end
                `CP0_REG_EBASE: begin
                    ebase_o[29:12] <= data_i[29:12];
                end
                default: begin end
            endcase
        end

        case (except_type_i)
            `EXC_INTERRUPT: begin
                `EPC_CAUSE_SET;
                status_o[1] <= 1;
                cause_o[6:2] <= 5'b00000;
            end
            `EXC_SYSCALL: begin
                if (status_o[1] == 0) begin // 不能嵌套异常
                    `EPC_CAUSE_SET;
                end
                status_o[1] <= 1;
                cause_o[6:2] <= 5'b01000;
            end
            `EXC_OVERFLOW: begin
                if (status_o[1] == 0) begin
                    `EPC_CAUSE_SET;
                end
                status_o[1] <= 1;
                cause_o[6:2] <= 5'b01100;
            end
            `EXC_ERET: begin
                status_o[1] <= 0;
            end
            default: begin end
        endcase
    end
end

always_comb begin
    if (rst) begin
        data_o <= 0;
    end else begin
        case (raddr_i)
            `CP0_REG_STATUS: begin
                data_o <= status_o;
            end
            `CP0_REG_CAUSE: begin
                data_o <= cause_o;
            end
            `CP0_REG_EPC: begin
                data_o <= epc_o;
            end
            `CP0_REG_EBASE: begin
                data_o <= {2'b00, ebase_o[29:12], 2'b00, ebase_o[9:0]};
            end
            default: begin
                data_o <= 0;
            end
        endcase
    end
end

endmodule