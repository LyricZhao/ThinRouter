`include "cpu_defs.vh"

module addr_ctrl(
    input  logic                    rst,

    input  logic                    inst_ce,
    input  inst_t                   inst_addr,
    
    input  logic                    data_ce,
    input  logic                    data_we,
    input  inst_t                   data_addr,
    input  sel_t                    data_sel,
    input  word_t                   data_data_w,

    output word_t                   ram_addr,
    output word_t                   ram_data_w,
    output logic                    ram_we,
    output sel_t                    ram_sel,
    output logic                    ram_ce
);

always_comb begin
    if (rst) begin

    end else begin
        
    end
end