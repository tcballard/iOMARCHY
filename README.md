<h1 align="center">iOMARCHY</h1>
<p align="center">An experimental path to native Omarchy on iPad.</p>

> **Experimental prototype — hardware boot untested.**
> No successful boot on the target iPad has been demonstrated. There is no
> validated iPad Omarchy desktop image or end-user installer yet. This project is
> for development and hardware experimentation and is not ready for daily use.

iOMARCHY is a hardware bring-up project for developers working toward a usable
Omarchy desktop on iPad, starting with the **iPad mini 4 Wi-Fi
(iPad5,1 / J96 / A1538, Apple A8/T7000)**. The first milestone is a temporary,
RAM-only Linux boot with display output and a USB shell.

**Get started:** [One-command first-boot guide](docs/first-boot.md#run-once-the-ipad-is-connected).
The [cloud validation record](docs/validation/2026-10-13/README.md) covers
the current builds and their limits. The original host evidence is retained.

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
  source plus 370 signed packages for a separate emulator filesystem.
- Matched two fresh userspace archive hashes and booted the filesystem in a
  separate 4 KB ARM64 VM. Real Omarchy CLI, package composition, theme parsing,
  Bash/jq, Hyprland and Quickshell version checks passed.
- Verified real Hyprland display/input: a Wayland terminal renders red,
  receives a virtual key and turns green. The upstream Omarchy bar, icon font
  and wallpaper render; a pointer opens the visible menu and Escape closes it.
- Streamed the compressed filesystem into diskless 2048 and 1536 MiB ARM64
  VMs at 1024×768, plus 2048×1536 at 2048 MiB. All three passed in both a
  focused run and an independent clean build, with an isolated graphics candidate,
  verified read-only lower/writable RAM overlay, and zero emulated disks.
  Corrupt and interrupted transfers were rejected before mounting the root.
  Exact results and limits are in the
  [RAM integration record](docs/validation/2026-10-13/ram-integration.md).
  See [userspace scope](docs/arm64-rootfs.md) and [driver gaps](docs/graphics-input-audit.md).

![Omarchy menu in the diskless ARM64 QEMU test](docs/validation/2026-10-13/ram-1536-menu.png)

Actual emulator capture: 1536 MiB RAM, 1024×768 virtual display. Its source,
unaltered pixel conversion and test results are in the integration record.
The [full-resolution capture](docs/validation/2026-10-13/ram-2048-full-resolution-menu.png)
comes from the independent clean build at 2048 MiB and compositor scale 1.

Touchscreen, Wi-Fi and audio remain unverified. The researched support
matrix does not provide GPU acceleration; internal storage is unfinished.
Whether this hardware can support a usable Omarchy desktop is still unknown.

## First hardware attempt

Device interaction requires an **x86_64 Linux host** with the USB tools and
namespace support checked by `scripts/check-host.sh --device --artifacts`.
Preparation has passed on clean Ubuntu and Arch CI environments. Run from
this branch's repository root:

```bash
./scripts/start.sh
```

The current work is on `dev/arm64-userspace` in draft PR #2; `main` still has
the earlier prototype. For a fresh checkout of this draft:

```bash
git clone --branch dev/arm64-userspace https://github.com/tcballard/iOMARCHY.git
cd iOMARCHY
./scripts/start.sh --prepare
```

Then connect the iPad and run `./scripts/start.sh` in a real terminal.

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
- [Staged RAM boot and display/input tests](docs/ram-boot.md)
- [Graphics and input audit](docs/graphics-input-audit.md)
- [Current validation evidence](docs/validation/2026-10-13/README.md)
- [First hardware boot record](docs/hardware-boot.md)
- [Original host verification evidence](docs/validation/2026-10-12/README.md)
- [`config/sources.lock`](config/sources.lock): exact upstream revisions
- [`scripts/`](scripts/): host checks, fetch/build/verify and temporary boot
- [`initramfs/`](initramfs/): minimal RAM userspace startup

Downloaded code retains its upstream licensing. This repository does not
redistribute the third-party bootloader binaries or Apple firmware.
