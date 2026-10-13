#!/bin/sh
# Read-only public-safe summary; no raw device tree, dmesg, IDs or MAC addresses.
set -eu
printf 'iOMARCHY guest capability report (does not establish hardware support)\n'
uname -srm
printf '\nMemory\n'
grep -E '^(MemTotal|MemAvailable|SwapTotal):' /proc/meminfo
printf '\nFramebuffer devices\n'
for entry in /sys/class/graphics/fb*; do
    [ -d "$entry" ] || continue
    printf '%s\n' "${entry##*/}"
    for property in name virtual_size bits_per_pixel; do
        [ ! -r "$entry/$property" ] || { printf '  %s: ' "$property"; cat "$entry/$property"; }
    done
done
printf '\nDRM devices/connectors\n'
for entry in /sys/class/drm/card*; do
    [ -e "$entry" ] || continue
    printf '%s\n' "${entry##*/}"
    if [ -L "$entry/device/driver" ]; then
        driver=$(readlink "$entry/device/driver")
        printf '  driver: %s\n' "${driver##*/}"
    fi
    for property in status enabled modes; do
        [ ! -r "$entry/$property" ] || { printf '  %s: ' "$property"; cat "$entry/$property"; }
    done
done
printf '\nInput devices (names/capabilities only)\n'
for entry in /sys/class/input/input*; do
    [ -d "$entry" ] || continue
    printf '%s\n' "${entry##*/}"
    [ ! -r "$entry/name" ] || cat "$entry/name"
    for property in ev key abs rel; do
        [ ! -r "$entry/capabilities/$property" ] || { printf '  %s: ' "$property"; cat "$entry/capabilities/$property"; }
    done
done
printf '\nNetwork interfaces (no addresses)\n'
for entry in /sys/class/net/*; do
    [ -d "$entry" ] || continue
    printf '%s\n' "${entry##*/}"
    [ ! -r "$entry/operstate" ] || cat "$entry/operstate"
done
printf '\nUSB device-controller state (no serial numbers)\n'
for entry in /sys/class/udc/*; do
    [ -d "$entry" ] || continue
    printf '%s\n' "${entry##*/}"
    [ ! -r "$entry/state" ] || cat "$entry/state"
done
printf '\nRelevant effective kernel configuration\n'
if [ -r /proc/config.gz ] && command -v zcat >/dev/null 2>&1; then
    zcat /proc/config.gz | grep -E '^(CONFIG_(ARM64_4K_PAGES|DRM|DRM_SIMPLEDRM|DRM_FBDEV_EMULATION|FB_SIMPLE|INPUT_EVDEV|INPUT_UINPUT|NET|UNIX|INET|BLOCK|WLAN|SOUND)=|# CONFIG_(ARM64_16K_PAGES|ARM64_64K_PAGES|DRM|DRM_SIMPLEDRM|FB_SIMPLE|NET|INET|BLOCK|WLAN|SOUND) is not set)' || :
else
    printf '/proc/config.gz unavailable\n'
fi
