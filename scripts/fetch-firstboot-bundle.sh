#!/usr/bin/env bash
# Retrieve verified binaries without a compiler or connected iPad.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
[[ $# == 0 ]] || { echo 'Usage: fetch-firstboot-bundle.sh' >&2; exit 2; }
mkdir -p downloads build artifacts
url=$(awk '$1 == "url" {print $2}' config/firstboot-bundle.lock)
digest=$(awk '$1 == "sha256" {print $2}' config/firstboot-bundle.lock)
[[ $url == https://* && $digest =~ ^[a-f0-9]{64}$ ]]
archive=downloads/firstboot-bundle.zip
if [[ ! -f $archive ]] || [[ $(sha256sum "$archive" | cut -d' ' -f1) != "$digest" ]]; then
    echo 'Downloading the verified minimal boot bundle...'
    curl --fail --location --retry 3 --output "$archive.part" "$url" || {
        echo 'Pinned bundle unavailable. Retain the verified cache or rebuild the pinned sources; no replacement was selected.' >&2
        exit 1
    }
    [[ $(sha256sum "$archive.part" | cut -d' ' -f1) == "$digest" ]] || {
        echo 'STOP: boot bundle ZIP checksum mismatch.' >&2; exit 1;
    }
    mv -- "$archive.part" "$archive"
fi
stage=$(mktemp -d "$PWD/build/bundle-XXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir "$stage/artifacts"
while read -r hash path; do
    [[ $hash =~ ^[a-f0-9]{64}$ && $path =~ ^artifacts/[a-zA-Z0-9._-]+$ ]]
    unzip -p "$archive" "$path" > "$stage/$path"
done < docs/validation/2026-10-13/baseline-SHA256SUMS
cp docs/validation/2026-10-13/baseline-SHA256SUMS "$stage/artifacts/SHA256SUMS"
(cd "$stage" && sha256sum -c artifacts/SHA256SUMS)
# Preserve differing local build outputs before installing the verified set.
backup=
while read -r hash path; do
    if [[ -e $path ]] && [[ $(sha256sum "$path" | cut -d' ' -f1) != "$hash" ]]; then
        if [[ -z $backup ]]; then backup=$(mktemp -d "$PWD/build/previous-artifacts-XXXX"); fi
        cp -a -- "$path" "$backup/"
    fi
    mv -- "$stage/$path" "$path"
done < "$stage/artifacts/SHA256SUMS"
mv -- "$stage/artifacts/SHA256SUMS" artifacts/SHA256SUMS
chmod 755 artifacts/palera1n artifacts/pongoterm artifacts/busybox
[[ -z $backup ]] || printf 'Previous differing artifacts preserved: %s\n' "$backup"
echo 'Verified minimal boot bundle ready. No device accessed.'
