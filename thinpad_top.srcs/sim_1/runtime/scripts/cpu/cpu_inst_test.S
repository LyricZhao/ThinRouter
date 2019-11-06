# include <regdef.h>
# include <mipsregs.h>
# include <unistd.h>
# include <exception.h>
# include <shell.h>

.org 0x0          // 指示程序从地址0x0开始
.global _start    // 定义一个全局符号_start
.set noat         // 同意自由使用寄存器$1 
_start:
    lui $1, 0x0000 // $1 = 0x00000000
    lui $2, 0xffff // $2 = 0xffff0000
    lui $3, 0x0505 // $3 = 0x05050000
    lui $4, 0x0000 // $4 = 0x00000000

    movz $4, $2, $1 // $4 = 0xffff0000
    movn $4, $3, $1 // $4 保持
    movn $4, $3, $2 // $4 = 0x05050505
    movz $4, $3, $2 // $4 保持

    mthi $0 // hi = 0x00000000
    mthi $2 // hi = 0xffff0000
    mthi $3 // hi = 0x05050505
    mfhi $4 // $4 = 0x05050505
    mtlo $3 // lo = 0x05050505
    mtlo $2 // lo = 0xffff0000
    mtlo $1 // lo = 0x00000000
    mflo $4 // $4 = 0x00000000