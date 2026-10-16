#!/usr/bin/env bash
set -euo pipefail
cd /home/USER/Projects/iOMARCHY
umask 077
source scripts/identity.sh
apple_devices
[[ ${#APPLE[@]} == 1 ]]
port=${APPLE[0]}
[[ $(<"$port/idProduct") == 1227 ]]
parse_identity "$(<"$port/serial")"
[[ $ID_ECID == "$(sudo -n cat logs/boot-20261014-215412-ZynE/ecid.txt)" ]]
./scripts/start.sh
