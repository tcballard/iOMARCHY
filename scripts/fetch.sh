#!/usr/bin/env bash
# Restore the pinned inputs; cached archives are the durable offline copy.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p src downloads build logs artifacts
fetch() {
    local url=$1 target=$2
    if [[ ! -s $target ]]; then
        curl --fail --location --retry 3 "$url" -o "$target.part"
        mv -- "$target.part" "$target"
    fi
}
for name in linux docs pongoOS; do
    read -r _ url revision < <(awk -v n="$name" '$1 == n' config/sources.lock)
    if [[ ! -d src/$name/.git ]]; then
        git init "src/$name"
        git -C "src/$name" remote add origin "$url"
        git -C "src/$name" fetch --depth 1 origin "$revision"
        git -C "src/$name" checkout --detach "$revision"
    fi
    [[ $(git -C "src/$name" rev-parse HEAD) == "$revision" ]] || {
        echo "src/$name revision differs; preserve it and restore the pinned checkout separately." >&2
        exit 1
    }
done
fetch https://busybox.net/downloads/busybox-1.37.0.tar.bz2 downloads/busybox-1.37.0.tar.bz2
fetch https://busybox.net/downloads/busybox-1.37.0.tar.bz2.sig downloads/busybox-1.37.0.tar.bz2.sig
fetch https://busybox.net/~vda/vda_pubkey.gpg downloads/vda_pubkey.gpg
fetch https://github.com/palera1n/palera1n/releases/download/v2.4/palera1n-linux-x86_64 downloads/palera1n-linux-x86_64
# This is a specific artifact ID, never a moving "latest" URL. It expires at
# GitHub on 2026-11-29; retain downloads/m1n1-9753630137.zip for offline rebuilds.
fetch https://nightly.link/HoolockLinux/m1n1/actions/artifacts/9753630137.zip downloads/m1n1-9753630137.zip
sha256sum -c config/downloads.sha256
gpg --batch --yes --dearmor --output build/vda-keyring.gpg downloads/vda_pubkey.gpg
gpgv --keyring "$PWD/build/vda-keyring.gpg" downloads/busybox-1.37.0.tar.bz2.sig downloads/busybox-1.37.0.tar.bz2
[[ -d src/busybox-1.37.0 ]] || tar -xf downloads/busybox-1.37.0.tar.bz2 -C src
