# 生成mem文件测例

## 备注

- 使用前要先设置一下TOOLCHAIN_PREFIX这个环境变量，它是交叉编译器的路径（或者命令的配置），因为三个人路径可能不太一样，所以大家在这里需要设置TOOLCHAIN_PREFIX这个环境变量为交叉编译器的前缀，比如我的是/opt/cross/mipsel-linux-musl-cross/bin/mipsel-linux-musl-，看一下Makefile就懂了

## 几种文件

- o: 中间格式（本质也是.elf）
- bin: 二进制文件，每32个bit就是一个指令（objdump可以读）
- elf: 一种中间格式，其实.o文件就是这种格式（可执行链接格式，readelf可以读） 
- mem: 文本格式的指令16进制，Vivado可以直接读

## 目前工作流程
.S -(gcc)> .o -(ld)> .elf -(objcopy)> .bin -(bin2mem)> .mem

## 工具链

- as/gcc: 汇编器
- ld: 链接器
- objcopy: 把一种格式的目标文件复制为另一种格式
- objdump: 反汇编
- bin2mem.py: 把小端的bin文件翻译成mem文件
- 有关make的命令:
    - 单独一个make会生成.mem文件
    - make dump会反汇编.elf文件（有一堆别的指令，但是在生成.bin的时候过滤了）
    - make clean
    - 还有ON_FPGA, EN_INT和EN_TLB三个选项

## TODO 和 问题

- Python自动化生成脚本而不是自己写汇编
- ON_FPGA/EN_INT那几个选项可能存在潜在的问题
- 书上的大端序，工具链注意大小端（还没管这件事）