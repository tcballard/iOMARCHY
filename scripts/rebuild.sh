#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
scripts/check-host.sh
mkdir -p build/linux logs artifacts
sha256sum -c config/downloads.sha256
# Fail instead of silently rebuilding newer revisions or local source changes.
for name in linux docs pongoOS; do
    expected=$(awk -v n="$name" '$1 == n {print $3}' config/sources.lock)
    [[ $(git -C "src/$name" rev-parse HEAD) == "$expected" ]]
    [[ -z $(git -C "src/$name" status --porcelain --untracked-files=no) ]]
done
export KBUILD_BUILD_TIMESTAMP='2026-10-12 00:00:00 UTC'
export KBUILD_BUILD_USER=j96 KBUILD_BUILD_HOST=omarchy KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1791763200 KCONFIG_NOTIMESTAMP=1
make -C src/linux O="$PWD/build/linux" ARCH=arm64 LLVM=1 KCONFIG_ALLCONFIG="$PWD/config/kernel.fragment" allnoconfig > logs/kernel-config.log 2>&1
make -C src/linux O="$PWD/build/linux" ARCH=arm64 LLVM=1 -j"${JOBS:-4}" Image.gz apple/t7000-j96.dtb > logs/kernel-build.log 2>&1
cp build/linux/arch/arm64/boot/Image{,.gz} artifacts/
cp build/linux/arch/arm64/boot/dts/apple/t7000-j96.dtb artifacts/
cp build/linux/.config artifacts/kernel.config
cp config/busybox.config src/busybox-1.37.0/.config
make -C src/busybox-1.37.0 CROSS_COMPILE=aarch64-linux-gnu- -j"${JOBS:-4}" > logs/busybox-build.log 2>&1
scripts/build-initramfs.sh > logs/initramfs-build.log 2>&1
unzip -p downloads/m1n1-9753630137.zip m1n1.bin > artifacts/m1n1.bin
cp src/docs/binaries/Pongo.bin artifacts/Pongo.bin
install -m755 downloads/palera1n-linux-x86_64 artifacts/palera1n
patch -s -o build/pongoterm.c src/pongoOS/scripts/pongoterm.c < config/pongoterm-identity.patch
clang -Os build/pongoterm.c -DUSE_LIBUSB -lusb-1.0 -pthread -o artifacts/pongoterm > logs/pongoterm-build.log 2>&1
scripts/assemble.sh
scripts/verify.sh 2>&1 | tee logs/verification.log
scripts/manifest.sh
