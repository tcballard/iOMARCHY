#!/usr/bin/env bash
# Network resolution is intentional and separate from a locked rebuild.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/rootfs-common.sh
source scripts/rootfs-common.sh
[[ $# == 1 ]] || rootfs_fail 'usage: sudo scripts/resolve-rootfs.sh artifacts/rootfs-inputs.lock'
lock=$1
[[ ! -e $lock ]] || rootfs_fail 'refusing to overwrite a lock; review a new filename'
[[ $EUID == 0 ]] || rootfs_fail 'pacman database refresh requires root; use sudo'
rootfs_require pacman curl bsdtar sha256sum gpg gpgv base64 sort awk
rootfs_setup
rootfs_config
rootfs_trust
mapfile -t packages < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' config/rootfs-packages.list)
pacman --config "$ROOTFS_WORK/pacman.conf" --dbpath "$ROOTFS_WORK/db" --logfile "$PWD/logs/rootfs/pacman-resolve.log" --sync --refresh --noconfirm
pacman --config "$ROOTFS_WORK/pacman.conf" --dbpath "$ROOTFS_WORK/db" --sync --print-format $'%n\t%v\t%a\t%h\t%l\t%g' "${packages[@]}" | LC_ALL=C sort > "$ROOTFS_WORK/resolved.tsv"
[[ -s $ROOTFS_WORK/resolved.tsv ]] || rootfs_fail 'empty package closure'
archive="$ROOTFS_CACHE/omarchy-$ROOTFS_OMARCHY_REV.tar.gz"
curl --fail --location --retry 3 --output "$archive" "https://codeload.github.com/omacom/omarchy/tar.gz/$ROOTFS_OMARCHY_REV"
mkdir -p "$(dirname -- "$lock")"
{
    printf '# iOMARCHY ARM64 input lock v1; resolve is a reviewed network snapshot.\n'
    printf '# type\tname\tversion\tarchitecture\tsha256\tHTTPS URL\tPGP signature (base64)\n'
    printf 'source\tomarchy\t%s\tany\t%s\t%s\t-\n' "$ROOTFS_OMARCHY_REV" "$(sha256sum "$archive" | cut -d' ' -f1)" "https://codeload.github.com/omacom/omarchy/tar.gz/$ROOTFS_OMARCHY_REV"
    for db in "$ROOTFS_WORK/db/sync/"*.db; do
        repo=$(basename "$db" .db)
        if [[ $repo == omarchy ]]; then url="https://pkgs.omarchy.org/edge/aarch64/$repo.db"; else url="https://arm-mirror.omarchy.org/aarch64/$repo/$repo.db"; fi
        printf 'database\t%s\tresolved\taarch64\t%s\t%s\t-\n' "$repo" "$(sha256sum "$db" | cut -d' ' -f1)" "$url"
    done
    while IFS=$'\t' read -r name version arch hash url sig; do
        [[ $arch == aarch64 || $arch == any ]] || rootfs_fail "wrong architecture: $name $arch"
        [[ $hash =~ ^[0-9a-f]{64}$ && $url == https://* && $sig != '(null)' && -n $sig ]] || rootfs_fail "missing integrity/signature: $name"
        printf 'package\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$version" "$arch" "$hash" "$url" "$sig"
    done < "$ROOTFS_WORK/resolved.tsv"
} > "$lock.tmp"
mv -- "$lock.tmp" "$lock"
printf 'RESOLVED: %s packages; review and commit %s before future rebuilds.\n' "$(wc -l < "$ROOTFS_WORK/resolved.tsv")" "$lock"
