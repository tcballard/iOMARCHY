# Returning RAM diagnostic for J96 / A8

Status: builds and passes the QEMU tests described below. **Hardware untested.**
The first experiment uses your existing PongoOS session, not the failing
iBSS/iBEC → device-tree → m1n1 handoff. No Linux image or UART hardware is needed
for this diagnostic. Pongo remains responsible for USB output and its existing
hardware initialization. This does not prove a cold boot or direct SecureROM
payload delivery.

## Run on the XPS

Use the existing development checkout and its built, identity-checking
`artifacts/pongoterm` and `artifacts/SHA256SUMS`. Keep only the J96 connected.
Start the already-established Pongo-only route and stop at the Pongo shell;
close the other host terminal/transport before starting this test. Do not use
the ordinary `scripts/boot.sh` for this step: it proceeds to Linux.

The additional build tools on Omarchy/Arch are `base-devel clang lld llvm`.
They are already among the original project's build dependencies.

```bash
./scripts/ramprobe.sh --check    # compile only; no USB access
./scripts/ramprobe.sh            # returning RAM marker via existing Pongo
./scripts/ramprobe.sh --state    # marker, then CPU-state capture
```

The marker run requires a unique, completed readback containing a fresh
64-bit nonce. `--state` proceeds only after that marker passes, and then reads
CurrentEL, the corresponding SCTLR, SP, PC, LR, DAIF, MIDR and MPIDR. Logs,
nonce, device descriptors, artifact hashes and result files stay under
`logs/ramprobe-*/`. Device descriptors include ECID; review logs before sharing.

The runner refuses normal mode, recovery, DFU, wrong boards, multiple Apple
devices, identity changes, transport exit, malformed/stale/duplicate records,
guard failures and missing output. It does not retry exploitation or reconnect
to another device. The existing transport's exact USB bus/address/full-serial
lock is reused. A PASS is a checked memory readback after our assembly returns,
not an upload/disconnect message. It is not an independent byte-for-byte dump
of the uploaded module.

To leave the experiment, use Home + Top/Power until the Apple logo appears.
If state capture traps on a register read, the earlier marker log remains useful;
force restart and return to the known Pongo-only route before another attempt.

## Payload contract

The two raw binaries in `build/ramprobe/` are position-independent AArch64 leaf
functions. Each starts at byte zero. Pass a caller-owned 16-byte-aligned,
writable 128-byte buffer in x0 and a nonzero nonce in x1, with a valid return
address in x30. Zero the buffer first. The caller must reserve non-overlapping
executable code and writable data, arrange instruction/data coherency before
calling, and provide coherent readback afterwards. These functions do not pick
a physical RAM/SRAM address, install page tables, set up a stack, access storage,
touch MMIO, disable caches or write system registers. x0/x2 and condition flags
are caller-clobbered; SP, x19–x29 and x30 are preserved. x0 returns 0 on success;
the unsupported-level path in state capture returns 1. State capture requires
EL1/EL2/EL3 with the relevant reads permitted; it is not an EL0 function.

| Offset | 64-bit little-endian field |
|---|---|
| 0 | Magic `0x31304d41524d4f49` (`IOMRAM01`) |
| 8 | Status: 1 entered, 2 completed, 3 unsupported EL |
| 16 | Nonce |
| 24 | Raw CurrentEL: 4 / 8 / 12 |
| 32 | SCTLR for that EL |
| 40 | Entry SP |
| 48 | Payload entry virtual address |
| 56 | Entry LR |
| 64 | DAIF |
| 72 | MIDR_EL1 |
| 80 | MPIDR_EL1 |
| 88 | Record virtual address |
| 96–120 | Reserved zero words |

The marker sets only magic/status/nonce/record address; it performs no MRS.
Barriers order completion but do not by themselves clean dirty cache lines to
RAM for an external observer. The Pongo wrapper reads through the same CPU
mapping. A future direct checkm8 adapter must establish its own execution,
cache and memory-ownership contract. Do not reuse guessed addresses.

The Pongo adapter owns the record and surrounding guards. It registers two
commands, calls these same assembly routines, and emits readback words over
Pongo's console. The host C verifier checks the words, rather than accepting a
target-side success string.

## Module packaging and provenance

The adapter targets Pongo revision
`bb492b004265ce91123caa23b8bc04b2eff6d2b7`, already pinned by this project.
Its public [module loader](https://github.com/checkra1n/PongoOS/blob/bb492b004265ce91123caa23b8bc04b2eff6d2b7/src/dynamic/modload_macho.c),
[exports](https://github.com/checkra1n/PongoOS/blob/bb492b004265ce91123caa23b8bc04b2eff6d2b7/src/dynamic/modload.c)
and [legacy console ABI](https://github.com/checkra1n/PongoOS/blob/bb492b004265ce91123caa23b8bc04b2eff6d2b7/src/kernel/legacy.c)
define the integration. Pongo itself is not rebuilt or modified here.

LLVM's Linux Mach-O linker does not implement the required kext output, so the
small C packer emits the pinned loader's minimal format from a fully linked
ELF binary: one 16 KB RWX segment, an entry/name/empty exports table, two absolute
64-bit import relocations and one local module-name pointer relocation. This
is a diagnostic-specific packer, not a general Mach-O linker. The sole external
functions are `command_register` and `command_puts`; no Apple SDK, leaked source,
firmware binary or Apple ROM function is incorporated into the new payload.
The existing device ROM still runs, and Pongo supplies the hosted environment.
The new code is MIT-licensed; upstream components retain their own licences.

## Offline verification

```bash
./scripts/test-ramprobe.sh
```

Requires `qemu-system-aarch64`, `timeout` and `rg` in addition to build tools.
The QEMU virt harness loads the actual generated Mach-O module, applies the
pinned loader's relevant segment/symbol/relocation rules, mocks its two Pongo
exports, invokes both registered commands and verifies their readbacks at EL1,
EL2 and EL3. It also exercises invalid nonce inputs and checks stale, missing
and duplicate log rejection. Its PL011 console is only emulator test I/O.
**QEMU does not emulate A8, verify Pongo's live mappings/USB, or validate UART.**

## UART comes after the hardware readbacks

Public T7000 device-tree patches list UART0 at `0x20a0c0000` and UART6 at
`0x20a0d8000`, both `apple,s5l-uart`. Those trees explicitly rely on
bootloader-enabled clocks; they do not establish cold UART initialization.
Use the S5L/Samsung register family, not PL011 or 16550 offsets. Validate the
actual Lightning debug accessory, routing, orientation and electrical levels
before wiring. A passive breakout does not establish the debug UART route.

Sources: [public A8 DTS patch](https://lists.infradead.org/pipermail/linux-arm-kernel/2024-October/972293.html),
[Linux S5L UART driver](https://code.googlesource.com/linux/torvalds/linux/+/f24ba334afafc70c3149e9db9c0cf8ecc6d52a09/drivers/tty/serial/samsung_tty.c),
[Lightning research](https://nyansatan.github.io/lightning/).
