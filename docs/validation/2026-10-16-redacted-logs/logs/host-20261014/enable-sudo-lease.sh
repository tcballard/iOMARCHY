#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 && ${SUDO_USER:-} == USER ]]
file=/etc/sudoers.d/90-iomarchy-temporary
[[ ! -e $file ]]
expiry=$(date -u -d '+60 minutes' +%Y%m%d%H%M%SZ)
local_expiry=$(date -d '+60 minutes' --iso-8601=seconds)
stage=$(mktemp /etc/sudoers.d/.iomarchy-lease-XXXX)
trap 'rm -f -- "$stage"' EXIT
printf '# User-requested 60-minute sudo lease; expires even across reboot.\ntcballard ALL=(ALL:ALL) NOTAFTER=%s NOPASSWD: ALL\n' "$expiry" > "$stage"
chmod 0440 "$stage"
visudo -cf "$stage"
install -o root -g root -m 0440 "$stage" "$file"
if ! visudo -c; then rm -f -- "$file"; exit 1; fi
systemd-run --unit=iomarchy-sudo-lease-cleanup --on-active=60m /usr/bin/rm -f -- "$file"
printf 'Passwordless sudo expires at %s (policy NOTAFTER=%s).\n' "$local_expiry" "$expiry"
