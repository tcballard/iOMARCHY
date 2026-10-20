/* SPDX-License-Identifier: MIT
 * Same ABI as marker.S. EL1/EL2/EL3 only, subject to higher-level traps.
 * Reads only the SCTLR belonging to CurrentEL. Changes no system registers.
 */
#ifdef __APPLE__
#define ENTRY _ram_state
#else
#define ENTRY ram_state
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
    mov x2, sp
    str x2, [x0, #40]
    adr x2, ENTRY
    str x2, [x0, #48]
    str x30, [x0, #56]
    mrs x2, CurrentEL
    str x2, [x0, #24]
    cmp x2, #4
    b.eq 1f
    cmp x2, #8
    b.eq 2f
    cmp x2, #12
    b.eq 3f
    mov x2, #3
    str x2, [x0, #8]
    mov x0, #1
    ret
1:  mrs x2, SCTLR_EL1
    b 4f
2:  mrs x2, SCTLR_EL2
    b 4f
3:  mrs x2, SCTLR_EL3
4:  str x2, [x0, #32]
    mrs x2, DAIF
    str x2, [x0, #64]
    mrs x2, MIDR_EL1
    str x2, [x0, #72]
    mrs x2, MPIDR_EL1
    str x2, [x0, #80]
    mov x2, #2
    dmb sy
    str x2, [x0, #8]
    dsb sy
    mov x0, #0
    ret
