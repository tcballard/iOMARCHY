#!/usr/bin/env bash
# Deterministic defaults for the isolated userspace image, without provisioning.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source scripts/rootfs-common.sh
[[ $EUID == 0 ]] || rootfs_fail 'use sudo to configure the root-owned image'
upstream="$ROOTFS_TREE/usr/share/omarchy"
background=/usr/share/omarchy/themes/tokyo-night/backgrounds/0-winding-road.webp
[[ -s $ROOTFS_TREE$background ]] || rootfs_fail 'missing pinned Tokyo Night wallpaper'
# Keeping the source under /usr/share/omarchy alone does not register this
# private-use icon font with fontconfig. Copy its unchanged upstream bytes.
install -Dm644 "$upstream/default/fonts/omarchy/omarchy.ttf" \
    "$ROOTFS_TREE/usr/share/fonts/omarchy/omarchy.ttf"
for user_home in root home/ioprobe; do
    current="$ROOTFS_TREE/$user_home/.local/state/omarchy/current"
    [[ -L $current/theme ]] || rootfs_fail "missing configured theme: $user_home"
    ln -sfn "$background" "$current/background"
    printf '%s\n' tokyo-night > "$current/theme.name"
done
chown -R 1000:1000 "$ROOTFS_TREE/home/ioprobe/.local"
