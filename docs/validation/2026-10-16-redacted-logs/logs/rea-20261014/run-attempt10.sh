#!/usr/bin/env bash
set -euo pipefail
cd /home/USER/Projects/iOMARCHY
umask 077
[[ $EUID == 0 ]] || exec sudo -- "$0"
runlog=$PWD/logs/rea-20261014
begin=$(date --iso-8601=seconds)
timeout 8 ideviceinfo > "$runlog/attempt10-device-info.txt"
node - <<'JS'
const fs=require('fs');const a=fs.readFileSync('logs/host-20261014/device-info.txt','utf8'),b=fs.readFileSync('logs/rea-20261014/attempt10-device-info.txt','utf8');
for(const k of ['UniqueChipID','UniqueDeviceID','SerialNumber','ProductType','HardwareModel','ProductVersion']){const v=[a,b].map(t=>t.match(new RegExp('^'+k+': (.+)$','m'))?.[1]);if(!v[0]||v[0]!==v[1])throw Error('Original device comparison failed')}
const chip=BigInt(b.match(/^UniqueChipID: (.+)$/m)[1]);fs.writeFileSync('logs/rea-20261014/attempt10-expected-ecid.txt',chip.toString(16).toUpperCase()+'\n',{mode:0o600});console.log('Original normal-mode iPad identity verified.');
JS
source scripts/identity.sh
apple_devices
[[ ${#APPLE[@]} == 1 ]] || exit 1
port=${APPLE[0]}
printf '%s\n' "$port" > "$runlog/attempt10-port.txt"
sha256sum scripts/boot.sh scripts/recovery-diagnostic.sh tools/recovery-diagnostic.c \
    artifacts/recovery-diagnostic/recovery-diagnostic artifacts/usb-node-gate/usb-node-gate \
    artifacts/palera1n artifacts/Pongo.bin > "$runlog/attempt10-inputs.sha256"
sha256sum -c artifacts/recovery-diagnostic/SHA256SUMS
# Negative identity test must fail in normal mode before opening any USB handle.
status=0
artifacts/recovery-diagnostic/recovery-diagnostic "$runlog/attempt10-expected-ecid.txt" "$port" \
    "$(<"$port/busnum")" "$(<"$port/devnum")" > "$runlog/diagnostic-normal-rejection.txt" 2>&1 || status=$?
[[ $status == 1 ]] && rg -q 'no USB opened' "$runlog/diagnostic-normal-rejection.txt"
udevadm monitor --udev --property --subsystem-match=usb > "$runlog/attempt10-udev-private.log" 2>&1 &
monitor=$!
cleanup() { kill "$monitor" 2>/dev/null || true; wait "$monitor" 2>/dev/null || true; }
trap cleanup EXIT
status=0
scripts/boot.sh --usb-gate --trace-usb-control --embedded-pongo || status=$?
printf 'Boot launcher exited %s.\n' "$status"
cleanup
trap - EXIT
journalctl -k --since "$begin" --no-pager > "$runlog/attempt10-kernel-private.log"
journalctl -t mtp-probe --since "$begin" --no-pager > "$runlog/attempt10-mtp-private.log"
if [[ -f $port/idProduct && $(<"$port/idProduct") == 1281 ]]; then
    echo 'Recovery returned; collecting allowlisted read-only diagnostics on the original device.'
    scripts/recovery-diagnostic.sh "$port" "$runlog/attempt10-expected-ecid.txt" || true
fi
printf 'Attempt complete. Leave the device connected for evidence inspection; no retry is queued.\n'
