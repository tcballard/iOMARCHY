#!/usr/bin/env bash
set -u
cd /home/USER/Projects/iOMARCHY
umask 077
printf 'iOMARCHY RAM-only boot preparation. Authenticate locally if requested.\n'
./scripts/start.sh --check
status=$?
printf '%s\n' "$status" > logs/host-20261014/check-terminal.exit
if (( status != 0 )); then printf 'Host check stopped (%s). Leave this window open.\n' "$status"; read -r; exit "$status"; fi
printf '\nHost checks passed. Waiting for device/cable verification by Codex.\n'
while [[ ! -f logs/host-20261014/boot-ready ]]; do sleep 1; done
./scripts/start.sh
status=$?
printf '%s\n' "$status" > logs/host-20261014/boot-terminal.exit
printf '\nBoot launcher finished (%s). Leave this window open for diagnosis.\n' "$status"
read -r
