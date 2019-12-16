.org 0x0          #指示程序从地址0x0开始
.set noreorder
.global __start   # // 定义一个全局符号_start
.set noat         #// 同意自由使用寄存器$1 
__start:
    ori   $1, $0, 0x01
    sw    $1, 0x8($0)
    ori   $2, $0, 0x02
    lw    $2, 0x8($0)
    ori   $3, $0, 0x04
    lw    $4, 0x8($0)
    beq   $1, $4, S2
    addiu $5, $0, 0x05
    addiu $6, $0, 0x06
S2:
    addiu $7, $0, 0x06
    bne   $1, $2, -0x08
    nop
    j 0x0