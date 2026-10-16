#!/usr/bin/env bash
# Read-only iBoot diagnostics in a separate selected-recovery-node namespace.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
[[ $EUID == 0 && $# == 2 ]] || { echo 'Usage (root): recovery-diagnostic.sh SYSFS_PORT PRIVATE_HEX_ECID_FILE' >&2; exit 2; }
port=$1
identity_file=$2
[[ $port =~ ^/sys/bus/usb/devices/[0-9]+-[0-9]+(\.[0-9]+)*$ ]] || exit 2
[[ -f $identity_file && ! -L $identity_file ]] || exit 2
[[ $(stat -c %a "$identity_file") == 600 ]] || { echo 'Expected identity file must be mode 0600.' >&2; exit 2; }
expected=$(<"$identity_file")
[[ $expected =~ ^[0-9A-Fa-f]{1,16}$ ]] || exit 2
expected=${expected^^}
while [[ ${#expected} -gt 1 && $expected == 0* ]]; do expected=${expected#0}; done
[[ $expected != 0 ]] || exit 2
source "$ROOT/scripts/identity.sh"
exec 9>"$ROOT/build/boot.lock"
flock -n 9 || { echo 'A boot or diagnostic session is already running.' >&2; exit 1; }
sha256sum -c artifacts/recovery-diagnostic/SHA256SUMS >/dev/null
validate() {
    apple_devices
    [[ ${#APPLE[@]} == 1 && ${APPLE[0]} == "$port" ]] || return 1
    [[ $(<"$port/idProduct") == 1281 ]] || return 1
    parse_identity "$(<"$port/serial")" || return 1
    [[ $ID_ECID == "$expected" ]] || return 1
}
validate || { echo 'Selected original recovery identity not verified; no diagnostic opened.' >&2; exit 1; }
bus=$(<"$port/busnum")
address=$(<"$port/devnum")
[[ $bus =~ ^[0-9]{1,3}$ && $address =~ ^[0-9]{1,3}$ ]] || exit 1
printf -v bus '%03d' "$((10#$bus))"
printf -v address '%03d' "$((10#$address))"
usbroot=$(mktemp -d /dev/j96-recovery-XXXX)
# Invoked through the EXIT trap.
# shellcheck disable=SC2329
cleanup() {
    find "$usbroot" -type c -delete
    find "$usbroot" -depth -type d -empty -delete
}
trap cleanup EXIT
trap 'exit 130' INT TERM
mkdir "$usbroot/$bus"
read -r major minor < <(stat -c '%t %T' "/dev/bus/usb/$bus/$address")
[[ $((16#$major)) == 189 && $((16#$minor)) == $(((10#$bus-1)*128+10#$address-1)) ]] || exit 1
mknod -m 0600 "$usbroot/$bus/$address" c "$((16#$major))" "$((16#$minor))"
validate && [[ $(<"$port/busnum") == "$((10#$bus))" && $(<"$port/devnum") == "$((10#$address))" ]] || exit 1
run=$(mktemp -d "$ROOT/logs/recovery-$(date +%Y%m%d-%H%M%S)-XXXX")
printf '%s\n' "$port" "$bus/$address" > "$run/selected-port.txt"
status=0
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
    --dev-bind "$usbroot" /dev/bus/usb --unshare-pid --die-with-parent \
    timeout --kill-after=2 20 "$ROOT/artifacts/recovery-diagnostic/recovery-diagnostic" \
    "$identity_file" "$port" "$((10#$bus))" "$((10#$address))" \
    > "$run/console-private.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$run/exit-status.txt"
printf 'Read-only recovery diagnostic exit %s; private evidence: %s\n' "$status" "$run"
exit "$status"
