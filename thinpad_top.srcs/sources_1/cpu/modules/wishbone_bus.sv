/*
Wishbone总线模块，感觉似乎没什么用，因为sram没有ack信号，所以先不接wishbone
*/

`include "cpu_defs.vh"

module wishbone_bus(

    input logic              clk,
    input logic              rst,

    //来自ctrl模块的信号
    input stall_t           stall_i,
    input logic             flush_i,

    //CPU侧的接口
    input logic              cpu_ce_i,
    input word_t            cpu_data_i,
    input word_t            cpu_addr_i,
    input logic              cpu_we_i,
    input logic[3:0]         cpu_sel_i,
    output word_t           cpu_data_o,

    //Wishbone侧的接口
    input word_t            wishbone_data_i,
    input logic             wishbone_ack_i,
    output word_t           wishbone_addr_o,
    output word_t           wishbone_data_o,
    output logic            wishbone_we_o,
    output logic[3:0]       wishbone_sel_o,
    output logic            wishbone_stb_o,
    output logic            wishbone_cyc_o,

    output logic            stallreq	       
	
);

logic[1:0] wishbone_state;
word_t rd_buf;

always_ff @ (posedge clk) begin
    if(rst == 1) begin
        wishbone_state <= `WB_IDLE;
        wishbone_addr_o <= 0;
        wishbone_data_o <= 0;
        wishbone_we_o <= `WriteDisable;
        wishbone_sel_o <= 4'b0000;
        wishbone_stb_o <= 1'b0;
        wishbone_cyc_o <= 1'b0;
        rd_buf <= 0;
        // cpu_data_o <= `ZeroWord;
    end else begin
        case (wishbone_state)
            `WB_IDLE: begin
                if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
                    wishbone_stb_o <= 1'b1;
                    wishbone_cyc_o <= 1'b1;
                    wishbone_addr_o <= cpu_addr_i;
                    wishbone_data_o <= cpu_data_i;
                    wishbone_we_o <= cpu_we_i;
                    wishbone_sel_o <=  cpu_sel_i;
                    wishbone_state <= `WB_BUSY;
                    rd_buf <= `ZeroWord;
                // end else begin
                // 	wishbone_state <= WB_IDLE;
                // 	wishbone_addr_o <= `ZeroWord;
                // 	wishbone_data_o <= `ZeroWord;
                // 	wishbone_we_o <= `WriteDisable;
                // 	wishbone_sel_o <= 4'b0000;
                // 	wishbone_stb_o <= 1'b0;
                // 	wishbone_cyc_o <= 1'b0;
                // 	cpu_data_o <= `ZeroWord;			
                end							
            end
            `WB_BUSY: begin
                if(wishbone_ack_i == 1'b1) begin
                    wishbone_stb_o <= 1'b0;
                    wishbone_cyc_o <= 1'b0;
                    wishbone_addr_o <= `ZeroWord;
                    wishbone_data_o <= `ZeroWord;
                    wishbone_we_o <= `WriteDisable;
                    wishbone_sel_o <=  4'b0000;
                    wishbone_state <= `WB_IDLE;
                    if(cpu_we_i == `WriteDisable) begin
                        rd_buf <= wishbone_data_i;
                    end
                    if(stall_i != 6'b000000) begin
                        wishbone_state <= `WB_WAIT_FOR_STALL;
                    end					
                end else if(flush_i == `True_v) begin
                    wishbone_stb_o <= 1'b0;
                    wishbone_cyc_o <= 1'b0;
                    wishbone_addr_o <= `ZeroWord;
                    wishbone_data_o <= `ZeroWord;
                    wishbone_we_o <= `WriteDisable;
                    wishbone_sel_o <=  4'b0000;
                    wishbone_state <= `WB_IDLE;
                    rd_buf <= `ZeroWord;
                end
            end
            `WB_WAIT_FOR_STALL: begin
                if(stall_i == 6'b000000) begin
                    wishbone_state <= `WB_IDLE;
                end
            end
            default: begin
            end 
        endcase
    end
end

always_comb begin
    if(rst == 1) begin
        stallreq <= `NoStop;
        cpu_data_o <= `ZeroWord;
    end else begin
        stallreq <= `NoStop;
        case (wishbone_state)
            `WB_IDLE: begin
                if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
                    stallreq <= `Stop;
                    cpu_data_o <= `ZeroWord;				
                end
            end
            `WB_BUSY: begin
                if(wishbone_ack_i == 1'b1) begin
                    stallreq <= `NoStop;
                    if(wishbone_we_o == `WriteDisable) begin
                        cpu_data_o <= wishbone_data_i;  //????
                    end else begin
                        cpu_data_o <= `ZeroWord;
                    end					
                end else begin
                    stallreq <= `Stop;	
                    cpu_data_o <= `ZeroWord;				
                end
            end
            `WB_WAIT_FOR_STALL: begin
                stallreq <= `NoStop;
                cpu_data_o <= rd_buf;
            end
            default: begin
            end 
        endcase
    end
end
endmodule