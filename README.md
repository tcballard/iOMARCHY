<h1 align="center">iOMARCHY</h1>
<p align="center">An experimental path to native Omarchy on iPad.</p>

> **Experimental prototype — hardware boot untested.**
> No successful boot on the target iPad has been demonstrated. There is no
> working Omarchy desktop image or end-user installer yet. This project is
> for development and hardware experimentation and is not ready for daily use.

iOMARCHY is a hardware bring-up project for developers working toward a usable
Omarchy desktop on iPad, starting with the **iPad mini 4 Wi-Fi
(iPad5,1 / J96 / A1538, Apple A8/T7000)**. The first milestone is a temporary,
RAM-only Linux boot with display output and a USB shell.

**Get started:** [Build and first-boot guide](docs/first-boot.md#rebuild-and-check).
The [cloud validation record](docs/validation/2026-10-13/README.md) covers
the current builds and their limits. The original host evidence is retained.

*Device preview pending — awaiting a contributor-provided capture after a
successful hardware boot.*

## Current status

The first-boot kernel, userspace and loader bundle have been prepared and
verified on the host. **The iPad has not been boot-tested.** The current
bundle is intended to boot a RAM-only Linux shell. A separate, pinned ARM64
Omarchy filesystem builds reproducibly and boots in QEMU, where its core
command checks pass. Emulation does not establish that the kernel or drivers
work on this iPad.

- Built ARM64 kernel with **4 KB pages**, J96 device tree and built-in
  framebuffer/console/USB gadget support.
- Built static ARM64 BusyBox and a gzip initramfs with executable `/init`.
- Pinned upstream m1n1, PongoOS and palera1n; built an identity-checking
  pongoterm and assembled the combined boot image.
- Passed offline artifact checks, ShellCheck and ARM64 shell emulation on
  Ubuntu 24.04 CI. Two builds with fresh BusyBox outputs matched all eleven
  baseline artifact hashes; historical cross-host bytes are not promised.
- Built a separate 4 KB DRM/simpledrm probe, without changing the baseline.
- Audited official Omarchy ARM64 support and pinned the actual upstream
  source plus 362 signed packages for a separate emulator filesystem.
- Matched two fresh userspace archive hashes and booted the filesystem in a
  separate 4 KB ARM64 VM. Real Omarchy CLI, package composition, theme parsing,
  Bash/jq, Hyprland and Quickshell version checks passed.
- Reached a Hyprland monitor response and loaded the genuine Omarchy QML shell
  in the VM. Its process stayed alive for ten seconds; repeated renderer errors
  remain, and visible output or desktop usability has not been verified.
- Built a reproducible 845 MiB compressed filesystem candidate. Its RAM boot
  integration and runtime memory budget remain untested.
  See [userspace scope](docs/arm64-rootfs.md) and [driver gaps](docs/graphics-input-audit.md).

Touchscreen, Wi-Fi and audio remain unverified. The researched support
matrix does not provide GPU acceleration; internal storage is unfinished.
Whether this hardware can support a usable Omarchy desktop is still unknown.

## First hardware attempt

Device interaction requires an **x86_64 Linux host** with the USB tools and
namespace support checked by `scripts/check-host.sh --device --artifacts`.
Offline builds have passed on Ubuntu CI. After completing the build guide,
run from the repository root:

```bash
./scripts/start.sh
```

The launcher installs missing runtime dependencies and retrieves the verified
prebuilt bundle; no local compiler or ARM emulator is required. It supports
Arch/Omarchy and Ubuntu/Debian. Use `--prepare` before connecting the iPad.

Use a USB-A to Lightning data cable, with a USB-C adapter if needed, and
connect only this Apple device. The script is designed to guide DFU, check
device identity across reconnections, load the temporary Linux bundle and
open USB serial. This live boot sequence has not been tested on the iPad.
It contains no erase, restore, repartition, firmware-update or installation
operations. No full iPadOS jailbreak is part of the selected Pongo-only path.

Read the [first-boot runbook](docs/first-boot.md) for prerequisites, expected
output, returning to iPadOS, pinned versions and known limitations.

## Reproduce the preparation

A fresh clone contains the scripts, configuration and historical verification
records. It does not contain the compiled kernel, upstream source trees,
loader binaries or Apple firmware.

```bash
./scripts/check-host.sh       # reports required host tools
./scripts/fetch.sh            # retrieve exact pinned source and payload inputs
./scripts/rebuild.sh          # compile, assemble, verify and generate a manifest
./scripts/boot.sh --check     # readiness and hashes only; no device interaction
```

Dependencies and upstream binary provenance are documented in the runbook.
Retain the downloaded m1n1 CI ZIP locally: its upstream artifact expires on
29 November 2026. The fetch script fails if the exact pinned payload is no
longer available; it does not silently substitute a newer build.

## Project map

- [Roadmap to Omarchy](docs/roadmap.md)
- [Cloud builds and reproducibility](docs/cloud-build.md)
- [Official ARM64 package/source audit](docs/arm64-audit.md)
- [Experimental ARM64 userspace](docs/arm64-rootfs.md)
- [Graphics and input audit](docs/graphics-input-audit.md)
- [Current validation evidence](docs/validation/2026-10-13/README.md)
- [First hardware boot record](docs/hardware-boot.md)
- [Original host verification evidence](docs/validation/2026-10-12/README.md)
- [`config/sources.lock`](config/sources.lock): exact upstream revisions
- [`scripts/`](scripts/): host checks, fetch/build/verify and temporary boot
- [`initramfs/`](initramfs/): minimal RAM userspace startup

Downloaded code retains its upstream licensing. This repository does not
redistribute the third-party bootloader binaries or Apple firmware.
