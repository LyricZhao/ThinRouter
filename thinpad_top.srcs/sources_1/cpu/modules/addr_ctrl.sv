/*
地址控制器：
    cpu是Harvard结构的，需要转换为Neumann结构
*/

`include "cpu_defs.vh"

module addr_ctrl(
    input  logic                    rst,

    input  logic                    inst_ce,        // inst访问使能
    input  addr_t                   inst_addr,      // inst访问地址
    
    input  logic                    mem_ce,         // 访存访问使能
    input  logic                    mem_we,         // 访存写使能
    input  addr_t                   mem_addr,       // 访存访问地址
    input  sel_t                    mem_sel,        // 访存字节使能
    input  word_t                   mem_data_w,     // 访存写的数据

    input  word_t                   ram_data_r,     // ram中读到的数据

    output word_t                   ram_addr,       // ram要访问的地址
    output word_t                   ram_data_w,     // ram要写的数据
    output logic                    ram_we,         // ram写使能
    output sel_t                    ram_sel,        // ram字节使能
    output logic                    ram_ce,         // ram访问使能

    output word_t                   inst_data_r,    // 从ram读到的inst
    output word_t                   mem_data_r      // 从ram读到的data
);

always_comb begin
    if (rst) begin
        {ram_addr, ram_data_w, ram_we, ram_sel, ram_ce, inst_data_r, mem_data_r} <= 0;
    end else begin
        if (mem_ce) begin // 优先访存
            ram_addr <= mem_addr;
            ram_data_w <= mem_data_w;
            ram_we <= mem_we;
            ram_sel <= mem_sel;
            ram_ce <= 1;
            inst_data_r <= 0;
            mem_data_r <= ram_data_r;
        end else if (inst_ce) begin
            ram_addr <= inst_addr;
            {ram_data_w, ram_we} <= 0;
            ram_sel <= 4'b1111;
            ram_ce <= 1;
            inst_data_r <= ram_data_r;
            mem_data_r <= 0;
        end else begin
            {ram_addr, ram_data_w, ram_we, ram_sel, ram_ce, inst_data_r, mem_data_r} <= 0;
        end
    end
end

endmodule