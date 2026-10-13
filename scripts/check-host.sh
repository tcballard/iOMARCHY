#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
device=0
artifacts=0
for option in "$@"; do
    case "$option" in
        --device) device=1 ;;
        --artifacts) artifacts=1 ;;
        *) echo 'Usage: check-host.sh [--device] [--artifacts]' >&2; exit 2 ;;
    esac
done
missing=0
for command in bash git curl make cc clang ld.lld llvm-objcopy aarch64-linux-gnu-gcc bc flex bison dtc fdtget cpio gzip unzip sha256sum shellcheck pkg-config patch gpg gpgv file readelf ldd awk cmp find sort xargs tar od; do
    command -v "$command" >/dev/null || { echo "MISSING: $command"; missing=1; }
done
# shellcheck source=scripts/lib/qemu.sh
source scripts/lib/qemu.sh
find_qemu_aarch64 || missing=1
if command -v pkg-config >/dev/null; then
    pkg-config --exists libusb-1.0 || { echo 'MISSING: libusb development files'; missing=1; }
fi
[[ $(uname -s) == Linux ]] || { echo 'The build workflow requires a Linux host'; missing=1; }
if [[ $device == 1 ]]; then
    for command in picocom ideviceinfo idevice_id setsid timeout bwrap flock; do
        command -v "$command" >/dev/null || { echo "MISSING: device host tool $command"; missing=1; }
    done
    if [[ ! -d /sys/module/cdc_acm ]]; then
        if ! command -v modinfo >/dev/null || ! modinfo cdc_acm >/dev/null; then
            echo 'MISSING: host cdc_acm USB serial driver'; missing=1
        fi
    fi
    [[ $(uname -m) == x86_64 ]] || { echo 'Device boot requires the pinned x86_64 palera1n binary'; missing=1; }
fi
uname -srmo
if command -v free >/dev/null; then free -h; fi
df -h .
[[ $missing == 0 ]] || exit 1
printf 'Selected ARM64 emulator: %s\n' "$QEMU_AARCH64"
if [[ $artifacts == 1 ]]; then
    sha256sum -c artifacts/SHA256SUMS
fi
if [[ $device == 1 ]]; then
    # Validate namespace support without enumerating or exposing USB devices.
    bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-pid --die-with-parent /bin/true
    echo 'Device-host readiness checks passed. No device interaction performed.'
else
    echo 'Build-host checks passed. Device tools, USB drivers and namespace access were not checked.'
fi
