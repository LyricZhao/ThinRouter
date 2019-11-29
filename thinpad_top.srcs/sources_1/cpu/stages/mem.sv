/*
MEM模块：
    访存阶段，现在还涉及不到RAM，只是把执行阶段的结果向回写阶段传递
*/

`include "cpu_defs.vh"

module mem(
    input  logic            rst,

    input  reg_addr_t       wd_i,                   // 要写入的寄存器编号
    input  logic            wreg_i,                 // 是否要写入寄存器
    input  word_t           wdata_i,                // 要写入的数据
    input  word_t           hi_i,                   // 要写入的hi值
    input  word_t           lo_i,                   // 要写入的lo值
    input  logic            whilo_i,                // 是否要写入hilo寄存器
    input  aluop_t          aluop_i,                // aluop的值
    input  word_t           mem_addr_i,             // 想要存入内存的地址
    input  word_t           reg2_i,                 // 欲写入内存的值

    input  word_t           mem_data_i,             // RAM读出来的数

    input  logic            cp0_reg_we_i,           // 是否写CP0
    input  reg_addr_t       cp0_reg_write_addr_i,   // 要写CP0的地址
    input  word_t           cp0_reg_data_i,         // 要写入的数据

    input  word_t           except_type_i,          // 异常类型
    input  logic            in_delayslot_i,         // 在延迟槽中
    input  addr_t           current_inst_addr_i,    // 当前指令地址

    input  word_t           cp0_status_i,           // CP0 Status寄存器
    input  word_t           cp0_cause_i,            // CP0 Cause寄存器
    input  word_t           cp0_epc_i,              // CP0 EPC寄存器

    input  logic            wb_cp0_reg_we,          // 回写阶段是否写CP0
    input  reg_addr_t       wb_cp0_reg_write_addr,  // 回写阶段要写的寄存器地址
    input  word_t           wb_cp0_reg_data,        // 回写阶段要写的数据

    output reg_addr_t       wd_o,                   // 要写入的寄存器编号
    output logic            wreg_o,                 // 是否要写入寄存器
    output word_t           wdata_o,                // 要写入的数据
    output word_t           hi_o,                   // 要写入的hi值
    output word_t           lo_o,                   // 要写入的lo值
    output logic            whilo_o,                // 是否要写入hilo寄存器

    output word_t           mem_addr_o,             // 送到RAM中的信号，RAM的地址
    output logic            mem_we_o,               // 送到RAM中的信号，写使能
    output logic[3:0]       mem_sel_o,              // 送到RAM中的信号，从一个word中四个字节选取若干个
    output word_t           mem_data_o,             // 送到RAM中的信号
    output logic            mem_ce_o,               // 送到RAM中的信号

    output logic            cp0_reg_we_o,           // 是否写CP0
    output reg_addr_t       cp0_reg_write_addr_o,   // 要写CP0的地址
    output word_t           cp0_reg_data_o,         // 要写入的数据

    output logic            stallreq_o,             // 暂停请求

    output word_t           except_type_o,          // 异常类型
    output word_t           cp0_epc_o,              // CP0中epc寄存器的最新值
    output logic            in_delayslot_o,         // 是否在延迟槽中

    output addr_t           current_inst_addr_o     // 当前指令的地址
);

logic mem_we; // TODO

assign in_delayslot_o = in_delayslot_i;
assign current_inst_addr_o = current_inst_addr_i;

word_t cp0_status, cp0_epc, cp0_cause;

// 获得CP0寄存器的最新值
always_comb begin
    if (rst) begin
        cp0_status <= 0;
    end else if (wb_cp0_reg_we && wb_cp0_reg_write_addr == `CP0_REG_STATUS) begin
        cp0_status <= wb_cp0_reg_data;
    end else begin
        cp0_status <= cp0_status_i;
    end
end

always_comb begin
    if (rst) begin
        cp0_epc <= 0;
    end else if (wb_cp0_reg_we && wb_cp0_reg_write_addr == `CP0_REG_EPC) begin
        cp0_epc <= wb_cp0_reg_data;
    end else begin
        cp0_epc <= cp0_epc_i;
    end
end

assign cp0_epc_o = cp0_epc;

always_comb begin
    if (rst) begin
        cp0_cause <= 0;
    end else if (wb_cp0_reg_we && wb_cp0_reg_write_addr == `CP0_REG_CAUSE) begin
        cp0_cause[9:8] <= wb_cp0_reg_data[9:8];
        cp0_cause[23:22] <= wb_cp0_reg_data[23:22];
    end else begin
        cp0_cause <= cp0_cause_i;
    end
end

// 最终的异常类型
always_comb begin
    if (rst) begin
        except_type_o <= 0;
    end else begin
        except_type_o <= 0;
        if (current_inst_addr_i) begin
            if (((cp0_cause[15:8] & (cp0_status[15:8])) != 0) && (cp0_status[1] == 0) && (cp0_status[0] == 1)) begin
                except_type_o <= 32'h1; // 中断
            end else if (except_type_i[8]) begin
                except_type_o <= 32'h8; // syscall
            end else if (except_type_i[9]) begin
                except_type_o <= 32'ha;
            end else if (except_type_i[10]) begin
                except_type_o <= 32'hd;
            end else if (except_type_i[11]) begin
                except_type_o <= 32'hc;
            end else if (except_type_i[12]) begin
                except_type_o <= 32'he;
            end
        end
    end
end

// 如果异常了就就不写了
assign mem_we_o = mem_we & (~(|except_type_o));

// 其他指令
always_comb begin
    if (rst) begin
        wd_o <= `NOP_REG_ADDR;
        {wreg_o, wdata_o, hi_o, lo_o, whilo_o, mem_addr_o, mem_we, mem_sel_o, mem_data_o, mem_ce_o} <= 0;
        {cp0_reg_write_addr_o, cp0_reg_we_o, cp0_reg_data_o} <= 0;
        stallreq_o <= 0;
    end else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
        {hi_o, lo_o} <= {hi_i, lo_i};
        whilo_o <= whilo_i;
        {mem_we, mem_addr_o, mem_ce_o} <= 0;
        mem_sel_o <= 4'b1111; // 默认四个字节都读/写
        stallreq_o <= 0;
        cp0_reg_we_o <= cp0_reg_we_i;
        cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
        cp0_reg_data_o <= cp0_reg_data_i;
        case (aluop_i)
            EXE_LW_OP: begin
                stallreq_o <= 1;
                mem_addr_o <= mem_addr_i;
                mem_we <= 0;
                wdata_o <= mem_data_i;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= 1;
            end
            EXE_LH_OP: begin
                stallreq_o <= 1;
                mem_addr_o <= mem_addr_i;
                mem_we <= 0;
                mem_ce_o <= 1;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o <= {{16{mem_data_i[15]}}, mem_data_i[15:0]};
                        mem_sel_o <= 4'b1111;
                    end
                    2'b10: begin
                        wdata_o <= {{16{mem_data_i[31]}}, mem_data_i[31:16]};
                        mem_sel_o <= 4'b1111;
                    end
                    default: begin
                        wdata_o <= 0;
                    end
                endcase
            end
            EXE_LB_OP: begin
                stallreq_o <= 1;
                mem_addr_o <= mem_addr_i;
                mem_we <= 0;
                mem_ce_o <= 1;
                case (mem_addr_i[1:0])
                    2'b11: begin
                        wdata_o <= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
                        mem_sel_o <= 4'b1111;
                    end
                    2'b10: begin
                        wdata_o <= {{24{mem_data_i[23]}}, mem_data_i[23:16]};
                        mem_sel_o <= 4'b1111;
                    end
                    2'b01: begin
                        wdata_o <= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
                        mem_sel_o <= 4'b1111;
                    end
                    2'b00: begin
                        wdata_o <= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
                        mem_sel_o <= 4'b1111;
                    end
                    default: begin
                        wdata_o <= 0;
                    end
                endcase
            end
            EXE_SW_OP: begin
                stallreq_o <= 1;
                mem_addr_o <= mem_addr_i;
                mem_we <= 1;
                mem_data_o <= reg2_i;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= 1;                
            end
            EXE_SB_OP: begin
                stallreq_o <= 1;
                mem_addr_o <= mem_addr_i;
                mem_we <= 1;
                mem_data_o <= {reg2_i[7:0], reg2_i[7:0], reg2_i[7:0], reg2_i[7:0]}; // 这样写仅仅是为了接下来选择某个字节进行写入时方便
                mem_ce_o <= 1;
                case (mem_addr_i[1:0])
                    2'b11: begin
                        mem_sel_o <= 4'b1000;
                    end
                    2'b10: begin
                        mem_sel_o <= 4'b0100;
                    end
                    2'b01: begin
                        mem_sel_o <= 4'b0010;
                    end
                    2'b00: begin
                        mem_sel_o <= 4'b0001;
                    end
                    default: begin
                        mem_sel_o <= 4'b0000;
                    end
                endcase
            end
        endcase
    end
end

endmodule