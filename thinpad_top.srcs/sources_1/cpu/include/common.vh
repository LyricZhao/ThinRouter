/*
一些常用的定义
*/

`ifndef _COMMON_VH_
`define _COMMON_VH_

`define WORD_BUS            31:0
`define DWORD_BUS           63:0
`define WORD_WIDTH          32
`define WORD_WIDTH_LOG2     5
`define CLZO_FILL           26  // clz, clo两个操作的结果是6位的，这里的意思是补26个0
`define STALL_CTRL_BUS      5:0 // 暂停信号

typedef logic[`WORD_BUS]        word_t;
typedef logic[`DWORD_BUS]       dword_t;
typedef logic[`STALL_CTRL_BUS]  stall_t;

`endif