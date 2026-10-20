/* SPDX-License-Identifier: MIT */
#ifndef IOMARCHY_PROBE_H
#define IOMARCHY_PROBE_H
#define PROBE_MAGIC 0x31304d41524d4f49ULL /* little-endian IOMRAM01 */
#define PROBE_WORDS 16
#define PROBE_GUARD 0x97a65b4c1234fedcULL
#ifndef __ASSEMBLER__
typedef unsigned long long probe_u64;
struct probe_record { probe_u64 word[PROBE_WORDS]; };
_Static_assert(sizeof(struct probe_record) == 128, "record ABI");
void ram_marker(volatile struct probe_record *, probe_u64);
void ram_state(volatile struct probe_record *, probe_u64);
#endif
#endif
