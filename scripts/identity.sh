#!/usr/bin/env bash
# Library: pure descriptor parsing is also used by offline fixture tests.
parse_identity() {
    local text=${1^^}
    local token value cpid=0 bdid=0 ecid=0
    local -a tokens
    ID_ECID=
    [[ $text != *$'\n'* && $text != *$'\r'* ]] || return 1
    read -r -a tokens <<< "$text"
    for token in "${tokens[@]}"; do
        value=${token#*:}
        case "$token" in
            CPID:*)
                [[ $cpid == 0 && ${#value} -le 16 && $value =~ ^0*7000$ ]] || return 1
                cpid=1 ;;
            BDID:*)
                [[ $bdid == 0 && ${#value} -le 16 && $value =~ ^0*8$ ]] || return 1
                bdid=1 ;;
            ECID:*)
                [[ $ecid == 0 && $value =~ ^[0-9A-F]{1,16}$ ]] || return 1
                ID_ECID=$value
                ecid=1 ;;
        esac
    done
    [[ $cpid == 1 && $bdid == 1 && $ecid == 1 ]] || return 1
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
