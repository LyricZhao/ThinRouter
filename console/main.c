# include "address.h"
# include "utility.h"
# include "router.h"

u32 pos;
char buffer[MAX_LENGTH];

void new_command() {
    pos = 0;
    print("root@ThinRouter.4:~$ ");
}

void command_help() {
    puts("ThinRouter Group 4 Help:");
    puts("    help:    show this help message");
    puts("    route:   show routing table");
    puts("    clear:   clear the screen");
}

void command_clear() {
    putc(0);
}

void command_route() {
    printRoute();
}

void process_command() {
    if (compare_str(buffer, "help")) {
        command_help();
    } else if (compare_str(buffer, "route")) {
        command_route();
    } else if (compare_str(buffer, "clear")) {
        command_clear();
    } else {
        puts("Invalid command.");
    }
}

// 策略：轮询串口不断append输入
void _main() {
    // command_route();
    print("Console@ThinRouter.4 initialized\n");
    new_command();

    while (true) {
        char val = read(); // 可见字符 / 回车 / backspace
        if (val == DISP_ENTER) {
            puts("");
            if (pos) {
                buffer[pos ++] = '\0';
                process_command();
            }
            new_command();
        } else if (val == DISP_BACKSPACE) {
            if (pos) {
                -- pos;
                putc(val);
            }
        } else {
            buffer[pos ++] = val;
            putc(val);
        }
    }
}