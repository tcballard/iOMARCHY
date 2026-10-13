#!/usr/bin/env bash
# Compression candidate only; no kernel, device boot or storage installation.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source scripts/rootfs-common.sh
[[ $EUID == 0 ]] || rootfs_fail 'use sudo to read the complete root-owned tree'
rootfs_require mksquashfs unsquashfs sha256sum stat cmp
[[ -d $ROOTFS_TREE ]] || rootfs_fail 'build the signed rootfs first'
mkdir -p artifacts build/squashfs logs/rootfs
image=artifacts/iomarchy-arm64-rootfs.squashfs
rm -f -- "$image.tmp"
mksquashfs "$ROOTFS_TREE" "$image.tmp" -noappend -comp zstd \
    -Xcompression-level 15 -b 1048576 -processors 2 -no-progress \
    -all-time "$ROOTFS_EPOCH" -mkfs-time "$ROOTFS_EPOCH" > logs/rootfs/squashfs-build.log
unsquashfs -s "$image.tmp" > logs/rootfs/squashfs-superblock.log
for path in usr/bin/bash usr/share/omarchy/shell/shell.qml; do
    unsquashfs -cat "$image.tmp" "$path" > build/squashfs/check-file
    cmp -- "$ROOTFS_TREE/$path" build/squashfs/check-file
done
mv -- "$image.tmp" "$image"
sha256sum "$image" > artifacts/SQUASHFS-SHA256SUMS
{
    printf 'Compressed ARM64 deployment candidate; source lock SHA-256: '
    sha256sum config/rootfs-inputs.lock
    printf 'SquashFS bytes: %s\n' "$(stat -c %s "$image")"
    printf 'Unpacked tree bytes (allocated): %s\n' "$(du -s -B1 "$ROOTFS_TREE" | cut -f1)"
    cat artifacts/SQUASHFS-SHA256SUMS
    printf '%s\n' 'Not boot-tested from RAM. Account for kernel, overlay, applications and peak image loading before deployment.'
} | tee artifacts/SQUASHFS-MANIFEST.txt
