#!/usr/bin/env bash
# Build a separate virtual-machine kernel; no iPad or bootloader interaction.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
scripts/check-host.sh
expected=$(awk '$1 == "linux" {print $3}' config/sources.lock)
[[ $(git -C src/linux rev-parse HEAD) == "$expected" ]]
[[ -z $(git -C src/linux status --porcelain --untracked-files=no) ]]
mkdir -p build/qemu-kernel artifacts/qemu logs
# Later fragment values explicitly replace the baseline's n values. The
# merged file remains separate; the original fragment and artifacts survive.
awk -F'[ =]' '
  /^CONFIG_/ {name=$1; values[name]=$0; next}
  /^# CONFIG_/ {name=$2; values[name]=$0; next}
  END {for (name in values) print values[name]}
' config/kernel.fragment config/qemu.fragment | LC_ALL=C sort > build/qemu-kernel.fragment
export KBUILD_BUILD_TIMESTAMP='2026-10-12 00:00:00 UTC'
export KBUILD_BUILD_USER=j96 KBUILD_BUILD_HOST=omarchy KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1791763200 KCONFIG_NOTIMESTAMP=1
make -C src/linux O="$PWD/build/qemu-kernel" ARCH=arm64 LLVM=1 \
  KCONFIG_ALLCONFIG="$PWD/build/qemu-kernel.fragment" allnoconfig > logs/qemu-kernel-config.log 2>&1
make -C src/linux O="$PWD/build/qemu-kernel" ARCH=arm64 LLVM=1 \
  -j"${JOBS:-2}" Image > logs/qemu-kernel-build.log 2>&1
cp build/qemu-kernel/arch/arm64/boot/Image artifacts/qemu/Image
cp build/qemu-kernel/.config artifacts/qemu/kernel.config
for option in ARM64_4K_PAGES ARM_GIC ARM_PSCI_FW SERIAL_AMBA_PL011_CONSOLE VIRTIO_MMIO VIRTIO_BLK EXT4_FS NET UNIX DRM DRM_VIRTIO_GPU; do
    grep -qx "CONFIG_${option}=y" artifacts/qemu/kernel.config || { echo "Missing QEMU kernel option: $option" >&2; exit 1; }
done
for option in ARM64_16K_PAGES ARM64_64K_PAGES; do
    grep -qx "# CONFIG_${option} is not set" artifacts/qemu/kernel.config
done
flags=$(od -An -tu8 -j24 -N8 artifacts/qemu/Image)
[[ $(((flags >> 1) & 3)) == 1 ]]
sha256sum artifacts/qemu/Image artifacts/qemu/kernel.config > artifacts/qemu/SHA256SUMS
printf '%s\n' 'PASS: separate 4 KB QEMU virt kernel built. This is not an iPad kernel.'
