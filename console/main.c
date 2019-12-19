# include "address.h"
# include "utility.h"

uint_32 pos;
char buffer[MAX_LENGTH];

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
void print(char *str) {
    for (;(*str) != 0; ++ str) {
        putc(*str);
    }
}

char read() {
    while (true) {
        uint_32 stat = CATCH(uint_32, ADDR_UART_STATUS);
        if (stat & 2) { // 有数据
            return CATCH(uint_32, ADDR_UART_DATA) & 0xff;
        }
    }
    return 0;
}

void new_command() {
    pos = 0;
    print("root@ThinRouter.4 > ");
}

void command_help() {
    print("ThinRouter Group 4 Help:\n");
    print(" - Command: help, show this help message\n");
    print(" - Command: route, show routing table\n");
}

void command_route() {
    // TODO
}

void process_command() {
    if (compare_str(buffer, "help")) {
        command_help();
    } else if (compare_str(buffer, "route")) {
        command_route();
    }
}

// 策略：轮询串口不断append输入
void _main() {
    pos = 0;
    for (uint_32 i = 0; i < MAX_LENGTH; ++ i) {
        buffer[i] = 0;
    }
    print("Console@ThinRouter.4 initialized\n");
    new_command();

    while (true) {
        char val = read();
        buffer[pos ++] = val;
        putc(val);
        if (val == DISP_ENTER) {
            buffer[pos ++] = '\0';
            process_command();
            new_command();
        }
    }
}