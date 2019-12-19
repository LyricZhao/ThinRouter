export CROSS_COMPILE ?= mipsel-linux-musl-

CC=${CROSS_COMPILE}gcc
CXX=${CROSS_COMPILE}g++
LD=${CROSS_COMPILE}ld
AR=${CROSS_COMPILE}ar
OBJCOPY=${CROSS_COMPILE}objcopy
OBJDUMP=${CROSS_COMPILE}objdump

TARGET=main.bootrom

CFLGAS=-msingle-float -nostdinc -nostdlib -ffunction-sections -fdata-sections -ffreestanding -Wall -mxgot -fno-builtin -fno-PIC -fno-PIE -mno-abicalls -g -EL -mhard-float -mips32r2 -Os
LDFLAGS=-static -EL -nostdlib --nmagic --gc-sections

all: $(TARGET).bin

main.bootrom.bin: main.bootrom.elf
	$(OBJCOPY) -O binary -j .text -j .data $< $@

main.bootrom.elf: linker.bootrom.ld startup.o main.o
	$(LD) $(LDFLAGS) -T $< -o $@ $(filter-out $<,$^)
	$(OBJDUMP) -alDS $@ > dump.s

startup.o: startup.S
	$(CC) $(CFLGAS) -c -o $@ $<

main.o: main.c
	$(CC) $(CFLGAS) -c -o $@ $<

linker.bootrom.ld: linker.ld.S 
	$(CC) -E -P $(CFLAGS) $< -o $@

clean:
	rm -rf *.ld *.elf *.o *.s