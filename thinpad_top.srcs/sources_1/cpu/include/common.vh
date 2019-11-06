/*
一些常用的定义
*/

`ifndef _COMMON_VH_
`define _COMMON_VH_

`define ZeroWord            32'h00000000
`define WORD_BUS            31:0
`define DWORD_BUS           63:0

typedef logic[`WORD_BUS]         word_t;
typedef logic[`DWORD_BUS]       dword_t;

`endif