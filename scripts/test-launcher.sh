#!/usr/bin/env bash
# Offline negative tests in a disposable checkout; no USB enumeration.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source scripts/identity.sh
for good in \
    'CPID:7000 CPRV:11 BDID:08 ECID:000000001234ABCD SRTG:[iBoot-test]' \
    'CPID:00007000 BDID:0008 ECID:1234abcd SRTG:[PongoOS-test]'; do
    parse_identity "$good"
    [[ $ID_ECID == 1234ABCD ]]
done
for bad in \
    'CPID:7000 BDID:09 ECID:1' 'CPID:7001 BDID:08 ECID:1' \
    'CPID:7000 BDID:08 ECID:0' 'CPID:7000 BDID:08' \
    'CPID:10000000000007000 BDID:08 ECID:1' \
    'CPID:7000 BDID:10000000000000008 ECID:1' \
    'CPID:7000 BDID:08 ECID:1 ECID:2' \
    'CPID:7000 CPID:7001 BDID:08 ECID:1' \
    'prefixCPID:7000 BDID:08 ECID:1' 'CPID:7000 BDID:08 ECID:1junk' \
    $'CPID:7000 BDID:08 ECID:1\nCPID:7001'; do
    if parse_identity "$bad"; then echo "Accepted invalid descriptor: $bad" >&2; exit 1; fi
done
sha256sum -c artifacts/SHA256SUMS
scratch=$(mktemp -d "$PWD/build/launcher-fixtures-XXXX")
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/scripts" "$scratch/config" "$scratch/docs/validation/2026-10-13" "$scratch/bin" "$scratch/artifacts"
cp scripts/fetch-firstboot-bundle.sh "$scratch/scripts/"
cp config/firstboot-bundle.lock "$scratch/config/"
cp docs/validation/2026-10-13/baseline-SHA256SUMS "$scratch/docs/validation/2026-10-13/"
printf 'Existing local build\n' > "$scratch/artifacts/pongoterm"
cp "$scratch/artifacts/pongoterm" "$scratch/expected"
cat > "$scratch/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
while [[ $# -gt 0 ]]; do
    if [[ $1 == --output ]]; then printf 'corrupted download\n' > "$2"; exit 0; fi
    shift
done
exit 1
MOCK
chmod 755 "$scratch/bin/curl"
if PATH="$scratch/bin:$PATH" bash "$scratch/scripts/fetch-firstboot-bundle.sh" > "$scratch/rejected.log" 2>&1; then
    echo 'Invalid ZIP was accepted' >&2; exit 1
fi
grep -q 'checksum mismatch' "$scratch/rejected.log"
expected=$(sha256sum "$scratch/expected" | cut -d' ' -f1)
[[ $(sha256sum "$scratch/artifacts/pongoterm" | cut -d' ' -f1) == "$expected" ]]
mkdir -p "$scratch/downloads"
cp downloads/firstboot-bundle.zip "$scratch/downloads/"
# A valid cache succeeds even while the download stub deliberately corrupts data.
PATH="$scratch/bin:$PATH" bash "$scratch/scripts/fetch-firstboot-bundle.sh"
(cd "$scratch" && sha256sum -c artifacts/SHA256SUMS)
mapfile -t backups < <(find "$scratch/build" -path '*/previous-artifacts-*/pongoterm')
[[ ${#backups[@]} == 1 ]]
[[ $(sha256sum "${backups[0]}" | cut -d' ' -f1) == "$expected" ]]
echo 'PASS: identity overflow/ambiguity rejected; bad download preserves local binaries; verified cache works offline and preserves previous outputs.'
