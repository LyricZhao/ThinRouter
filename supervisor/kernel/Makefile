RM	:= rm -f
# 这里是交叉编译器的路径（或者命令的配置），因为三个人路径可能不太一样，所以大家在这里需要设置TOOLCHAIN_PREFIX这个环境变量为交叉编译器的前缀，比如我的是/opt/cross/mipsel-linux-musl-cross/bin/mipsel-linux-musl-
ifeq ($(OS),Windows_NT)
GCCPREFIX	?= $(TOOLCHAIN_PREFIX)
else
GCCPREFIX	?= $(TOOLCHAIN_PREFIX)
endif
QEMU := qemu-system-mipsel
LD	:= $(GCCPREFIX)ld
CC	:= $(GCCPREFIX)gcc
MODULE	:= init
OBJDIR	:= obj
INCLUDE	:= include
SRCDIR	:= kern
LDSCRIPT	:= kern/kernel.ld
SRC	:= $(foreach sdir, $(SRCDIR), $(wildcard $(sdir)/*.S))
OBJ	:= $(patsubst $(SRCDIR)/%.S, $(OBJDIR)/%.o, $(SRC))
TARGET	:= kernel.elf
ASFLAG	:= -D__ASSEMBLY__ -EL -g -mips32r2 -mno-abicalls -mno-shared

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

.PHONY: all clean show-utest

all: $(TARGET) kernel.bin

$(CONFIG_FILE):
	@rm -f .config_*
	touch $@

$(TARGET): checkdirs $(OBJ) $(LDSCRIPT)
	$(LD) $(OBJ) -T$(LDSCRIPT)

$(OBJ): $(OBJDIR)/%.o : $(SRCDIR)/%.S $(CONFIG_FILE)
	$(CC) -o $@ $< -c -I$(INCLUDE) $(ASFLAG)

checkdirs: $(OBJDIR)

$(OBJDIR):
	test -d $@ || mkdir $@

kernel.bin: $(TARGET)
	@$(GCCPREFIX)objcopy -j .text -j .text.* -O binary -v $< kernel.bin

show-utest: $(TARGET)
	@$(GCCPREFIX)objdump -D $< | grep "^[0-9a-f]\{8\} <UTEST_" | grep -n --color=auto 'UTEST_'

.PHONY: commits-num show-utest sim clean

sim: $(TARGET)
	$(QEMU) -M mipssim -m 8M -kernel $< -nographic -monitor none -serial tcp::6666,server -s

commits-num:
	@git log --pretty=format:"commit %H" | grep -c 'commit'

clean:
	-$(RM) -r $(OBJDIR)
