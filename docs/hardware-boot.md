# First J96 hardware boot record

**Status: physical DFU and completed checkm8 reported on 14 October 2026;
the iPad returned to recovery during PongoOS startup.** No verified PongoOS,
m1n1, Linux kernel or USB shell was observed. Host preparation, emulator
results and physical observations are separate.

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
unchanged retry was queued. Recovery to normal iPadOS was requested. At the
handoff, the user was performing that restart; the final lockdown query
found no device, so normal-mode recovery remains to be verified.

Private attempt 8 evidence: `logs/boot-20261014-222657-r517/` contains
session, syscall, mirror and gate logs; `logs/host-20261014-followup/`
contains terminal/timing, exact inputs and the kernel USB timeline. Raw
logs are private and remain uncommitted.

## Next investigation

Investigate the pinned Pongo startup path for J96/iPadOS 15.8.3, using the
confirmed successful transport and clean loader exit as the boundary.
Compare relevant upstream changes before selecting a separately pinned
experimental payload; preserve baseline artifacts and the prebuilt m1n1.
Any further physical attempt should capture transient screen text/photo
alongside USB enumeration to locate the failure more precisely. Do not
repeat the same payload simply to see whether it works next time. Verified
PongoOS enumeration remains the next acceptance point; Linux, DRM and
desktop integration have not been reached.

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
