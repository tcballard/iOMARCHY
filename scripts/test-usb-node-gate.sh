#!/usr/bin/env bash
# Root-only fixture. Exposes /dev/null clones, never real USB devices.
# The single-quoted snippets deliberately expand positional arguments in Bash.
# shellcheck disable=SC2016
set -euo pipefail
umask 077
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
[[ $EUID == 0 ]] || { echo 'Run this host mount test with sudo.'; exit 1; }
work=$(mktemp -d /dev/j96-gate-test-XXXX)
helper=
cleanup() {
    mountpoint -q "$work/gate" && umount "$work/gate" || true
    [[ -z $helper ]] || { kill "$helper" 2>/dev/null || true; wait "$helper" 2>/dev/null || true; }
    find "$work" -depth -delete
}
trap cleanup EXIT
mkdir "$work/backing" "$work/gate" "$work/backing/003"
artifacts/usb-node-gate/usb-node-gate --test-null "$work/backing" "$work/gate" > "$work/helper.log" 2>&1 &
helper=$!
for ((i=0;i<100;i++)); do mountpoint -q "$work/gate" && break; sleep 0.05; done
mountpoint -q "$work/gate" || { cat "$work/helper.log"; exit 1; }
case ",$(findmnt -n -o OPTIONS -T "$work/gate")," in *,nodev,*) echo 'Unexpected nodev'; exit 1;; esac
mknod -m 0600 "$work/backing/003/001" c 1 3
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
    --dev-bind "$work/gate" /dev/bus/usb --unshare-pid --die-with-parent \
    /bin/sh -c ': <> /dev/bus/usb/003/001'
# An early open must block until publication, then succeed without a retry.
(bash -c ': <> "$1"' bash "$work/gate/003/002" && touch "$work/opened") &
opener=$!
sleep 0.15
[[ ! -e $work/opened ]]
mknod -m 0600 "$work/backing/003/002" c 1 3
wait "$opener"
[[ -e $work/opened ]]
echo 'PASS: namespace device access; early open waited for publication.'
# Removal must revoke new opens despite earlier positive lookups.
find "$work/backing/003" -name 002 -delete
status=0
timeout 6 bash -c ': <> "$1"' bash "$work/gate/003/002" 2>/dev/null || status=$?
[[ $status != 0 && $status != 124 ]]
# No publication (including identity rejection) must fail within the bound.
status=0
timeout 4 bash -c ': <> "$1"' bash "$work/gate/003/003" 2>/dev/null || status=$?
[[ $status != 0 && $status != 124 ]]
mknod -m 0600 "$work/backing/003/004" c 1 5
ln -s /dev/null "$work/backing/003/005"
for address in 004 005; do
    if bash -c ': <> "$1"' bash "$work/gate/003/$address" 2>/dev/null; then exit 1; fi
done
if mkdir "$work/gate/004" 2>/dev/null; then exit 1; fi
echo 'PASS: removal, unpublished addresses, wrong device numbers, symlinks and writes denied.'
cat "$work/helper.log"
umount "$work/gate"
wait "$helper"
helper=
# Production mode must reject the harmless test nodes. Only stat a synthetic
# USB node to check bus/address arithmetic; never open it or perform USB I/O.
mkdir "$work/backing/999"
mknod -m 0600 "$work/backing/999/127" c 189 "$((998*128+126))"
mknod -m 0600 "$work/backing/999/126" c 189 "$((998*128+126))"
artifacts/usb-node-gate/usb-node-gate "$work/backing" "$work/gate" > "$work/production.log" 2>&1 &
helper=$!
for ((i=0;i<100;i++)); do mountpoint -q "$work/gate" && break; sleep 0.05; done
mountpoint -q "$work/gate"
stat "$work/gate/999/127" >/dev/null
if stat "$work/gate/999/126" >/dev/null 2>&1; then exit 1; fi
if bash -c ': <> "$1"' bash "$work/gate/003/001" 2>/dev/null; then exit 1; fi
echo 'PASS: production mode enforces USB major/minor mapping and rejects test devices.'
