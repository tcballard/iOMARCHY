#!/usr/bin/env bash
# Build a private host diagnostic; no system install, device access or udev rules.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
root=$PWD
pin=93c117c29b1f6669bc4ceca8b84e1df06449fe33
source_dir=$root/build/recovery-diagnostic-src
prefix=$root/artifacts/recovery-diagnostic
if [[ ! -d $source_dir ]]; then
    git clone --no-checkout https://github.com/libimobiledevice/libirecovery.git "$source_dir"
    git -C "$source_dir" checkout --detach "$pin"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$pin" ]] || { echo 'Unexpected libirecovery revision; refusing to overwrite.' >&2; exit 1; }
git -C "$source_dir" diff --quiet HEAD -- || { echo 'Modified libirecovery tracked source; refusing build.' >&2; exit 1; }
mkdir -p "$prefix"
(
    cd "$source_dir"
    ./autogen.sh --prefix="$prefix" --without-tools --without-udev --disable-shared --enable-static
    make -j2
    make install
)
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
# pkg-config emits intentional compiler/linker words.
# shellcheck disable=SC2046
cc -std=c11 -O2 -Wall -Wextra -Werror tools/recovery-diagnostic.c \
    $(pkg-config --cflags --libs --static libirecovery-1.0) -o "$prefix/recovery-diagnostic"
printf '%s\n' "$pin" > "$prefix/upstream-commit"
sha256sum tools/recovery-diagnostic.c scripts/build-recovery-diagnostic.sh \
    "$prefix/lib/libirecovery-1.0.a" "$prefix/recovery-diagnostic" > "$prefix/SHA256SUMS"
