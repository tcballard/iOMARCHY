#!/usr/bin/env bash
# One local entry point: runtime dependencies, verified bundle, guided RAM boot.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT"
mode=${1:-boot}
[[ $# -le 1 && ( $mode == boot || $mode == --prepare || $mode == --check ) ]] || {
    echo 'Usage: start.sh [--prepare|--check]' >&2; exit 2;
}
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
    echo 'Use the x86_64 Linux XPS for this boot bundle.' >&2; exit 1;
}
# shellcheck disable=SC1091
source /etc/os-release
privilege=()
if [[ $EUID != 0 ]]; then
    command -v sudo >/dev/null || { echo 'Install sudo or run this launcher as root.' >&2; exit 1; }
    privilege=(sudo --)
fi
# Repeated launches can use the verified cache without package-network access.
if ! { command -v curl >/dev/null && command -v unzip >/dev/null &&
    ./scripts/check-host.sh --device --tools-only >/dev/null 2>&1; }; then
case " ${ID:-} ${ID_LIKE:-} " in
    *' arch '*)
        "${privilege[@]}" pacman -S --needed --noconfirm curl ca-certificates unzip \
            bubblewrap picocom libimobiledevice usbmuxd libusb kmod util-linux
        ;;
    *' ubuntu '*|*' debian '*)
        "${privilege[@]}" apt-get update
        "${privilege[@]}" apt-get install -y --no-install-recommends curl ca-certificates \
            unzip bubblewrap picocom libimobiledevice-utils usbmuxd libusb-1.0-0 kmod util-linux
        ;;
    *) echo 'Automatic runtime setup supports Arch/Omarchy and Ubuntu/Debian. Use docs/first-boot.md on other hosts.' >&2; exit 1 ;;
esac
fi
./scripts/fetch-firstboot-bundle.sh
./scripts/check-host.sh --device --artifacts --tools-only
if [[ $mode == --prepare ]]; then
    echo 'Prepared. Connect the iPad and run ./scripts/start.sh to boot.'
    exit 0
fi
"${privilege[@]}" modprobe cdc_acm
if [[ $mode == --check ]]; then exec "${privilege[@]}" "$ROOT/scripts/boot.sh" --check; fi
exec "$ROOT/scripts/boot.sh"
