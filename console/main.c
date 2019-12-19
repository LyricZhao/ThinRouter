# include "address.h"
# include "utility.h"

uint_32 pos, buffer[MAX_LENGTH];

// TODO: 有时间改成中断
// TODO: \r和\n的处理
void putc(uint_32 data) {
    while (true) {
        uint_32 stat = CATCH(uint_32, ADDR_UART_STATUS);
        if (stat & 1) { // 可写
            WRITE(int, ADDR_UART_DATA, data);
            break;
        }
    }
}

// 同时向串口和屏幕发送（这里串口和屏幕的地址写在了一起）为了速度后面可以拆开
void print(uint_32 *str) {
    for (;(*str) != 0; ++ str) {
        putc(*str);
    }
}

uint_32 read() {
    while (true) {
        uint_32 stat = CATCH(uint_32, ADDR_UART_STATUS);
        if (stat & 2) { // 有数据
            return CATCH(uint_32, ADDR_UART_DATA);
        }
    }
    return 0;
}

void new_command() {
    pos = 0;
    print("root@ThinRouter.4 > ");
}

void process_command() {
    
}

// 策略：轮询串口不断append输入
void console_main() {
    pos = 0;
    for (uint_32 i = 0; i < MAX_LENGTH; ++ i) {
        buffer[i] = 0;
    }
    print("Console@ThinRouter.4 initialized\n");
    new_command();

    while (true) {
        uint_32 val = read();
        buffer[pos ++] = val;
        putc(val);
        if (val == DISP_ENTER) {
            buffer[pos ++] = 0;
            process_command();
            new_command();
        }
    }
}