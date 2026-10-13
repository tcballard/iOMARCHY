#!/usr/bin/env bash
# Shared by the separate experimental desktop-rootfs scripts.
export LC_ALL=C
export ROOTFS_OMARCHY_REV=47caa9be439e1876b6048a32a868688e9c697d48
export ROOTFS_EPOCH=1791849600
export ROOTFS_WORK="$PWD/build/rootfs"
export ROOTFS_CACHE="$PWD/downloads/rootfs"
export ROOTFS_TREE="$ROOTFS_WORK/tree"
rootfs_fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
rootfs_require() {
    local tool
    for tool in "$@"; do command -v "$tool" >/dev/null || rootfs_fail "missing host tool: $tool"; done
}
rootfs_setup() {
    [[ $PWD != / ]] || rootfs_fail 'run in a project checkout'
    mkdir -p "$ROOTFS_WORK" "$ROOTFS_CACHE" logs/rootfs artifacts
}
rootfs_config() {
    mkdir -p "$ROOTFS_WORK/db/local" "$ROOTFS_WORK/db/sync"
    cat > "$ROOTFS_WORK/pacman.conf" <<CONF
[options]
Architecture = aarch64
# Unsigned database snapshots are recorded, not called authenticated.
# Every package is separately SHA-256 + GPG verified before extraction.
SigLevel = Never
[omarchy]
Server = https://pkgs.omarchy.org/edge/\$arch
[core]
Server = https://arm-mirror.omarchy.org/\$arch/\$repo
[extra]
Server = https://arm-mirror.omarchy.org/\$arch/\$repo
[alarm]
Server = https://arm-mirror.omarchy.org/\$arch/\$repo
[aur]
Server = https://arm-mirror.omarchy.org/\$arch/\$repo
CONF
}
rootfs_download() {
    local url=$1 expected=$2 path=$3
    [[ $url == https://* ]] || rootfs_fail "non-HTTPS input: $url"
    if [[ ! -s $path ]] || [[ $(sha256sum "$path" | cut -d' ' -f1) != "$expected" ]]; then
        curl --fail --location --retry 3 --output "$path.tmp" "$url"
        [[ $(sha256sum "$path.tmp" | cut -d' ' -f1) == "$expected" ]] || rootfs_fail "SHA-256 mismatch: $url"
        mv -- "$path.tmp" "$path"
    fi
}
rootfs_trust() {
    [[ -s config/rootfs-keyrings/SHA256SUMS ]] || rootfs_fail 'missing reviewed keyring hashes'
    (cd config/rootfs-keyrings && sha256sum -c SHA256SUMS)
    mkdir -p "$ROOTFS_WORK/gpg"
    chmod 700 "$ROOTFS_WORK/gpg"
    gpg --batch --homedir "$ROOTFS_WORK/gpg" --import config/rootfs-keyrings/archlinuxarm.gpg config/rootfs-keyrings/omarchy.gpg >&2
    # The supplied official ARM keyring, including its revocation packets, is
    # the trust root. This does not independently certify release maintainers.
    gpg --batch --homedir "$ROOTFS_WORK/gpg" --export > "$ROOTFS_WORK/trusted.gpg"
}
