//ALU

`include "constants_cpu.vh"

module ex(

	input wire	rst,
	
	
	input wire[`AluOpBus]         aluop_i,//ALU控制信号
	input wire[`RegBus]           reg1_i,
	input wire[`RegBus]           reg2_i,
	input wire[`RegAddrBus]       wd_i,
	input wire                    wreg_i,

	
	output reg[`RegAddrBus]       wd_o,
	output reg                    wreg_o,
	output reg[`RegBus]			  wdata_o
	
);

always_comb begin
    if (rst == 1'b1) begin
        wdata_o <= `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_OR_OP:begin
                wdata_o <= reg1_i | reg2_i;
            end
            default:begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end   
end 


always_comb begin
    wd_o <= wd_i;	 	 	
    wreg_o <= wreg_i;
end	

endmodule