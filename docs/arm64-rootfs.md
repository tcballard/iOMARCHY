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
Fonts and themes are present; template generation and desktop personalization
have not run. Full upstream installation/provisioning/autostart scripts are
not executed. No Asahi Mac detection or installation is invoked; the platform
argument for package composition is explicitly aarch64.

## Resolve once, then rebuild the reviewed lock

An x86_64 Ubuntu 24.04 runner can install host dependencies with:

    sudo apt-get update
    sudo apt-get install pacman-package-manager libarchive-tools zstd gnupg curl binutils

An Arch host already has pacman; install the equivalent packages.
The resolver writes a new lock, never overwrites an existing one:

    sudo scripts/resolve-rootfs.sh artifacts/initial-rootfs-inputs.lock
    sudo scripts/build-rootfs.sh artifacts/initial-rootfs-inputs.lock

Review and commit the produced input lock before calling a later build
reproducible. Subsequent build-rootfs.sh uses only the URLs/versions/hashes/
signatures in that lock; it does not refresh databases or substitute versions.
Unavailable/deleted packages or mismatched hashes/signatures fail explicitly.
Retain downloads/rootfs for future offline rebuilds if upstream prunes packages.

The resolver snapshots Omarchy's official edge aarch64 repository and official
ARM mirror. Those are moving repositories; resolution is a deliberate update
operation. Database digests are recorded, but databases are not authenticated
because these endpoints may not publish database signatures. Every package
archive must carry a verifiable PGP signature, checked against the separately
pinned official public keyrings before extraction. Public keyring source
revisions, blob hashes, fingerprints and limits are recorded alongside them.
This authenticates against those upstream trust roots, not an independent
personal certification of the maintainers.

Package installation uses host pacman in database-only mode after extraction.
Foreign install hooks and ldconfig are not executed. Owner IDs, archive order,
file timestamps and installation-date metadata are normalized. Fixed versions
and package signatures alone do not demonstrate byte-identical rootfs output:
compare ROOTFS-SHA256SUMS from repeated clean builds before claiming that.

Produced files are artifacts/iomarchy-arm64-rootfs.tar.zst,
artifacts/rootfs-inputs.lock, artifacts/ROOTFS-MANIFEST.txt and
artifacts/ROOTFS-SHA256SUMS. The unpacked tree is build/rootfs/tree.
scripts/verify-rootfs.sh checks ELF architecture, dynamic loader, actual Omarchy
source/shell and archive integrity. These are static host checks.

## QEMU runtime scope

scripts/emulate-rootfs.sh selects the separate QEMU virt kernel and
/usr/local/sbin/iomarchy-qemu-init. The guest checks 4 KB pages, ARM64, real
Bash associative arrays, jq, real Omarchy command routing/help, explicit ARM
package composition, Tokyo Night palette parsing, Hyprland and Quickshell
dynamic loading. IOMARCHY_QEMU_USERSPACE_PASS means those checks completed.

A separate session probe starts seatd, a private D-Bus session and the real
Hyprland binary with an isolated compositor configuration. Both Lua and legacy
.conf configurations are supported by pinned Hyprland 0.56.2; this probe uses
.conf and avoids full upstream provisioning/autostart. Software-renderer
environment settings are an experimental diagnostic, not proof that software
rendering solves the iPad graphics gap.

A Wayland socket alone is insufficient: hyprctl must return a usable output.
The real upstream Quickshell shell is then launched. A surviving process for
ten seconds is recorded as process liveness; this does not verify rendering,
interaction, all service dependencies or desktop usability. Failures and
renderer logs remain visible and distinct from successful CLI checks.

No QEMU result validates the J96 kernel, panel, USB host input, touchscreen,
Wi-Fi, audio, storage, bootloaders or GPU. The full rootfs is not added to the
minimal firstboot initramfs: measure compressed and expanded size and account
for J96's 2 GB RAM before considering any RAM-only deployment. No device
interaction occurs in the builder or QEMU scripts.
