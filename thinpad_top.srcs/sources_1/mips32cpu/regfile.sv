
`include "constants_cpu.vh"

module regfile(

	input wire clk,
	input wire rst,
	
	input wire we,
	input wire[`RegAddrBus] waddr,
	input wire[`RegBus]	wdata,
	
	input wire[`RegAddrBus] raddr1,
	output reg[`RegBus] rdata1,
	
	input wire[`RegAddrBus] raddr2,
	output reg[`RegBus] rdata2
	
);

reg[`RegBus]  regs[0:`RegNum-1];

always_ff @ (posedge clk) begin
    if (rst == 1'b0) begin
        if ((we == 1'b1) && (waddr != 5'h0)) begin
            regs[waddr] <= wdata;
        end
    end
end

always_comb begin
    if (rst == 1'b1) begin
        rdata1 <= `ZeroWord;
    end else if (raddr1 == 5'h0) begin //如果读0号寄存器
        rdata1 <= `ZeroWord;
    end else if ((raddr1 == waddr) && (we == 1'b1)) begin //如果读的寄存器正准备被写，直接读即将被写的值
        rdata1 <= wdata;      
    end else begin
        rdata1 <= regs[raddr1];
    end
end

always_comb begin
    if (rst == 1'b1) begin
        rdata2 <= `ZeroWord;
    end else if (raddr2 == 5'h0) begin //如果读0号寄存器
        rdata2 <= `ZeroWord;
    end else if ((raddr2 == waddr) && (we == 1'b1)) begin //如果读的寄存器正准备被写，直接读即将被写的值（数据前传）
        rdata2 <= wdata;
    end else begin
        rdata2 <= regs[raddr2];
    end
end

endmodule