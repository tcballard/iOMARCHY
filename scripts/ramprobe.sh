#!/usr/bin/env bash
# Diagnostic against an already-running, identity-verified J96 PongoOS.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
mode=mark
case ${1:-} in
    '') [[ $# == 0 ]] || exit 2 ;;
    --state) [[ $# == 1 ]] || exit 2; mode=state ;;
    --check) [[ $# == 1 ]] || exit 2; exec bash scripts/build-ramprobe.sh ;;
    *) echo 'Usage: ramprobe.sh [--state|--check]' >&2; exit 2 ;;
esac
fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
[[ -x artifacts/pongoterm ]] || fail 'Build the existing identity-checking artifacts/pongoterm first.'
# Require the repository pin's pongoterm digest, not an arbitrary unpatched tool.
[[ -f artifacts/SHA256SUMS ]] || fail 'Missing existing artifact manifest.'
mapfile -t pongohash < <(awk '$2 == "artifacts/pongoterm" {print}' artifacts/SHA256SUMS)
[[ ${#pongohash[@]} == 1 ]] || fail 'Manifest must contain exactly one artifacts/pongoterm entry.'
printf '%s\n' "${pongohash[0]}" | sha256sum --check --status || fail 'pongoterm hash mismatch.'
[[ $EUID == 0 ]] || exec sudo -- bash "$ROOT/scripts/ramprobe.sh" "$@"
mkdir -p build logs
exec 9>"$ROOT/build/boot.lock"
flock -n 9 || fail 'Another device session holds build/boot.lock.'
bash scripts/build-ramprobe.sh
sha256sum --check --status build/ramprobe/SHA256SUMS || fail 'Probe artifact hash mismatch.'
# shellcheck source=scripts/identity.sh
source scripts/identity.sh
apple_devices
[[ ${#APPLE[@]} == 1 ]] || fail 'Connect exactly one Apple device.'
port=${APPLE[0]}
[[ $(<"$port/idProduct") == 4141 ]] || fail 'Start the existing Pongo-only boot route first, then rerun. This diagnostic does not exploit DFU or boot Apple stages.'
parse_identity "$(cat "$port/serial")" || fail 'Pongo identity is not J96 CPID=7000 BDID=08 with a nonzero ECID.'
expected=$ID_ECID
export J96_USB_BUS J96_USB_ADDRESS J96_USB_SERIAL
J96_USB_BUS=$(<"$port/busnum")
J96_USB_ADDRESS=$(<"$port/devnum")
J96_USB_SERIAL=$(<"$port/serial")
run=$(mktemp -d "$ROOT/logs/ramprobe-$(date +%Y%m%d-%H%M%S)-XXXX")
nonce=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
[[ $nonce =~ ^[0-9a-f]{16}$ && $nonce != 0000000000000000 ]] || fail 'Failed to generate fresh nonce.'
printf '%s\n' "$nonce" > "$run/nonce.txt"
printf '%s\n' "$J96_USB_SERIAL" > "$run/device.txt"
cp build/ramprobe/SHA256SUMS "$run/SHA256SUMS"
mkfifo "$run/commands.fifo"
exec 8<>"$run/commands.fifo"
child=''
cleanup() {
    if [[ -n $child ]]; then kill "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true; fi
    exec 8>&-
    rm -f "$run/commands.fifo"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
stdbuf -oL -eL artifacts/pongoterm < "$run/commands.fifo" 8>&- > "$run/pongo.log" 2>&1 &
child=$!
send() { printf '%s\n' "$*" | tee -a "$run/commands.txt" >&8; }
verify_identity() {
    apple_devices
    [[ ${#APPLE[@]} == 1 && ${APPLE[0]} == "$port" ]] || fail 'Device disconnected, moved, or another Apple device appeared.'
    [[ $(<"$port/idProduct") == 4141 && $(<"$port/busnum") == "$J96_USB_BUS" &&
       $(<"$port/devnum") == "$J96_USB_ADDRESS" && $(<"$port/serial") == "$J96_USB_SERIAL" ]] || fail 'Pongo USB identity changed.'
    parse_identity "$J96_USB_SERIAL" && [[ $ID_ECID == "$expected" ]] || fail 'ECID changed.'
}
wait_result() {
    local stage=$1 deadline=$((SECONDS+20))
    while (( SECONDS < deadline )); do
        verify_identity
        if build/ramprobe/check-log "$stage" "$nonce" "$run/pongo.log" > "$run/$stage.result" 2>/dev/null; then
            cat "$run/$stage.result"
            return
        fi
        kill -0 "$child" 2>/dev/null || fail "Transport stopped. Inspect $run/pongo.log"
        sleep 0.1
    done
    fail "No verified $stage readback. Inspect $run/pongo.log"
}
verify_identity
send '/send build/ramprobe/ramprobe.pongo'
send modload
send "rammark $nonce"
printf 'Logs: %s\n' "$run"
wait_result mark
if [[ $mode == state ]]; then
    send "ramstate $nonce"
    wait_result state
fi
verify_identity
build/ramprobe/check-log mark "$nonce" "$run/pongo.log" > "$run/mark.result"
if [[ $mode == state ]]; then
    build/ramprobe/check-log state "$nonce" "$run/pongo.log" > "$run/state.result"
fi
printf 'Verified execution under PongoOS. Direct SecureROM execution and UART remain untested.\n'
