#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
bash scripts/build-ramprobe.sh
out=build/ramprobe
src=diagnostics/ramprobe
clang=${PROBE_CLANG:-clang}
linker=${PROBE_ELF_LD:-ld.lld}
qemu=${PROBE_QEMU:-qemu-system-aarch64}
"$clang" --target=aarch64-none-elf -c "$src/qemu-start.S" -o "$out/qemu-start.o"
"$clang" --target=aarch64-none-elf -std=c11 -Os -Wall -Wextra -Werror \
    -ffreestanding -mgeneral-regs-only -fno-builtin -fno-stack-protector \
    -fno-asynchronous-unwind-tables -fno-unwind-tables -nostdlibinc \
    -c "$src/qemu-test.c" -o "$out/qemu-test.o"
"$linker" -T "$src/qemu.ld" -o "$out/qemu-test.elf" "$out/qemu-start.o" "$out/qemu-test.o"
for level in 1 2 3; do
    opts=secure=off,virtualization=off
    [[ $level != 2 ]] || opts=secure=off,virtualization=on
    [[ $level != 3 ]] || opts=secure=on,virtualization=on
    timeout 15 "$qemu" -M "virt,$opts" -cpu cortex-a53 -m 128M \
        -nodefaults -display none -monitor none -serial stdio -semihosting-config enable=on,target=native \
        -device "loader,file=$out/qemu-test.elf,cpu-num=0" > "$out/qemu-el$level.log" 2>&1
    rg -q '^EMULATION_ONLY_PASS$' "$out/qemu-el$level.log"
    "$out/check-log" mark 0123456789abcdef "$out/qemu-el$level.log"
    "$out/check-log" state 0123456789abcdef "$out/qemu-el$level.log" | tee "$out/qemu-el$level.result"
    rg -q "EL$level " "$out/qemu-el$level.result"
done
# A stale nonce, absent output, and duplicated proof must fail closed.
if "$out/check-log" mark fedcba9876543210 "$out/qemu-el1.log"; then exit 1; fi
if "$out/check-log" mark 0123456789abcdef /dev/null; then exit 1; fi
cat "$out/qemu-el1.log" "$out/qemu-el1.log" > "$out/duplicate.log"
if "$out/check-log" mark 0123456789abcdef "$out/duplicate.log"; then exit 1; fi
sed 's/31304d41524d4f49/31304d41524d4f48/' "$out/qemu-el1.log" > "$out/bad-magic.log"
if "$out/check-log" mark 0123456789abcdef "$out/bad-magic.log"; then exit 1; fi
sed 's/0000000000000002/0000000000000001/' "$out/qemu-el1.log" > "$out/incomplete.log"
if "$out/check-log" mark 0123456789abcdef "$out/incomplete.log"; then exit 1; fi
cat "$out/qemu-el1.log" > "$out/bad-guard.log"
printf '\nIOMARCHY_RAMPROBE_GUARD_FAILED\n' >> "$out/bad-guard.log"
if "$out/check-log" mark 0123456789abcdef "$out/bad-guard.log"; then exit 1; fi
printf 'Offline checks passed. QEMU emulation is not A8 hardware evidence.\n'
