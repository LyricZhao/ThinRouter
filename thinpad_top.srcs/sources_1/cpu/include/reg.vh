/*
寄存器相关的一些定义
*/

`ifndef _REG_VH_
`define _REG_VH_

`define RegAddrBus          4:0
`define RegNum              32
`define NOPRegAddr          5'b00000

typedef logic[`RegAddrBus]      reg_addr_t;

`endif