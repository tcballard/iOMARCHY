# Cloud validation — 13 October 2026

No iPad was attached or booted. This record covers offline artifacts and a
separate ARM64 userspace experiment. Hardware observations remain in
[hardware-boot.md](../../hardware-boot.md), which still says not attempted.

## Minimal firstboot and graphics probe

[Run 38359096052](https://github.com/tcballard/iOMARCHY/actions/runs/38359096052),
firstboot job `115168870068`, completed successfully on Ubuntu 24.04. The
branch head was `3a6f7f159387bd73782c5208c7ae36d1d03de1a2`; pull-request
checkout used merge commit `14478656d40c62df7f7a9797f48c821506a70f0f`.

- Fresh pinned downloads and source checkouts succeeded.
- Kernel/DTB formats, 4 KB pages, built-in configuration, static ARM64 BusyBox,
  initramfs contents and permissions, image assembly, ShellCheck, and synthetic
  identity parsing passed. ARM64 shell checks ran under QEMU user emulation.
- Two baseline rebuilds matched all eleven artifact hashes. BusyBox now runs
  `make distclean` before each build, so stale object files are not reused.
- The separate DRM/simpledrm probe built successfully. It was not booted,
  combined with a loader, or substituted for the baseline.

[Download the verified firstboot bundle](https://github.com/tcballard/iOMARCHY/actions/runs/38359096052/artifacts/11794014962).
Its artifact ZIP is 17,415,080 bytes with SHA-256
`96ba371bbf9e1998e4ce33e50e8381c12f0b81af6a4722831c713b462cbd8e89`.
GitHub currently expires this copy on 12 November 2026. The bundle includes
the actual build manifest and logs. Individual hashes are retained in
[baseline-SHA256SUMS](baseline-SHA256SUMS) and
[graphics-probe-SHA256SUMS](graphics-probe-SHA256SUMS).
[cloud-artifacts.json](cloud-artifacts.json) records the fetched artifact metadata.

The earlier local clean-output comparison matched eight of the eleven
historical hashes. BusyBox, the initramfs and the combined image changed:
the old BusyBox executable retained a build-time banner from an earlier build
despite the generated timestamp header having been cleared. The clean build
reports `BusyBox v1.37.0 ()`. The old same-workspace repeat result remains
historical evidence; it was not an independent clean rebuild. Historical
records have not been overwritten. Cross-host/toolchain byte identity is not
claimed, and upstream prebuilt loaders were not independently rebuilt.

The exact upstream m1n1 artifact `9753630137` was still available and its
published ZIP digest was verified. Its source pin is
`d5a10ac52a6468484854419a6c5130f1d62073eb`, ZIP SHA-256 is
`b92c7a15c8c7c6720eedd9e7021ac6ffb5ff0e15d62afddb45897ec705496867`,
and upstream expiry is 29 November 2026 at 10:04:02 UTC. Subsequent workflow
artifacts also retain the downloaded ZIP. Preserve it before expiry; the
fetch script must fail rather than substitute another loader.

## ARM64 userspace

Official Omarchy source is pinned at
`47caa9be439e1876b6048a32a868688e9c697d48`. The committed package lock has
362 packages and SHA-256
`4ee103e7857b80042776b0c87476bf9630aed236102fe01392119fd9cd63f4ac`.
Repository databases are a recorded, unauthenticated snapshot; each package
archive is independently SHA-256 checked and signature verified using the
pinned upstream public keys before extraction. No Asahi hardware installer
or Omarchy installation script runs.

The initial run produced an archive but failed static verification because
`qs` is an absolute symlink to `/usr/bin/quickshell` inside the guest. It also
exposed that Pacman's `--noscriptlet` does not suppress transaction hooks.
The corrected builder temporarily removes the guest hook directory while
registering packages, restores it afterwards, and checks the actual guest
ELF file without following its alias into the host.

[Run 38361273071](https://github.com/tcballard/iOMARCHY/actions/runs/38361273071)
built the corrected filesystem and passed static checks. Its archive hash was
`78a47c9ba866b147946d65ffb477b2a5eeedb74a927e40b7d6ee61d93d041fab`.
The following comparison step stopped on CI output-directory ownership,
before a second build or QEMU execution. That workflow error was corrected.
Run `38361636151` then completed two builds, but their hashes differed
(`2ad9d90a...` and `50ad474c...`). The comparison step incorrectly printed
PASS because its pipeline ended in `tee` without pipefail. The workflow now
uses explicit Bash pipefail and explicitly fails a nonmatching comparison;
it retains file-content/ownership inventories to diagnose differences. No
userspace reproducibility claim is made from that run. The virtual kernel
built, but its verifier required `ARCH_VIRT`, a symbol absent from this ARM64
Kconfig. That check was replaced with the actual interrupt, console, block,
filesystem and DRM driver requirements. QEMU did not run in that attempt.

Runtime testing may continue independently after a repeat-hash failure so
that one run can diagnose both issues; the overall job still fails, and
runtime results cannot imply reproducibility.

The initial corrected archive is about 787 MiB compressed and 2.18 GiB as an
uncompressed tar stream; the extracted tree occupies about 2.3 GB as reported
by `du -sh`. It is a virtual-machine disk filesystem. It cannot simply be
added to the current iPad RAM initramfs: J96 has 2 GB physical RAM and also
needs memory for the kernel, applications and display buffers.

## What remains unproven

No result here establishes Pongo→m1n1→Linux handoff on J96, display format,
USB ACM operation, touch, USB host input, Wi-Fi, audio, internal storage,
GPU acceleration, or a usable Omarchy desktop. The graphics and package
audits identify constraints; their source findings are not hardware tests.
See the [next local test plan](../../roadmap.md#next-local-hardware-tests).
