# Experimental ARM64 Omarchy userspace

This is a separate ARM64 userspace experiment. It does not replace the static
BusyBox/J96 firstboot bundle, enable new iPad drivers, or install to a device.
The root filesystem is intended first for QEMU virt, not the iPad's RAM.
A virtual compositor output cannot establish J96 display or touch support.

## Inputs and scope

The official Omarchy Quattro tree is pinned at
47caa9be439e1876b6048a32a868688e9c697d48. Its full unmodified source is installed
at /usr/share/omarchy: real CLI, shell QML, Bash defaults, configurations and
themes. config/rootfs-packages.list selects actual aarch64 Hyprland,
Aquamarine, Quickshell, Foot, UWSM, Qt, Mesa, PipeWire and core utilities.

The root list is an explicit subset, not the full official 161-package ARM
manifest. Browsers, commercial applications, AI agents, developer tools,
printing, Bluetooth, storage installation and hardware setup are omitted.
Some copied upstream commands/configuration refer to omitted applications.
Their presence in the source does not make those applications operational.
PipeWire/WirePlumber are packaged, but audio services and hardware are untested.
The original icon font is registered with fontconfig, and Tokyo Night's first
wallpaper is selected. Theme template generation has not run.
Full upstream installation/provisioning/autostart scripts are
not executed. No Asahi Mac detection or installation is invoked; the platform
argument for package composition is explicitly aarch64.

## Resolve once, then rebuild the reviewed lock

An x86_64 Ubuntu 24.04 runner can install host dependencies with:

    sudo apt-get update
    sudo apt-get install pacman-package-manager libarchive-tools zstd gnupg curl binutils

An Arch host already has pacman; install the equivalent packages.
Build the committed snapshot without refreshing repositories:

    mkdir -p build artifacts logs/rootfs downloads/rootfs src
    sudo scripts/build-rootfs.sh config/rootfs-inputs.lock

The lock contains 370 packages selected on 13 October 2026. Its SHA-256 is
`236cc343fd73eb836dde03ed9e3105d7be1fc263c87ec41b1d51817a373c7d66`.
All original 362 package pins remain unchanged. Eight later additions supply
shell IPC, plugin watching, image-header detection and process utilities.
Their versions, signature checks and dependency closure are recorded in the
[RAM integration record](validation/2026-10-13/ram-integration.md).
CI consumes this file directly. To deliberately prepare an updated snapshot,
the resolver writes a new lock and never overwrites an existing one:

    sudo scripts/resolve-rootfs.sh artifacts/initial-rootfs-inputs.lock

Review and commit the produced input lock before calling a later build
reproducible. Subsequent build-rootfs.sh uses only the URLs/versions/hashes/
signatures in that lock; it does not refresh databases or substitute versions.
Unavailable/deleted packages or mismatched hashes/signatures fail explicitly.
If a pinned mirror URL disappears, the builder attempts the SHA-256-pinned
input cache in `config/rootfs-cache.lock` once. The restored package still
must pass its original hash and signature checks; versions never change.
This recovery was exercised when the locked libtiff URL returned HTTP 404.
The fallback cache predates the eight runtime additions; their signed archives
are included in subsequent complete builds' downloadable input caches.
Retain `downloads/rootfs` for offline rebuilds: the remote cache expires on
12 November 2026. Missing or mismatched inputs fail explicitly.

The resolver snapshots Omarchy's official edge aarch64 repository and official
ARM mirror. Those are moving repositories; resolution is a deliberate update
operation. Database digests are recorded, but databases are not authenticated
because these endpoints may not publish database signatures. Every package
archive must carry a verifiable PGP signature, checked against the separately
pinned official public keyrings before extraction. Public keyring source
revisions, blob hashes, fingerprints and limits are recorded alongside them.
This authenticates against those upstream trust roots, not an independent
personal certification of the maintainers.

Package registration uses host pacman in database-only mode after extraction.
Install scripts are disabled, and the guest libalpm hook directory is temporarily
removed during registration and restored afterwards. `--noscriptlet` alone
does not disable transaction hooks. Owner IDs, archive order,
file timestamps and installation-date metadata are normalized. Fixed versions
and package signatures alone do not demonstrate byte-identical rootfs output:
compare ROOTFS-SHA256SUMS from repeated clean builds before claiming that.

The [recorded CI run](validation/2026-10-13/README.md) does this comparison
and boots the resulting filesystem. It establishes matching output from two
fresh trees on the same Ubuntu runner with the committed lock; it does not
establish byte identity across arbitrary host toolchains.

Pacman also invokes `ldconfig` during database-only registration. The stable
guest loader cache is retained; its auxiliary cache is removed because it
contains inode data from the temporary build filesystem. The first diagnosed
repeat-build mismatch was confined to that auxiliary cache.

Produced files are artifacts/iomarchy-arm64-rootfs.tar.zst,
artifacts/rootfs-inputs.lock, artifacts/ROOTFS-MANIFEST.txt and
artifacts/ROOTFS-SHA256SUMS. The unpacked tree is build/rootfs/tree.
CI also archives the original downloaded inputs in `rootfs-download-cache.tar`;
wrapping them in tar preserves package filenames containing version epochs
that GitHub artifact upload otherwise rejects. Retain this cache before the
30-day CI artifact retention ends.
scripts/verify-rootfs.sh checks ELF architecture, dynamic loader, actual Omarchy
source/shell and archive integrity. These are static host checks.

## QEMU runtime scope

A separate compressed deployment candidate can be produced with
`sudo ./scripts/build-rootfs-squashfs.sh` after building the signed tree.
It requires `squashfs-tools`, preserves that tree, and writes a read-only
SquashFS image, checksum and size manifest. CI compares two freshly produced
images and checks extracted Bash and upstream shell bytes against the source.
The separate [staged RAM bootstrap](ram-boot.md) now receives the compressed
image after boot, verifies its embedded hash and mounts a read-only lower
filesystem with a bounded writable overlay. This avoids a large loader upload
and a second complete filesystem copy. Its diskless 2048 and 1536 MiB tests
verify actual terminal, wallpaper, bar, menu, pointer and keyboard interaction.
Both memory budgets pass at 1024×768; a separate 2048 MiB case also passes
at 2048×1536 and compositor scale 1. The focused and independent clean runs
are retained in the [integration record](validation/2026-10-13/ram-integration.md).

The [measured candidate](validation/2026-10-13/plug-in-preparation.md) is
885,948,416 bytes (844.91 MiB), with identical hashes from two builds.
That earlier result is packaging evidence. Later RAM images include an isolated
graphics candidate and updated defaults. Their hashes and sizes differ; the
ordinary disk test continues to use the original packaged graphics library.

After building the rootfs, install the compiler dependencies in
[cloud-build.md](cloud-build.md), plus `qemu-system-arm` and `e2fsprogs`.
In a fresh checkout, retrieve only the locked Linux source for this test:

```bash
mkdir -p src
revision=$(awk '$1 == "linux" {print $3}' config/sources.lock)
git init src/linux
git -C src/linux remote add origin https://github.com/HoolockLinux/linux
git -C src/linux fetch --depth 1 origin "$revision"
git -C src/linux checkout --detach "$revision"
JOBS=2 ./scripts/build-qemu-kernel.sh
sudo ./scripts/emulate-rootfs.sh
```

If the pinned source checkout already exists, use it directly. The emulator
creates a disposable 3 GiB ext4 file, uses 1536 MiB RAM and two Cortex-A53
virtual CPUs, and has no NIC or USB passthrough. Its kernel and checksum file
live under `artifacts/qemu/`; its serial log is `logs/qemu-rootfs.log`.
Modern VirtIO MMIO transport is selected for the virtual GPU and input devices.

scripts/emulate-rootfs.sh selects the separate QEMU virt kernel and
/usr/local/sbin/iomarchy-qemu-init. The guest checks 4 KB pages, ARM64, real
Bash associative arrays, POSIX file locking, jq, real Omarchy command routing/help, explicit ARM
package composition, Tokyo Night palette parsing, Hyprland and Quickshell
dynamic loading. IOMARCHY_QEMU_USERSPACE_PASS means those checks completed.

A separate session probe initializes packaged service accounts and udev rules
inside the disposable guest, checks unprivileged render-node access, and starts
seatd, a private D-Bus session and the real Hyprland binary with an isolated
compositor configuration. It does not start the full systemd service set.
Both Lua and legacy
.conf configurations are supported by pinned Hyprland 0.56.2; this probe uses
.conf and avoids full upstream provisioning/autostart. Software-renderer
environment settings are an experimental diagnostic, not proof that software
rendering solves the iPad graphics gap.

The separate QEMU fragment enables systemd/libudev's required file-handle,
cgroup, inotify and local-socket support; the guest mounts cgroup2 for device
initialization. Required options are checked in the generated kernel config.
The requirements are documented by [systemd v262](https://github.com/systemd/systemd/blob/v262/README).

A Wayland socket alone is insufficient: hyprctl must return an active output.
The probe allows sixty readiness attempts for EGL, the control socket and
monitor initialization. Each control query is bounded to five seconds, and
the probe checks that the compositor is still running.
The real upstream Quickshell shell is then launched on the same private
session bus. The RAM harness requires terminal colour changes after keyboard
input, an uncovered bar, wallpaper pixels and a visible pointer-opened menu
that closes with Escape. Live logs and memory samples remain available during
startup; control-socket queries are bounded to expose a stalled compositor.

The earlier packaged-library run reached a 1024×768 Virtual-1 monitor response, initialized
Hyprland's llvmpipe OpenGL ES 3.2 context, and loaded the real Omarchy shell
configuration. Its process stayed alive for ten seconds and created bar and
background layer surfaces. Aquamarine still reported repeated renderer-state
errors, so this establishes startup and liveness without verified visible
frames, interaction or desktop usability. See the full scope and log excerpts
in the [validation record](validation/2026-10-13/README.md). The later isolated
graphics candidate passes the actual display/input test at both RAM budgets;
the [integration record](validation/2026-10-13/ram-integration.md) preserves
the exact results. This remains a desktop subset with omitted services/apps.

No QEMU result validates the J96 kernel, panel, USB host input, touchscreen,
Wi-Fi, audio, storage, bootloaders or GPU. The full rootfs is not added to the
minimal firstboot initramfs: measure compressed and expanded size and account
for J96's 2 GB RAM before considering any RAM-only deployment. No device
interaction occurs in the builder or QEMU scripts.
