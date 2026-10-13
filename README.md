# iOMARCHY

> **Experimental prototype — hardware boot untested.**
> No successful boot on the target iPad has been demonstrated. There is no
> working Omarchy desktop image or end-user installer yet. This project is
> for development and hardware experimentation and is not ready for daily use.

**The goal is a usable Omarchy desktop running natively on an iPad.**

The first target is an **iPad mini 4 Wi-Fi (iPad5,1 / J96 / A1538)** with
Apple A8/T7000 and iPadOS 15.8.3. Development and USB boot transport run on
an x86_64 Dell XPS using Omarchy/Arch Linux.

## Current status

The first-boot kernel, userspace and loader bundle have been prepared and
verified on the host. **The iPad has not been boot-tested.** The current
bundle is intended to boot a RAM-only Linux shell. The Omarchy desktop remains
to be built and validated after hardware bring-up. Host verification and ARM64
shell emulation do not establish that the kernel or drivers work on this iPad.

- Built ARM64 kernel with **4 KB pages**, J96 device tree and built-in
  framebuffer/console/USB gadget support.
- Built static ARM64 BusyBox and a gzip initramfs with executable `/init`.
- Pinned upstream m1n1, PongoOS and palera1n; built an identity-checking
  pongoterm and assembled the combined boot image.
- Passed offline artifact checks, ShellCheck and ARM64 shell emulation.
  A repeat build in the original workspace matched all eleven artifact hashes.

Touchscreen, Wi-Fi and audio remain unverified. The researched support
matrix does not provide GPU acceleration; internal storage is unfinished.
Whether this hardware can support a usable Omarchy desktop is still unknown.

## First hardware attempt

On the prepared Dell checkout:

```bash
/home/tcballard/Projects/iOMARCHY/scripts/boot.sh
```

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
- [First hardware boot record](docs/hardware-boot.md)
- [Original host verification evidence](docs/validation/2026-10-12/README.md)
- [`config/sources.lock`](config/sources.lock): exact upstream revisions
- [`scripts/`](scripts/): host checks, fetch/build/verify and temporary boot
- [`initramfs/`](initramfs/): minimal RAM userspace startup

Downloaded code retains its upstream licensing. This repository does not
redistribute the third-party bootloader binaries or Apple firmware.
