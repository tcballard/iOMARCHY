#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
find artifacts -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > artifacts/SHA256SUMS
{
    echo 'J96 first native Linux boot preparation'
    date --utc --iso-8601=seconds
    printf 'Workspace: %s\n' "$PWD"
    echo 'This build manifest does not establish hardware boot success; see docs/hardware-boot.md.'
    cat config/sources.lock
    printf '\nToolchain and installed host packages:\n'
    clang --version
    ld.lld --version
    aarch64-linux-gnu-gcc --version
    make --version
    qemu-aarch64-static --version
    pacman -Q aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils aarch64-linux-gnu-glibc clang llvm lld bc shellcheck picocom libusb libimobiledevice bubblewrap
    printf '\nBuild environment:\n'
    echo 'ARCH=arm64 LLVM=1 JOBS=4; BusyBox CROSS_COMPILE=aarch64-linux-gnu-'
    echo 'SOURCE_DATE_EPOCH=1791763200 KCONFIG_NOTIMESTAMP=1'
    echo 'KBUILD_BUILD_TIMESTAMP=2026-10-12 00:00:00 UTC; user=j96 host=omarchy version=1'
    printf '\nArtifact SHA256:\n'
    cat artifacts/SHA256SUMS
    printf '\nInputs SHA256:\n'
    sha256sum README.md docs/*.md config/* scripts/*.sh initramfs/*
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
