export CROSS_COMPILE ?= mipsel-linux-musl-

CC=${CROSS_COMPILE}gcc
CXX=${CROSS_COMPILE}g++
LD=${CROSS_COMPILE}ld
AR=${CROSS_COMPILE}ar
OBJCOPY=${CROSS_COMPILE}objcopy
OBJDUMP=${CROSS_COMPILE}objdump

CFLGAS=-msingle-float -nostdinc -nostdlib -ffunction-sections -fdata-sections -ffreestanding -Wall -mxgot -fno-builtin -fno-PIC -fno-PIE -mno-abicalls -g -EL -mhard-float -mips32 -O2
LDFLAGS=-static -EL -nostdlib --nmagic --gc-sections

all: main.bootrom.bin

main.bootrom.bin: main.bootrom.elf
	$(OBJCOPY) -O binary -j .text -j .data $< $@

main.bootrom.elf: linker.bootrom.ld startup.o main.o
	$(LD) $(LDFLAGS) -T $< -o $@ $(filter-out $<,$^)
	$(OBJDUMP) -alDS $@ > dump.s

startup.o: startup.S
	$(CC) $(CFLGAS) -c -o $@ $<

main.o: main.c utility.h router.h
	$(CC) $(CFLGAS) -c -o $@ $<

linker.bootrom.ld: linker.ld.S 
	$(CC) -E -P $(CFLAGS) $< -o $@

clean:
	rm -rf *.ld *.elf *.o *.s *.bin

cp_to_runtime: main.bootrom.bin
	cp main.bootrom.bin ../thinpad_top.srcs/sim_1/runtime/console.bin
	python3 bin2mem.py main.bootrom.bin ../thinpad_top.srcs/sources_1/bootrom/bootrom.mem

cp_test: console_test.bin
	cp console_test.bin ../thinpad_top.srcs/sim_1/runtime/console_test.bin

cp_all: main.bootrom.bin console_test.bin
	cp main.bootrom.bin ../thinpad_top.srcs/sim_1/runtime/console.bin
	python3 bin2mem.py main.bootrom.bin ../thinpad_top.srcs/sources_1/bootrom/bootrom.mem
	cp console_test.bin ../thinpad_top.srcs/sim_1/runtime/console_test.bin
