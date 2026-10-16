#!/usr/bin/env bash
# Temporary PongoOS -> m1n1 -> Linux boot. No restore/install operations.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
if [[ ${1:-} == --check ]]; then
    [[ $EUID == 0 ]] || exec sudo -- "$ROOT/scripts/boot.sh" --check
    exec scripts/check-host.sh --device --artifacts
fi
boot_args=("$@")
trace_usb=0
trace_usb_control=0
usb_gate=0
embedded_pongo=0
for arg in "$@"; do
    case "$arg" in
        --trace-usb) trace_usb=1 ;;
        --trace-usb-control) trace_usb=1; trace_usb_control=1 ;;
        --usb-gate) usb_gate=1 ;;
        --embedded-pongo) embedded_pongo=1 ;;
        *) echo 'Usage: boot.sh [--check] [--trace-usb|--trace-usb-control] [--usb-gate] [--embedded-pongo]' >&2; exit 1 ;;
    esac
done
[[ -t 0 && -t 1 ]] || { echo 'Run the launcher in an interactive terminal for the DFU guide and shell.' >&2; exit 1; }
if [[ $EUID != 0 ]]; then
    exec sudo -- "$ROOT/scripts/boot.sh" "${boot_args[@]}"
fi
if (( trace_usb )); then command -v strace >/dev/null || { echo 'Install strace for --trace-usb.' >&2; exit 1; }; fi
scripts/check-host.sh --device --artifacts
if (( usb_gate )); then
    sha256sum -c artifacts/usb-node-gate/SHA256SUMS
    [[ -x artifacts/usb-node-gate/usb-node-gate ]] || { echo 'Build the optional USB node gate first.'; exit 1; }
    modprobe fuse
fi
mkdir -p build logs
# shellcheck source=scripts/identity.sh
source "$ROOT/scripts/identity.sh"
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
command -v bwrap >/dev/null || fail 'Install bubblewrap.'
exec 9>"$ROOT/build/boot.lock"
flock -n 9 || fail 'Another boot session is already running.'
run=$(mktemp -d "$ROOT/logs/boot-$(date +%Y%m%d-%H%M%S)-XXXX")
# Bind mounts retain nodev from their source. /tmp is commonly nodev, which
# makes mirrored USB nodes unusable even as root inside --dev-bind.
usbroot=$(mktemp -d /dev/j96-usb-XXXX)
child=''
gate_child=''
gate_mount=''
mtp_rule=/run/udev/rules.d/60-iomarchy-no-mtp.rules
mtp_rule_owned=0
# libmtp's 69-libmtp.rules runs mtp-probe on add and bind unless MTP_NO_PROBE=1.
# Attempt 9 set the variable for add only; the bind event still probed DFU.
# This file sorts first, applies only to later events, and is removed on exit.
block_mtp_probe() {
    [[ ! -e $mtp_rule ]] || fail 'An MTP exclusion rule already exists; inspect it before starting.'
    mkdir -p /run/udev/rules.d
    printf 'ACTION=="add|bind", SUBSYSTEM=="usb", KERNEL=="%s", ATTR{idVendor}=="05ac", ENV{MTP_NO_PROBE}="1"\n' "${port##*/}" > "$mtp_rule"
    mtp_rule_owned=1
    udevadm control --reload
    printf 'Blocked libmtp probing of Apple USB devices for this session.\n'
}
unblock_mtp_probe() {
    (( mtp_rule_owned )) || return 0
    rm -f "$mtp_rule"
    udevadm control --reload || true
}
cleanup() {
    [[ -z $child ]] || kill -- "-$child" 2>/dev/null || true
    [[ -z $child ]] || wait "$child" 2>/dev/null || true
    if [[ -n $gate_mount ]]; then
        mountpoint -q "$gate_mount" && umount "$gate_mount" || true
        [[ -z $gate_child ]] || kill "$gate_child" 2>/dev/null || true
        [[ -z $gate_child ]] || wait "$gate_child" 2>/dev/null || true
        rmdir "$gate_mount" 2>/dev/null || true
    fi
    # Contains only device nodes created by this session.
    find "$usbroot" -type c -delete
    find "$usbroot" -depth -type d -empty -delete
    unblock_mtp_probe
}
trap cleanup EXIT
trap 'exit 130' INT TERM
exec > >(tee -a "$run/session.log") 2>&1
printf 'Disconnect every other Apple USB device. Keep this iPad on the same port.\n'
printf 'Use a USB-A to Lightning data cable (USB-C to USB-A adapter is OK).\n'
apple_devices
if [[ ${#APPLE[@]} == 0 ]]; then
    printf 'Waiting up to 60 seconds for the iPad. Connect it now.\n'
    deadline=$((SECONDS + 60))
    while [[ ${#APPLE[@]} == 0 ]] && (( SECONDS < deadline )); do
        sleep 0.5
        apple_devices
    done
fi
[[ ${#APPLE[@]} == 1 ]] || fail 'Connect exactly one Apple device; a charge-only cable cannot carry this boot.'
port=${APPLE[0]}
product=$(<"$port/idProduct")
expected=
case "$product" in
    1227|1280|1281|1282|1283|4141)
        parse_identity "$(cat "$port/serial" 2>/dev/null)" || fail 'Cannot establish J96 CPID=7000, BDID=08 and nonzero ECID.'
        expected=$ID_ECID
        ;;
    12[0-9a-f][0-9a-f])
        printf 'Unlock the iPad and accept Trust if prompted; waiting up to 45 seconds.\n'
        deadline=$((SECONDS + 45))
        info=
        while (( SECONDS < deadline )); do
            apple_devices
            [[ ${#APPLE[@]} == 1 && ${APPLE[0]} == "$port" ]] || fail 'USB identity/port changed while waiting for trust.'
            mapfile -t udids < <(timeout 3 idevice_id -l)
            [[ ${#udids[@]} -le 1 ]] || fail 'More than one lockdown device appeared.'
            if [[ ${#udids[@]} == 1 ]]; then
                udid=${udids[0]}
                [[ ${udid,,} == "$(tr '[:upper:]' '[:lower:]' < "$port/serial")" ]] || fail 'USB serial and lockdown UDID disagree.'
                if info=$(timeout 3 ideviceinfo -u "$udid" 2>/dev/null); then break; fi
            fi
            sleep 1
        done
        [[ -n $info ]] || fail 'Trust/lockdown timeout. Unlock and trust this host, or start again with the iPad in DFU.'
        [[ $(awk -F ': ' '$1 == "ProductType" {print $2}' <<< "$info") == iPad5,1 ]] || fail 'Connected product is not iPad5,1.'
        board=$(awk -F ': ' '$1 == "HardwareModel" {print $2}' <<< "$info")
        [[ ${board,,} == j96ap ]] || fail 'Board is not j96ap.'
        chip=$(awk -F ': ' '$1 == "UniqueChipID" {print $2}' <<< "$info")
        [[ $chip =~ ^[0-9]{1,20}$ ]] || fail 'Cannot read ECID.'
        while [[ ${#chip} -gt 1 && $chip == 0* ]]; do chip=${chip#0}; done
        [[ $chip != 0 ]] || fail 'Zero ECID.'
        printf -v expected '%X' "$chip" || fail 'ECID outside the supported range.'
        awk -F ': ' '$1 == "ProductVersion" {print "iPadOS " $2}' <<< "$info"
        ;;
    *) fail "Unsupported initial USB mode: 05ac:$product" ;;
esac
printf 'Identified J96, ECID %s, USB port %s\n' "$expected" "${port##*/}"
printf '%s\n' "$expected" > "$run/ecid.txt"
block_mtp_probe
if [[ $product != 1227 && $product != 4141 ]]; then
    printf '\nDFU: screen must end completely black. Cable/iTunes graphic is recovery.\n'
    printf 'Read the whole sequence first; the timer starts only after Enter:\n'
    printf '  1. After the preparation countdown, hold Top/Power + Home together for 8 seconds.\n'
    printf '  2. Release only Top/Power; hold Home until DFU is verified.\n'
    printf 'Press Enter when ready for the timed Home + Top/Power sequence.\n'
    read -r
    printf 'Get ready; do not hold any buttons yet.\n'
    for ((remaining=3;remaining>0;remaining--)); do printf '\rStarting in %d seconds ' "$remaining"; sleep 1; done
    printf '\n\aHOLD TOP/POWER + HOME TOGETHER NOW (8 seconds).\n'
    for ((remaining=8;remaining>0;remaining--)); do printf '\rTop + Home: %2d seconds remaining ' "$remaining"; sleep 1; done
    printf '\n\aRELEASE TOP/POWER NOW; keep holding Home until DFU is detected.\n'
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
mirror_state=
mirror_event() {
    [[ $mirror_state != "$*" ]] || return 0
    mirror_state=$*
    printf '%s %s\n' "$EPOCHREALTIME" "$mirror_state" >> "$run/usb-mirror.log"
}
mirror_device() {
    apple_devices
    [[ ${#APPLE[@]} -le 1 ]] || return 1
    local node bus address major minor serial
    if [[ ${#APPLE[@]} == 0 ]]; then
        find "$usbroot" -type c -delete
        mirror_event disconnected
        return 0
    fi
    [[ ${APPLE[0]} == "$port" ]] || return 1
    serial=$(cat "$port/serial" 2>/dev/null) || serial=''
    if [[ -z $serial ]]; then
        find "$usbroot" -type c -delete
        mirror_event descriptor-pending
        return 2
    fi
    parse_identity "$serial" || return 1
    [[ $ID_ECID == "$expected" ]] || return 1
    # Recovery is accepted for initial identification, then manual DFU is
    # required. Never expose recovery to palera1n's auto-boot-setting helper.
    case "$(<"$port/idProduct")" in 1227|4141) ;; *) return 1 ;; esac
    printf -v bus '%03d' "$(<"$port/busnum")"
    printf -v address '%03d' "$(<"$port/devnum")"
    node="$usbroot/$bus/$address"
    if [[ ! -c $node ]]; then
        mirror_event validated "$bus/$address"
        find "$usbroot" -type c -delete
        mkdir -p "$usbroot/$bus"
        read -r major minor < <(stat -c '%t %T' "/dev/bus/usb/$bus/$address")
        mknod -m 0600 "$node" c "$((16#$major))" "$((16#$minor))"
        mirror_event published "$bus/$address"
    fi
}
mirror_device || fail 'Identity changed before transport start.'
usbview=$usbroot
if (( usb_gate )); then
    gate_mount=$(mktemp -d /dev/j96-gate-XXXX)
    artifacts/usb-node-gate/usb-node-gate "$usbroot" "$gate_mount" > "$run/usb-gate.log" 2>&1 &
    gate_child=$!
    for ((i=0;i<100;i++)); do
        mountpoint -q "$gate_mount" && break
        kill -0 "$gate_child" 2>/dev/null || fail 'USB node gate exited before mounting.'
        sleep 0.05
    done
    mountpoint -q "$gate_mount" || fail 'USB node gate mount timed out.'
    usbview=$gate_mount
    printf 'Optional USB gate active; opens wait only for identity-validated nodes.\n'
fi
if [[ $(<"$port/idProduct") != 4141 ]]; then
    # -vv reaches checkra1n's own verbose flag (palera1n adds it at verbose >= 2).
    # -p stops before any jailbreak ramdisk. --embedded-pongo leaves palera1n's
    # bundled image in place; the default still passes the pinned Hoolock file.
    loader_args=(--cli -l -p -vv)
    if (( embedded_pongo )); then
        printf 'Control payload: palera1n bundled PongoOS, not artifacts/Pongo.bin.\n'
    else
        loader_args+=(-k "$ROOT/artifacts/Pongo.bin")
        printf 'Payload: pinned artifacts/Pongo.bin.\n'
    fi
    printf 'Starting temporary palera1n Pongo-only boot.\n'
    trace=()
    if (( trace_usb )); then
        trace_calls=open,openat,openat2,execve
        # Optional transfer diagnostics stay in private logs. They can include
        # device data; redact before publishing. No terminal input is traced.
        (( trace_usb_control == 0 )) || trace_calls+=,ioctl
        trace=(strace -ff -ttt -T -s 256 -o "$run/usb-open" -e "trace=$trace_calls")
    fi
    setsid "${trace[@]}" bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
        --dev-bind "$usbview" /dev/bus/usb --unshare-pid --die-with-parent \
        --setenv PALERA1N_BYPASS_PASSCODE_CHECK 1 \
        "$ROOT/artifacts/palera1n" "${loader_args[@]}" &
    child=$!
    deadline=$((SECONDS + 180))
    while (( SECONDS < deadline )); do
        [[ -z $gate_child ]] || kill -0 "$gate_child" 2>/dev/null || fail 'USB node gate exited.'
        # A disappeared descriptor is normal during re-enumeration. A present,
        # readable but different identity is fatal; do not admit its device node.
        if mirror_device; then
            if [[ -f $port/idProduct && $(<"$port/idProduct") == 4141 ]]; then break; fi
        else
            status=$?
            if [[ $status != 2 && -f $port/idProduct && $(<"$port/idProduct") == 1281 ]]; then
                fail 'Device returned to recovery before PongoOS enumeration.'
            fi
            [[ $status == 2 ]] || fail 'USB identity changed during palera1n.'
        fi
        if [[ -n $child ]] && ! kill -0 "$child" 2>/dev/null; then
            status=0
            wait "$child" || status=$?
            child=
            [[ $status == 0 ]] || fail "palera1n exited with status $status before verified PongoOS appeared; see session log."
            printf 'palera1n exited successfully; waiting for verified PongoOS USB enumeration.\n'
        fi
        sleep 0.2
    done
    [[ -f $port/idProduct && $(<"$port/idProduct") == 4141 ]] || fail 'PongoOS timeout. Force restart and retry.'
    # A8 can leave palera1n waiting after PongoOS is already running.
    [[ -z $child ]] || kill -- "-$child" 2>/dev/null || true
    [[ -z $child ]] || wait "$child" 2>/dev/null || true
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
setsid timeout 90 artifacts/pongoterm < "$run/pongo-commands.txt" > "$run/pongoterm.log" 2>&1 &
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
kill -- "-$child" 2>/dev/null || true
wait "$child" 2>/dev/null || true
child=
[[ -n $tty ]] || fail "No verified Linux ACM console. Inspect iPad display and $run/pongoterm.log."
printf 'Linux USB gadget verified: %s. Opening the shell; Ctrl-A then Ctrl-X exits terminal.\n' "$tty"
printf 'Logs: %s\n' "$run"
picocom --baud 115200 --flow n --initstring $'\r' --logfile "$run/serial.log" "$tty"
