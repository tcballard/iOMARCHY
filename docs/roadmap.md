# Roadmap to an Omarchy iPad

Success means an Omarchy desktop that can be operated on the iPad. A kernel
boot and a shell are prerequisites. Hardware support and ARM64 package
availability determine whether that end goal is achievable on J96.

| Milestone | Exit condition | Status |
|---|---|---|
| Host preparation | Pinned bundle built; offline configuration, userspace, image and identity checks pass | Passed on local Arch and Ubuntu CI; live transport untested |
| First native boot | Identified J96 reaches `/init`; display output and interactive USB shell recorded | Next; untested |
| Hardware bring-up | CPU, display, usable input and networking assessed; driver gaps documented | Pending |
| ARM64 userspace experiment | Pinned official source and signed packages build reproducibly; core commands run in a 4 KB ARM64 VM | Separate build and emulator validation in progress |
| ARM64 desktop base | Graphics/session and input work on the hardware within its memory budget | Pending |
| Omarchy integration | Hyprland, Omarchy configuration, tools and applications run; ARM64 substitutions are explicit | Pending |
| Tablet usability | Evaluate touch/keyboard interaction, scaling, rotation, power and recovery | Pending |

For the first boot, retain logs of `uname -a`, `dmesg`, `/proc/cmdline`,
`/proc/cpuinfo`, `/proc/meminfo` and the USB controller state. Record observed
results separately from expectations in [hardware-boot.md](hardware-boot.md).
The transport's private logs include device identifiers; redact them before
adding evidence to the public repository.

After boot works, establish whether the available graphics path can support
a usable compositor and what input/network paths are actually available.
The [official ARM64 audit](arm64-audit.md) establishes package availability
for the experimental subset. Omarchy's generic Apple detection selects an
Asahi Mac setup for this old iPad, so no upstream hardware installer is run.
The composition target is explicitly `aarch64`; omissions are recorded in
[arm64-rootfs.md](arm64-rootfs.md).
Do not mark the Omarchy milestone complete based on a framebuffer console,
USB shell or emulation result.

Storage installation is outside the current phase. The current experiment
runs from RAM and does not need internal storage, wireless or touchscreen.

## Next local hardware tests

1. On the local x86_64 Linux host, run `scripts/check-host.sh --device --artifacts`
   and `scripts/boot.sh --check` using the verified minimal bundle. Keep the
   artifact manifest and original private logs.
2. Follow [first-boot.md](first-boot.md) for one temporary `scripts/boot.sh`
   attempt. Record separately whether DFU identity, Pongo, m1n1, the framebuffer,
   `/init`, USB ACM and an interactive shell were actually observed. Stop at
   the first failing stage and diagnose its evidence before changing inputs.
3. After a shell works, record page size, both CPUs, available RAM, USB device
   controller binding, framebuffer characteristics and available input devices.
   The read-only `scripts/guest-hardware-report.sh` can be pasted into the guest;
   it is not added to the baseline initramfs. Review output before publishing.
4. Only after preserving a successful baseline, consider a separate graphics
   probe to inspect DRM/KMS output. The simpledrm build is not assembled into
   the normal boot bundle. It provides no GPU acceleration or touchscreen driver.
5. Establish a usable keyboard/touch route and compositor-compatible rendering
   before attempting desktop integration. The active Lightning path is USB
   peripheral mode; USB host input and touch are not established by the J96 tree.

The first experimental desktop archive occupies roughly 2.3 GB unpacked, above
the mini 4's 2 GB physical RAM even before kernel/runtime memory. It is a QEMU
disk filesystem, not an iPad initramfs. A smaller RAM deployment or another
explicitly approved storage strategy remains future work. No storage writes
or full desktop hardware boot are part of the current test plan.
