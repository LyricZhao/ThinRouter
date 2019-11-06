/*
寄存器相关的一些定义
*/

`ifndef _REG_VH_
`define _REG_VH_

`define REG_ADDR_BUS        4:0
`define REG_NUM             32
`define NOP_REG_ADDR        5'b00000

typedef logic[`REG_ADDR_BUS]  reg_addr_t;

`endif