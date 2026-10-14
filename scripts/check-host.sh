#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
device=0
artifacts=0
tools_only=0
for option in "$@"; do
    case "$option" in
        --device) device=1 ;;
        --artifacts) artifacts=1 ;;
        --tools-only) tools_only=1 ;;
        *) echo 'Usage: check-host.sh [--device] [--artifacts] [--tools-only]' >&2; exit 2 ;;
    esac
done
missing=0
commands=(bash sha256sum awk cat cut find stat readlink uname df grep)
if [[ $device == 0 ]]; then
    commands+=(git curl make cc clang ld.lld llvm-objcopy aarch64-linux-gnu-gcc bc flex bison dtc fdtget cpio gzip unzip shellcheck pkg-config patch gpg gpgv file readelf ldd cmp sort xargs tar od)
fi
for command in "${commands[@]}"; do
    command -v "$command" >/dev/null || { echo "MISSING: $command"; missing=1; }
done
# shellcheck source=scripts/lib/qemu.sh
source scripts/lib/qemu.sh
if [[ $device == 0 ]]; then
    find_qemu_aarch64 || missing=1
    if command -v pkg-config >/dev/null; then
        pkg-config --exists libusb-1.0 || { echo 'MISSING: libusb development files'; missing=1; }
    fi
fi
[[ $(uname -s) == Linux ]] || { echo 'The build workflow requires a Linux host'; missing=1; }
if [[ $device == 1 ]]; then
    for command in picocom ideviceinfo idevice_id setsid timeout bwrap flock ldd modprobe mknod mktemp tee tr; do
        command -v "$command" >/dev/null || { echo "MISSING: device host tool $command"; missing=1; }
    done
    if [[ $tools_only == 0 && ! -d /sys/module/cdc_acm ]]; then
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
if [[ $device == 0 ]]; then printf 'Selected ARM64 emulator: %s\n' "$QEMU_AARCH64"; fi
if [[ $artifacts == 1 ]]; then
    sha256sum -c artifacts/SHA256SUMS
    if [[ $device == 1 ]]; then
        # Hashes are verified before inspecting these trusted host executables.
        for binary in artifacts/pongoterm artifacts/palera1n; do
            report=$(ldd "$binary" 2>&1 || true)
            if [[ $report == *'not found'* ]]; then
                printf 'MISSING: host runtime libraries for %s\n%s\n' "$binary" "$report"
                exit 1
            fi
        done
    fi
fi
if [[ $device == 1 ]]; then
    if [[ $tools_only == 1 ]]; then
        echo 'Runtime tools and requested artifacts checked; USB driver and namespaces not tested.'
        exit 0
    fi
    # Exercise the actual device-node mount without enumerating/exposing USB.
    # /bin/true alone misses nodev inherited from a staging directory on /tmp.
    [[ $EUID == 0 ]] || { echo 'Run device namespace checks with sudo (or use start.sh --check).'; exit 1; }
    probe=$(mktemp -d /dev/j96-check-XXXX)
    cleanup_probe() {
        find "$probe" -type c -delete
        find "$probe" -depth -type d -empty -delete
    }
    trap cleanup_probe EXIT
    mkdir "$probe/001"
    mknod -m 0600 "$probe/001/001" c 1 3 # harmless /dev/null, not a USB device
    bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
        --dev-bind "$probe" /dev/bus/usb --unshare-pid --die-with-parent \
        /bin/sh -c ': < /dev/bus/usb/001/001; : > /dev/bus/usb/001/001'
    cleanup_probe
    trap - EXIT
    echo 'Device-host readiness checks passed. No device interaction performed.'
else
    echo 'Build-host checks passed. Device tools, USB drivers and namespace access were not checked.'
fi
