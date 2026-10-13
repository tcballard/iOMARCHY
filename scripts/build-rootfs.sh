#!/usr/bin/env bash
# Separate experimental ARM64 userspace build. Does not change firstboot.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/rootfs-common.sh
source scripts/rootfs-common.sh
[[ $# == 1 ]] || rootfs_fail 'usage: sudo scripts/build-rootfs.sh config/rootfs-inputs.lock'
lock=$(realpath "$1")
[[ -s $lock ]] || rootfs_fail 'missing lock: run resolve-rootfs.sh explicitly first'
[[ $EUID == 0 ]] || rootfs_fail 'package ownership/database creation require root; use sudo'
rootfs_require curl bsdtar sha256sum gpg gpgv base64 sort awk tar zstd readelf pacman
rootfs_setup
rootfs_config
rootfs_trust
[[ $(awk -F '\t' '$1=="source" {print $3}' "$lock") == "$ROOTFS_OMARCHY_REV" ]] || rootfs_fail 'wrong Omarchy source revision'
[[ $(awk -F '\t' '$1=="package" {n++} END {print n+0}' "$lock") -gt 20 ]] || rootfs_fail 'incomplete package lock'
rm -rf -- "$ROOTFS_TREE"
mkdir -p "$ROOTFS_TREE"
: > logs/rootfs/package-verification.log
package_files=()
while IFS=$'\t' read -r type name version arch hash url sig; do
    [[ $type == package || $type == source ]] || continue
    [[ $hash =~ ^[0-9a-f]{64}$ && $url == https://* ]] || rootfs_fail "malformed lock record: $name"
    if [[ $type == source ]]; then
        archive="$ROOTFS_CACHE/omarchy-$version.tar.gz"
        rootfs_download "$url" "$hash" "$archive"
        mkdir -p "$ROOTFS_TREE/usr/share/omarchy"
        bsdtar -xf "$archive" --strip-components=1 -C "$ROOTFS_TREE/usr/share/omarchy"
        continue
    fi
    [[ $arch == aarch64 || $arch == any ]] || rootfs_fail "wrong architecture: $name $arch"
    [[ -n $sig && $sig != '(null)' ]] || rootfs_fail "no package signature: $name"
    archive="$ROOTFS_CACHE/${url##*/}"
    rootfs_download "$url" "$hash" "$archive"
    printf '%s' "$sig" | base64 --decode > "$archive.sig"
    gpgv --homedir "$ROOTFS_WORK/gpg" --keyring "$ROOTFS_WORK/trusted.gpg" "$archive.sig" "$archive" >> logs/rootfs/package-verification.log 2>&1 || rootfs_fail "signature verification: $name"
    printf 'VERIFIED %s %s %s\n' "$name" "$version" "$hash" >> logs/rootfs/package-verification.log
    bsdtar -xf "$archive" -C "$ROOTFS_TREE" --exclude=.PKGINFO --exclude=.BUILDINFO --exclude=.MTREE --exclude=.INSTALL
    package_files+=("$archive")
done < "$lock"
# No foreign package hooks. GPG above verifies every archive before registration.
mkdir -p "$ROOTFS_TREE/var/lib/pacman/local" "$ROOTFS_TREE/var/log"
pacman --config "$ROOTFS_WORK/pacman.conf" --root "$ROOTFS_TREE" --dbpath "$ROOTFS_TREE/var/lib/pacman" --logfile "$ROOTFS_TREE/var/log/pacman.log" --upgrade --dbonly --nodeps --noscriptlet --noconfirm "${package_files[@]}"
# Remove the host transaction clock from the reproducible tree.
find "$ROOTFS_TREE/var/lib/pacman/local" -name desc -exec sed -i '/^%INSTALLDATE%$/{n;s/.*/1791849600/;}' {} +
: > "$ROOTFS_TREE/var/log/pacman.log"
cp -a rootfs-overlay/. "$ROOTFS_TREE/"
mkdir -p "$ROOTFS_TREE/root/.config/omarchy/current" "$ROOTFS_TREE/root/.local/state/omarchy/current" "$ROOTFS_TREE/home/ioprobe" "$ROOTFS_TREE/etc/profile.d" "$ROOTFS_TREE/run" "$ROOTFS_TREE/proc" "$ROOTFS_TREE/sys" "$ROOTFS_TREE/dev" "$ROOTFS_TREE/tmp"
chmod 1777 "$ROOTFS_TREE/tmp"
upstream="$ROOTFS_TREE/usr/share/omarchy"
[[ -d $upstream/shell && -d $upstream/config/hypr && -f $upstream/bin/omarchy ]] || rootfs_fail 'pinned archive lacks shell/Hyprland/CLI'
cp -a "$upstream/config/." "$ROOTFS_TREE/root/.config/"
cp "$upstream/default/bashrc" "$ROOTFS_TREE/root/.bashrc"
ln -sfn /usr/share/omarchy/themes/tokyo-night "$ROOTFS_TREE/root/.config/omarchy/current/theme"
ln -sfn /usr/share/omarchy/themes/tokyo-night "$ROOTFS_TREE/root/.local/state/omarchy/current/theme"
# shellcheck disable=SC2016
printf '%s\n' 'export OMARCHY_PATH=/usr/share/omarchy' 'export PATH=/usr/share/omarchy/bin:$PATH' > "$ROOTFS_TREE/etc/profile.d/iomarchy.sh"
printf '%s\n' 'LANG=C.UTF-8' > "$ROOTFS_TREE/etc/locale.conf"
printf '%s\n' 'iomarchy-emulator' > "$ROOTFS_TREE/etc/hostname"
printf '%s\n' 'root:x:0:0:root:/root:/bin/bash' 'ioprobe:x:1000:1000:emulation-only user:/home/ioprobe:/bin/bash' > "$ROOTFS_TREE/etc/passwd"
printf '%s\n' 'root:x:0:' 'ioprobe:x:1000:' > "$ROOTFS_TREE/etc/group"
printf '%s\n' 'root:!:20000:0:99999:7:::' 'ioprobe:!:20000:0:99999:7:::' > "$ROOTFS_TREE/etc/shadow"
chmod 600 "$ROOTFS_TREE/etc/shadow"
cp -a "$ROOTFS_TREE/root/.config" "$ROOTFS_TREE/root/.local" "$ROOTFS_TREE/root/.bashrc" "$ROOTFS_TREE/home/ioprobe/"
chown -R 1000:1000 "$ROOTFS_TREE/home/ioprobe"
printf '%s\n' 'EXPERIMENTAL ARM64 OMARCHY SUBSET - HARDWARE UNTESTED.' 'No installation scripts or Apple/Asahi hardware setup were run.' > "$ROOTFS_TREE/etc/issue"
cp "$lock" "$ROOTFS_TREE/etc/iomarchy/input.lock"
cp config/rootfs-packages.list "$ROOTFS_TREE/etc/iomarchy/package-roots.list"
cp config/rootfs-keyrings/SHA256SUMS "$ROOTFS_TREE/etc/iomarchy/keyring-sha256.txt"
# Hooks, machine IDs, locale/font caches and a guest ld cache are not generated.
find "$ROOTFS_TREE" -exec touch -h -d "@$ROOTFS_EPOCH" {} +
tar --sort=name --mtime="@$ROOTFS_EPOCH" --format=gnu --numeric-owner -C "$ROOTFS_TREE" -cf - . | zstd -T1 -19 --no-progress -f -o artifacts/iomarchy-arm64-rootfs.tar.zst
sha256sum artifacts/iomarchy-arm64-rootfs.tar.zst > artifacts/ROOTFS-SHA256SUMS
cp "$lock" artifacts/rootfs-inputs.lock
{
    printf 'Omarchy source: %s\nSource epoch: %s\n' "$ROOTFS_OMARCHY_REV" "$ROOTFS_EPOCH"
    printf 'Input lock SHA256: %s\n' "$(sha256sum "$lock" | cut -d' ' -f1)"
    printf 'Package count: %s\n' "${#package_files[@]}"
    du -sh "$ROOTFS_TREE"
    cat artifacts/ROOTFS-SHA256SUMS
    printf 'Built ARM64 userspace subset only. No iPad boot/drivers validated.\n'
} | tee artifacts/ROOTFS-MANIFEST.txt
scripts/verify-rootfs.sh
