#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
output=${1:-artifacts/m1n1-linux.bin}
session=${2:-J96-FIRSTBOOT}
[[ $session =~ ^[a-zA-Z0-9-]+$ ]] || { echo 'Invalid session ID' >&2; exit 1; }
{
    cat artifacts/m1n1.bin
    printf 'chosen.bootargs=%s j96.session=%s\n' "$(<config/bootargs)" "$session"
    cat artifacts/t7000-j96.dtb artifacts/Image.gz artifacts/initramfs.cpio.gz
} > "$output"
