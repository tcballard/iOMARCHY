# Roadmap to an Omarchy iPad

Success means an Omarchy desktop that can be operated on the iPad. A kernel
boot and a shell are prerequisites. Hardware support and ARM64 package
availability determine whether that end goal is achievable on J96.

| Milestone | Exit condition | Status |
|---|---|---|
| Host preparation | Pinned bundle built; configuration, userspace, image and transport checks pass | Complete |
| First native boot | Identified J96 reaches `/init`; display output and interactive USB shell recorded | Next; untested |
| Hardware bring-up | CPU, display, usable input and networking assessed; driver gaps documented | Pending |
| ARM64 desktop base | Suitable ARM64 userspace boots; graphics/session and input work on the hardware | Pending |
| Omarchy integration | Hyprland, Omarchy configuration, tools and applications run; ARM64 substitutions are explicit | Pending |
| Tablet usability | Evaluate touch/keyboard interaction, scaling, rotation, power and recovery | Pending |

For the first boot, retain logs of `uname -a`, `dmesg`, `/proc/cmdline`,
`/proc/cpuinfo`, `/proc/meminfo` and the USB controller state. Record observed
results separately from expectations in [hardware-boot.md](hardware-boot.md).
The transport's private logs include device identifiers; redact them before
adding evidence to the public repository.

After boot works, establish whether the available graphics path can support
a usable compositor and what input/network paths are actually available.
Check the ARM64 availability of Omarchy's dependencies before designing an
installer. Track any replacement packages and resulting feature differences.
Do not mark the Omarchy milestone complete based on a framebuffer console,
USB shell or emulation result.

Storage installation is outside the current phase. The current experiment
runs from RAM and does not need internal storage, wireless or touchscreen.
