RM	:= rm -f
# 这里是交叉编译器的路径（或者命令的配置），因为三个人路径可能不太一样，所以大家在这里需要设置TOOLCHAIN_PREFIX这个环境变量为交叉编译器的前缀，比如我的是/opt/cross/mipsel-linux-musl-cross/bin/mipsel-linux-musl-
ifeq ($(OS),Windows_NT)
GCCPREFIX	?= $(TOOLCHAIN_PREFIX)
else
GCCPREFIX	?= $(TOOLCHAIN_PREFIX)
endif
QEMU 	 := qemu-system-mipsel
LD		 := $(GCCPREFIX)ld
CC		 := $(GCCPREFIX)gcc
INCLUDE	 := ../../../../../supervisor/kernel/include
TARGET	 := testcase
LDSCRIPT := ram.ld
ASFLAG	 := -D__ASSEMBLY__ -EL -g -O0 -mips32r2 -mno-abicalls -mno-shared

override ON_FPGA ?= n

ifeq ($(ON_FPGA), y)
	MACH_DEF = -DMACH_FPGA
else
   	MACH_DEF = -DMACH_QEMU
endif
ASFLAG += $(MACH_DEF)

override EN_INT ?= n
ifeq ($(EN_INT), y)
	ASFLAG += -DENABLE_INT
	EN_TLB = n
endif

override EN_TLB ?= n
ifeq ($(EN_TLB), y)
	ASFLAG += -DENABLE_TLB
endif

CONFIG_FILE := .config_$(ON_FPGA)_$(EN_INT)_$(EN_TLB)

.PHONY: clean

default: $(TARGET).mem

$(CONFIG_FILE):
	@rm -f .config_*
	touch $@

dump: $(TARGET).elf
	@$(GCCPREFIX)objdump -D $(TARGET).elf

$(TARGET).o: $(TARGET).S
	@$(GCCPREFIX)CC $(TARGET).S -o $(TARGET).o -c -I$(INCLUDE) $(ASFLAG)

$(TARGET).elf: $(TARGET).o
	$(LD) $(TARGET).o -o $(TARGET).elf -T$(LDSCRIPT)

$(TARGET).bin: $(TARGET).elf
	@$(GCCPREFIX)objcopy -j .text -j .text.* -O binary $(TARGET).elf $(TARGET).bin

$(TARGET).mem: $(TARGET).bin
	python3 bin2mem.py $(TARGET).bin $(TARGET).mem

clean:
	-$(RM) -r $(TARGET).o $(TARGET).bin $(TARGET).elf $(TARGET).mem