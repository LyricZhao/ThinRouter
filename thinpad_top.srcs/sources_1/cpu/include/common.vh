/*
一些常用的定义
*/

`ifndef _COMMON_VH_
`define _COMMON_VH_

`define INIT_PC             32'h80000000

`define BYTE_WITDH          8
`define DWORD_WIDTH         64
`define WORD_WIDTH          32
`define WORD_WIDTH_LOG2     5
`define CLZO_FILL           26  // clz, clo两个操作的结果是6位的，这里的意思是补26个0
`define ADDR_WIDTH          32
`define SEL_WIDTH           4

typedef logic[`BYTE_WITDH-1:0]        byte_t;
typedef logic[`WORD_WIDTH-1:0]        word_t;
typedef logic[`DWORD_WIDTH-1:0]       dword_t;
typedef logic[`ADDR_WIDTH-1:0]        addr_t;
typedef logic[`SEL_WIDTH-1:0]         sel_t;

typedef struct {
    logic pc;
    logic ifetch;
    logic id;
    logic ex;
    logic mem;
    logic wb;
} stall_t;

`endif