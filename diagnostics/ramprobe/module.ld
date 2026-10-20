ENTRY(module_entry)
SECTIONS {
    . = 0;
    .text : { *(.text .text.*) }
    probe_code_end = .;
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) }
    .bss : { *(.bss .bss.*) *(COMMON) }
    probe_module_end = .;
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
