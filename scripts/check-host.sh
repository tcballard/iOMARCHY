#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
missing=0
for command in bash git make cc clang ld.lld llvm-objcopy aarch64-linux-gnu-gcc bc flex bison dtc fdtget cpio gzip unzip sha256sum qemu-aarch64-static shellcheck pkg-config picocom ideviceinfo idevice_id setsid timeout bwrap flock patch gpgv; do
    command -v "$command" >/dev/null || { echo "MISSING: $command"; missing=1; }
done
pkg-config --exists libusb-1.0 || { echo 'MISSING: libusb'; missing=1; }
if [[ ! -d /sys/module/cdc_acm ]]; then
    modinfo cdc_acm >/dev/null || { echo 'MISSING: host cdc_acm USB serial driver'; missing=1; }
fi
[[ $(uname -m) == x86_64 ]] || { echo 'Host palera1n binary requires x86_64'; missing=1; }
uname -srmo
free -h
df -h .
[[ $missing == 0 ]] || exit 1
if [[ ${1:-} == --artifacts ]]; then
    sha256sum -c artifacts/SHA256SUMS
fi
echo 'Host checks passed. No device interaction performed.'
