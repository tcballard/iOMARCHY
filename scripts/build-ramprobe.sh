#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
src=diagnostics/ramprobe
out=build/ramprobe
mkdir -p "$out"
clang=${PROBE_CLANG:-clang}
elf_linker=${PROBE_ELF_LD:-ld.lld}
objcopy=${PROBE_OBJCOPY:-llvm-objcopy}
nm=${PROBE_NM:-llvm-nm}
for t in "$clang" "$elf_linker" "$objcopy" "$nm" cc; do
    command -v "$t" >/dev/null || { printf 'Missing tool: %s\n' "$t" >&2; exit 1; }
done
cc -std=c11 -O2 -Wall -Wextra -Werror "$src/check-log.c" -o "$out/check-log"
cc -std=c11 -O2 -Wall -Wextra -Werror "$src/pack-module.c" -o "$out/pack-module"
for name in marker state; do
    entry=ram_marker
    [[ $name != state ]] || entry=ram_state
    "$clang" --target=aarch64-none-elf -c "$src/$name.S" -o "$out/$name.o"
    "$elf_linker" -e "$entry" -Ttext=0 -o "$out/$name.elf" "$out/$name.o"
    "$objcopy" -O binary --only-section=.text "$out/$name.elf" "$out/$name.bin"
done
"$clang" --target=aarch64-none-elf -std=c11 -Os -Wall -Wextra -Werror \
    -ffreestanding -mgeneral-regs-only -fno-builtin -fno-stack-protector -fno-asynchronous-unwind-tables \
    -fno-unwind-tables -nostdlibinc -c "$src/pongo.c" -o "$out/pongo.o"
"$clang" --target=aarch64-none-elf -c "$src/pongo-imports.S" -o "$out/pongo-imports.o"
"$elf_linker" -T "$src/module.ld" -o "$out/module.elf" "$out/pongo.o" \
    "$out/marker.o" "$out/state.o" "$out/pongo-imports.o"
"$objcopy" -O binary "$out/module.elf" "$out/module.bin"
"$nm" --defined-only "$out/module.elf" > "$out/module.symbols"
symbol() { awk -v name="$1" '$3 == name {print $1; count++} END {if (count != 1) exit 1}' "$out/module.symbols"; }
"$out/pack-module" "$out/module.bin" "$out/ramprobe.pongo" \
    "$(symbol module_entry)" "$(symbol module_name)" "$(symbol exported_symbols)" \
    "$(symbol probe_puts_slot)" "$(symbol probe_register_slot)" \
    "$(symbol probe_module_end)" "$(symbol probe_code_end)"
sha256sum "$out/marker.bin" "$out/state.bin" "$out/ramprobe.pongo" "$out/check-log" > "$out/SHA256SUMS"
printf 'Built RAM probe (hardware untested): %s/%s\n' "$ROOT" "$out"
