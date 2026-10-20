/* SPDX-License-Identifier: MIT */
.text
.balign 4
.global command_puts, command_register
command_puts:
    adr x16, probe_puts_slot
    ldr x16, [x16]
    br x16
command_register:
    adr x16, probe_register_slot
    ldr x16, [x16]
    br x16
.data
.balign 8
.global probe_puts_slot, probe_register_slot
probe_puts_slot: .quad 0
probe_register_slot: .quad 0
