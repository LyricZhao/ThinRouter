/*
DataROM:
    一个简单的数据储存器
*/

`include "cpu_defs.vh"

module data_ram(
    input  logic            clk,
    input  logic            ce,
    input  logic            we,
    input  word_t           addr,
    input  logic[3:0]       sel,
    input  word_t           data_i,

    output word_t           data_o
);

byte_t data_mem0[0:`DATA_MEM_NUM-1];
byte_t data_mem1[0:`DATA_MEM_NUM-1];
byte_t data_mem2[0:`DATA_MEM_NUM-1];
byte_t data_mem3[0:`DATA_MEM_NUM-1];

always_ff @ (posedge clk) begin
    if(ce == 1 && we == 1) begin
        if (sel[3] == 1) begin
            data_mem3[addr[`DATA_MEM_NUM_LOG2+1:2]] <= data_i[31:24];
        end
        if (sel[2] == 1) begin
            data_mem2[addr[`DATA_MEM_NUM_LOG2+1:2]] <= data_i[23:16];
        end
        if (sel[1] == 1) begin
            data_mem1[addr[`DATA_MEM_NUM_LOG2+1:2]] <= data_i[15:8];
        end
        if (sel[0] == 1) begin
            data_mem0[addr[`DATA_MEM_NUM_LOG2+1:2]] <= data_i[7:0];
        end
    end
end

always_comb begin
    if (ce == 0) begin
        data_o <= 0;
    end else if(we == 0) begin
        data_o <= {data_mem3[addr[`DATA_MEM_NUM_LOG2+1:2]],
                data_mem2[addr[`DATA_MEM_NUM_LOG2+1:2]],
                data_mem1[addr[`DATA_MEM_NUM_LOG2+1:2]],
                data_mem0[addr[`DATA_MEM_NUM_LOG2+1:2]]};
    end else begin
        data_o <= 0;
    end
end

endmodule