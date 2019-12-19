# ifndef __UTILITY_H__
# define __UTILITY_H__

# define CATCH(type, addr)  (*((type *) (addr)))
# define WRITE(type, addr, data)  (*((type *)addr)) = (data)

// 所有的类型暂时用uint_32, 字符类型高位补0
typedef unsigned int uint_32;

# define DISP_CLEAR_SCREEN      0x00
# define DISP_NEW_LINE          0x0a // '\n'
# define DISP_RETURN            0x0d // '\r'
# define DISP_BACKSPACE         0x7f // backspace
# define DISP_ENTER             0x01 // enter

# define true 1
# define false 0

# define MAX_LENGTH 1024

# endif