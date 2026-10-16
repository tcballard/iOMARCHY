#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/rootfs-common.sh
source scripts/rootfs-common.sh
rootfs_require readelf sha256sum zstd readlink
[[ -d $ROOTFS_TREE ]] || rootfs_fail 'missing rootfs tree'
[[ $(readlink "$ROOTFS_TREE/bin") == usr/bin && $(readlink "$ROOTFS_TREE/sbin") == usr/bin ]] || rootfs_fail 'missing standard filesystem /bin and /sbin links'
# Upstream installs an absolute guest symlink. Do not follow it into the host.
[[ $(readlink "$ROOTFS_TREE/usr/bin/qs") == /usr/bin/quickshell ]] || rootfs_fail 'unexpected Quickshell alias'
for binary in bash jq Hyprland hyprctl quickshell systemctl; do
    path="$ROOTFS_TREE/usr/bin/$binary"
    [[ -f $path ]] || rootfs_fail "missing ARM64 executable $binary"
    readelf -h "$path" | grep -q 'Machine:.*AArch64' || rootfs_fail "not AArch64: $binary"
done
[[ -s $ROOTFS_TREE/usr/lib/ld-linux-aarch64.so.1 ]] || rootfs_fail 'missing ARM64 dynamic loader'
[[ -f $ROOTFS_TREE/usr/share/omarchy/bin/omarchy && -d $ROOTFS_TREE/usr/share/omarchy/shell ]] || rootfs_fail 'missing real Omarchy CLI/shell'
cmp "$ROOTFS_TREE/usr/share/omarchy/default/fonts/omarchy/omarchy.ttf" \
    "$ROOTFS_TREE/usr/share/fonts/omarchy/omarchy.ttf" || rootfs_fail 'missing or modified Omarchy icon font'
for user_home in root home/ioprobe; do
    [[ $(readlink "$ROOTFS_TREE/$user_home/.local/state/omarchy/current/background") == \
        /usr/share/omarchy/themes/tokyo-night/backgrounds/0-winding-road.webp ]] || rootfs_fail 'missing default wallpaper'
done
[[ -x $ROOTFS_TREE/usr/local/sbin/iomarchy-qemu-init ]] || rootfs_fail 'missing emulation init'
sha256sum -c artifacts/ROOTFS-SHA256SUMS
zstd --test artifacts/iomarchy-arm64-rootfs.tar.zst
printf 'PASS: ARM64 ELF headers, loader, official Omarchy source and archive integrity.\n'
printf 'NOT TESTED HERE: package runtime, compositor startup, iPad display or input.\n'
