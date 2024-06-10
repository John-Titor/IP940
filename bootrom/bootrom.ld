/*
 * Linker script for IP940 bootrom.
 */

MEMORY
{
    ram(rw)     : ORIGIN = 0x01800000 - 20K, LENGTH = 20K
}

OUTPUT_ARCH(m68k)
OUTPUT(elf32-m68k)
ENTRY(_start)

SECTIONS
{
    .text :
    {
    	_vectors = .;
        /* lower m68k vectors */
        LONG(_stack_top)
        LONG(_reset - ORIGIN(ram))
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        LONG(_fleh)
        . = 0x3c;
        LONG(_fleh)
        . = 0x60;
        LONG(_fleh)
        LONG(vector_ipl1)
        LONG(vector_ipl2)
        LONG(vector_ipl3)
        LONG(vector_ipl4)
        LONG(vector_ipl5)
        LONG(vector_ipl6)
        LONG(vector_ipl7)

        /* code */
        *(.text);
        *(.text.*);
        *(.rodata);
        *(.rodata.*);
        . = ALIGN(4);
    } > ram

    .data :
    {
        _sdata = .;
        *(.data);
        *(.data.*);
        . = ALIGN(4);
        _edata = .;
    } > ram

    .bss :
    {
        _sbss = .;
        *(.bss);
        *(.bss.*);
        . = ALIGN(4);
        _ebss = .;

    	/* stack */
        _stack_base = .;
        . = ORIGIN(ram) + LENGTH(ram) - 4;
        _stack_top = .;

    } > ram

    .stab 0 (NOLOAD) :
    {
        *(.stab);
    }

    .stabstr 0 (NOLOAD) :
    {
        *(.stabstr);
    }

}
