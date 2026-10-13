#!/usr/bin/env bash
# Temporary PongoOS -> m1n1 -> Linux boot. No restore/install operations.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
if [[ ${1:-} == --check ]]; then
    [[ $EUID == 0 ]] || exec sudo -- "$ROOT/scripts/boot.sh" --check
    exec scripts/check-host.sh --device --artifacts
fi
[[ $# == 0 ]] || { echo 'Usage: boot.sh [--check]' >&2; exit 1; }
[[ $EUID == 0 ]] || exec sudo -- "$ROOT/scripts/boot.sh"
scripts/check-host.sh --device --artifacts
mkdir -p build logs
# shellcheck source=scripts/identity.sh
source "$ROOT/scripts/identity.sh"
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
command -v bwrap >/dev/null || fail 'Install bubblewrap.'
exec 9>"$ROOT/build/boot.lock"
flock -n 9 || fail 'Another boot session is already running.'
run=$(mktemp -d "$ROOT/logs/boot-$(date +%Y%m%d-%H%M%S)-XXXX")
usbroot=$(mktemp -d /tmp/j96-usb-XXXX)
child=''
cleanup() {
    [[ -z $child ]] || kill -- "-$child" 2>/dev/null || true
    # Contains only device nodes created by this session.
    find "$usbroot" -type c -delete
    find "$usbroot" -depth -type d -empty -delete
}
trap cleanup EXIT
trap 'exit 130' INT TERM
exec > >(tee -a "$run/session.log") 2>&1
printf 'Disconnect every other Apple USB device. Keep this iPad on the same port.\n'
printf 'Use a USB-A to Lightning data cable (USB-C to USB-A adapter is OK).\n'
apple_devices
[[ ${#APPLE[@]} == 1 ]] || fail 'Connect exactly one Apple device and rerun.'
port=${APPLE[0]}
product=$(<"$port/idProduct")
expected=
case "$product" in
    1227|1280|1281|1282|1283|4141)
        parse_identity "$(cat "$port/serial" 2>/dev/null)" || fail 'Cannot establish J96 CPID=7000, BDID=08 and nonzero ECID.'
        expected=$ID_ECID
        ;;
    12[0-9a-f][0-9a-f])
        mapfile -t udids < <(idevice_id -l)
        [[ ${#udids[@]} == 1 ]] || fail 'Cannot identify a unique normal-mode iPad; unlock, trust this computer, and rerun, or enter DFU manually.'
        udid=${udids[0]}
        [[ ${udid,,} == "$(tr '[:upper:]' '[:lower:]' < "$port/serial")" ]] || fail 'USB serial and lockdown UDID disagree.'
        [[ $(ideviceinfo -u "$udid" -k ProductType) == iPad5,1 ]] || fail 'Connected product is not iPad5,1.'
        [[ $(ideviceinfo -u "$udid" -k HardwareModel | tr '[:upper:]' '[:lower:]') == j96ap ]] || fail 'Board is not j96ap.'
        chip=$(ideviceinfo -u "$udid" -k UniqueChipID)
        [[ $chip =~ ^[0-9]+$ && $chip != 0 ]] || fail 'Cannot read ECID. Unlock and trust this host, or use DFU.'
        printf -v expected '%X' "$chip"
        ideviceinfo -u "$udid" -k ProductVersion
        ;;
    *) fail "Unsupported initial USB mode: 05ac:$product" ;;
esac
printf 'Identified J96, ECID %s, USB port %s\n' "$expected" "${port##*/}"
printf '%s\n' "$expected" > "$run/ecid.txt"
if [[ $product != 1227 && $product != 4141 ]]; then
    printf '\nDFU: screen must end completely black. Cable/iTunes graphic is recovery.\n'
    printf 'Press Enter when ready for the timed Home + Top/Power sequence.\n'
    read -r
    printf 'Hold Top/Power now (3 seconds).\n'; sleep 3
    printf 'Keep Top held; ALSO hold Home now (8 seconds).\n'; sleep 8
    printf 'Release Top/Power; keep holding Home until DFU is detected.\n'
    deadline=$((SECONDS + 35))
    while (( SECONDS < deadline )); do
        apple_devices
        [[ ${#APPLE[@]} -le 1 ]] || fail 'Another Apple device appeared.'
        if [[ ${#APPLE[@]} == 1 ]]; then
            [[ ${APPLE[0]} == "$port" ]] || fail 'Device moved USB ports; rerun to identify it.'
            if [[ $(<"$port/idProduct") == 1227 ]]; then break; fi
        fi
        sleep 0.25
    done
    [[ -f $port/idProduct && $(<"$port/idProduct") == 1227 ]] || fail 'DFU timeout; force restart and retry.'
    parse_identity "$(cat "$port/serial" 2>/dev/null)" || fail 'Unidentified DFU device.'
    [[ $ID_ECID == "$expected" ]] || fail 'DFU ECID differs from the original device.'
    printf 'DFU verified. Release Home.\n'
fi
# Expose only validated device nodes to palera1n in a private /dev/bus/usb.
# New addresses are admitted only after checking the same port + CPID/BDID/ECID.
mirror_device() {
    apple_devices
    [[ ${#APPLE[@]} -le 1 ]] || return 1
    local node bus address major minor serial
    if [[ ${#APPLE[@]} == 0 ]]; then
        find "$usbroot" -type c -delete
        return 0
    fi
    [[ ${APPLE[0]} == "$port" ]] || return 1
    serial=$(cat "$port/serial" 2>/dev/null) || serial=''
    if [[ -z $serial ]]; then
        find "$usbroot" -type c -delete
        return 2
    fi
    parse_identity "$serial" || return 1
    [[ $ID_ECID == "$expected" ]] || return 1
    case "$(<"$port/idProduct")" in 1227|1280|1281|1282|1283|4141) ;; *) return 1 ;; esac
    printf -v bus '%03d' "$(<"$port/busnum")"
    printf -v address '%03d' "$(<"$port/devnum")"
    node="$usbroot/$bus/$address"
    if [[ ! -c $node ]]; then
        find "$usbroot" -type c -delete
        mkdir -p "$usbroot/$bus"
        read -r major minor < <(stat -c '%t %T' "/dev/bus/usb/$bus/$address")
        mknod -m 0600 "$node" c "$((16#$major))" "$((16#$minor))"
    fi
}
mirror_device || fail 'Identity changed before transport start.'
if [[ $(<"$port/idProduct") != 4141 ]]; then
    printf 'Starting temporary palera1n Pongo-only boot.\n'
    setsid bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
        --dev-bind "$usbroot" /dev/bus/usb --unshare-pid --die-with-parent \
        --setenv PALERA1N_BYPASS_PASSCODE_CHECK 1 \
        "$ROOT/artifacts/palera1n" --cli -l -p -k "$ROOT/artifacts/Pongo.bin" &
    child=$!
    deadline=$((SECONDS + 180))
    while (( SECONDS < deadline )); do
        # A disappeared descriptor is normal during re-enumeration. A present,
        # readable but different identity is fatal; do not admit its device node.
        if mirror_device; then
            if [[ -f $port/idProduct && $(<"$port/idProduct") == 4141 ]]; then break; fi
        else
            status=$?
            [[ $status == 2 ]] || fail 'USB identity changed during palera1n.'
        fi
        kill -0 "$child" 2>/dev/null || fail 'palera1n exited before verified PongoOS appeared; see session log.'
        sleep 0.2
    done
    [[ -f $port/idProduct && $(<"$port/idProduct") == 4141 ]] || fail 'PongoOS timeout. Force restart and retry.'
    # A8 can leave palera1n waiting after PongoOS is already running.
    kill -- "-$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    child=
fi
mirror_device || fail 'PongoOS identity does not match the selected J96.'
export J96_USB_BUS J96_USB_ADDRESS J96_USB_SERIAL
J96_USB_BUS=$(<"$port/busnum")
J96_USB_ADDRESS=$(<"$port/devnum")
J96_USB_SERIAL=$(<"$port/serial")
session="J96-$(cat /proc/sys/kernel/random/uuid)"
scripts/assemble.sh "$run/m1n1-linux.bin" "$session"
sha256sum "$run/m1n1-linux.bin" > "$run/image.sha256"
printf '/send %s\nbootm\n' "$run/m1n1-linux.bin" > "$run/pongo-commands.txt"
printf 'Verified PongoOS ECID. Uploading Linux RAM boot image.\n'
timeout 90 artifacts/pongoterm < "$run/pongo-commands.txt" > "$run/pongoterm.log" 2>&1 &
child=$!
# pongoterm itself checks bus/address and the complete ECID-bearing serial at open.
deadline=$((SECONDS + 100))
tty=
while (( SECONDS < deadline )); do
    apple_devices
    [[ ${#APPLE[@]} -le 1 ]] || fail 'Another Apple device appeared.'
    [[ ${#APPLE[@]} == 0 || ${APPLE[0]} == "$port" ]] || fail 'Device moved ports.'
    if [[ -f $port/idProduct && $(<"$port/idProduct") == 4142 ]]; then
        [[ $(<"$port/serial") == "$session" ]] || fail 'Linux gadget session identifier mismatch.'
        for t in /sys/class/tty/ttyACM*; do
            [[ -e $t ]] || continue
            case "$(readlink -f "$t/device")" in "$(readlink -f "$port")"/*) tty="/dev/${t##*/}" ;; esac
        done
        [[ -z $tty ]] || break
    fi
    sleep 0.25
done
kill "$child" 2>/dev/null || true
wait "$child" 2>/dev/null || true
child=
[[ -n $tty ]] || fail "No verified Linux ACM console. Inspect iPad display and $run/pongoterm.log."
printf 'Linux USB gadget verified: %s. Opening the shell; Ctrl-A then Ctrl-X exits terminal.\n' "$tty"
printf 'Logs: %s\n' "$run"
picocom --baud 115200 --flow n --initstring $'\r' --logfile "$run/serial.log" "$tty"
