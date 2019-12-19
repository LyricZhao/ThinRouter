# ifndef __UTILITY_H__
# define __UTILITY_H__

# define CATCH(type, addr)  (*((type *) (addr)))
# define WRITE(type, addr, data)  (*((type *)addr)) = (data)

typedef unsigned int uint_32;

# define DISP_CLEAR_SCREEN      0x00
# define DISP_NEW_LINE          0x0a // '\n'
# define DISP_BACKSPACE         0x7f // backspace
# define DISP_ENTER             0x01 // enter

# define true 1
# define false 0

# define MAX_LENGTH 1024

# include "address.h"

uint_32 compare_str(char *a, char *b) {
    for (; (*a) && (*b); ++ a, ++ b) {
        if ((*a) != (*b)) {
            return 0;
        }
    }
    return (*a) == (*b);
}

// TODO: 有时间改成中断
void putc(uint_32 data) {
    volatile uint_32 stat;
    while (true) {
        stat = CATCH(uint_32, ADDR_UART_STATUS);
        if (stat & 1) { // 可写
            WRITE(int, ADDR_UART_DATA, data);
            break;
        }
    }
}

// 同时向串口和屏幕发送（这里串口和屏幕的地址写在了一起）为了速度后面可以拆开
void print(char *str) {
    for (;(*str) != 0; ++ str) {
        putc(*str);
    }
}

void puts(char *str) {
    for (;(*str) != 0; ++ str) {
        putc(*str);
    }
    putc('\n');
}

char read() {
    volatile uint_32 stat;
    while (true) {
        stat = CATCH(uint_32, ADDR_UART_STATUS);
        if (stat & 2) { // 有数据
            return CATCH(uint_32, ADDR_UART_DATA) & 0xff;
        }
    }
    return 0;
}

# endif