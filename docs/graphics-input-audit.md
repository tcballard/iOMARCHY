# J96 graphics and input feasibility

Audit date: 13 October 2026. **Experimental, hardware untested.**
This audit records source evidence and implements a separate diagnostic kernel.
Neither compilation nor QEMU userspace establishes that the loader, display,
USB transport or drivers work on the target iPad.

## Exact official sources inspected

| Source | Revision | Scope |
|---|---|---|
| Hoolock Linux | `6831bc701a6ce059e71e5aaa9488c9195bea6927` | Pinned J96/A8 DTs, simpledrm and Kconfig |
| Hoolock docs | `23ebe1fbc375599221553a7e1815e5de182a6b42` | A8 support matrix |
| Official Omarchy package recipes | `1cf4b3113947a62c90b80d343dd3455aefdf1478` | ARM64 Hyprland `0.56.2-5`, Aquamarine `0.15.1-1.1` |
| Hyprland `v0.56.2` | `efb50993780079460b0cbed1363e2166a2de1d9f` | Packaged upstream renderer requirements |
| Aquamarine `v0.15.1` | `f31c47a1b9d300847d8fc3108ad959448103dfc1` | Packaged upstream allocator/backend |
| Hyprland main | `6cc0822e24ad18df62689de80593541a61b49924` | Current renderer source cross-check |
| Aquamarine main | `52ea11f06dd492f34b3cc0b39a9c805beecafcff` | Current backend source cross-check |

The branch and tag revisions were retrieved through official GitHub APIs on
the audit date. Both packaged upstream versions and current main retain the
relevant EGL/GLES/GBM constraints. These are inspected source revisions:
recipe existence alone does not establish package availability or runtime.
The subsequent [cloud validation record](validation/2026-10-13/README.md)
records actual signed downloads and ARM64 execution of the selected packages.

## Device evidence and blockers

| Capability | Concrete evidence | Consequence |
|---|---|---|
| Display console | J96 includes `t7000-mini4.dtsi`; `t7000-handheld.dtsi` declares a disabled `simple-framebuffer` with zero address/size and loader-supplied format. Baseline enables `FB_SIMPLE`, disables DRM. | Loader-populated console is the first test. Baseline has no native DRM/KMS compositor path. |
| Modesetting/GPU | A8 matrix marks Display Pipe and GPU **TBA**. J96's include chain has no GPU node. | No established A8 acceleration, runtime modesetting or rotation. Enabling PowerVR Kconfig does not supply absent integration, device description or firmware support. |
| Possible software scanout | Pinned simpledrm matches `simple-framebuffer`, preserves display power domains and provides atomic/GEM/modeset features with shared-memory buffers. It does not advertise `DRIVER_RENDER`. | Separate simpledrm build is a useful KMS probe. No acceleration, dedicated render node or proven EGL/GBM compatibility follows from it. |
| Physical input | Mini4 DT defines Home, Power, Volume and Mute GPIO keys. No touchscreen controller appears in J96's include chain. | Evdev can expose buttons; it does not create touch, a pointer or a normal keyboard. |
| USB keyboard/mouse | Active USB node has `dr_mode = "peripheral"`; EHCI/OHCI host nodes are inside `#if 0`. | ACM is the selected peripheral route. A Lightning host adapter/keyboard must not be assumed to work. |
| Network/audio | No Wi-Fi, Bluetooth or audio nodes appear in the include chain; baseline disables NET/SOUND. | No wireless/audio claim. ACM serial is neither Ethernet nor an evdev keyboard. |
| Storage/userspace | Baseline disables BLOCK and loadable modules. | Keep RAM-only bring-up. A desktop root filesystem requires a separately designed kernel/userspace profile. |

Pinned source links:
[J96](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/arch/arm64/boot/dts/apple/t7000-j96.dts),
[mini4 input](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/arch/arm64/boot/dts/apple/t7000-mini4.dtsi),
[framebuffer](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/arch/arm64/boot/dts/apple/t7000-handheld.dtsi),
[USB/controllers](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/arch/arm64/boot/dts/apple/t7000.dtsi),
[A8 support](https://github.com/HoolockLinux/docs/blob/23ebe1fbc375599221553a7e1815e5de182a6b42/features/A8.md),
[simpledrm](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/drivers/gpu/drm/sysfb/simpledrm.c),
[Kconfig](https://github.com/HoolockLinux/linux/blob/6831bc701a6ce059e71e5aaa9488c9195bea6927/drivers/gpu/drm/sysfb/Kconfig).

## Why software rendering is unresolved

At both inspected Aquamarine versions, `CBackend::start` creates a primary
GBM allocator. `CGBMAllocator::create` requires PRIME export and successful
GBM device creation. Buffers are exported as DMA-BUF file descriptors. A
dumb-buffer allocator exists, but does not replace that primary allocator
requirement. The inspected explicit no-renderer exception is for evdi,
not a general simpledrm guarantee.

Hyprland creates an EGL device/GBM platform, requests GLES 3.2 then retries
3.0, and requires `GL_EXT_texture_format_BGRA8888`. Missing DMA-BUF import
extensions produce warnings, so inspection does not prove every software
path fails either. **Test the complete GBM allocation, EGL context, DMA-BUF
import and simpledrm scanout combination.**

The official Omarchy ARM64 Hyprland recipe backports software-renderer
classification from `GL_RENDERER` after making an EGL context current.
It recognizes llvmpipe, softpipe or Software Rasterizer. This helps identify
an already working software renderer; it does not initialize a missing
display/input driver or establish A8 performance. Pinned patch SHA-256:
`380bb6d61c36d6c68bcccf242131f5b259734e8570ea39b3bc519b9ed137eddd`.

Mesa rasterization addresses shader execution. It does not create a missing
DRM device, initialize J96 display hardware or add a touchscreen. Off-screen
EGL success is weaker evidence than actual native scanout. Emulator speed
does not predict frame time/memory use on A8.

Sources:
[packaged Hyprland renderer](https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/render/OpenGL.cpp),
[packaged Aquamarine backend](https://github.com/hyprwm/aquamarine/blob/f31c47a1b9d300847d8fc3108ad959448103dfc1/src/backend/Backend.cpp),
[packaged allocator](https://github.com/hyprwm/aquamarine/blob/f31c47a1b9d300847d8fc3108ad959448103dfc1/src/allocator/GBM.cpp),
[current DRM backend](https://github.com/hyprwm/aquamarine/blob/52ea11f06dd492f34b3cc0b39a9c805beecafcff/src/backend/drm/DRM.cpp),
[official backport](https://github.com/omacom/omarchy-pkgs/blob/1cf4b3113947a62c90b80d343dd3455aefdf1478/pkgbuilds/hyprland/software-renderer.patch),
[Mesa LLVMpipe](https://docs.mesa3d.org/drivers/llvmpipe.html).

## Observed virtual sessions

The separate [ARM64 VM test](validation/2026-10-13/README.md) reached an enabled
1024×768 Virtual-1 output in Hyprland's control response and an OpenGL ES 3.2
llvmpipe context. The real Omarchy QML shell loaded and created bar/background
layer surfaces. Aquamarine nevertheless logged repeated EGL device-matching
and renderer-state commit errors. Process liveness and the monitor response
therefore do not establish visible scanout, interaction or a working desktop.
This is the earlier packaged-library result; native simpledrm remains untested.

The later [staged RAM integration](validation/2026-10-13/ram-integration.md)
adds an isolated Aquamarine GBM fallback and fixes a cross-compiler C++ symbol
collision. At both 2048 and 1536 MiB, actual QEMU scanout shows a red Wayland
terminal, receives an injected key and changes to green. The real Omarchy bar,
wallpaper and pointer-opened menu also render, and Escape dismisses the menu.
These results establish virtual software rendering and input delivery at
1024×768 with both memory budgets, and at 2048×1536 with 2048 MiB. Both display
modes use compositor scale 1. The focused and independent clean runs pass
all three cases. Matching the panel's pixel count supplies no missing J96
driver and predicts neither native-panel memory use nor A8 speed. Exact
captures and limits are recorded in the integration evidence.

## Implemented optional kernel probe

Run `./scripts/build-graphics-probe.sh`. It verifies clean pinned Linux
sources and builds a separate `build/graphics-probe/linux` tree. Outputs
under `artifacts/graphics-probe/`: `Image`, `Image.gz`,
`t7000-j96.dtb`, `kernel.config`, `MANIFEST.txt`, `SHA256SUMS`.

The script checks the effective Kconfig: 4 KB pages, simpledrm/fbdev,
evdev/uinput, local UNIX sockets; 16/64 KB pages, simplefb, modules, block
devices, IP, wireless and audio remain disabled. `INPUT_MISC` enables the
enclosing uinput menu. UNIX sockets support Wayland/D-Bus IPC; no Ethernet
gadget or network interface is added. Disabled symbols can be absent from
Kconfig output when an enclosing menu is disabled; checks reject any
unexpected `y`/`m` state.

The baseline fragment, initial initramfs, original artifact paths and device
boot script are unchanged. This probe assembles no m1n1 image, runs no
compositor and accesses no iPad. It is a diagnostic kernel, not a desktop
image. Console behavior under simpledrm is hardware untested. Its successful
CI build and separate hashes are retained in the
[validation record](validation/2026-10-13/README.md).

## Validation and next local hardware actions

1. **First local action remains the baseline:** run `./scripts/start.sh --prepare`,
   then follow [first-boot.md](first-boot.md) and `./scripts/start.sh`. Establish
   identified J96 `/init`, two CPUs, display console and interactive ACM
   before another kernel. Keep private logs local; use the documented force
   restart to return to iPadOS.
2. `scripts/guest-hardware-report.sh` may be pasted into a temporary guest
   file and run with `sh`. It reads framebuffer geometry, DRM driver/
   connector state, input names/capabilities, interface/controller state
   and relevant kernel flags. It does not read raw dmesg/DT, input `uniq`,
   ECID, serial numbers or MAC addresses. Inspect additional logs before
   publishing them.
3. After baseline acceptance, explicitly integrate the separate simpledrm
   kernel/DTB with the pinned loader and RAM initramfs in a later local change.
   Record DRM card nodes, `modetest -M simpledrm -c -p` (when an ARM64
   libdrm utility is built), native geometry/format and console behavior.
   Expected absence of a render node does not alone decide GBM compatibility.
4. Probe GBM/PRIME, EGL/GLES/BGRA and a rendered buffer reaching the real
   connector. Only then attempt reduced-effects Hyprland, measure frame
   times/memory and establish usable pointer/keyboard input. Uinput permits
   an explicit synthetic input experiment; it does not solve tablet input.
5. User-mode ARM64 QEMU checks ABI/shared libraries/CLI behavior, without a
   guest DRM/kernel/session. System QEMU virt needs a separate GIC/PL011/
   virtio-capable kernel. It can test ARM64 init and a virtual graphics
   session, but cannot boot this Apple-specific configuration as an iPad or
   validate A8 display/USB/touch. Keep renderer/backend details with results.

[Official QEMU virt documentation](https://www.qemu.org/docs/master/system/arm/virt.html)
explicitly describes a board unrelated to real hardware and an explicitly
selected display device. No J96 hardware result was recorded in this work.
