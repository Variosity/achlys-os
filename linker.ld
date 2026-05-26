ENTRY(_start)

SECTIONS
{
    /* Tell GRUB to load us at the 1 Megabyte mark */
    . = 1M;

    /* Force the multiboot header to be the absolute first thing */
    .boot :
    {
        *(.multiboot)
    }

    .text :
    {
        *(.text)
    }

    .rodata :
    {
        *(.rodata)
    }

    .data :
    {
        *(.data)
    }

    .bss :
    {
        *(.bss)
    }
}
