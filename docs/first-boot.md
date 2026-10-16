# iPad mini 4: first native Linux boot

Target: **iPad mini 4 Wi-Fi / iPad5,1 / J96 / A1538 / Apple A8 T7000**.
The device boot host requires x86_64 Linux; Arch and Ubuntu build dependency
instructions are available. This is a temporary, RAM-only boot experiment; the pinned bootloaders
follow Hoolock's documented iOS 15 PongoOS route. Hardware compatibility has
not yet been demonstrated by this project.

The boot bundle contains a locally built 4 KB-page ARM64 kernel, J96 DTB,
static ARM64 BusyBox, executable initramfs, and locally built pongoterm.
m1n1, PongoOS and palera1n are pinned upstream binaries. **Physical DFU and
checkm8 completion were observed. Both the pinned Hoolock PongoOS and
palera1n's own embedded PongoOS returned the iPad to recovery, with no
PongoOS USB device. No Linux boot has been demonstrated.** See the
[hardware record](hardware-boot.md). Host checks and QEMU user-mode checks
cannot establish hardware support.

## Run once the iPad is connected

On the XPS, run from this branch's repository root:

```bash
./scripts/start.sh
```

These changes are on `dev/arm64-userspace` in draft PR #2. `main` is unchanged.
For a fresh checkout, run:

```bash
git clone --branch dev/arm64-userspace https://github.com/tcballard/iOMARCHY.git
cd iOMARCHY
./scripts/start.sh --prepare
```

Once preparation completes, connect the iPad and run `./scripts/start.sh`.

The launcher installs missing runtime tools on Arch/Omarchy or Ubuntu/Debian,
downloads the checksum-pinned verified bundle, and starts the guided boot.
It needs no compiler, kernel source checkout or ARM emulator. Subsequent
launches reuse the verified cache and skip package setup when tools exist.
Differing previous local binaries are backed up under `build/previous-artifacts-*`.
The pinned downloadable bundle expires on 12 November 2026; the verified local
ZIP remains usable afterwards. Unavailable or mismatched downloads stop the
launcher rather than selecting another version.

Use `./scripts/start.sh --prepare` to install tools and fetch the bundle without
accessing the iPad. `./scripts/start.sh --check` additionally checks the host
USB serial driver and root namespace support without identifying or booting
the device. Builders can still use `./scripts/boot.sh` with their own artifacts.

Run in a real terminal. The script requests sudo for USB access, checks every
artifact hash, identifies the iPad, guides DFU, boots PongoOS, uploads Linux,
and opens the verified USB serial port in picocom, sending Enter automatically
to start the shell. It records the attempt
under `logs/boot-*/`, including Pongo output, serial output, ECID and the exact
per-attempt image hash. Logs are created with private permissions. ECIDs and
device logs stay local. The launcher waits up to 60 seconds for connection
and, in normal iPadOS, up to 45 seconds for unlocking and Trust.

Fresh Ubuntu 24.04 and Arch Linux CI environments have both completed
`--prepare` twice, including dependency installation, all eleven binary hash
checks and cached reuse. Malformed/overflowing USB identity fields and a
corrupted download are rejected in offline fixtures. These tests do not
exercise the XPS USB controller, real DFU timing or device reconnection.

- Use a **USB-A to Lightning data cable**. A USB-C to USB-A adapter can be
  used on hosts with USB-C ports. USB-C to Lightning cables can prevent DFU entry.
- Disconnect other Apple USB devices; keep the iPad on the same physical
  USB port throughout the attempt. Close other tools controlling this iPad.
- Starting in normal iPadOS requires unlocking and trusting this computer
  so `ideviceinfo` can read ProductType, HardwareModel and ECID. Starting in
  recovery or DFU uses USB descriptors instead; pairing is then unnecessary.
- Manual DFU guidance: hold Top/Power and Home together for 8 seconds,
  release Top/Power and continue holding Home until DFU is detected. The
  script times these steps. A black screen is expected. An Apple logo or
  cable/computer graphic means retry; the latter is recovery, not DFU.
- Required DFU identity: VID:PID **05ac:1227**, CPID **7000**, BDID **08**,
  and a nonzero ECID. Normal-mode ECID must survive the transition unchanged.
- PongoOS uses **05ac:4141** and exposes CPID/BDID/ECID. The script checks
  these again. The Linux gadget uses **05ac:4142** and a random per-attempt
  serial string, checked before opening its `/dev/ttyACM*` port.

The script exposes only the selected device's validated USB nodes to
palera1n inside a private `/dev/bus/usb`. It stops on additional Apple devices,
a changed port or identity, or a timeout. The patched pongoterm independently
checks bus/address and the full Pongo serial before uploading and never
reattaches after disconnect. These safeguards have been inspected and their
parsing/namespace components checked. The physical session verified DFU
identity and checkm8 completion but stopped during PongoOS startup; see the
[hardware record](hardware-boot.md).
Follow-up syscall tracing confirmed that the replacement USB open preceded
publication of its validated node. An optional host publication gate has
passed isolated fixture tests and two successive physical USB reopens in
one attempt. Its build and diagnostic commands are in the hardware
record; it is not enabled by the default launcher. `start.sh --trace-usb`
adds private path-open traces when strace is installed.
If identity cannot be read, fix the cable/trust/USB mode and rerun; it does not
guess or fall back to another device.

Only verified DFU and Pongo USB nodes are admitted while palera1n runs.
Recovery is accepted for initial identification and manual DFU guidance,
but is not exposed to palera1n's recovery helper, which can set auto-boot.

## Expected first hardware result

PongoOS and m1n1 output should appear, followed by Linux messages on the iPad
framebuffer. Successful userspace startup prints:

```text
J96 FIRSTBOOT: native Linux RAM root started
J96 FIRSTBOOT: USB ACM ready; open host terminal and press Enter.
```

Press Enter in picocom for `J96 native Linux — RAM-only root shell` and the
`j96-linux#` prompt. Try `uname -a`, `dmesg | tail -80`, `cat /proc/cmdline`
and `cat /proc/meminfo`. The kernel identifies as `7.3.0-rc1-j96-firstboot+`.
The shell is root without a password on this local USB link.
The root filesystem and any changes exist only in RAM.

The display console is `tty0`; J96's DT selects `serial0`, which Linux's
Samsung/Apple UART driver calls `ttySAC0`. This hardware UART is **not** the
Lightning USB serial port. The userspace ACM shell uses `ttyGS0` on the iPad
and normally `ttyACM0` on the host, but the script discovers its actual name.
Kernel messages are available with `dmesg` after the USB shell appears.

To return to iPadOS, exit picocom with **Ctrl-A, then Ctrl-X**, then hold
**Home + Top/Power until the Apple logo appears** and release both. You can
also try `reboot -f` from Linux. If Linux or USB is stuck, use the physical
force restart. A disconnected/restarted iPad normally boots iPadOS; Linux is
not persistent. This workflow contains no erase, restore, partitioning,
firmware update, or internal-storage installation commands.

## Rebuild and check

From the repository root:

```bash
./scripts/check-host.sh               # build tools only; no device access
./scripts/fetch.sh                    # fetch missing pinned inputs
./scripts/rebuild.sh                  # build, assemble and verify
./scripts/boot.sh --check              # check final artifacts; no device access
```

Default build parallelism is four jobs; override with `JOBS=2` on a busy host.
`config/sources.lock` records exact revisions; `config/kernel.fragment` and
`config/busybox.config` are build inputs. `artifacts/kernel.config` records
the full effective configuration. `MANIFEST.txt` contains revisions,
toolchains, input hashes, artifact hashes and verification output.
`artifacts/SHA256SUMS` is used by the boot script. Logs are in `logs/`.
All baseline offline checks passed on Ubuntu 24.04 CI. Two builds with fresh
BusyBox outputs matched all eleven artifact hashes. See the
[13 October record](validation/2026-10-13/README.md) for the exact run,
downloadable bundle, and the historical BusyBox timestamp discrepancy.
Cross-toolchain binary identity and independent reproduction of upstream
prebuilt loaders are not established.

Install the host dependencies on an Arch-based distribution with:

```bash
sudo pacman -S --needed base-devel git clang llvm lld aarch64-linux-gnu-gcc \
  bc flex bison dtc cpio gzip unzip libusb libimobiledevice usbmuxd \
  shellcheck picocom qemu-user-static bubblewrap gnupg
```

Ubuntu build instructions and the distinction between build tools and device
host readiness are in [cloud-build.md](cloud-build.md). Before a local attempt,
`sudo ./scripts/check-host.sh --device --artifacts` additionally checks USB tooling,
host serial support and namespace isolation. No cloud build performs this
device interaction.

The build workflow has no Python application or Python dependencies. It uses
prebuilt m1n1 and does not require a local Rust toolchain.

## Selected inputs and provenance

| Component | Pin / decision |
|---|---|
| Hoolock kernel | `hoolock`, `6831bc701a6ce059e71e5aaa9488c9195bea6927` |
| m1n1 | `idevice`, `d5a10ac52a6468484854419a6c5130f1d62073eb`; CI run `33380676898`, artifact `9753630137` |
| Hoolock docs | `23ebe1fbc375599221553a7e1815e5de182a6b42` |
| PongoOS | Hoolock docs' supplied `Pongo.bin`, embedded version `2.6.3-bb492b00`; corresponding source `bb492b004265ce91123caa23b8bc04b2eff6d2b7` |
| palera1n | stable `v2.4`, `3ba32c40dbd90b9bcff1a71b5f9ee26c3388b0ad`, official Linux x86_64 release binary |
| BusyBox | `1.37.0` official source tarball; built static with the recorded ARM64 GCC/glibc toolchain |
| HoolockRD reference | `2dce746e1165ad81b23e354773c19795dbd6b328`; used to check USB gadget/console conventions |

The current PongoOS `iOS15` tip was `cc532fac72e97f7c7f50f891073fde12f519f0a1`,
and master `4c9b7541629234147fcc778f0ce4162482aaccef`. The selected binary is
Hoolock's documented example, whose embedded revision includes the m1n1
load-address fix. Its complete binary-to-source reproducibility was not
independently established. The matching source is retained for pongoterm.

The latest palera1n prerelease was `v3.0.0-beta.2`. Stable v2.4 was selected
because its actual help and source confirm the documented `-l -p -k` path.
`-p` exits at the Pongo shell before the jailbreak payload/commands; the
script never uses `-P`, fakefs options, jailbreak installation or restore.
It sets the documented `PALERA1N_BYPASS_PASSCODE_CHECK=1` for this Pongo-only
route. No full iPadOS jailbreak or passcode removal is required by this path.

The docs' `git checkout -b iOS15` creates a local branch and is not a valid
way to select a remote revision; the pins above replace it. The example
`cd iOS15` is also stale. macOS `sysctl` build commands were not copied onto
Linux. A dedicated minimal kernel configuration replaces the broad example
16 KB config; **4 KB is enabled and 16/64 KB are disabled**. All first-boot
drivers are built in; loadable modules and block-device support are disabled.

The upstream m1n1 AGENTS.md prohibits AI work in its source repository.
Its existing upstream CI binary was used without source changes or a local
m1n1 build, as permitted by this task. The cached ZIP is essential: GitHub
currently gives it an expiry of **29 November 2026**. Retain `downloads/`
for offline rebuilds after that date.

The m1n1 ZIP and palera1n binary match GitHub's published SHA-256 digests.
BusyBox matches its upstream SHA-256 and has a verified detached signature
from fingerprint `C9E9416F76E610DBD09D040F47B70C55ACC9965B`; the key was
retrieved from `https://busybox.net/~vda/vda_pubkey.gpg` and pinned locally.
This checks the signature using the key from the upstream HTTPS site, not
an independently established personal trust chain. No upstream signatures
were supplied with the selected m1n1/Pongo/palera1n payloads. The Hoolock
kernel commit is unsigned; hashes are provenance/integrity checks.

## Hardware checks still required

The loader must populate RAM, framebuffer address/format, CPU release
addresses and USB PHY tunables in the J96 DTB. These placeholder properties
are expected before boot and cannot be validated against this iPad while it
is disconnected. Verify checkm8 reliability, Pongo→m1n1→Linux handoff, display
output, both CPUs, USB device-controller binding and an interactive shell.
A8 can leave palera1n waiting even after Pongo is visible; the script checks
for the verified Pongo USB device and stops the waiting host process.

No Apple firmware was downloaded. The selected simple framebuffer and USB
path do not load external firmware files; the device's existing boot chain
and loader-provided configuration are still prerequisites. If later hardware
enablement requires extracted firmware, keep it under ignored `firmware/`
or `downloads/`, document Apple's official IPSW URL and extraction tool,
and never commit it.

Internal storage is not used. Wi-Fi, touchscreen, audio, GPU acceleration
and a full Omarchy desktop are deferred. A successful minimal boot will
establish a starting point, not readiness for a daily-use tablet.

References read during preparation:
[Hoolock setup](https://github.com/HoolockLinux/docs/blob/23ebe1fbc375599221553a7e1815e5de182a6b42/tutorials/SETUP.md),
[Pongo route](https://github.com/HoolockLinux/docs/blob/23ebe1fbc375599221553a7e1815e5de182a6b42/tutorials/SETUP_pongoOS.md),
[A8 support](https://github.com/HoolockLinux/docs/blob/23ebe1fbc375599221553a7e1815e5de182a6b42/features/A8.md),
[mainline J96 tree](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/apple/t7000-j96.dts),
[palera1n v2.4](https://github.com/palera1n/palera1n/releases/tag/v2.4),
[DFU steps](https://theapplewiki.com/wiki/DFU_Mode).
