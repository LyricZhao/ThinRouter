# ifndef __UTILITY_H__
# define __UTILITY_H__

# define CATCH(type, addr)  (*((type *) (addr)))
# define WRITE(type, addr, data)  (*((type *)addr)) = (data)

typedef unsigned int uint_32;

# define DISP_CLEAR_SCREEN      0x00
# define DISP_NEW_LINE          0x0a // '\n'
# define DISP_RETURN            0x0d // '\r'
# define DISP_BACKSPACE         0x7f // backspace
# define DISP_ENTER             0x01 // enter

# define true 1
# define false 0

# define MAX_LENGTH 1024

uint_32 compare_str(char *a, char *b) {
    for (;(*a) && (*b); ++ a, ++ b) {
        if ((*a) != (*b)) {
            return 0;
        }
    }
    return (*a) == (*b);
}

# endif