/*
cp0模块：
    0号协处理器
*/

`include "cpu_defs.vh"

module cp0(
    input  logic                    clk,
    input  logic                    rst,
	
    input  logic                    we_i,
    input  reg_addr_t               waddr_i,
    input  reg_addr_t               raddr_i,
    input  word_t                   data_i,
    input  logic[`NUM_DEVICES-1:0]  int_i,

    output word_t                    data_o,
    output word_t                    count_o,
    output word_t                    compare_o,
    output word_t                    status_o,
    output word_t                    cause_o,
    output word_t                    epc_o,
    output word_t                    config_o,
    output word_t                    prid_o,
    output logic                     timer_int_o,
);

always_comb begin
end

endmodule