/*
CPU顶层设计：
    把所有模块都连接起来，模块实在很多线也很多，重构了一遍，所有的命名统一以(模块_出去的线)命名
    如果想知道有谁接入了某个模块，可以搜索：给xx模块，如：搜索“给if_id”可搜到所有到if_id的连线
    每个线是干嘛的请翻阅对于模块的定义
*/

`include "cpu_defs.vh"

module cpu_top(
    input  logic                        clk,
    input  logic                        rst,

    input  int_t                        int_i,

    input  word_t                       ram_data_r,

    output word_t                       ram_addr,
    output word_t                       ram_data_w,
    output logic                        ram_we,
    output sel_t                        ram_sel,
    output logic                        ram_ce
);

/* ---------------- 模块出线 ----------------- */

/** addr_ctrl的出线 **/
// addr_ctrl给if_id的出线
word_t addr_ctrl_inst_data_r;
// addr_ctrl给mem的出线
word_t addr_ctrl_mem_data_r;


/** pc的出线 **/
// pc给addr_ctrl和给if_id的连线
addr_t pc_pc;
// pc给addr_ctrl的连线
logic pc_ce;


/** CP0的出线 **/
// cp0给ex的出线
word_t cp0_data_o;
// cp0给mem的出线
word_t cp0_status_o, cp0_cause_o, cp0_epc_o;
// cp0给ctrl的出线
word_t cp0_ebase_o;


/** comm_reg的出线 **/
// comm_reg给id的连线
word_t comm_reg_rdata1, comm_reg_rdata2;


/** hilo_reg的出线 **/
// hilo_reg给ex的连线
word_t hilo_reg_hi_o, hilo_reg_lo_o;


/** ctrl的出线 **/
// ctrl给ex_mem、给id_ex、给if_id、给mem_wb、给pc的连线
stall_t ctrl_stall;
logic ctrl_flush;
// ctrl给pc的连线
addr_t ctrl_new_pc;


/** if_id的出线 **/
// if_id给id的连线
addr_t if_id_id_pc;
word_t if_id_id_inst;


/** id的出线 **/
// id给comm_reg的连线
reg_addr_t id_reg1_addr_o, id_reg2_addr_o;
// id给id_ex的连线
aluop_t id_aluop_o;
word_t id_reg1_o, id_reg2_o;
reg_addr_t id_wd_o;
logic id_wreg_o;
logic id_next_in_delayslot_o, id_in_delayslot_o;
addr_t id_return_addr_o;
word_t id_inst_o;
word_t id_except_type_o;
addr_t id_current_inst_addr_o;
// id给ctrl的连线
logic id_stallreq_o;
// id给pc的出线
logic id_jump_flag_o;
addr_t id_target_addr_o;


/** id_ex的出线 **/
// id_ex给ex的连线
aluop_t id_ex_ex_aluop;
word_t id_ex_ex_reg1, id_ex_ex_reg2;
reg_addr_t id_ex_ex_wd;
logic id_ex_ex_wreg;
logic id_ex_ex_in_delayslot;
addr_t id_ex_ex_return_addr;
word_t id_ex_ex_inst;
word_t id_ex_ex_except_type;
addr_t id_ex_ex_current_inst_addr;
// id_ex给id的连线
logic id_ex_id_in_delayslot_o;


/** ex的出线 **/
// ex给id（数据回传）和给ex_mem的连线
reg_addr_t ex_wd_o;
logic ex_wreg_o;
word_t ex_wdata_o;
// ex给ex_mem的连线
word_t ex_hi_o, ex_lo_o;
logic ex_whilo_o;
aluop_t ex_aluop_o;
word_t ex_mem_addr_o;
word_t ex_reg2_o;
word_t ex_cp0_reg_data_o;
reg_addr_t ex_cp0_reg_write_addr_o;
logic ex_cp0_reg_we_o;
word_t ex_except_type_o;
addr_t ex_current_inst_addr_o;
logic ex_in_delayslot_o;
// ex给ctrl的连线
logic ex_stallreq_o;
// ex给cp0的出线
reg_addr_t ex_cp0_reg_read_addr_o;


/** ex_mem的出线 **/
// ex_mem给mem的连线
word_t ex_mem_mem_hi, ex_mem_mem_lo;
logic ex_mem_mem_whilo;
reg_addr_t ex_mem_mem_wd;
logic ex_mem_mem_wreg;
word_t ex_mem_mem_wdata;
aluop_t ex_mem_mem_aluop;
word_t ex_mem_mem_mem_addr;
word_t ex_mem_mem_reg2;
word_t ex_mem_mem_cp0_reg_data;
reg_addr_t ex_mem_mem_cp0_reg_write_addr;
logic ex_mem_mem_cp0_reg_we;
word_t ex_mem_mem_except_type;
addr_t ex_mem_mem_current_inst_addr;
logic ex_mem_mem_in_delayslot;

/** mem的出线 **/
// mem给id（数据回传）和给mem_wb的连线
reg_addr_t mem_wd_o;
logic mem_wreg_o;
word_t mem_wdata_o;
// mem给ex（hilo、cp0数据回传）和给mem_wb的连线
word_t mem_hi_o, mem_lo_o;
logic mem_whilo_o;
word_t mem_cp0_reg_data_o;
reg_addr_t mem_cp0_reg_write_addr_o;
logic mem_cp0_reg_we_o;
// mem给ctrl的连线
logic mem_stallreq_o;
word_t mem_cp0_epc_o;
// mem给cp0的连线
addr_t mem_current_inst_addr_o;
logic mem_in_delayslot_o;
// mem给cp0、给ctrl的连线
word_t mem_except_type_o;
// mem给addr_ctrl的出线
addr_t mem_mem_addr_o;
logic mem_mem_we_o, mem_mem_ce_o;
sel_t mem_mem_sel_o;
word_t mem_mem_data_o;


/** mem_wb的出线 **/
// mem_wb给hilo_reg的连线
reg_addr_t mem_wb_wb_wd;
logic mem_wb_wb_wreg;
word_t mem_wb_wb_wdata;
// mem_wb给ex（hilo）和给hilo_reg的连线
word_t mem_wb_wb_hi, mem_wb_wb_lo;
logic mem_wb_wb_whilo;
// mem_wb给ex（cp0数据回传）和给mem（cp0数据回传）的连线
word_t mem_wb_wb_cp0_reg_data;
reg_addr_t mem_wb_wb_cp0_reg_write_addr;
logic mem_wb_wb_cp0_reg_we;


/* ---------------- 模块声明 ----------------- */

// PC（同步地址线加一）
pc pc_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),
    .flush(ctrl_flush),
    .new_pc(ctrl_new_pc),

    .jump_flag(id_jump_flag_o),
    .target_addr(id_target_addr_o),

    .pc(pc_pc),
    .ce(pc_ce)
);

// 地址控制器
addr_ctrl addr_ctrl_inst(
    .rst(rst),

    .inst_ce(pc_ce),
    .inst_addr(pc_pc),

    .mem_ce(mem_mem_ce_o),
    .mem_we(mem_mem_we_o),
    .mem_addr(mem_mem_addr_o),
    .mem_sel(mem_mem_sel_o),
    .mem_data_w(mem_mem_data_o),

    .ram_data_r(ram_data_r),
    .ram_addr(ram_addr),
    .ram_data_w(ram_data_w),
    .ram_we(ram_we),
    .ram_sel(ram_sel),
    .ram_ce(ram_ce),

    .inst_data_r(addr_ctrl_inst_data_r),
    .mem_data_r(addr_ctrl_mem_data_r)
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

// CP0
cp0 cp0_inst(
    .clk(clk),
    .rst(rst),
    .int_i(int_i),

    .raddr_i(ex_cp0_reg_read_addr_o),
    .data_i(mem_wb_wb_cp0_reg_data),
    .waddr_i(mem_wb_wb_cp0_reg_write_addr),
    .we_i(mem_wb_wb_cp0_reg_we),

    .except_type_i(mem_except_type_o),
    .current_inst_addr_i(mem_current_inst_addr_o),
    .in_delayslot_i(mem_in_delayslot_o),

    .data_o(cp0_data_o),
    .ebase_o(cp0_ebase_o),
    .status_o(cp0_status_o),
    .cause_o(cp0_cause_o),
    .epc_o(cp0_epc_o)
);

// ctrl暂停控制器
ctrl ctrl_inst(
    .rst(rst),

    .stallreq_from_id(id_stallreq_o),
    .stallreq_from_ex(ex_stallreq_o),
    .stallreq_from_mem(mem_stallreq_o),

    .cp0_epc_i(mem_cp0_epc_o),
    .cp0_ebase_i(cp0_ebase_o),
    .except_type_i(mem_except_type_o),

    .new_pc(ctrl_new_pc),

    .stall(ctrl_stall),
    .flush(ctrl_flush)
);

// IF到ID的连接（IF相当于在这里实现了，同步把数据传给ID）
if_id if_id_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),
    .flush(ctrl_flush),

    .if_pc(pc_pc),
    .if_inst(addr_ctrl_inst_data_r),
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

    .ex_aluop_i(ex_aluop_o),

    .in_delayslot_i(id_ex_id_in_delayslot_o),

    .reg1_addr_o(id_reg1_addr_o),
    .reg2_addr_o(id_reg2_addr_o),

    .in_delayslot_o(id_in_delayslot_o),
    .next_in_delayslot_o(id_next_in_delayslot_o),
    .jump_flag_o(id_jump_flag_o),
    .target_addr_o(id_target_addr_o),
    .return_addr_o(id_return_addr_o),

    .aluop_o(id_aluop_o),
    .reg1_o(id_reg1_o),
    .reg2_o(id_reg2_o),
    .wd_o(id_wd_o),
    .wreg_o(id_wreg_o),

    .stallreq_o(id_stallreq_o),

    .inst_o(id_inst_o),

    .except_type_o(id_except_type_o),
    .current_inst_addr_o(id_current_inst_addr_o)
);

// ID到EX的连接（同步把数据传给EX）
id_ex id_ex_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),
    .flush(ctrl_flush),

    .id_aluop(id_aluop_o),
    .id_reg1(id_reg1_o),
    .id_reg2(id_reg2_o),
    .id_wd(id_wd_o),
    .id_wreg(id_wreg_o),

    .id_return_addr(id_return_addr_o),
    .id_in_delayslot_i(id_in_delayslot_o),
    .id_next_in_delayslot(id_next_in_delayslot_o),

    .id_except_type(id_except_type_o),
    .id_current_inst_addr(id_current_inst_addr_o),

    .ex_aluop(id_ex_ex_aluop),
    .ex_reg1(id_ex_ex_reg1),
    .ex_reg2(id_ex_ex_reg2),
    .ex_wd(id_ex_ex_wd),
    .ex_wreg(id_ex_ex_wreg),

    .ex_return_addr(id_ex_ex_return_addr),
    .ex_in_delayslot(id_ex_ex_in_delayslot),
    .id_in_delayslot_o(id_ex_id_in_delayslot_o),

    .ex_except_type(id_ex_ex_except_type),
    .ex_current_inst_addr(id_ex_ex_current_inst_addr),

    .id_inst(id_inst_o),
    .ex_inst(id_ex_ex_inst)
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

    .mem_hi_i(mem_hi_o),
    .mem_lo_i(mem_lo_o),
    .mem_whilo_i(mem_whilo_o),

    .mem_cp0_reg_data(mem_cp0_reg_data_o),
    .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
    .mem_cp0_reg_we(mem_cp0_reg_we_o),

    .except_type_i(id_ex_ex_except_type),
    .current_inst_addr_i(id_ex_ex_current_inst_addr),

    .wb_hi_i(mem_wb_wb_hi),
    .wb_lo_i(mem_wb_wb_lo),
    .wb_whilo_i(mem_wb_wb_whilo),

    .wb_cp0_reg_data(mem_wb_wb_cp0_reg_data),
    .wb_cp0_reg_write_addr(mem_wb_wb_cp0_reg_write_addr),
    .wb_cp0_reg_we(mem_wb_wb_cp0_reg_we),

    .cp0_reg_data_o(ex_cp0_reg_data_o),
    .cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
    .cp0_reg_we_o(ex_cp0_reg_we_o),

    .in_delayslot_i(id_ex_ex_in_delayslot),
    .return_addr_i(id_ex_ex_return_addr),

    .wd_o(ex_wd_o),
    .wreg_o(ex_wreg_o),
    .wdata_o(ex_wdata_o),

    .hi_o(ex_hi_o),
    .lo_o(ex_lo_o),
    .whilo_o(ex_whilo_o),

    .stallreq_o(ex_stallreq_o),

    .inst_i(id_ex_ex_inst),

    .cp0_reg_read_addr_o(ex_cp0_reg_read_addr_o),
    .cp0_reg_data_i(cp0_data_o),

    .except_type_o(ex_except_type_o),
    .current_inst_addr_o(ex_current_inst_addr_o),
    .in_delayslot_o(ex_in_delayslot_o),

    .aluop_o(ex_aluop_o),
    .mem_addr_o(ex_mem_addr_o),
    .reg2_o(ex_reg2_o)
);

// EX到MEM的连接（同步把数据给MEM）
ex_mem ex_mem_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),
    .flush(ctrl_flush),

    .ex_wd(ex_wd_o),
    .ex_wreg(ex_wreg_o),
    .ex_wdata(ex_wdata_o),
    .ex_hi(ex_hi_o),
    .ex_lo(ex_lo_o),
    .ex_whilo(ex_whilo_o),

    .ex_cp0_reg_data(ex_cp0_reg_data_o),
    .ex_cp0_reg_write_addr(ex_cp0_reg_write_addr_o),
    .ex_cp0_reg_we(ex_cp0_reg_we_o),

    .ex_except_type(ex_except_type_o),
    .ex_current_inst_addr(ex_current_inst_addr_o),
    .ex_in_delayslot(ex_in_delayslot_o),

    .mem_hi(ex_mem_mem_hi),
    .mem_lo(ex_mem_mem_lo),
    .mem_whilo(ex_mem_mem_whilo),

    .mem_wd(ex_mem_mem_wd),
    .mem_wreg(ex_mem_mem_wreg),
    .mem_wdata(ex_mem_mem_wdata),

    .mem_except_type(ex_mem_mem_except_type),
    .mem_current_inst_addr(ex_mem_mem_current_inst_addr),
    .mem_in_delayslot(ex_mem_mem_in_delayslot),

    .ex_aluop(ex_aluop_o),
    .ex_mem_addr(ex_mem_addr_o),
    .ex_reg2(ex_reg2_o),

    .mem_aluop(ex_mem_mem_aluop),
    .mem_mem_addr(ex_mem_mem_mem_addr),
    .mem_reg2(ex_mem_mem_reg2),

    .mem_cp0_reg_data(ex_mem_mem_cp0_reg_data),
    .mem_cp0_reg_write_addr(ex_mem_mem_cp0_reg_write_addr),
    .mem_cp0_reg_we(ex_mem_mem_cp0_reg_we)
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

    .cp0_reg_data_i(ex_mem_mem_cp0_reg_data),
    .cp0_reg_write_addr_i(ex_mem_mem_cp0_reg_write_addr),
    .cp0_reg_we_i(ex_mem_mem_cp0_reg_we),

    .wd_o(mem_wd_o),
    .wreg_o(mem_wreg_o),
    .wdata_o(mem_wdata_o),
    .hi_o(mem_hi_o),
    .lo_o(mem_lo_o),
    .whilo_o(mem_whilo_o),

    .mem_data_i(addr_ctrl_mem_data_r),
    .mem_addr_o(mem_mem_addr_o),
    .mem_we_o(mem_mem_we_o),
    .mem_sel_o(mem_mem_sel_o),
    .mem_data_o(mem_mem_data_o),
    .mem_ce_o(mem_mem_ce_o),

    .except_type_i(ex_mem_mem_except_type),
    .current_inst_addr_i(ex_mem_mem_current_inst_addr),
    .in_delayslot_i(ex_mem_mem_in_delayslot),

    .cp0_status_i(cp0_status_o),
    .cp0_cause_i(cp0_cause_o),
    .cp0_epc_i(cp0_epc_o),

    .wb_cp0_reg_we(mem_wb_wb_cp0_reg_we),
    .wb_cp0_reg_write_addr(mem_wb_wb_cp0_reg_write_addr),
    .wb_cp0_reg_data(mem_wb_wb_cp0_reg_data),

    .cp0_reg_data_o(mem_cp0_reg_data_o),
    .cp0_reg_write_addr_o(mem_cp0_reg_write_addr_o),
    .cp0_reg_we_o(mem_cp0_reg_we_o),

    .aluop_i(ex_mem_mem_aluop),
    .mem_addr_i(ex_mem_mem_mem_addr),
    .reg2_i(ex_mem_mem_reg2),

    .stallreq_o(mem_stallreq_o),

    .cp0_epc_o(mem_cp0_epc_o),
    .except_type_o(mem_except_type_o),
    .current_inst_addr_o(mem_current_inst_addr_o),
    .in_delayslot_o(mem_in_delayslot_o)
);

// MEM到WB（同步），写回的信号直接接到寄存器（寄存器会同步下一个周期写入）
mem_wb mem_wb_inst(
    .clk(clk),
    .rst(rst),

    .stall(ctrl_stall),
    .flush(ctrl_flush),

    .mem_wd(mem_wd_o),
    .mem_wreg(mem_wreg_o),
    .mem_wdata(mem_wdata_o),
    .mem_hi(mem_hi_o),
    .mem_lo(mem_lo_o),
    .mem_whilo(mem_whilo_o),

    .mem_cp0_reg_data(mem_cp0_reg_data_o),
    .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
    .mem_cp0_reg_we(mem_cp0_reg_we_o),

    .wb_wd(mem_wb_wb_wd),
    .wb_wreg(mem_wb_wb_wreg),
    .wb_wdata(mem_wb_wb_wdata),
    .wb_hi(mem_wb_wb_hi),
    .wb_lo(mem_wb_wb_lo),
    .wb_whilo(mem_wb_wb_whilo),

    .wb_cp0_reg_data(mem_wb_wb_cp0_reg_data),
    .wb_cp0_reg_write_addr(mem_wb_wb_cp0_reg_write_addr),
    .wb_cp0_reg_we(mem_wb_wb_cp0_reg_we)
);

endmodule