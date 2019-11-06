/*
CPU顶层设计：
    把所有模块都连接起来，模块实在很多线也很多，重构了一遍，所有的命名统一以(模块_出去的线)命名
    如果想知道有谁接入了某个模块，可以搜索：给xx模块，如：搜索“给if_id”可搜到所有到if_id的连线
    每个线是干嘛的请翻阅对于模块的定义
*/

`include "cpu_defs.vh"

module cpu_top(
    input  logic            clk,
    input  logic            rst,

    input  word_t           rom_data_i,
    output inst_addr_t      rom_addr_o,
    output logic            rom_ce_o
);

/* ---------------- 模块出线 ----------------- */

/** pc_reg的出线 **/
// pc_reg给rom和给if_id的连线
inst_addr_t pc_reg_pc;
// pc_reg给rom的连线
logic pc_reg_ce;


/** rom的出线 **/
// rom给if_id的连线: 
// rom_data_i，也就是ROM读进来的指令，在接口处已经声明了


/** comm_reg的出线 **/
// comm_reg给id的连线
word_t comm_reg_rdata1, comm_reg_rdata2;


/** hilo_reg的出线 **/
// hilo_reg给ex的连线
word_t hilo_reg_hi_o, hilo_reg_lo_o;


/** ctrl的出线 **/
// ctrl给ex_mem、给id_ex、给if_id、给mem_wb、给pc_reg的连线
stall_t ctrl_stall;


/** if_id的出线 **/
// if_id给id的连线
inst_addr_t if_id_id_pc;
word_t if_id_id_inst;


/** id的出线 **/
// id给comm_reg的连线
reg_addr_t id_reg1_addr_o, id_reg2_addr_o;
// id给id_ex的连线
aluop_t id_aluop_o;
word_t id_reg1_o, id_reg2_o;
reg_addr_t id_wd_o;
logic id_wreg_o;
// id给ctrl的连线
logic id_stallreq_o;


/** id_ex的出线 **/
// id_ex给ex的连线
aluop_t id_ex_ex_aluop;
word_t id_ex_ex_reg1, id_ex_ex_reg2;
reg_addr_t id_ex_ex_wd;
logic id_ex_ex_wreg;


/** ex的出线 **/
// ex给id（数据回传）和给ex_mem的连线
reg_addr_t ex_wd_o;
logic ex_wreg_o;
word_t ex_wdata_o;
// ex给ex_mem的连线
word_t ex_hi_o, ex_lo_o;
logic ex_whilo_o;
// ex给ctrl的连线
logic ex_stallreq_o;


/** ex_mem的出线 **/
// ex_mem给mem的连线
word_t ex_mem_mem_hi, ex_mem_mem_lo;
logic ex_mem_mem_whilo;
reg_addr_t ex_mem_mem_wd;
logic ex_mem_mem_wreg;
word_t ex_mem_mem_wdata;


/** mem的出线 **/
// mem给id（数据回传）和给mem_wb的连线
reg_addr_t mem_wd_o;
logic mem_wreg_o;
word_t mem_wdata_o;
// mem给ex（hilo数据回传）和给mem_wb的连线
word_t mem_hi_o, mem_lo_o;
logic mem_whilo_o;


/** mem_wb的出线 **/
// mem_wb给hilo_reg的连线
reg_addr_t mem_wb_wb_wd;
logic mem_wb_wb_wreg;
word_t mem_wb_wb_wdata;
// mem_wb给ex（hilo数据回传）和给hilo_reg的连线
word_t mem_wb_wb_hi, mem_wb_wb_lo;
logic mem_wb_wb_whilo;


/** cpu_top的两个出线 **/
// cpu_top给rom的连线
assign rom_addr_o = pc_reg_pc;
assign rom_ce_o = pc_reg_ce;


/* ---------------- 模块声明 ----------------- */

// PC（同步地址线加一）
pc_reg pc_reg_inst(
    .clk(clk),
    .rst(rst),
    .stall(ctrl_stall),

    .pc(pc_reg_pc),
    .ce(pc_reg_ce)
);

// 通用寄存器（同步写寄存器）
comm_reg comm_reg_inst(
    .clk(clk),
    .rst(rst),

    .we(mem_wb_wb_wreg),
    .waddr(mem_wb_wb_wd),
    .wdata(mem_wb_wb_wdata),

    .raddr1(id_reg1_addr_o),
    .raddr2(id_reg2_addr_o),

    .rdata1(comm_reg_rdata1),
    .rdata2(comm_reg_rdata2)
);

// HILO寄存器（同步写寄存器）
hilo_reg hilo_reg_inst(
    .clk(clk),
    .rst(rst),

    .we(mem_wb_wb_whilo),
    .hi_i(mem_wb_wb_hi),
    .lo_i(mem_wb_wb_lo),

    .hi_o(hilo_reg_hi_o),
    .lo_o(hilo_reg_lo_o)
);

// ctrl暂停控制器
ctrl ctrl_inst(
    .rst(rst),

    .stallreq_from_id(id_stallreq_o),
    .stallreq_from_ex(ex_stallreq_o),

    .stall(ctrl_stall)
);

// IF到ID的连接（IF相当于在这里实现了，同步把数据传给ID）
if_id if_id_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),

    .if_pc(pc_reg_pc),
    .if_inst(rom_data_i),
    .id_pc(if_id_id_pc),
    .id_inst(if_id_id_inst)
);

// ID（异步的组合逻辑）
id id_inst(
    .rst(rst),
    .pc_i(if_id_id_pc),
    .inst_i(if_id_id_inst),

    .reg1_data_i(comm_reg_rdata1),
    .reg2_data_i(comm_reg_rdata2),

    .ex_wreg_i(ex_wreg_o),
    .ex_wdata_i(ex_wdata_o),
    .ex_wd_i(ex_wd_o),

    .mem_wreg_i(mem_wreg_o),
    .mem_wdata_i(mem_wdata_o),
    .mem_wd_i(mem_wd_o),

    .reg1_addr_o(id_reg1_addr_o),
    .reg2_addr_o(id_reg2_addr_o),

    .aluop_o(id_aluop_o),
    .reg1_o(id_reg1_o),
    .reg2_o(id_reg2_o),
    .wd_o(id_wd_o),
    .wreg_o(id_wreg_o),

    .stallreq_o(id_stallreq_o)
);

// ID到EX的连接（同步把数据传给EX）
id_ex id_ex_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),

    .id_aluop(id_aluop_o),
    .id_reg1(id_reg1_o),
    .id_reg2(id_reg2_o),
    .id_wd(id_wd_o),
    .id_wreg(id_wreg_o),

    .ex_aluop(id_ex_ex_aluop),
    .ex_reg1(id_ex_ex_reg1),
    .ex_reg2(id_ex_ex_reg2),
    .ex_wd(id_ex_ex_wd),
    .ex_wreg(id_ex_ex_wreg)
);

// EX（异步的组合逻辑）
ex ex_inst(
    .rst(rst),

    .aluop_i(id_ex_ex_aluop),
    .reg1_i(id_ex_ex_reg1),
    .reg2_i(id_ex_ex_reg2),
    .wd_i(id_ex_ex_wd),
    .wreg_i(id_ex_ex_wreg),

    .hi_i(hilo_reg_hi_o),
    .lo_i(hilo_reg_lo_o),

    .wb_hi_i(mem_wb_wb_hi),
    .wb_lo_i(mem_wb_wb_lo),
    .wb_whilo_i(mem_wb_wb_whilo),

    .mem_hi_i(mem_hi_o),
    .mem_lo_i(mem_lo_o),
    .mem_whilo_i(mem_whilo_o),

    .wd_o(ex_wd_o),
    .wreg_o(ex_wreg_o),
    .wdata_o(ex_wdata_o),

    .hi_o(ex_hi_o),
    .lo_o(ex_lo_o),
    .whilo_o(ex_whilo_o),

    .stallreq_o(ex_stallreq_o)
);

// EX到MEM的连接（同步把数据给MEM）
ex_mem ex_mem_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),

    .ex_wd(ex_wd_o),
    .ex_wreg(ex_wreg_o),
    .ex_wdata(ex_wdata_o),
    .ex_hi(ex_hi_o),
    .ex_lo(ex_lo_o),
    .ex_whilo(ex_whilo_o),

    .mem_hi(ex_mem_mem_hi),
    .mem_lo(ex_mem_mem_lo),
    .mem_whilo(ex_mem_mem_whilo),

    .mem_wd(ex_mem_mem_wd),
    .mem_wreg(ex_mem_mem_wreg),
    .mem_wdata(ex_mem_mem_wdata)
);

// MEM（异步的组合逻辑）
mem mem_inst(
    .rst(rst),

    .wd_i(ex_mem_mem_wd),
    .wreg_i(ex_mem_mem_wreg),
    .wdata_i(ex_mem_mem_wdata),
    .hi_i(ex_mem_mem_hi),
    .lo_i(ex_mem_mem_lo),
    .whilo_i(ex_mem_mem_whilo),

    .wd_o(mem_wd_o),
    .wreg_o(mem_wreg_o),
    .wdata_o(mem_wdata_o),
    .hi_o(mem_hi_o),
    .lo_o(mem_lo_o),
    .whilo_o(mem_whilo_o)
);

// MEM到WB（同步），写回的信号直接接到寄存器（寄存器会同步下一个周期写入）
mem_wb mem_wb_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),

    .mem_wd(mem_wd_o),
    .mem_wreg(mem_wreg_o),
    .mem_wdata(mem_wdata_o),
    .mem_hi(mem_hi_o),
    .mem_lo(mem_lo_o),
    .mem_whilo(mem_whilo_o),

    .wb_wd(mem_wb_wb_wd),
    .wb_wreg(mem_wb_wb_wreg),
    .wb_wdata(mem_wb_wb_wdata),
    .wb_hi(mem_wb_wb_hi),
    .wb_lo(mem_wb_wb_lo),
    .wb_whilo(mem_wb_wb_whilo)
);

endmodule