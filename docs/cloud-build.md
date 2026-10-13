# Offline builds on Linux hosts and CI

The first-boot bundle remains the minimal, hardware-untested J96 baseline.
Building it does not require a connected iPad, libimobiledevice, picocom,
host USB serial support, root, Docker, or permission to create namespaces.
Device-host readiness is checked separately with
`scripts/check-host.sh --device --artifacts`, or `scripts/boot.sh --check`.
Only the local hardware runbook should be used for actual device interaction.

## Build environment

The build scripts use standard Linux tools instead of requiring an Arch
package database. `scripts/manifest.sh` records compiler and emulator versions,
the host OS, and available package versions from pacman, dpkg, or rpm. A
package database is optional; the compiler versions and artifact hashes are
always recorded. The pinned palera1n payload remains x86_64, so the current
device boot host must still be x86_64 Linux.

The original baseline was built with LLVM/LLD 23.1.1, ARM64 GCC 16.1.0,
ARM64 glibc 2.44, and QEMU 11.1.2. Those versions are recorded in the
[original manifest](validation/2026-10-12/MANIFEST.txt). Changing a toolchain
can change compiled artifact hashes even when source revisions and
configuration match. A successful build on another distribution is a
portability result; byte-identical reproduction must be established by
comparing hashes and toolchains.

For an Ubuntu 24.04 x86_64 runner, install build dependencies with:

```bash
sudo apt-get update
sudo apt-get install --no-install-recommends \
  git curl ca-certificates build-essential clang llvm lld \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross \
  bc flex bison device-tree-compiler cpio gzip unzip bzip2 \
  libusb-1.0-0-dev pkg-config shellcheck qemu-user-static gnupg file
```

`qemu-user` can replace `qemu-user-static` for the explicit emulation used by
this baseline. The scripts prefer `qemu-aarch64-static`, then
`qemu-aarch64`; `QEMU_AARCH64=/absolute/path/to/qemu-aarch64` selects one
explicitly. This does not configure binfmt or execute a chroot.

The repository's [offline build workflow](../.github/workflows/offline-build.yml)
describes a clean GitHub-hosted Ubuntu build. The environment manifest is the
record of the versions actually installed by any run; the Ubuntu release
label does not pin the package repository or guarantee identical compilers.

## Reproduce the baseline

From a clean checkout, with network access to the pinned upstream inputs:

```bash
./scripts/check-host.sh
./scripts/fetch.sh
JOBS=4 ./scripts/rebuild.sh
./scripts/check-host.sh --artifacts
```

`rebuild.sh` compiles the kernel and BusyBox, builds the initramfs and
identity-checking host pongoterm, assembles the combined RAM boot image,
runs offline verification, then writes `artifacts/SHA256SUMS` and
`MANIFEST.txt`. It checks Git source revisions and tracked changes before
compiling. The original `config/kernel.fragment`, `config/busybox.config`,
boot arguments and first-boot userspace remain the baseline build inputs.
No cloud command should call `boot.sh` without `--check`.

For a repeat build, retain the first checksum file and compare:

```bash
cp artifacts/SHA256SUMS build/first-SHA256SUMS
JOBS=4 ./scripts/rebuild.sh
diff -u build/first-SHA256SUMS artifacts/SHA256SUMS
```

This checks a repeat build in the same workspace. Independent clean outputs
and different host distributions must be reported separately. To compare
with the historical eleven artifacts, run
`sha256sum -c docs/validation/2026-10-12/SHA256SUMS` and preserve the output;
do not overwrite historical evidence with newer hashes.

The input cache remains excluded from Git. Cached copies may seed an offline
build only after `config/downloads.sha256` and pinned Git revisions have been
checked. The m1n1 input is the exact CI artifact `9753630137`, with its
original digest and source revision; its documented expiry is
**29 November 2026**. An expired or unavailable download must stop a fresh
build. Retain the verified ZIP with its provenance instead of substituting
a newer loader. The current validation record must distinguish a tested
fresh download from reuse of a previously verified local cache.

## Verification boundaries

Offline verification establishes kernel image format and 4 KB pages,
required built-in configuration, J96 DT compatibility, static ARM64 BusyBox,
initramfs contents and permissions, deterministic assembly, shell syntax,
and synthetic identity parsing. QEMU executes ARM64 shell arithmetic and
syntax checks on a generic emulated CPU. It does not emulate this iPad's
bootloaders, Apple A8 SoC, USB gadget, touchscreen, framebuffer or GPU.

Namespace support is relevant to the selected-device USB boot safeguards,
so it is checked by `--device`, not by baseline verification. A cloud build
that lacks USB devices or namespace permission can still produce and verify
the first-boot artifacts. That result does not establish local USB readiness
or any hardware support.
