#!/usr/bin/env bash
set -u
cd /home/USER/Projects/iOMARCHY
umask 077
printf 'iOMARCHY second DFU sequence — temporary RAM boot only.\n'
printf 'When the guide asks for Enter, get both buttons ready first.\n'
./scripts/start.sh
status=$?
printf '%s\n' "$status" > logs/host-20261014/attempt2.exit
printf '\nLauncher stopped (%s). Leave this terminal open.\n' "$status"
read -r
printf 'Local diagnostic shell ready.\n'
exec bash --noprofile --norc
