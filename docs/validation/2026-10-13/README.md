# Cloud validation — 13 October 2026

The minimal boot bundle passes offline checks and repeat builds. The separate
ARM64 Omarchy filesystem builds byte-identically and boots in QEMU, where its
core userspace checks pass. **No iPad was attached or booted.** Hardware
observations remain in [hardware-boot.md](../../hardware-boot.md).

The subsequent [one-command preparation and compression record](plug-in-preparation.md)
covers the tested runtime-only launcher and a reproducible 845 MiB SquashFS
candidate. The launcher still selects the verified minimal boot bundle.

The later [RAM integration and hardening record](ram-integration.md) covers
clean Ubuntu/Arch preparation, exact-cache recovery, staged diskless boot,
and passing focused/independent clean display/input tests, including the full
2048×1536 pixel count at 2048 MiB. The results below remain historical disk-based
validation and must not be read as passing those later tests.

## Validated revision and outputs

[Run 38370893989](https://github.com/tcballard/iOMARCHY/actions/runs/38370893989)
uses branch head `6766b0e2bfba6f6c2f5f70e3a0815a4055110018` and pull-request
merge checkout `44ea6e3bcb78478c1a6d23094abd907fb0297278`. Both jobs completed
successfully: baseline `115207317462`, userspace `115207317627`.
The checked-in record is a subsequent documentation update; runtime evidence
belongs to the exact tested code revision above.

| Check | Observed result |
|---|---|
| Minimal J96 bundle | Eleven artifact hashes match across repeat builds; offline checks pass |
| Separate J96 graphics probe | Built with DRM/simpledrm and 4 KB pages; never assembled into the normal bundle or booted |
| Locked ARM64 userspace | 362 packages verified by SHA-256 and PGP; two fresh filesystem archives match |
| ARM64 VM boot | Separate QEMU kernel boots the filesystem with 4 KB pages, two CPUs and 1536 MiB RAM |
| Core commands | Bash, jq, real Omarchy help, explicit ARM package composition and theme parsing pass |
| Dynamic libraries | Hyprland 0.56.2 and Quickshell 0.3.2 version commands run as the guest user |
| Graphical session | Virtual-1 monitor query and real shell startup/liveness pass; renderer errors remain and visible output is unverified |
| iPad boot and desktop | Not attempted; no hardware or usability result |

- [Minimal firstboot bundle](https://github.com/tcballard/iOMARCHY/actions/runs/38370893989/artifacts/11799118225):
  18,414,433 bytes; artifact ZIP SHA-256
  `12850d3902598e8b8eba0e39114774c661fe0d67e99d57e0709e4e3914af0029`.
- [ARM64 userspace, kernel, input cache and logs](https://github.com/tcballard/iOMARCHY/actions/runs/38370893989/artifacts/11798964345):
  1,561,411,668 bytes; artifact ZIP SHA-256
  `90857b6a254d62fe26627f8bfec067bca3bf17b33dd1ebc0f0ebf32b81d4fbe0`.

Both artifact copies expire on 12 November 2026. These ZIP digests differ
from the individual payload hashes inside them. Preserve the downloads and
manifests before retention expires.

Individual baseline and probe hashes are retained in
[baseline-SHA256SUMS](baseline-SHA256SUMS) and
[graphics-probe-SHA256SUMS](graphics-probe-SHA256SUMS).
[ROOTFS-SHA256SUMS](ROOTFS-SHA256SUMS) records the matching userspace archive.
[cloud-artifacts.json](cloud-artifacts.json) retains GitHub artifact metadata.
[qemu-userspace.log](qemu-userspace.log) contains selected runtime output, with omissions marked;
the downloadable userspace artifact includes the complete serial log, kernel,
filesystem, manifests and exact package/source download cache.

## Minimal firstboot and graphics probe

Ubuntu 24.04 CI fetched the pinned source and loader inputs, built the baseline,
and passed kernel/DTB format, 4 KB page, built-in configuration, static ARM64
BusyBox, initramfs contents/permissions, assembly, ShellCheck and synthetic
identity checks. ARM64 shell checks ran under QEMU user emulation.

The repeat step matched all eleven artifact hashes. BusyBox runs `make
distclean` before each rebuild so stale object files are not reused. The
separate DRM/simpledrm probe was built without replacing the baseline kernel,
changing its boot arguments or modifying the firstboot initramfs.

The earlier local clean-output comparison matched eight of eleven historical
hashes. BusyBox, the initramfs and the combined image changed because the old
BusyBox executable retained an earlier build-time banner. The clean build
reports `BusyBox v1.37.0 ()`. The old same-workspace repeat result remains
historical evidence; it was not an independent clean rebuild. Cross-host or
cross-toolchain byte identity is not claimed, and the upstream prebuilt
loaders were not independently rebuilt.

The exact upstream m1n1 artifact `9753630137` was available and its published
ZIP digest was verified. Its source pin is
`d5a10ac52a6468484854419a6c5130f1d62073eb`; ZIP SHA-256 is
`b92c7a15c8c7c6720eedd9e7021ac6ffb5ff0e15d62afddb45897ec705496867`.
Upstream expiry is 29 November 2026 at 10:04:02 UTC. The current firstboot
artifact also retains this ZIP. Preserve it before expiry; the fetch script
fails rather than substituting another loader.

## ARM64 userspace and runtime

Official Omarchy source is pinned at
`47caa9be439e1876b6048a32a868688e9c697d48`. The committed 362-package lock has
SHA-256 `4ee103e7857b80042776b0c87476bf9630aed236102fe01392119fd9cd63f4ac`.
Repository databases are a recorded, unauthenticated snapshot; each package
archive is independently hash checked and signature verified using the pinned
upstream public keys before extraction. No Asahi hardware installer or
Omarchy installation script runs. The full source is present; the selected
package subset and unconfigured services are listed in
[arm64-rootfs.md](../../arm64-rootfs.md).

The VM executed real Omarchy help and `omarchy-pkg-defaults aarch64` (161
upstream package names), parsed Tokyo Night background `#1a1b26`, and ran
Hyprland and Quickshell version commands successfully. It emitted
`IOMARCHY_QEMU_USERSPACE_PASS` and powered off. The emulator has no network
interface or USB passthrough and uses a disposable ext4 disk.

The guest initialized service accounts and udev, recognized the virtual
keyboard and pointer, opened `/dev/dri/renderD128` as UID 1000, and created a
Wayland socket. Hyprland's monitor query reported enabled output `Virtual-1`
at 1024×768 and 60.004 Hz. Its renderer identified OpenGL ES 3.2, Mesa 26.2.4
and llvmpipe (LLVM 23.1.1). This used the isolated probe configuration, not
the complete upstream Hyprland Lua session.

Quickshell loaded `/usr/share/omarchy/shell/shell.qml`, reported
`Configuration Loaded`, and survived the ten-second liveness check. Hyprland
logged creation of `omarchy-background` and `omarchy-bar` layer surfaces.
The guest emitted `IOMARCHY_QEMU_COMPOSITOR_PASS`,
`IOMARCHY_QEMU_SHELL_PROCESS_ALIVE` and session result 0.

**This is startup/control-plane and process-liveness evidence, not a verified
rendered desktop.** Aquamarine repeatedly reported EGL device-matching and
renderer-state errors while committing Virtual-1. The log also contains a
QML `displayCutouts` binding-loop warning, cursor-theme warnings and missing
optional system metadata. No frame capture, visible pixels, interaction,
frame-time measurement or full-service desktop validation was performed.
A passing monitor query and live shell process must not hide those errors.

The compressed filesystem is about 787 MiB; its uncompressed tar stream is
about 2.18 GiB and its extracted tree is reported by `du -sh` as about 2.3 GiB.
It cannot simply be added to the iPad RAM initramfs: J96 has 2 GB physical RAM
and also needs memory for the kernel, applications and display buffers.

## Reproducibility corrections and historical failures

An early CI comparison incorrectly printed PASS because `diff | tee` did not
use pipefail. That run is not reproducibility evidence. The workflow now uses
explicit Bash pipefail, fails a nonmatching comparison, and preserves complete
file-content/ownership inventories to diagnose differences. The successful
result above was checked against both actual archive hashes in the full log.

The inventory in run `38362916097` confined the differing image bytes to
`var/cache/ldconfig/aux-cache`. Pacman invokes ldconfig during database-only
registration; that auxiliary cache records temporary filesystem inode data.
The builder removes it while retaining the stable guest loader cache. See
[rootfs-mismatch.log](rootfs-mismatch.log) for the observed diff. Subsequent
run [38364931432](https://github.com/tcballard/iOMARCHY/actions/runs/38364931432)
at `6990c5daa9c494ca604b748fc93906ae2d5f6738` matched both archive hashes:
`9ff14bfa41de96f6c5bf9ff4cab980da48f6edf5a5feb87c660a5cda41ab5c14`.

The guest runtime setup was also corrected: version checks need the guest's
`XDG_RUNTIME_DIR`; seatd uses its default socket rather than an unsupported
`-s` option; the separate QEMU kernel needs inotify and the pinned Linux tree's
explicit `DRM_VIRTIO_GPU_KMS` option; the virtual GPU/input devices use modern
VirtIO MMIO transport. Wayland socket locks require `FILE_LOCKING`; the guest
also initializes sysusers and udev explicitly because its diagnostic PID 1
does not start normal services. A Wayland socket appears before EGL/control
initialization completes, so the monitor query now retries while the process
is alive. [qemu-initial-boot.log](qemu-initial-boot.log) preserves
an earlier failure. These changes apply only to the emulator setup.

## What remains unproven

No result here establishes Pongo→m1n1→Linux handoff on J96, display format,
USB ACM operation, touch, USB host input, Wi-Fi, audio, internal storage,
GPU acceleration or a usable Omarchy desktop. Source audits and virtual
outputs are distinct from hardware observations. See the
[next local test plan](../../roadmap.md#next-local-hardware-tests).
