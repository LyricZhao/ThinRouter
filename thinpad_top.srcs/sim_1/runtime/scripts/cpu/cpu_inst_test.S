# include <regdef.h>
# include <mipsregs.h>
# include <unistd.h>
# include <exception.h>
# include <shell.h>

.org 0x0          // 指示程序从地址0x0开始
.global _start    // 定义一个全局符号_start
.set noat         // 同意自由使用寄存器$1 
_start:
    lui $1, 0x0101
    ori $1, $1, 0x0101
    ori $2, $1, 0x1100
    or  $1, $1, $2
    andi $3, $1, 0x00fe
    and $1, $3, 0x00fe
    xori $4, $1, 0xff00
    xor $1, $4, $1
    nor $1, $4, $1