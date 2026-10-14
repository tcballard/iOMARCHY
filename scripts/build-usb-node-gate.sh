#!/usr/bin/env bash
# Optional host-only reconnection experiment; baseline binaries are untouched.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p artifacts/usb-node-gate
# pkg-config returns compiler/linker words for the local toolchain.
# shellcheck disable=SC2046
cc -std=c11 -O2 -Wall -Wextra -Werror tools/usb-node-gate.c \
    $(pkg-config --cflags --libs fuse3) -o artifacts/usb-node-gate/usb-node-gate
sha256sum tools/usb-node-gate.c artifacts/usb-node-gate/usb-node-gate > artifacts/usb-node-gate/SHA256SUMS
