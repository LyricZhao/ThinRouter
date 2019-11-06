/*
comm_reg:
    实现了32个32位的通用寄存器，同时可以对两个寄存器进行读操作，对一个寄存器进行写
    该模块是译码阶段的一部分
*/

`include "cpu_defs.vh"

module comm_reg(
    input  logic            clk,
    input  logic            rst,
	
    input  logic            we,     // 写寄存器使能
    input  reg_addr_t       waddr,  // 写寄存器的编号
    input  word_t           wdata,  // 写入的数据
	
    input  reg_addr_t       raddr1, // 读寄存器1的地址
    input  reg_addr_t       raddr2, // 读寄存器2的地址
    
    output word_t           rdata1, // 读出来1的数据
    output word_t           rdata2  // 读出来2的数据
);

word_t regs[0:`REG_NUM-1];

// 清零逻辑
genvar i;
generate
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        always_ff @ (posedge clk) begin
            if (rst == 1) begin
                regs[i] <= 0;
            end
        end
    end
endgenerate

// 同步写入
always_ff @ (posedge clk) begin
    if (rst == 0) begin
        if ((we == 1) && (waddr != 0)) begin
            regs[waddr] <= wdata;
        end
    end
end

// 下面两个读是异步的组合逻辑，下面的数据前传解决了相隔2个指令的数据冲突
always_comb begin
    if (rst == 1) begin
        rdata1 <= 0;
    end else if (raddr1 == 0) begin // 如果读0号寄存器
        rdata1 <= 0;
    end else if ((raddr1 == waddr) && (we == 1)) begin // 如果读的寄存器正准备被写，直接读即将被写的值（数据前传）
        rdata1 <= wdata;
    end else begin
        rdata1 <= regs[raddr1];
    end
end

always_comb begin
    if (rst == 1) begin
        rdata2 <= 0;
    end else if (raddr2 == 0) begin // 如果读0号寄存器
        rdata2 <= 0;
    end else if ((raddr2 == waddr) && (we == 1)) begin // 如果读的寄存器正准备被写，直接读即将被写的值（数据前传）
        rdata2 <= wdata;
    end else begin
        rdata2 <= regs[raddr2];
    end
end

endmodule