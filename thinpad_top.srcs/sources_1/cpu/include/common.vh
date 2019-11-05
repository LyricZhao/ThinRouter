/*
一些常用的定义
*/

`ifndef _COMMON_VH_
`define _COMMON_VH_

`define ZeroWord            32'h00000000
`define WordBus             31:0
`define DoubleWordBus       63:0

typedef logic[`WordBus]         word_t;
typedef logic[`DoubleWordBus]   dword_t;

`endif