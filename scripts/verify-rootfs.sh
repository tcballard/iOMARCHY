#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/rootfs-common.sh
source scripts/rootfs-common.sh
rootfs_require readelf sha256sum zstd
[[ -d $ROOTFS_TREE ]] || rootfs_fail 'missing rootfs tree'
for binary in bash jq Hyprland hyprctl qs; do
    path="$ROOTFS_TREE/usr/bin/$binary"
    [[ -f $path ]] || rootfs_fail "missing ARM64 executable $binary"
    readelf -h "$path" | grep -q 'Machine:.*AArch64' || rootfs_fail "not AArch64: $binary"
done
[[ -s $ROOTFS_TREE/usr/lib/ld-linux-aarch64.so.1 ]] || rootfs_fail 'missing ARM64 dynamic loader'
[[ -f $ROOTFS_TREE/usr/share/omarchy/bin/omarchy && -d $ROOTFS_TREE/usr/share/omarchy/shell ]] || rootfs_fail 'missing real Omarchy CLI/shell'
[[ -x $ROOTFS_TREE/usr/local/sbin/iomarchy-qemu-init ]] || rootfs_fail 'missing emulation init'
sha256sum -c artifacts/ROOTFS-SHA256SUMS
zstd --test artifacts/iomarchy-arm64-rootfs.tar.zst
printf 'PASS: ARM64 ELF headers, loader, official Omarchy source and archive integrity.\n'
printf 'NOT TESTED HERE: package runtime, compositor startup, iPad display or input.\n'
