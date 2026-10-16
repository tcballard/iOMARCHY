#!/usr/bin/env bash
set -euo pipefail
cd /home/USER/Projects/iOMARCHY
umask 077
timeout 8 ideviceinfo > logs/host-20261014-followup/attempt9-device-info.txt
node - <<'JS'
const fs = require('fs');
const paths = [
  'logs/host-20261014/device-info.txt',
  'logs/host-20261014-followup/attempt9-device-info.txt',
];
const infos = paths.map((p) => fs.readFileSync(p, 'utf8'));
for (const key of ['UniqueChipID', 'UniqueDeviceID', 'SerialNumber']) {
  const values = infos.map((t) => t.match(new RegExp('^' + key + ': (.+)$', 'm'))?.[1]);
  if (!values[0] || values[0] !== values[1]) throw new Error('Original device identity does not match.');
}
const product = infos[1].match(/^ProductVersion: (.+)$/m)?.[1];
if (product !== '15.8.3') throw new Error('Unexpected iPadOS version.');
console.log('Original normal-mode iPad identity verified before fresh DFU.');
JS
sha256sum scripts/boot.sh scripts/start.sh tools/usb-node-gate.c artifacts/usb-node-gate/usb-node-gate \
  > logs/host-20261014-followup/attempt9-inputs.sha256
echo 'Control payload: palera1n embedded PongoOS. Baseline artifacts/Pongo.bin is not passed.'
exec scripts/boot.sh --usb-gate --trace-usb --embedded-pongo
