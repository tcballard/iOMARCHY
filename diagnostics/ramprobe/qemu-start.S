/* SPDX-License-Identifier: MIT. Emulator harness only. */
.text
.global _start
_start:
    ldr x0, =test_stack_top
    mov sp, x0
    bl test_main
    b .
.section .rodata
.balign 16
.global packed_module, packed_module_end
packed_module:
    .incbin "build/ramprobe/ramprobe.pongo"
packed_module_end:
.bss
.balign 16
    .skip 16384
test_stack_top:
