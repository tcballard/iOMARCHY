# First J96 hardware boot record

**Status: attempt 10 on 15 October 2026 proves execution of Pongo’s early
iBoot interposer, followed by iBoot recovery.** Full PongoOS shell/USB
enumeration, m1n1, Linux kernel and USB serial shell have not been observed.
Host preparation, emulator results and physical observations are separate.

Target: iPad mini 4 Wi-Fi, iPad5,1, J96, A1538, Apple A8/T7000,
MK9N2LL/A; reported iPadOS 15.8.3. Capacity was not verified in this session.

## Host preparation and exact inputs

Host: Dell XPS 9320, Omarchy, x86_64, `Linux 7.2.8-5-omarchy-bore`.
The user confirmed a USB-C-to-Lightning cable; no USB-A-to-Lightning cable
was available. The selected physical USB port stayed unchanged.

The clean checkout at `/home/tcballard/Projects/iOMARCHY` was switched to
`dev/arm64-userspace`. Fetch confirmed remote HEAD was still handoff commit
`610c92e877ecdd56194486098abc84e67fc3177f`, with no subsequent changes.
The older dirty checkout under `Documents/Codex/2026-10-13/new-chat-3/` was
left untouched. PR #2 was verified open and draft; it was not changed.

- `./scripts/start.sh --prepare` passed on this XPS. Runtime prerequisites
  were already installed. The launcher preserved differing older artifacts
  under `build/previous-artifacts-ALYo/`.
- The pinned ZIP SHA-256 was
  `12850d3902598e8b8eba0e39114774c661fe0d67e99d57e0709e4e3914af0029`.
  All eleven artifacts matched [the original baseline](validation/2026-10-13/baseline-SHA256SUMS).
  The installed `artifacts/SHA256SUMS` file itself hashed to
  `2bb5e586e4eac81eb1cd5179b66cecfb3b4682b6b41cac726d5f0c51cfb3a82f`.
- `./scripts/start.sh --check` passed after local sudo authentication in a
  real terminal. Host `cdc_acm` loading and root namespace creation passed.
  The original namespace check missed the device-open failure described below.
  An earlier noninteractive check stopped because sudo required a terminal;
  this was a host invocation issue, not a device failure.
- Attempts 1 and 2 used unmodified boot scripts at the handoff revision.
  `scripts/boot.sh` SHA-256:
  `dde1b722bf54513f3a9811891d9aeeaa26e51aa3030d4cd3a782e4cefb2ffdf7`.
  `scripts/start.sh` SHA-256:
  `647360b819d6e8439fac4113f59e41b0e0e6f06e579969a23ce44042f386d5d2`.
- The pinned prebuilt m1n1 binary was verified without modifying or building
  its source. No experimental kernel or desktop image was selected.
- The separate emulator runtime revision remains
  `619fefa4fc056dfe82d281f3436db941f3e26244`; its results are recorded in
  [ram-integration.md](validation/2026-10-13/ram-integration.md). They establish
  none of the native hardware stages below.

## Attempt 1: DFU timing

Exactly one Apple USB device was detected in normal mode, `05ac:12ab`.
The first lockdown query was denied. After unlocking and Trust, it reported
`iPad5,1`, `J96AP`, `MK9N2` and iPadOS `15.8.3`. The launcher's product, board
and ECID checks passed. Identifiers remain in private local logs.

The timed manual sequence did not produce `05ac:1227`. Host monitoring saw
disconnects and the original normal-mode device return. The launcher exited
1 with `DFU timeout`. palera1n was not launched; no later stage was reached.

The user reported possibly missing a timed button change and requested
another sequence with all steps explained in advance. Although USB-C cables
can cause DFU problems according to [upstream guidance](https://docs.palera.in/installing-palera1n/),
the successful second sequence establishes that this cable entered DFU in
this session. The first failure cannot be attributed to the cable.

## Attempt 2: verified DFU, blocked host USB access

After the complete button sequence was explained before starting the timer,
the original device entered `05ac:1227` at 21:55:37 BST. The launcher verified
CPID `7000`, BDID `08`, the original ECID and the same physical port. The user
confirmed a completely black screen. This establishes physical DFU, not a
booted Linux console.

The isolated pinned palera1n process remained at `Waiting for devices` until
the launcher's 180-second PongoOS timeout. No checkm8 execution or PongoOS
enumeration was observed in this attempt.

Read-only diagnosis reproduced the cause: `/tmp` is a `nodev` tmpfs on this
XPS. The private USB directory inherited that flag through bubblewrap's
`--dev-bind`. The correct root-owned, mode-0600 USB node existed inside the
namespace, but opening it returned `errno=13` / `LIBUSB_ERROR_ACCESS`.
Both isolated `lsusb` and pinned palera1n's `--device-info` failed to open it.
The missing usbmuxd socket warning was not the cause: it remained present in
the successful read-only query after the mount fix.

Focused fixes:

- `scripts/boot.sh` creates its private, mode-0700 USB staging directory on
  `/dev` instead of `/tmp`. Same port/model/chip/board/ECID validation,
  selected-node-only exposure, recovery exclusion and cleanup remain intact.
- `scripts/check-host.sh` now opens a harmless `/dev/null` clone inside the
  same USB mount arrangement. Previously, `/bin/true` only tested namespace
  creation and incorrectly passed this host. Full device namespace checks
  require root; `--tools-only` preparation remains unprivileged.
- The launcher prints the entire three-part DFU sequence before asking for
  Enter. Timings and identity checks are unchanged.

Validation: a harmless-node regression reproduced permission denial with
`/tmp` staging and success with `/dev` staging. The corrected read-only
palera1n query exited 0, reporting `Mode: DFU` and `iPad5,1`. The strengthened
`start.sh --check`, Bash syntax checks, `shellcheck -x`, and the existing
launcher identity/cache/corruption fixtures passed.

## Attempt 3: checkm8 starts, reconnection fails

Resumed from existing DFU after independently comparing its ECID with attempt
2. No new button sequence was needed. Tested code was handoff
`610c92e877ecdd56194486098abc84e67fc3177f` plus the focused fixes above:

| Changed script | SHA-256 used for attempt 3 |
|---|---|
| `scripts/boot.sh` | `135c4b32520289f203a27a86ee2a097d52e36a91e1f84c60837940ef184671a1` |
| `scripts/check-host.sh` | `bfcc75fc44c9826f01376db0a88be0a981b0d0e1be8243c351c2d4df7b26a10f` |

All eleven pinned artifacts remained unchanged and passed hash verification
again. The original baseline kernel, initramfs and prebuilt m1n1 were retained.

Observed sequence (BST):

- **22:02:30:** palera1n launched bundled checkra1n `0.1337.3`, found DFU,
  selected chip `7000` revision `11`, and reported entering initial checkm8
  state after one setup step. This is not evidence of a completed exploit.
- **22:02:31:** the device disconnected and re-enumerated on the same port
  in DFU with a new USB address. The kernel completed enumeration at
  `22:02:31.629`; the independent sysfs monitor saw the original CPID/BDID/ECID
  at `22:02:31.669`.
- checkra1n reported `Failed to open USB interface: (No such file or directory)`
  (`-status_usb_device_open_error`). At **22:02:40** it reported a timeout
  waiting for the exploit trigger stage (`-status_exploit_timeout_error`).
- The failed attempt was interrupted and its child processes/private USB
  staging directory cleaned up. It was not retried unchanged.

The new failure is USB reopening during checkm8 reconnection. The launcher
publishes replacement device nodes only after its polling loop validates
the new descriptor, while the loader can see host hotplug/sysfs enumeration
earlier. This makes an event-before-node race a concrete hypothesis. The
logs do **not** record the failed syscall pathname or precise node-publication
time, so they do not prove the complete root cause. Do not remove identity
checks, expose the host USB bus, or describe a shorter sleep as a verified fix.

| Hardware stage | Furthest observed result |
|---|---|
| Normal-mode identity | Passed; actual iPad5,1 / J96AP / MK9N2 / iPadOS 15.8.3. |
| DFU entry and identity | Passed; black screen, CPID 7000 / BDID 08 / original ECID. |
| checkm8 | Attempt 8 reported Checkmate and entered download mode after both validated reopens succeeded. |
| PongoOS startup / payload transfer | Not observed; no `05ac:4141`. |
| m1n1 handoff | Not reached. |
| Linux kernel / display console | Not reached. |
| `/init` / USB ACM / interactive shell | Not reached. |

No per-attempt combined image was assembled: assembly occurs only after
verified PongoOS enumeration. The baseline combined-image hash is in the
linked manifest, but no Linux image was transferred to this iPad. No native
DRM, desktop, touchscreen or other physical input evidence was collected.
No erase, restore, partitioning, installation, firmware update or persistent
boot-setting operation was invoked.

## Follow-up: measured reconnection race and optional gate

Follow-up work starts from local commit
`f52420cb03cb7085a7e72834c8607df497584a56`; remote remained at the handoff.
Baseline binaries and the pinned m1n1 payload remain unchanged. Diagnostic
code is local and has not changed draft PR #2.

Attempt 4 (22:11 BST) added path-open syscall tracing and timestamped mirror
publication events. Fresh DFU identity passed; the user reported a black
screen. The replacement USB open returned ENOENT at epoch
`1792012337.228407`. The mirror validated that same replacement address at
`1792012337.313882` and published its node at `1792012337.318178`, about
90 ms after the failed open. This confirms the ordering race suspected in
attempt 3. checkm8 again failed at the trigger; the run was stopped.

A host-only experimental FUSE gate now allows an early USB-address lookup
to wait up to two seconds for the launcher's validated node. It cannot
publish a device itself. The existing same-port/chip/board/ECID checks remain
the only publication path. Invalid devices, symlinks, writes and unexpected
USB major/minor numbers are rejected; metadata caches are disabled.

The optional helper lives in `tools/usb-node-gate.c`; experimental binaries
are separate under `artifacts/usb-node-gate/`. Build requires a C compiler,
pkg-config and libfuse3 development files. After ordinary preparation:

```bash
./scripts/build-usb-node-gate.sh
sudo ./scripts/test-usb-node-gate.sh
./scripts/boot.sh --usb-gate --trace-usb
```

Tracing additionally needs strace. The fixture passed actual device opens
inside the launcher's bubblewrap arrangement using harmless null clones,
delayed publication without retry, removal revocation, unpublished-address
timeout, forbidden node types/writes and production USB number validation.
These host tests are separate from attempt 8, which subsequently passed
both physical reconnections with the gate. The default launcher does not enable this experimental gate.

Attempt 5 (22:16 BST) tried the gate on the DFU state left by the failed
exploit, after comparing its identity. checkra1n stopped immediately with
`status_exploit_sanity_check_transfer_error` (device busy or crashed, 6e).
There was no reconnection, so this did not evaluate the gate's race fix.
The attempt was stopped and the user force-restarted into iPadOS.

Attempt 6 (22:18 BST) verified the original normal-mode identity but timed
out entering DFU; no exploit ran. Attempt 7 added visible countdowns and
phase bells with unchanged button timings. It also timed out before DFU;
the user saw a cable/laptop graphic and the host confirmed recovery mode
`05ac:1281`. No recovery device was exposed to the exploit. A physical
force restart returned the original device to iPadOS; a fresh lockdown
query verified its identity and unchanged version.

Exact follow-up inputs (SHA-256):

| Input | Hash |
|---|---|
| Attempt 4 boot.sh | `fe220e4462d5101b38e11fc4fadb64cd5fd95e8922844eec745db6c5098fbef1` |
| Attempts 5–6 boot.sh | `b4dcc6b9f1bf208323089f9b82af7f734efdaa0b23b78c028245da807e73697e` |
| Attempt 7 boot.sh | `e745a33655f393abe864b8b93ee816a8085d061a78ea1be21a5cdd920d7b2685` |
| Follow-up start.sh | `ef5afec8b22a53700d951e3a9f0be8a2f87884038d30fc9f9bf9a0d2c5121239` |
| Gate C source | `d6e157d8bf49acb1bf7c850f12616fb8317bf3f70564062495ff3ca187e4928f` |
| Gate binary | `864a413255f31f1dc31bc53a6b4d1f0cfbd21398f6815477ff58dc8e5ccac26c` |

Private follow-up evidence is in `logs/host-20261014-followup/` (terminal
transcripts/timing, exact input manifests, gate fixtures and identity
comparisons), plus each `logs/boot-20261014-*/` session directory. Attempt 4
is `221124-A5XK`, attempt 5 is `221645-7Zhs`, and attempt 6 is
`221845-8u6Q`; attempt 7 is `222236-M8Zq`. Syscall traces and mirror/gate events remain local.

## Attempt 8: reconnection fixed; PongoOS startup returns to recovery

The DFU guide was simplified to the manual two-phase sequence in
[iFixit's Home-button device guide](https://www.ifixit.com/News/41428/everything-you-need-to-know-about-dfu-mode-for-ios-devices):
Top + Home together for eight seconds, then Home alone until verified.
The initial three seconds now prepare the user without holding any buttons.
This sequence reached DFU. It does not establish the cause of earlier timing
failures or eliminate the upstream USB-C cable caveat.

Tested boot.sh SHA-256:
`755868c1dd19b3eac2038639f916573d860005feaad7801096c294361681c64c`.
Other inputs match the follow-up table. All eleven original artifacts passed
hash verification; the gate source and binary were unchanged.

Observed sequence (BST):

- **22:27:41:** same-device DFU verified and gate activated.
- **22:27:42:** checkm8 initial setup succeeded.
- **22:27:43:** the first replacement USB open waited approximately 163 ms
  for validated publication and succeeded. checkra1n printed `Checkmate!`.
- **22:27:44:** the download-mode replacement open waited approximately
  112 ms for validated publication and succeeded. The loader printed
  `Entered download mode` and `Booting PongoOS...`.
- The trace confirms checkra1n opened the pinned `artifacts/Pongo.bin`.
  It exited **0** at epoch `1792013264.746395`; its host parent also exited
  successfully. This establishes the host loader's result, not successful
  execution of PongoOS on the iPad.
- The launcher immediately stopped because it treated any loader exit
  before Pongo enumeration as a failure. All isolated staging/mounts were
  cleaned up; no m1n1/Linux image was assembled or sent.
- **22:27:50:** kernel USB logs recorded recovery `05ac:1281`, with no
  intervening `05ac:4141`. The user reported a reboot and confirmed the
  cable/laptop graphic. No Pongo text or display console was observed.

The gate has now resolved the measured host publication race in one physical
attempt, covering two successive address changes. It remains opt-in pending
further boot validation. No identifiers or host-wide USB access were added.

A focused post-attempt launcher fix now distinguishes successful child exit
from an error: status 0 continues waiting within the existing Pongo deadline,
while nonzero status stops. Identity validation continues during the wait.
This corrects premature host failure reporting; it has not been physically
retested and does not explain or fix the observed return to recovery.
Bash syntax and ShellCheck passed after the change. A host-only child-exit
fixture verified that status 0 continues waiting and status 7 stops. All
eleven baseline artifact hashes passed again.

The current failing stage is **PongoOS startup after checkm8/download mode**.
Host evidence does not establish whether the payload failed before entry,
during early initialization, or due to another device-side transition.
Do not infer a kernel/m1n1 fault or claim the host wait fix solves it. No
unchanged retry was queued.

Normal mode was verified again on 14 October 2026 before any further boot
work. The connected device was USB `05ac:12ab` on port 3-1, one Apple device,
reporting iPad5,1, J96AP, MK9N2, iPadOS 15.8.3, build 19H386, platform t7000.
UniqueChipID, SerialNumber and UniqueDeviceID matched
`logs/host-20261014/device-info.txt`. Those values stay in the private log.

Private attempt 8 evidence: `logs/boot-20261014-222657-r517/` contains
session, syscall, mirror and gate logs; `logs/host-20261014-followup/`
contains terminal/timing, exact inputs and the kernel USB timeline. Raw
logs are private and remain uncommitted.

## Pongo startup investigation

Attempt 8's private traces fix the order of the failure. checkra1n was
executed as `-Ep -k` with the pinned `artifacts/Pongo.bin`, opened that file,
printed `Booting PongoOS...`, and exited 0 at epoch `1792013264.746395`.
palera1n and the bubblewrap parent also exited 0. The download-mode USB
device disconnected at `1792013264.822237`, 76 ms later. The launcher polls
every 200 ms, so its cleanup could not have caused that disconnect. The
kernel next recorded recovery `05ac:1281` at 22:27:50, about six seconds
after the disconnect, with no `05ac:4141`. `Booting PongoOS...` is a loader
status line. It does not show that PongoOS reached its USB shell.

The session already contained checkra1n `<Verbose>` lines without a `-v`
flag. It did not contain `PongoOS image is dangerously close`, `Failed to
boot image`, or `Could not send all data`. Static disassembly of the
checkra1n 0.1337.3 binary embedded in pinned palera1n v2.4 shows that size
warning is taken only when the image length is at least `0x7c001`. The two
limits it logs are `0x7fe00` and `0x80000`. That is host static analysis,
not a measurement of the bytes the iPad executed.

The tested Hoolock image is `artifacts/Pongo.bin`, SHA-256
`1e5543fd8e6dbd84c334b87d71aa473f4d347c2ba8a5e863b6e10f18461c7575`,
238096 bytes (`0x3a210`), version `2.6.3-bb492b00`. Its entry copies up to
`0x3a210` and, when boot arguments are present, zeros up to `0x47844`.
The source pin `bb492b004265ce91123caa23b8bc04b2eff6d2b7` changes only the
m1n1 handoff used by the Pongo `bootm` command. That command runs after a
Pongo shell exists, so it cannot explain a missing `05ac:4141`.

palera1n without `-k` does not use checkra1n's internal Pongo. It writes
its own `Pongo_bin` to a temporary file and passes that to checkra1n. In
this palera1n binary that blob is the iOS 15 artifact, version
`2.6.3-e98323f8`, file offset `0x492180`, length `0x3a218`, SHA-256
`5475c5f701423858b34e92176c966a9d4b12950f38acb8d1c347f14d5b272655`. Its
entry copies up to `0x3a218` and zeros up to `0x47858`. checkra1n's
separate embedded image is `2.6.3-7ddd2752` and was not the file attempt 8
uploaded. Both candidate images end well below `0x7c001` and `0x80000`, so
the SRAM-size warning does not explain attempt 8.

`mtp-probe` opened the DFU nodes for USB devices 19, 20 and 21. On device
21 both probes had finished by 22:27:44.519, reported that it was not an
MTP device, and ended before the gated node was published at `.622` and
before checkra1n exited. The probe is not established as the reason the
iPad returned to recovery. It was still a second opener of the pwned DFU
node. `apple-mfi-fastcharge` matches DFU `1227` and recovery `1281`; its
probe does not send the vendor charge request. The `USBDEVFS_CONTROL`
lines during checkm8 name checkra1n and are part of the exploit. The module
was left loaded.

The uncommitted launcher can now block that probe for one session and can
boot palera1n's embedded image instead of repeating `artifacts/Pongo.bin`.
`scripts/boot.sh` SHA-256
`c8d13b1525ce67577c51c18434e595816a351ee6a97941fbd73cacbd1ca3405e` passed
`bash -n` and `shellcheck -x`. A `udevadm test` of the live normal-mode
`3-1` node, with no re-enumeration, showed `MTP_NO_PROBE=1` and did not
select `mtp-probe`. The temporary rule was removed. Those are host checks.
Attempt 9 ran that control:

```bash
sudo ./scripts/boot.sh --usb-gate --trace-usb --embedded-pongo
```

`-p` still returns before any jailbreak ramdisk. `-vv` adds checkra1n's
`v` because palera1n appends it when its own verbose level is at least 2.
Baseline `artifacts/Pongo.bin` stays the default and was not passed.
Its result is recorded below. Verified PongoOS enumeration remains the next
acceptance point. Linux, DRM and desktop integration have not been reached.

## Attempt 9: palera1n's own PongoOS also returns to recovery

The same iPad was verified in normal iPadOS immediately before this attempt.
The tested `scripts/boot.sh` SHA-256 was
`c8d13b1525ce67577c51c18434e595816a351ee6a97941fbd73cacbd1ca3405e`.
Gate source and binary hashes were unchanged. No jailbreak ramdisk was sent.

Observed sequence (BST):

- **23:05:40:** same-device DFU verified. The launcher installed the
  Apple-only `MTP_NO_PROBE` rule and activated the USB gate.
- **23:05:41:** checkm8 setup succeeded. The trace shows palera1n was started
  as `--cli -l -p -vv` with no `-k`, created `/tmp/Pongo.bin.mNNBPM`, and
  checkra1n ran as `-Epv -k /tmp/Pongo.bin.mNNBPM`. That is palera1n's
  embedded image, not `artifacts/Pongo.bin`.
- **23:05:42:** `Checkmate!`
- **23:05:43:** download mode, then `Booting PongoOS...`. checkra1n exited 0
  at epoch `1792015543.566402`. The download-mode device disconnected at
  `1792015543.637852`, 71 ms later. The launcher kept waiting after the
  successful exit.
- **23:05:49:** kernel USB logs recorded recovery `05ac:1281`. There was no
  `05ac:4141`. The launcher then stopped because recovery is not an accepted
  Pongo mode. Verbose checkra1n output still had no size warning, no
  `Failed to boot image`, and no `Could not send all data`.

The Hoolock image is not sufficient to explain the failure. Two different
Pongo payloads, both well under checkra1n's size warning, produced the same
host result: checkra1n exit 0, a disconnect about 70 ms later, and recovery
about six seconds after that.

The add-only probe block was incomplete. libmtp probes on both `add` and
`bind`. Device 26, the pwned download-mode node, was still opened by
`mtp-probe` at 23:05:43.316. That probe finished before the gated node was
published at `.441` and before checkra1n exited, and it reported that the
device was not MTP. It is still not established as the reason for recovery.
A host-only follow-up now matches `add|bind`. Its `scripts/boot.sh`
SHA-256 is
`3b93016a7ed95f76d3149315d0b47da734f10106b2cf59d40cba7550043c5662`.
`bash -n` and `shellcheck -x` passed. `udevadm test` for both actions on
the live port set `MTP_NO_PROBE=1` and did not select `mtp-probe`; the rule
was removed again. That follow-up has not been physically retried. The iPad
remained in recovery `05ac:1281` at the end of the attempt. The user watched
the screen and reported only the recovery cable graphic: no Pongo logo and
no Pongo text between the black DFU screen and that graphic. Pongo's
framebuffer logo is drawn before its USB shell, so this observation and the
missing `05ac:4141` agree that visible Pongo startup did not occur. A
sub-second flash cannot be excluded from the host log alone. The iPad was
still recovery `05ac:1281` when that report was recorded.

After minimal-shell acceptance, collect CPU/memory, framebuffer, USB
controller and input evidence with `scripts/guest-hardware-report.sh` and
review additional private kernel logs before publishing. A shell would not
establish a working native Omarchy desktop.

## Private evidence and recovery

All paths below are local and ignored by Git:

- `logs/host-20261014/`: preparation/check logs, terminal transcripts,
  private lockdown response, USB timelines, kernel USB logs, before/after
  read-only namespace diagnostics, regression results and tested-input
  hashes. Attempts 2 and 3 have separate terminal/timing logs. The directory
  is mode 0700; raw device files/transcripts are mode 0600.
- `logs/boot-20261014-215101-k2cR/`: first launcher's session and ECID.
- `logs/boot-20261014-215412-ZynE/`: verified DFU and the `nodev`-blocked run.
- `logs/boot-20261014-220229-uTBY/`: checkm8 setup and reconnection failure.

Only redacted findings are recorded here. After attempt 3, the user performed
a physical force restart and confirmed return to iPadOS. A fresh lockdown
query verified the original device identity, `iPad5,1`, `J96AP`, `MK9N2` and
iPadOS `15.8.3`. No persistent device change or storage operation was performed.

## REA investigation after attempt 9

The reverse-engineer-anything workflow analyzed the shipped palera1n and its
extracted checkra1n ELF with REA/Ghidra 12.1.4. No target binary was executed
by the analysis engine, and no m1n1 source was accessed or rebuilt. Current
normal-mode identity was rechecked against the original device and matched.
The existing uncommitted attempt-9 work was preserved.

- palera1n input SHA-256:
  `ea531df933c0c8edab25ecb8f43faedd010177484482bb3744eaa4cf1cd48658`.
- Extracted checkra1n starts at file offset `4238464`, length `554232`;
  SHA-256 `9f0e90c1e3750fc6265ec27479420b4bf3e1fee780ca360560266a6cb7c436ab`.
  Extraction was static, into the private analysis directory.
- REA Evidence `ev_360290360d7c10579cf48d2d473f0b0e3804b5da3f68580c079111760cad52b3`
  identifies palera1n's payload/loader extraction and argument construction
  in `FUN_00402044`. File mappings are retained in the evidence bundle.
- REA Evidence `ev_1677f319a8c383936e7c7a1245d4891c22bab99d375e229c9e1d2cde2286ee69`
  identifies checkra1n's download path in `FUN_0026e0d0`: it checks each
  upload chunk, then submits a zero-length control request with request type
  `0x21`, request `4`. The return value of that final ioctl is not tested
  before the `Booting PongoOS` status callback and the flag-controlled exit 0.
  Thus exit 0 does not establish a successful final trigger, much less
  execution of Pongo's shell. Earlier path-only traces did not record that
  ioctl result. Decompiled pseudocode is analysis output, not original source.

The source cross-check also matters: Pongo's `trampoline_entry` patches iBoot
and jumps back into it when called without boot arguments. The full Pongo
environment starts at a subsequent iBoot handoff. The maintainer describes
this distinction in [upstream issue 25](https://github.com/checkra1n/PongoOS/issues/25#issuecomment-818413157).
That issue's filesystem failure is not established on this iPad, which boots
normal iPadOS. Current upstream iOS15 `stage3.c` matches the pinned source;
updating it blindly is not a supported fix. A five-second panic-reset path
exists, but timing alone cannot identify it as the cause of this recovery.

Prepared discriminating diagnostics, not yet physical acceptance:

- `boot.sh --trace-usb-control` adds ioctl results and durations to private
  traces, to check the previously unobserved final boot trigger.
- MTP suppression now covers `add|bind` on the selected physical port and is
  installed before the first DFU transition. It refuses to overwrite an
  existing rule and removes only the rule it created.
- `scripts/recovery-diagnostic.sh SYSFS_PORT PRIVATE_HEX_ECID_FILE` exposes
  only the separately validated original recovery node in a new namespace.
  Recovery remains excluded from the palera1n namespace. The C helper checks
  chip/board/ECID, USB bus/address and sysfs inode before open and each command;
  it never reconnects. Only fixed `getenv auto-boot`, `getenv boot-command`,
  `getenv boot-args` and bounded console reads are allowed. Transfer failures
  and empty output remain unknown. Console capture is capped at 64 KiB and
  two seconds, with a 20-second whole-process deadline.
- The diagnostic uses a local static build of official libirecovery at
  `93c117c29b1f6669bc4ceca8b84e1df06449fe33`, installed only under
  `artifacts/recovery-diagnostic/`. It configures/claims USB interfaces and
  the library can clear an endpoint halt after a failed bulk read; these
  are transient transport operations. It has no persistent boot-setting,
  firmware, storage, reset, reconnect or upload operation.

Private REA evidence, immutable analysis snapshots, extraction provenance,
identity comparison and the findings ledger are in `logs/rea-20261014/`.
No raw device evidence is committed. The prepared attempt subsequently ran as attempt 10 below.

## Attempt 10: early Pongo execution established; iBoot returns to recovery

On 15 October 2026 the original normal-mode identity was verified again.
The selected device entered verified DFU; checkra1n reported Checkmate,
completed payload transfer and printed Booting PongoOS. The launcher stopped
when the same device returned to recovery (05ac:1281), before Pongo USB
enumeration (05ac:4141). The user reported the same STOP message.

This run used local HEAD 41b795bc1c8b5796d0a62dff6aed8b027b5418b6 plus
the uncommitted diagnostics, the USB gate and palera1n's embedded Pongo
2.6.3-e98323f8. Embedded payload SHA-256:
5475c5f701423858b34e92176c966a9d4b12950f38acb8d1c347f14d5b272655.
Exact script hashes are preserved in the private attempt10-inputs.sha256:

- boot.sh: 0df2030bde53ff4e49aaae3a3b0c8f8f70b93442a50687d7442b05e1c9160692
- recovery-diagnostic.sh: 04dd3f58f759bfc04c186313f12d4fd6fbe52fe0e55f6731e6470ccd3104e7ac
- C diagnostic: 2a3ee6fd82646c36ba627ed10d97cd5f2f96df965aaca7b7ecd1e3f1e0fa9177
- diagnostic binary: 58f7a22b7a005a8ee3e1abaee195b35e40a82d7b16ce4f6d9e7b7ab04b161335

The final loader control ioctl returned 0 in 0.000163 seconds. Its argument
was recorded as a pointer rather than decoded fields; identification of the
request depends on the analyzed call sequence. The selected-port add|bind
MTP suppression was active: eight MTP_NO_PROBE=1 events and no mtp-probe
journal entries. This run still failed, so the corrected MTP rule was not
sufficient to resolve the fault.

The separate identity-checked, read-only recovery diagnostic captured an
iBoot-7459.140.15 console containing “Supervisor Stage2 KJC Loader” and
“Entering recovery mode, starting command prompt”. The first marker is
written by Pongo's patch_bootloader. This is runtime evidence that Pongo's
early interposer executed and returned to patched iBoot; it is not evidence
that the full Pongo shell started. auto-boot returned true and boot-command
returned fsboot. The boot-args query stalled (-9), so its value is unknown.
The helper exited 1 for partial diagnostics; the boot itself also failed.
No m1n1 handoff, Linux kernel, /init or USB ACM shell was reached.

Opaque log markers map to source filenames in the author's published
[polinaserial mapping](https://github.com/NyanSatan/polinaserial/blob/4962913539b7461a965241a26daac8b25e01ffb4/sys/iboot_config.h):
ASP common_util.c line 351, APFS apfs.c line 695, and iBoot main.c lines
1247/1284. These are log locations, not decoded error codes. They do not
establish filesystem corruption or the precise cause of recovery.

Offline analysis downloaded only selected ZIP members from Apple's exact
iPad5,1 15.8.3 (19H386) IPSW. The J96 manifest's iBoot SHA-1 matched
e87bf8fe3450b23b1058a16c30864f25b72356e0. Public Apple Wiki keys decrypted
iBoot.ipad5.RELEASE.im4p; its embedded version matches the recovery console.
An ELF carrier was created strictly for static analysis, never execution or
upload. No Apple firmware image was sent to the device. Recovery reason
analysis remains unfinished; the user requested a stop before another test.

Private evidence: logs/boot-20261015-064833-qdN8/,
logs/recovery-20261015-065129-Ca6f/, and logs/rea-20261014/.
At stop, no boot/loader/gate/diagnostic process remained, no temporary MTP
rule or private /dev/j96-* path remained, and the device was still in
recovery 05ac:1281. All REA sessions were closed with evidence/snapshots saved.
No new commit, push, PR status change or persistent device change was made.
