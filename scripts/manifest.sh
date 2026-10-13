#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/lib/qemu.sh
source scripts/lib/qemu.sh
find_qemu_aarch64
# Derivative root filesystems and probe kernels have their own manifests.
# Keep this checksum file limited to the eleven minimal first-boot artifacts.
sha256sum artifacts/Image artifacts/Image.gz artifacts/Pongo.bin \
    artifacts/busybox artifacts/initramfs.cpio.gz artifacts/kernel.config \
    artifacts/m1n1-linux.bin artifacts/m1n1.bin artifacts/palera1n \
    artifacts/pongoterm artifacts/t7000-j96.dtb > artifacts/SHA256SUMS
{
    echo 'J96 first native Linux boot preparation'
    date --utc --iso-8601=seconds
    printf 'Workspace: %s\n' "$PWD"
    echo 'This build manifest does not establish hardware boot success; see docs/hardware-boot.md.'
    cat config/sources.lock
    printf '\nHost and toolchain:\n'
    uname -srmo
    if [[ -f /etc/os-release ]]; then cat /etc/os-release; fi
    clang --version
    ld.lld --version
    aarch64-linux-gnu-gcc --version
    make --version
    printf 'Selected QEMU: %s\n' "$QEMU_AARCH64"
    "$QEMU_AARCH64" --version
    printf '\nInstalled build packages (when a supported package database exists):\n'
    if command -v pacman >/dev/null; then
        for package in aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils aarch64-linux-gnu-glibc clang llvm lld bc shellcheck libusb qemu-user-static qemu-user; do
            pacman -Q "$package" 2>/dev/null || true
        done
    elif command -v dpkg-query >/dev/null; then
        for package in gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross clang llvm lld bc shellcheck libusb-1.0-0-dev qemu-user-static qemu-user; do
            dpkg-query -W -f='${Package}\t${Version}\n' "$package" 2>/dev/null || true
        done
    elif command -v rpm >/dev/null; then
        rpm -q clang llvm lld bc ShellCheck libusb1-devel qemu-user-static 2>/dev/null || true
    else
        echo 'No supported package database; toolchain versions above remain recorded.'
    fi
    printf '\nBuild environment:\n'
    printf 'ARCH=arm64 LLVM=1 JOBS=%s; BusyBox CROSS_COMPILE=aarch64-linux-gnu-\n' "${JOBS:-4}"
    echo 'SOURCE_DATE_EPOCH=1791763200 KCONFIG_NOTIMESTAMP=1'
    echo 'KBUILD_BUILD_TIMESTAMP=2026-10-12 00:00:00 UTC; user=j96 host=omarchy version=1'
    printf '\nArtifact SHA256:\n'
    cat artifacts/SHA256SUMS
    printf '\nInputs SHA256:\n'
    find README.md docs config scripts initramfs -type f \
        ! -path 'docs/validation/*' -print0 | sort -z | xargs -0 sha256sum
    printf '\nReference/metadata SHA256:\n'
    shopt -s nullglob
    metadata=(downloads/*.json downloads/*reference.c downloads/mainline-t7000-j96.dts)
    # Reference snapshots are optional: fetch.sh retrieves only build inputs.
    for file in "${metadata[@]}"; do
        [[ ! -f $file ]] || sha256sum "$file"
    done
    printf '\nVerification:\n'
    cat logs/verification.log
    if [[ -f logs/reproducibility.log ]]; then
        printf '\nRepeat-workflow artifact hash comparison (same workspace):\n'
        cat logs/reproducibility.log
    fi
    printf '\nComplete final kernel configuration:\n'
    cat artifacts/kernel.config
} > MANIFEST.txt
