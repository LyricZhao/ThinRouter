/*
cp0模块：
    0号协处理器
*/

`include "cpu_defs.vh"

module cp0(
    input  logic                    clk,
    input  logic                    rst,
	
    input  logic                    we_i,           // 是否要写寄存器
    input  reg_addr_t               waddr_i,        // 要写的寄存器的编号
    input  reg_addr_t               raddr_i,        // 要读的寄存器的编号
    input  word_t                   data_i,         // 要写入的值
    input  logic[`NUM_DEVICES-1:0]  int_i,          // 外部硬件的中断

    output word_t                   data_o,         // 读出的寄存器的值
    output word_t                   count_o,        // Count寄存器
    output word_t                   compare_o,      // Compare寄存器
    output word_t                   status_o,       // Status寄存器
    output word_t                   cause_o,        // Cause寄存器
    output word_t                   epc_o,          // EPC寄存器
    output word_t                   config_o,       // Config寄存器
    output word_t                   prid_o,         // PRId寄存器
    output logic                    timer_int_o     // 是否有定时中断
);

always @(posedge clk) begin
    if (rst) begin
        {count_o, compare_o, cause_o, epc_o, timer_int_o} <= 0;
        status_o <= 32'b00010000000000000000000000000000; // CU字段为0001表示CP0存在
        config_o <= 32'b00000000000000000000000000000000; // BE字段为0表示小端模式
        prid_o   <= 32'b00000000010011000000000100000010; // PRId寄存器 Company Options/Company ID/CPU ID/Revision
    end else begin
        count_o <= count_o + 1;
        cause_o[15:10] <= int_i;

        if (compare_o != 0 && count_o == compare_o) begin
            timer_int_o <= 1;
        end

        if (we_i) begin
            case (waddr_i)
                `CP0_REG_COUNT: begin
                    count_o <= data_i;
                end
                `CP0_REG_COMPARE: begin
                    compare_o <= data_i;
                    timer_int_o <= 0;
                end
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
                default: begin end
            endcase
        end
    end
end

always_comb begin
    if (rst) begin
        data_o <= 0;
    end else begin
        case (raddr_i)
            `CP0_REG_COUNT: begin
                data_o <= count_o;
            end
            `CP0_REG_COMPARE: begin
                data_o <= compare_o;
            end
            `CP0_REG_STATUS: begin
                data_o <= status_o;
            end
            `CP0_REG_CAUSE: begin
                data_o <= cause_o;
            end
            `CP0_REG_EPC: begin
                data_o <= epc_o;
            end
            `CP0_REG_PRId: begin
                data_o <= prid_o;
            end
            `CP0_REG_CONFIG: begin
                data_o <= config_o;
            end
            default: begin end
        endcase
    end
end

endmodule