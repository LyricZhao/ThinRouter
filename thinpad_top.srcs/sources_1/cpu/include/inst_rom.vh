/*
指令ROM相关的一些定义
*/

`ifndef _INST_ROM_VH_
`define _INST_ROM_VH_

`define INST_ADDR_BUS       31:0
`define INST_MEM_NUM        131071
`define INST_MEM_NUM_LOG2   17

typedef logic[`INST_ADDR_BUS] inst_addr_t;

`endif