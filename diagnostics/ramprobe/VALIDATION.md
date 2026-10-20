# Offline validation — 20 October 2026

Tested with LLVM/Clang 18.1.3, GNU host C compiler 13, and QEMU 8.2.2.
`scripts/test-ramprobe.sh` completed successfully. All new C files compile with
`-Wall -Wextra -Werror`; shell syntax checks and `git diff --check` pass.

| Check | Result |
|---|---|
| Actual packed module, mocked Pongo exports, QEMU virt EL1 | Marker + CPU-state readbacks pass |
| Same module at EL2 | Marker + CPU-state readbacks pass |
| Same module at EL3 | Marker + CPU-state readbacks pass |
| Wrong nonce | Rejected |
| Missing output | Rejected |
| Duplicate record | Rejected |
| Corrupted magic | Rejected |
| Entered but incomplete status | Rejected |
| Guard failure alongside a valid record | Rejected |

LLVM identifies the generated module as ARM64 Mach-O KextBundle with a 16 KB
segment, two external pointer relocations and one local pointer relocation.
The emulator harness consumes that generated module, resolves its two imports,
slides its module-name pointer and calls its registered commands. It does not
substitute a separately linked copy of the payload for this test.

No iPad is attached to the execution environment. Physical J96 execution,
Pongo transport behavior, A8 register state, direct post-checkm8 delivery and
Lightning UART have **not** been validated. Emulator passes are offline
implementation evidence only. The earlier hardware attempts remain unchanged:
no m1n1 or Linux upload was established in the last reported Hoolock attempt.
