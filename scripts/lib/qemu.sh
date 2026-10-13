#!/usr/bin/env bash
# Select explicit user-mode emulation; static QEMU is only needed for chroots.
find_qemu_aarch64() {
    if [[ -n ${QEMU_AARCH64:-} ]]; then
        command -v "$QEMU_AARCH64" >/dev/null || {
            echo "MISSING: QEMU_AARCH64=$QEMU_AARCH64" >&2
            return 1
        }
    elif command -v qemu-aarch64-static >/dev/null; then
        QEMU_AARCH64=$(command -v qemu-aarch64-static)
    elif command -v qemu-aarch64 >/dev/null; then
        QEMU_AARCH64=$(command -v qemu-aarch64)
    else
        echo 'MISSING: qemu-aarch64-static or qemu-aarch64' >&2
        return 1
    fi
    export QEMU_AARCH64
}
