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
# Ubuntu 24.04 ships pacman 6 without architecture/hash/signature print fields.
pacman --config "$ROOTFS_WORK/pacman.conf" --dbpath "$ROOTFS_WORK/db" --sync --noconfirm --print-format $'%n\t%v\t%r\t%l' "${packages[@]}" | LC_ALL=C sort > "$ROOTFS_WORK/selection.tsv"
[[ -s $ROOTFS_WORK/selection.tsv ]] || rootfs_fail 'empty package closure'
rm -rf -- "$ROOTFS_WORK/db-meta"
mkdir -p "$ROOTFS_WORK/db-meta"
for db in "$ROOTFS_WORK/db/sync/"*.db; do
    repo=$(basename "$db" .db)
    mkdir -p "$ROOTFS_WORK/db-meta/$repo"
    bsdtar -xf "$db" -C "$ROOTFS_WORK/db-meta/$repo"
done
db_field() { awk -v field="$2" '$0 == "%" field "%" {getline; print; exit}' "$1"; }
: > "$ROOTFS_WORK/resolved.tsv"
while IFS=$'\t' read -r name version repo url; do
    desc="$ROOTFS_WORK/db-meta/$repo/$name-$version/desc"
    if [[ ! -s $desc ]]; then
        # repo-add may exclude epoch from directory names; match exact metadata.
        for candidate in "$ROOTFS_WORK/db-meta/$repo/$name-"*/desc; do
            [[ -s $candidate ]] || continue
            if [[ $(db_field "$candidate" NAME) == "$name" && $(db_field "$candidate" VERSION) == "$version" ]]; then desc=$candidate; break; fi
        done
    fi
    [[ -s $desc ]] || rootfs_fail "selected package absent from database: $repo/$name $version"
    [[ $(db_field "$desc" NAME) == "$name" && $(db_field "$desc" VERSION) == "$version" ]] || rootfs_fail "database name/version mismatch: $name"
    arch=$(db_field "$desc" ARCH)
    hash=$(db_field "$desc" SHA256SUM)
    sig=$(db_field "$desc" PGPSIG)
    if [[ -z $sig ]]; then
        # Embedding package signatures in the database is optional in repo-add.
        # Freeze the exact detached signature in the same lock instead.
        sigfile="$ROOTFS_CACHE/${url##*/}.sig"
        curl --fail --location --retry 3 --output "$sigfile" "$url.sig"
        sig=$(base64 --wrap=0 "$sigfile")
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$version" "$arch" "$hash" "$url" "$sig" >> "$ROOTFS_WORK/resolved.tsv"
done < "$ROOTFS_WORK/selection.tsv"
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
