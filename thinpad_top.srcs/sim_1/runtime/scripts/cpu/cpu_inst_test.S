# include <regdef.h>
# include <mipsregs.h>
# include <unistd.h>
# include <exception.h>
# include <shell.h>

.org 0x0          // 指示程序从地址0x0开始
.global _start    // 定义一个全局符号_start
.set noat         // 同意自由使用寄存器$1 
_start:
    ori $1, $0, 0x0001
    ori $2, $0, 0x0010
    ori $3, $0, 0x0100
    ori $4, $0, 0x1000