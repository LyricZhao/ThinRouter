/*
指令ROM相关的一些定义
*/

`ifndef _INST_ROM_VH_
`define _INST_ROM_VH_

`define InstAddrBus         31:0
`define InstBus             31:0
`define InstMemNum          131071
`define InstMemNumLog2      17

typedef logic[`InstAddrBus] inst_addr_t;

`endif