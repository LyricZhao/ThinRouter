/*
IF/ID模块：
    暂时保存取指(Fetch)阶段取得的指令和地址，在下一个时钟传递给译码(Decode)阶段
*/

`include "cpu_defs.vh"

module if_id(
    input  logic            clk,
    input  logic            rst,
	
    input  inst_addr_t      if_pc,      // if得到的pc
    input  word_t           if_inst,    // if得到的地址
    output inst_addr_t      id_pc,      // 传给id的pc
    output word_t           id_inst     // 传给id的指令
);

always_ff @ (posedge clk) begin
    if (rst == 1'b1) begin
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
    end else begin
        id_pc <= if_pc;
        id_inst <= if_inst;
    end
end

endmodule