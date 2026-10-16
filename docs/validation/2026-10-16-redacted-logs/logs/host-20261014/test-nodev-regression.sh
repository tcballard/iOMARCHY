#!/usr/bin/env bash
set -euo pipefail
umask 077
for base in /tmp /dev; do
 probe=$(mktemp -d "$base/j96-regression-XXXX")
 mkdir "$probe/001"
 mknod -m 0600 "$probe/001/001" c 1 3
 status=0
 bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run --dev-bind "$probe" /dev/bus/usb --unshare-pid --die-with-parent /bin/sh -c ': <> /dev/bus/usb/001/001' || status=$?
 printf '%s staging open status: %s\n' "$base" "$status"
 find "$probe" -type c -delete
 find "$probe" -depth -type d -empty -delete
 if [[ $base == /tmp ]]; then [[ $status != 0 ]]; else [[ $status == 0 ]]; fi
 done
