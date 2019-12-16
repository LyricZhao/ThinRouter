/*
寄存器相关的一些定义
*/

`ifndef _REG_VH_
`define _REG_VH_

`define REG_ADDR_WIDTH      5
`define REG_NUM             32

typedef logic[`REG_ADDR_WIDTH-1:0]  reg_addr_t;

`endif