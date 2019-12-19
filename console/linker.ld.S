ENTRY(_start);

MEMORY
{
    BOOTROM  (rx)   : ORIGIN = 0x80000000, LENGTH = 2K
    RAM      (rwx)  : ORIGIN = 0x81000000, LENGTH = 7M
}

# define TEXT_AREA BOOTROM
# define DATA_AREA RAM

SECTIONS {
    . = ORIGIN(TEXT_AREA);

    _mem_start = ORIGIN(DATA_AREA);
    _mem_end = ORIGIN(DATA_AREA) + LENGTH(DATA_AREA);

    _mem_avail_start = ORIGIN(DATA_AREA);
    _mem_avail_end = ORIGIN(DATA_AREA) + LENGTH(DATA_AREA);

    .text :
    {
        _text = .;
        *(.text.startup)
        *(.text*)
        *(.rodata*)
        *(.reginfo)
        *(.init)
        *(.stub)
        *(.gnu.warning)
        *(.MIPS.abiflags)
        _text_end = .;
    } > TEXT_AREA

    .data :
    {
        _data = .;
        _stack = _data + LENGTH(DATA_AREA) - 32;
        *(.data)
        *(.data*)
        *(.eh_frame)
        _gp = ALIGN(16);  
        *(.got.plt) *(.got)
        *(.sdata) 
        *(.lit8) 
        *(.lit4)
        _data_end = .;
    } > DATA_AREA

    .sbss : 
    { 
        *(.sbss)
        *(.scommon)
    } > DATA_AREA
    
    .bss :
    {
        _bss = .;
        *(.dynbss)
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DATA_AREA

    /DISCARD/ :
    {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
    }
}