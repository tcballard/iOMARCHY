# Redacted development and physical-boot logs

Published on 16 October 2026 from the XPS checkout's local `logs/` directory.
This export covers **228 source files: 227 text copies and one omitted extracted
executable**. [inventory.json](inventory.json) lists every source path, export
status, exported size and SHA-256. The executable is represented by its original
size and SHA-256; it is an analysis input, not a log. One text file was added
after the original `logs/` export: the attempt 9 host journal had not been saved
under `logs/`, so the redacted copy was taken from the host journal.

The originals remain private and unchanged. Files retaining names such as
`console-private.log` are **redacted publication copies**, not original captures.
The directory structure is preserved so observations can be compared across
attempts. Empty logs are retained.

## What the physical attempt established

Attempt 10 verified the original iPad in DFU, completed the loader transfer and
captured the `Supervisor Stage2 KJC Loader` marker in the recovery console.
That establishes execution of Pongo's early iBoot interposer. iBoot then returned
to recovery before full Pongo USB enumeration. **No m1n1 handoff, Linux kernel,
USB serial shell or native desktop was observed.** Host and emulator results
are separate evidence. See [the hardware record](../../hardware-boot.md).

The summary above starts at attempt 10, so the preceding control is easy to
miss. On attempt 9 the user saw only the recovery cable graphic, with no Pongo
logo or text. That report is in the hardware record. [findings.txt](logs/rea-20261014/findings.txt)
only says "No observed Pongo logo/USB," and there is no screen-capture file.

Useful starting points:

- [Attempt 9 journal](logs/host-20261014-followup/attempt9-journal-private.log)
- [Attempt 10 terminal](logs/rea-20261014/attempt10-terminal.log)
- [Recovery console](logs/recovery-20261015-065129-Ca6f/console-private.log)
- [Attempt 10 input hashes](logs/rea-20261014/attempt10-inputs.sha256)
- [Attempt 10 host kernel log](logs/rea-20261014/attempt10-kernel-private.log)
- [Attempt 10 launcher session](logs/boot-20261015-064833-qdN8/session.log)
- [iBoot static-analysis evidence](logs/rea-20261014/iboot-evidence.json)
- [Next-session handoff](../../handoff-2026-10-15.md)

## Redaction and interpretation

Captured ECIDs (including decimal/hexadecimal and padded forms), UDIDs, serials,
device names, account fields, MAC addresses, UUIDs, email addresses and local
usernames/paths have been removed. Device-info exports retain only a small
allowlist of model, software and hardware fields. Other device-info values are
replaced even when not individually sensitive. Labelled serial/ECID fields and
credential patterns receive an additional pass. ANSI styling and NUL console
padding are removed. The originals are not rewritten.

REA JSON is parsed, its string values redacted and the result formatted as JSON.
These exported evidence/snapshot copies are for review; redacted paths and
values mean they should not be treated as original, reusable analysis snapshots.
Artifact identity hashes and REA evidence IDs describe the original analysis
inputs. Inventory hashes describe the **exported files**, not private captures.
Terminal timing files no longer align byte-for-byte with redacted transcripts.
Archived shell scripts/patches are historical evidence, not installation steps.

The publication was checked for captured identifiers across both pending Git
history and the staged export. Every JSON file parses, every exported-file hash
matches the inventory, and every source file has an inventory entry. This is a
log publication, not a new boot attempt or validation of untested fixes. Current
uncommitted diagnostic source changes remain local; tested working-tree hashes
are preserved in the attempt records. The PR remains draft and unmerged.
