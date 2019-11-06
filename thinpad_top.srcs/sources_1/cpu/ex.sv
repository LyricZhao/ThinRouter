/*
EX模块：
    执行阶段，这里实际是一个ALU
*/

`include "cpu_defs.vh"

module ex(
    input  logic            rst,

    input  aluop_t          aluop_i,
    input  word_t           reg1_i,
    input  word_t           reg2_i,
    input  reg_addr_t       wd_i,
    input  logic            wreg_i,

    input  word_t           hi_i,
    input  word_t           lo_i,

    input  word_t           wb_hi_i,
    input  word_t           wb_lo_i,
    input  logic            wb_whilo_i,

    input  word_t           mem_hi_i,
    input  word_t           mem_lo_i,
    input  logic            mem_whilo_i,

    output reg_addr_t       wd_o,
    output logic            wreg_o,
    output word_t           wdata_o,

    output word_t           hi_o,
    output word_t           lo_o,
    output logic            whilo_o
);

// 最新的hi, lo寄存器的值
word_t hi, lo;

logic overflow, reg1_lt_reg2;
word_t reg2_i_mux, result_sum, opdata1_mult, opdata2_mult;
dword_t hilo_temp, result_mul;
logic [`WORD_WIDTH_LOG2:0] result_clz, result_clo; // 注意这里的长度是6位的，前导零可能有32个

// 如果是减法或者有符号比较则reg2取相反数，否则不变
assign reg2_i_mux = ((aluop_i == EXE_SUB_OP) || (aluop_i == EXE_SUBU_OP) || (aluop_i == EXE_SLT_OP)) ? (~reg2_i + 1) : reg2_i;
assign result_sum = reg1_i + reg2_i_mux;

// 正正和为负，或者负负和为正，则溢出（有符号）
assign overflow = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

/*
reg1是否小于reg2：
    第一个情况是SLT有符号比较时：A 1为负2为正 B 1为正2为正但是减一下为负 C 都为负减一下为负
    第二个情况是无符号比较：直接比
*/
assign reg1_lt_reg2 = (aluop_i == EXE_SLT_OP) ?
                        ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31]) || (reg1_i[31] && reg2_i[31] && result_sum[31])):
                        (reg1_i < reg2_i);

// 前导零和前导一
count_lead_zero clz_inst( .in( reg1_i), .out(result_clz) );
count_lead_zero clo_inst( .in(~reg1_i), .out(result_clo) );

// 乘法：如果是负数先取相反数
assign opdata1_mult = (((aluop_i == EXE_MUL_OP) || (aluop_i == EXE_MULT_OP)) && reg1_i[31]) ? (~reg1_i + 1) : reg1_i;
assign opdata2_mult = (((aluop_i == EXE_MUL_OP) || (aluop_i == EXE_MULT_OP)) && reg2_i[31]) ? (~reg2_i + 1) : reg2_i;
assign hilo_temp = opdata1_mult * opdata2_mult;

always_comb begin
    if (rst == 1'b1) begin
        result_mul <= {`ZeroWord, `ZeroWord};
    end else begin
        case (aluop_i)
            EXE_MULT_OP, EXE_MUL_OP: begin
                result_mul <= (reg1_i[31] ^ reg2_i[31]) ? (~hilo_temp + 1) : hilo_temp;
            end
            default: begin
                result_mul <= hilo_temp;
            end
        endcase
    end
end

always_comb begin
    if (rst == 1'b1) begin
        wdata_o <= `ZeroWord;
    end else begin
        case (aluop_i)
            EXE_OR_OP: begin
                wdata_o <= reg1_i | reg2_i;
            end
            EXE_AND_OP: begin
                wdata_o <= reg1_i & reg2_i;
            end
            EXE_XOR_OP: begin
                wdata_o <= reg1_i ^ reg2_i;
            end
            EXE_NOR_OP: begin
                wdata_o <= ~(reg1_i | reg2_i);
            end
            EXE_SLL_OP: begin // 逻辑左移
                wdata_o <= reg2_i << reg1_i[4:0];
            end
            EXE_SRL_OP: begin // 逻辑右移
                wdata_o <= reg2_i >> reg1_i[4:0];
            end
            EXE_SRA_OP: begin // 算术右移
                wdata_o <= reg2_i >>> reg1_i[4:0];
            end
            EXE_MUL_OP, EXE_MULT_OP, EXE_MULTU_OP: begin
                wdata_o <= result_mul[`WORD_BUS];
            end
            EXE_SLT_OP, EXE_SLTU_OP: begin
                wdata_o <= reg1_lt_reg2;
            end
            EXE_ADD_OP, EXE_ADDU_OP, EXE_ADDI_OP, EXE_ADDIU_OP, EXE_SUB_OP, EXE_SUBU_OP: begin
                wdata_o <= result_sum;
            end
            EXE_CLZ_OP: begin
                wdata_o <= {`CLZO_FILL'b0, result_clz};
            end
            EXE_CLO_OP: begin
                wdata_o <= {`CLZO_FILL'b0, result_clo};
            end
            EXE_MFHI_OP: begin
                wdata_o <= hi;
            end
            EXE_MFLO_OP: begin
                wdata_o <= lo;
            end
            EXE_MOVZ_OP: begin
                wdata_o <= reg1_i;
            end
            EXE_MOVN_OP: begin
                wdata_o <= reg1_i;
            end
            default: begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end
end

always_comb begin
    if (rst == 1'b1) begin
        {hi, lo} <= {`ZeroWord, `ZeroWord};
    end else if (mem_whilo_i == 1'b1) begin
        {hi, lo} <= {mem_hi_i, mem_lo_i};
    end else if (wb_whilo_i == 1'b1) begin
        {hi, lo} <= {wb_hi_i, wb_lo_i};
    end else begin
        {hi, lo} <= {hi_i, lo_i};
    end
end

// 将要写入的hi, lo的值
always_comb begin
    if (rst == 1'b1) begin
        whilo_o <= 1'b0;
        {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
    end else begin
        case (aluop_i)
            EXE_MULT_OP, EXE_MULTU_OP: begin
                whilo_o <= 1'b1;
                {hi_o, lo_o} <= result_mul;
            end
            EXE_MTHI_OP: begin
                whilo_o <= 1'b1;
                {hi_o, lo_o} <= {reg1_i, lo};
            end
            EXE_MTLO_OP: begin
                whilo_o <= 1'b1;
                {hi_o, lo_o} <= {hi, reg1_i};
            end
            default: begin
                whilo_o <= 1'b0;
                {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
            end
        endcase
    end
end

always_comb begin
    wd_o <= wd_i;	 	 	
    case (aluop_i)
        EXE_ADD_OP, EXE_ADDI_OP, EXE_SUB_OP: begin
            wreg_o <= ~overflow; // 如果溢出就不写寄存器了
        end
        default: begin
            wreg_o <= wreg_i;
        end
    endcase
end

endmodule

// 二分递归求前导零个数
module count_lead_zero #(
    parameter in_width = 32,
    parameter out_width = $clog2(in_width) + 1
)(
    input  logic [in_width-1:0]  in,
    output logic [out_width-1:0] out
);

generate
if (in_width == 1) begin
    assign out = !in[0];
end else begin
    wire [out_width - 2:0] half_count;
    wire [in_width / 2 - 1: 0] lhs = in[in_width - 1: in_width / 2];
    wire [in_width / 2 - 1: 0] rhs = in[in_width / 2 - 1: 0];
    wire left_empty = (lhs == 0);

    count_lead_zero #(
        .in_width(in_width / 2)
    ) inner (
        .in (left_empty ? rhs : lhs),
        .out(half_count)
    );

    assign out = half_count + (left_empty ? 0 : (in_width / 2));
end
endgenerate

endmodule