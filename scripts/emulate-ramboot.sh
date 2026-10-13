#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
sha256sum -c artifacts/qemu/SHA256SUMS artifacts/ramboot/SHA256SUMS artifacts/SQUASHFS-SHA256SUMS
exec node scripts/qemu-evidence.mjs ram "${QEMU_MEMORY:-2048}"
