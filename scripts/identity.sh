#!/usr/bin/env bash
# Library: pure descriptor parsing is also used by offline fixture tests.
parse_identity() {
    local text=${1^^}
    [[ $text =~ CPID:([0-9A-F]+) ]] || return 1
    [[ $((16#${BASH_REMATCH[1]})) -eq 28672 ]] || return 1
    [[ $text =~ BDID:([0-9A-F]+) ]] || return 1
    [[ $((16#${BASH_REMATCH[1]})) -eq 8 ]] || return 1
    [[ $text =~ ECID:([0-9A-F]{1,16})([^0-9A-F]|$) ]] || return 1
    ID_ECID=${BASH_REMATCH[1]}
    while [[ ${#ID_ECID} -gt 1 && $ID_ECID == 0* ]]; do ID_ECID=${ID_ECID#0}; done
    [[ $ID_ECID != 0 ]]
}
apple_devices() {
    local d
    APPLE=()
    for d in /sys/bus/usb/devices/*; do
        [[ -f $d/idVendor ]] || continue
        [[ $(<"$d/idVendor") == 05ac ]] && APPLE+=("$d")
    done
    return 0
}
