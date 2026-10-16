#!/usr/bin/env bash
set -euo pipefail
cd /home/USER/Projects/iOMARCHY
umask 077
timeout 8 ideviceinfo > logs/host-20261014-followup/attempt8-device-info.txt
node - <<'JS'
const fs=require('fs'); const paths=['logs/host-20261014/device-info.txt','logs/host-20261014-followup/attempt8-device-info.txt'];
const infos=paths.map(p=>fs.readFileSync(p,'utf8'));
for(const key of ['UniqueChipID','UniqueDeviceID']) {
 const values=infos.map(t=>t.match(new RegExp('^'+key+': (.+)$','m'))?.[1]);
 if(!values[0]||values[0]!==values[1])throw new Error('Original device identity does not match.');
}
console.log('Original normal-mode iPad identity verified before fresh DFU.');
JS
exec scripts/boot.sh --usb-gate --trace-usb
