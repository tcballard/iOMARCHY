# Preparation for a guided first hardware attempt

The host preparation path now uses one local launcher, `scripts/start.sh`.
No iPad has been attached or booted in this validation.

## Launcher evidence

[Run 38442945957](https://github.com/tcballard/iOMARCHY/actions/runs/38442945957),
launcher job `115454541753`, passed at code revision
`7ac9b275e71ffc18dd7962e5d52e2bbff1ee8035` on Ubuntu 24.04.

The test called `start.sh --prepare` on a host missing the USB runtime tools.
It installed those tools, downloaded the pinned bundle, verified its complete
ZIP digest and all eleven payload hashes, and checked host library loading.
A second preparation reused the verified cache and did not install packages
or download another bundle. The actual picocom arguments were accepted and
stopped at an intentionally nonexistent port; no device was opened.

| Command | Behavior |
|---|---|
| `./scripts/start.sh --prepare` | Install missing runtime tools and prepare the verified binary bundle |
| `./scripts/start.sh --check` | Prepare, then check USB serial support and root namespace readiness |
| `./scripts/start.sh` | Prepare, load the host serial driver, guide device identity and DFU, upload the temporary boot bundle and open the shell |

The latter two commands require the local Linux host; their driver/namespace
and USB stages were not executed in CI. The Arch package branch is implemented
but has not been exercised on the XPS. Native hardware success is unproven.
The [current Arch package listing](https://archlinux.org/packages/extra/x86_64/libimobiledevice/files/)
contains the required `idevice_id` and `ideviceinfo` tools.

The download pin refers to artifact `11799118225` from the earlier verified
build, with ZIP digest
`12850d3902598e8b8eba0e39114774c661fe0d67e99d57e0709e4e3914af0029`.
Its online copy expires on 12 November 2026. Retained, verified local cache
copies work afterwards; the script stops if an uncached download is unavailable.
Differing previous local artifacts are preserved before replacement.

## Compressed filesystem candidate

[Run 38442945957](https://github.com/tcballard/iOMARCHY/actions/runs/38442945957)
also passed both image jobs. Two compressed filesystem images each contain
885,948,416 bytes (844.91 MiB), with matching SHA-256:
`436de0285e3b196bb7bc771fdd7ca5c090e925113b09fd2fc6bb44a75cd6a4cd`.

The allocated input tree was 2,460,676,096 bytes (about 2.3 GiB). Thus the
unpacked size alone does not rule out RAM deployment. The compressed file
would leave about 1.17 GiB of a nominal 2 GiB for other allocations, before
accounting for kernel/reserved memory, overlay, file caches, applications and
peak loading copies. This arithmetic is not a measured RAM-boot result.

The builder preserved the original source tree and compared extracted Bash
and upstream `shell.qml` bytes against it. The original rootfs archive hash
remains `9dd69a12e7e26c314f6e04033f6411e1556255a373628b853607f3324a060367`.
The VM still used its existing ext4 disk; it passed core checks and reported
Hyprland's virtual output and real shell process liveness. It did not boot
this SquashFS image from RAM or verify visible desktop frames.

The new baseline build matched all eleven earlier payload hashes.
[Download images, manifests and full logs](https://github.com/tcballard/iOMARCHY/actions/runs/38442945957/artifacts/11837719067).
The artifact ZIP digest and expiry are retained in
[plug-in-artifacts.json](plug-in-artifacts.json); the image digest is in
[SQUASHFS-SHA256SUMS](SQUASHFS-SHA256SUMS).

A SquashFS file is not a complete RAM-boot image. Native deployment still
requires an appropriate separate kernel, loop/SquashFS/overlay support,
bootstrap userspace, peak-load memory measurements and a real hardware test.
The current firstboot kernel and initramfs are preserved.

## First-time experience and remaining gates

The launcher removes local source downloads, compilation and ARM emulation
from a normal user's setup. It opens the verified terminal automatically and
sends Enter. The iPad still needs manual DFU button presses and may require
unlocking/trusting the host when starting in normal iPadOS.

The first native handoff and USB shell must be observed before claiming
first-time success. Visible desktop frames, A8 graphics, usable physical input,
RAM/runtime budget and full Omarchy integration remain unverified. The
[earlier emulator record](README.md) documents shell liveness alongside
renderer errors; packaging and automation do not resolve those driver gaps.
