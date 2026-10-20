/* SPDX-License-Identifier: MIT
 * x0: caller-owned, 16-byte-aligned, writable 128-byte record; x1: nonce.
 * Leaf AAPCS64 call: no stack use, imports, absolute addresses or MMIO.
 * Caller prepares coherent executable memory and reads back through its mapping.
 */
#ifdef __APPLE__
#define ENTRY _ram_marker
#else
#define ENTRY ram_marker
#endif
.text
.balign 4
.global ENTRY
ENTRY:
    mov x2, #1
    str x2, [x0, #8]
    str x1, [x0, #16]
    movz x2, #0x4f49
    movk x2, #0x524d, lsl #16
    movk x2, #0x4d41, lsl #32
    movk x2, #0x3130, lsl #48
    str x2, [x0]
    str x0, [x0, #88]
    mov x2, #2
    dmb sy
    str x2, [x0, #8]
    dsb sy
    mov x0, #0
    ret
