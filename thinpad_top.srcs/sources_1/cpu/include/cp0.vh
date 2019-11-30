/*
关于CP0的定义
*/

`ifndef _CP0_VH_
`define _CP0_VH_

`define CP0_REG_STATUS      5'b01100
`define CP0_REG_CAUSE       5'b01101
`define CP0_REG_EPC         5'b01110
`define CP0_REG_EBASE       5'b01111

`define EXCEPTION_WIDTH     32

`define NUM_DEVICES         6

`define EXC_INTERRUPT       32'h1
`define EXC_SYSCALL         32'h8
`define EXC_OVERFLOW        32'hc
`define EXC_ERET            32'he

`endif