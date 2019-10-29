
`include "constants_cpu.vh"

module ex(

	input wire	rst,
	
	
	input wire[`AluOpBus]         aluop_i,
	input wire[`AluSelBus]        alusel_i,
	input wire[`RegBus]           reg1_i,
	input wire[`RegBus]           reg2_i,
	input wire[`RegAddrBus]       wd_i,
	input wire                    wreg_i,

	
	output reg[`RegAddrBus]       wd_o,
	output reg                    wreg_o,
	output reg[`RegBus]			  wdata_o
	
);

	reg[`RegBus] logicout;
	always @ (*) begin
		if(rst == `RstEnable) begin
			logicout <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_OR_OP:begin
					logicout <= reg1_i | reg2_i;
				end
				default:begin
					logicout <= `ZeroWord;
				end
			endcase
		end   
	end 


    always @ (*) begin
        wd_o <= wd_i;	 	 	
        wreg_o <= wreg_i;
        case ( alusel_i ) 
            `EXE_RES_LOGIC:begin
                wdata_o <= logicout;
            end
            default:begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end	

endmodule