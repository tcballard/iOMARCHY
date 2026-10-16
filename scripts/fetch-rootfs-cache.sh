#!/usr/bin/env bash
# Restore exact inputs when rolling mirrors have removed pinned package files.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p downloads/rootfs build
url=$(awk '$1 == "url" {print $2}' config/rootfs-cache.lock)
digest=$(awk '$1 == "sha256" {print $2}' config/rootfs-cache.lock)
[[ $url == https://* && $digest =~ ^[a-f0-9]{64}$ ]]
scratch=$(mktemp -d "$PWD/build/input-cache-XXXX")
trap 'rm -rf -- "$scratch"' EXIT
curl --fail --location --retry 3 --output "$scratch/cache.zip" "$url"
[[ $(sha256sum "$scratch/cache.zip" | cut -d' ' -f1) == "$digest" ]] || {
    echo 'STOP: archived input ZIP checksum mismatch.' >&2; exit 1;
}
# The archive is authenticated above; extract only the cache's ordinary files.
unzip -p "$scratch/cache.zip" artifacts/rootfs-download-cache.tar |
    tar --extract --file=- --directory=downloads --no-same-owner --no-same-permissions
echo 'Exact package cache restored. The builder still checks each hash and signature.'
