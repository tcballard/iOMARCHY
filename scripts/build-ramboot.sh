#!/usr/bin/env bash
# Separate diskless QEMU image; never assembles or selects a J96 boot bundle.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build/ramboot artifacts/ramboot
sha256sum -c artifacts/SQUASHFS-SHA256SUMS
digest=$(sha256sum artifacts/iomarchy-arm64-rootfs.squashfs | cut -d' ' -f1)
bytes=$(stat -c %s artifacts/iomarchy-arm64-rootfs.squashfs)
[[ $bytes -gt 0 && $bytes -lt 1073741824 ]]
printf '#define ROOTFS_BYTES %sULL\n#define ROOTFS_SHA256 "%s"\n' "$bytes" "$digest" > build/ramboot/rootfs-pin.h
aarch64-linux-gnu-gcc -std=c11 -Os -static -Wall -Wextra -Werror \
    -I build/ramboot -Wl,--build-id=none ramboot/init.c -o build/ramboot/init
readelf -h build/ramboot/init | grep -q 'Machine:.*AArch64'
if readelf -l build/ramboot/init | grep -q INTERP; then exit 1; fi
cc -O2 -Wall -Wextra src/linux/usr/gen_init_cpio.c -o build/ramboot/gen_init_cpio
{
    printf 'dir /dev 0755 0 0\nnod /dev/console 0600 0 0 c 5 1\n'
    printf 'file /init %s/build/ramboot/init 0755 0 0\n' "$PWD"
} > build/ramboot/initramfs.list
# The large compressed filesystem arrives after boot through a verified stream.
build/ramboot/gen_init_cpio -t 0 build/ramboot/initramfs.list > artifacts/ramboot/initramfs.cpio
stat -c 'Diskless initramfs bytes: %s' artifacts/ramboot/initramfs.cpio
[[ $(stat -c %s artifacts/ramboot/initramfs.cpio) -lt 8388608 ]]
printf '%s %s\n' "$bytes" "$digest" > artifacts/ramboot/payload-pin.txt
sha256sum artifacts/ramboot/initramfs.cpio artifacts/ramboot/payload-pin.txt > artifacts/ramboot/SHA256SUMS
