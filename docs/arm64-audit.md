# Official Omarchy ARM64 compatibility audit

Audit date: **13 October 2026**. This records inspected sources, package recipes and public verification keys. The subsequent [cloud validation record](validation/2026-10-13/README.md) establishes signed package downloads, repeat filesystem builds and core ARM64 runtime checks. Neither result establishes an iPad boot or a working desktop session.

## Exact revisions

| Source | Revision inspected | Finding |
|---|---|---|
| iOMARCHY main | `9cd661f90edb5fa3d1b45512623522a5d3b14024` | Minimal J96 bundle and historical offline evidence; no hardware boot |
| [Official Omarchy](https://github.com/omacom/omarchy/tree/47caa9be439e1876b6048a32a868688e9c697d48), quattro | `47caa9be439e1876b6048a32a868688e9c697d48` | Current default branch; source version `4.0.0.alpha` |
| [Official package recipes](https://github.com/omacom/omarchy-pkgs/tree/1cf4b3113947a62c90b80d343dd3455aefdf1478), master | `1cf4b3113947a62c90b80d343dd3455aefdf1478` | ARM64 Hyprland, Aquamarine, Quickshell and Omarchy packaging |
| [Arch Linux ARM public keyring](https://github.com/archlinuxarm/archlinuxarm-keyring/tree/91e6b11698f8df66042d56aaa56fbe9c9263847d) | `91e6b11698f8df66042d56aaa56fbe9c9263847d` | Pinned public package-verification keys |
| [Hyprland v0.56.2](https://github.com/hyprwm/Hyprland/tree/efb50993780079460b0cbed1363e2166a2de1d9f) | `efb50993780079460b0cbed1363e2166a2de1d9f` | Tag resolves to this commit; supports Lua and legacy config managers |

Omarchy's old master branch redirects to quattro. Moving names were resolved before reading individual files. The package source and current Omarchy source differ: inspected `omarchy-dev` declares `4.0.0.r6942.gf5006bd-1` and pins source commit `f5006bd41a1755d46e0a4f2c0c4c54fca703cd9b`. Installing that package would not prove installation of source `47caa9b...`.

These userspace pins supplement the existing first-boot lock. They do not replace the pinned kernel, m1n1, PongoOS, palera1n or BusyBox baseline.

## Upstream ARM64 support and the J96 family gap

Official AGENTS.md, package composition and pacman templates explicitly distinguish `x86`, `aarch64` and `aarch64-apple`. ARM64 support is present upstream.

At the inspected source revision, stripping comments/blank lines and composing the package manifests gives:

| Set | Package count | Composition |
|---|---:|---|
| Base/x86 defaults | 161 | `install/omarchy-base.packages` |
| Generic ARM64 defaults | 161 | Base minus gliff, plus zram-generator |
| Apple Silicon Mac defaults | 168 | Generic ARM64 plus seven Mac packages |

The Mac additions are `omarchy-mac`, `omarchy-mac-boot`, `asahi-bless`, `avd-fw`, `libva-v4l2_request-avd`, `widevine` and `wf-recorder`. They belong to the M-series Mac boot, graphics and runtime stack. They do not establish A8 support. J96's checkm8 → PongoOS → Hoolock m1n1 → Linux route must not receive Mac boot packages, an Asahi kernel or Mac firmware as silent substitutions.

A concrete identification blocker exists in [omarchy-hw-platform](https://github.com/omacom/omarchy/blob/47caa9be439e1876b6048a32a868688e9c697d48/bin/omarchy-hw-platform): **every ARM device-tree token beginning apple, selects aarch64-apple**. J96 has Apple compatible strings, so the live detector would classify it as an Apple Silicon Mac. A build manifest `platform=aarch64` describes off-device construction only; once systemd is booted the detector intentionally reads live hardware.

This selects the Mac repository template and required lifecycle entrypoints from `omarchy-mac-boot`. Without that package required operations fail; installing it exposes incompatible boot-chain assumptions. Future J96 integration needs a distinct iDevice family/dispatch contract or an upstream distinction between Macs and iDevices. An experimental RAM root must not run Mac lifecycle setup or storage installation.

DMI matching is also unsuitable for J96 board identification: omarchy-hw-match reads only `/sys/class/dmi/id/product_name` and product_family. This limits hardware-specific install leaves, not ARM-independent shell functionality.

## Package repositories and reproducibility

The inspected [generic ARM pacman template](https://github.com/omacom/omarchy/blob/47caa9be439e1876b6048a32a868688e9c697d48/default/pacman/aarch64/pacman-edge.conf) uses:

- Omarchy: `https://pkgs.omarchy.org/edge/$arch`.
- Arch Linux ARM core, extra, alarm and aur: `https://arm-mirror.omarchy.org/$arch/$repo`.
- Required package signatures, optional database signatures.
- **Edge only** for ARM templates; stable/rc are not supplied by these sources.

The Mac template adds asahi-alarm and is unsuitable for this target.

The initial source audit could not read these package endpoints. Subsequent Ubuntu CI resolved the selected package subset, downloaded and signature-verified its 362-package dependency closure, and built it twice with matching archive hashes. [config/rootfs-inputs.lock](../config/rootfs-inputs.lock) freezes database hashes, package URLs/versions/architectures, SHA-256 values and signatures; the CI artifact retains the exact downloads. This verifies that selected closure, not every package listed in upstream recipes. A source commit or rolling latest rootfs URL alone is insufficient.

The inspected gliff recipe declares both x86_64 and aarch64, while the source default manifest still excludes gliff on ARM. Do not remove the exclusion based only on a recipe declaration; confirm publication and graphics requirements.

Public Omarchy and ALARM keys are retained with immutable provenance and checksums in [config/rootfs-keyrings](../config/rootfs-keyrings/README.md). Package signatures remain mandatory. Both upstream .gpg files are armored; the builder dearmors them into a fresh binary verification ring for gpgv. Supplying pinned official keys establishes the explicit trust roots; gpgv alone does not evaluate their master-key certification web of trust.

## Desktop stack

| Component | Official recipe at the package pin | Requirement |
|---|---|---|
| Hyprland | `0.56.2-5`, aarch64 | EGL/GLES, Mesa/GBM, DRM, Aquamarine, libinput, Wayland and matching Hypr libraries |
| Aquamarine | `0.15.1-1.1`, aarch64 | DRM/GBM outputs, libseat, udev, libinput; its Mac connector-rescan patch adds no J96 support |
| Quickshell | `0.3.2-4`, x86_64/aarch64 | Qt6 Quick/Wayland, Mesa, libdrm, PipeWire, PAM and polkit |

The Hyprland source archive checksum is `03ad3f5ef152ff44116ffd56fcf808486211ecabf4f0ba567108ee746ba5cd2e`. Its software-renderer patch checksum is `380bb6d61c36d6c68bcccf242131f5b259734e8570ea39b3bc519b9ed137eddd`, a backport of [Hyprland #16343](https://github.com/hyprwm/Hyprland/pull/16343), commits `61d0ff60a7547d49229714a68b7ca9c0b6658727` and `c3dcabc15ba7b71bd1bcd880e9f543909dd9372d`. It recognizes llvmpipe/softpipe from GL_RENDERER instead of a DRM driver name. This helps identify an existing software renderer; **it does not supply DRM/KMS scanout, GBM buffer support, input drivers or acceptable A8 performance**.

Aquamarine's source checksum is `2f9de98c0bd1b7b1b09c576e390a2fef436449762fb334163c414f0c300296f2`; its carried CRTC-rescan patch checksum is `50e9e38ff915b18074dc9b5dd1d07d7f24e340e99f254476d6abe578eece7864`.

Current Omarchy uses Lua Hyprland configuration: `config/hypr/hyprland.lua` loads default.hypr.omarchy through the official bootstrap and starts the QML shell. Hyprland v0.56.2 supports both .lua and legacy .conf in src/config/ConfigManager.cpp. A minimal classic-config compositor probe is therefore valid, but it does not load or validate the genuine Quattro configuration. An older distribution compositor or generic themed desktop cannot establish current Omarchy integration.

Official autostart imports systemd/dbus environment, starts omarchy-launch-shell, provisioning, power-profile initialization, a monitor watcher, udiskie and post-boot hooks. These require session services and a complete userspace. The desktop shell source lives at `/usr/share/omarchy/shell` inside omarchy/omarchy-dev; there is no separate omarchy-shell package.

The preserved first-boot kernel intentionally excludes modules and block devices. A desktop experiment needs a separate effective configuration and graphics/input/IPC evidence, not a silent replacement of that baseline. See the project's graphics audit for the native output feasibility gates.

## Genuine functionality before a graphical desktop

A 34-file unmodified source subset was retrieved into ignored src/omarchy from the exact official commit. [config/omarchy-source.files](../config/omarchy-source.files) records every Git blob identifier; all materialized files matched git hash-object during the local inspection.

| Functionality | Actual upstream files | Runtime boundary |
|---|---|---|
| CLI routing/discovery | bin/omarchy | Bash 5, dirname/readlink/sort/cut; jq for JSON |
| Presence/architecture checks | cmd-present, cmd-missing, hw-aarch64 | Bash; uname for architecture |
| Semantic palettes/terminal colors | theme-color, theme-dir, theme-osc | Bash arrays/process substitution, awk/dirname/sort and working /dev/fd |
| Default ARM package enumeration | pkg-defaults and original manifests | Bash, sed/awk and process substitution; does not install packages |
| Shell behavior/completion | Original default/bash files and default/bashrc | Bash/readline; optional tools and function bodies have additional dependencies |
| Tokyo Night palette | Original colors.toml | Exercises real palette code; not a desktop result |

BusyBox ash cannot run the original Bash scripts unchanged. Changing their shebangs or naming ash bash would invalidate the integration. GNU find -printf and GNU sed capitalization are needed by the original theme-list/theme-current paths; those were not included merely to inflate the feature count. A real Arch root can provide their GNU dependencies.

Unchanged dispatcher help still advertises upstream groups outside a small subset. Its installed command list, explicit prototype status and test results must define what works. Browser/editor defaults and optional aliases can point to missing applications until their actual packages are installed.

The separate filesystem now includes the full pinned source/configuration and selected signed ARM packages. Core CLI and dynamic-library checks pass in a full-system ARM64 VM. Desktop progress still needs the upstream Quickshell shell running with a matching Hyprland session, working output/input and useful applications, with each omission documented.

## Concrete remaining blockers

1. **Boot/storage mismatch:** Omarchy's provisioning, installer, factory reset and boot management assume persistent Linux storage. The current target is temporary RAM-only. Do not invoke apply-system, firmware updates, factory reset or internal-storage installation.
2. **Mac classification:** Live A8 detection selects Mac lifecycle code. Generic package roots do not correct it.
3. **Graphics:** No documented target GPU acceleration or established native Hyprland output path. Software-renderer classification alone is insufficient.
4. **Input/network/audio:** Touchscreen, Wi-Fi and audio are unestablished. Installing libinput, NetworkManager or PipeWire proves no hardware device works.
5. **Applications:** Chromium, LibreOffice, Pinta, Moonlight, Obsidian, Omarchy apps and development tools need a complete signed ARM package closure and runtime checks. Video/background/recording/dictation requirements remain distinct.
6. **Intentionally x86-only features:** Windows VM explicitly requires an x86_64 KVM host. Multilib GPU packages and x86 proprietary programs are not native A8 features.
7. **Resources:** Measure rootfs RAM, compositor/Qt/browser memory and full-resolution rendering latency after boot. Source inspection supplies no usability/performance conclusion.

## Evidence and next hardware action

**Inspected:** exact upstream sources, package manifests, pacman templates, recipes, public verification keys and unchanged CLI blob identities.

**Separate runtime evidence:** the [cloud validation record](validation/2026-10-13/README.md) reports successful package verification, reproducible filesystem builds and core userspace startup in QEMU. J96 DRM/input/display support, native compositor performance, networking/audio and a usable Omarchy desktop remain unproven.

The next hardware action remains the preserved minimal first-boot bundle: obtain the USB shell and record its first hardware result. Inspect /dev/dri, framebuffer and input devices, then decide whether a separate RAM-only graphics probe has the required native output/input path. Keep private identifiers, firmware and raw device logs out of public records.
