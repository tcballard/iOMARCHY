#!/usr/bin/env bash
set -euo pipefail
umask 077
cd /home/USER/Projects/iOMARCHY
source scripts/identity.sh
apple_devices
[[ ${#APPLE[@]} == 1 ]]
port=${APPLE[0]}
[[ $(<"$port/idProduct") == 1227 ]]
parse_identity "$(<"$port/serial")"
expected=$(<logs/boot-20261014-215412-ZynE/ecid.txt)
[[ $ID_ECID == "$expected" ]]
sha256sum -c artifacts/SHA256SUMS > logs/host-20261014/diagnostic-hashes.log
usbroot=$(mktemp -d /tmp/j96-diagnostic-XXXX)
trap 'find "$usbroot" -type c -delete; find "$usbroot" -depth -type d -empty -delete' EXIT
printf -v bus '%03d' "$(<"$port/busnum")"
printf -v address '%03d' "$(<"$port/devnum")"
mkdir "$usbroot/$bus"
read -r major minor < <(stat -c '%t %T' "/dev/bus/usb/$bus/$address")
mknod -m 0600 "$usbroot/$bus/$address" c "$((16#$major))" "$((16#$minor))"
ns=(bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run --dev-bind "$usbroot" /dev/bus/usb --unshare-pid --die-with-parent)
"${ns[@]}" /bin/sh -c 'id; findmnt -T /dev/bus/usb; ls -lR /dev/bus/usb' > logs/host-20261014/namespace-layout.log 2>&1
set +e
"${ns[@]}" --setenv LIBUSB_DEBUG 4 /usr/bin/lsusb -d 05ac:1227 -v > logs/host-20261014/isolated-lsusb.log 2>&1
printf 'Isolated lsusb exit: %s\n' "$?"
"${ns[@]}" --setenv LIBUSB_DEBUG 4 /usr/bin/timeout 12 "$PWD/artifacts/palera1n" --cli -I -S -vvv > logs/host-20261014/isolated-device-info.log 2>&1
printf 'Isolated read-only palera1n info exit: %s\n' "$?"
chown "${SUDO_UID:?}:${SUDO_GID:?}" logs/host-20261014/{diagnostic-hashes,namespace-layout,isolated-lsusb,isolated-device-info}.log
printf 'Read-only diagnostic complete; no boot command was issued.\n'
