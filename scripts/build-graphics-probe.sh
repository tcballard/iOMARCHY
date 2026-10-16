#!/usr/bin/env bash
# Build a separate, hardware-untested kernel. Never launch device tools.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
[[ $# == 0 ]] || { echo 'Usage: build-graphics-probe.sh' >&2; exit 2; }
for command in git make clang ld.lld llvm-objcopy bc flex bison sha256sum awk fdtget; do
    command -v "$command" >/dev/null || { echo "Missing build tool: $command" >&2; exit 1; }
done
expected=$(awk '$1 == "linux" {print $3}' config/sources.lock)
[[ $(git -C src/linux rev-parse HEAD) == "$expected" ]] || { echo 'Pinned Linux source required' >&2; exit 1; }
[[ -z $(git -C src/linux status --porcelain --untracked-files=no) ]] || { echo 'Linux tracked sources must be clean' >&2; exit 1; }
build_dir="$PWD/build/graphics-probe/linux"
output="$PWD/artifacts/graphics-probe"
mkdir -p "$build_dir" "$output" logs
fragment="$PWD/build/graphics-probe/kernel.fragment"
# Remove overlay symbols first so no symbol appears twice in allnoconfig input.
awk 'FNR == NR {
    if ($0 ~ /^CONFIG_[A-Z0-9_]+=/) { split($0, a, "="); overridden[a[1]]=1 }
    else if ($0 ~ /^# CONFIG_[A-Z0-9_]+ is not set$/) overridden[$2]=1
    next
}
{
    symbol=""
    if ($0 ~ /^CONFIG_[A-Z0-9_]+=/) { split($0, a, "="); symbol=a[1] }
    else if ($0 ~ /^# CONFIG_[A-Z0-9_]+ is not set$/) symbol=$2
    if (!(symbol in overridden)) print
}' config/graphics-probe.fragment config/kernel.fragment > "$fragment"
cat config/graphics-probe.fragment >> "$fragment"
export KBUILD_BUILD_TIMESTAMP='2026-10-12 00:00:00 UTC'
export KBUILD_BUILD_USER=j96 KBUILD_BUILD_HOST=omarchy KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1791763200 KCONFIG_NOTIMESTAMP=1
make -C src/linux O="$build_dir" ARCH=arm64 LLVM=1 KCONFIG_ALLCONFIG="$fragment" allnoconfig > logs/graphics-probe-config.log 2>&1
for flag in CONFIG_ARM64_4K_PAGES CONFIG_DRM CONFIG_DRM_SIMPLEDRM CONFIG_DRM_FBDEV_EMULATION CONFIG_INPUT_EVDEV CONFIG_INPUT_UINPUT CONFIG_NET CONFIG_UNIX; do
    grep -qx "$flag=y" "$build_dir/.config" || { echo "Effective configuration missing: $flag=y" >&2; exit 1; }
done
for flag in CONFIG_ARM64_16K_PAGES CONFIG_ARM64_64K_PAGES CONFIG_FB_SIMPLE CONFIG_MODULES CONFIG_BLOCK CONFIG_INET CONFIG_WLAN CONFIG_SOUND; do
    # Kconfig may omit a disabled symbol when its enclosing menu is unavailable.
    if grep -Eq "^$flag=(y|m)$" "$build_dir/.config"; then
        echo "Effective configuration unexpectedly enables: $flag" >&2; exit 1
    fi
done
make -C src/linux O="$build_dir" ARCH=arm64 LLVM=1 -j"${JOBS:-4}" Image.gz apple/t7000-j96.dtb > logs/graphics-probe-build.log 2>&1
cp "$build_dir/arch/arm64/boot/Image" "$build_dir/arch/arm64/boot/Image.gz" "$output/"
cp "$build_dir/arch/arm64/boot/dts/apple/t7000-j96.dtb" "$output/"
cp "$build_dir/.config" "$output/kernel.config"
[[ $(fdtget -t s "$output/t7000-j96.dtb" / compatible) == 'apple,j96 apple,t7000 apple,arm-platform' ]]
{
    printf 'Status: built, hardware untested; not a desktop image\nLinux commit: %s\n' "$expected"
    printf 'Compiler: '; clang --version | head -1
    printf 'Baseline fragment: '; sha256sum config/kernel.fragment
    printf 'Probe overlay: '; sha256sum config/graphics-probe.fragment
    printf 'Expected display: loader-provided simple-framebuffer, simpledrm KMS, no GPU acceleration\n'
    printf 'No m1n1 assembly or device interaction performed\n'
} > "$output/MANIFEST.txt"
sha256sum "$output"/Image "$output"/Image.gz "$output"/t7000-j96.dtb "$output"/kernel.config "$output"/MANIFEST.txt |
    sed "s|$PWD/||" > "$output/SHA256SUMS"
sha256sum -c "$output/SHA256SUMS"
echo 'Separate graphics-probe kernel built. Baseline boot artifacts were not changed.'
