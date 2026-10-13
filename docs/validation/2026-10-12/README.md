# Original host-preparation evidence

These are retained records from the preparation begun on 12 October 2026
in `/home/tcballard/Projects/ipad-mini4-linux`, before migration to iOMARCHY.
They are historical snapshots; the manifest's original paths and input hashes
are intentionally unchanged. Repository documentation and scripts have since
been adapted for this checkout.

- `MANIFEST.txt`: pinned sources, toolchains, full effective kernel config,
  artifact/input hashes and offline verification.
- `SHA256SUMS`: the eleven original artifact hashes, relative to a workspace
  containing `artifacts/`.
- `verification.log`: kernel/DTB, static ARM64 userspace, archive/assembly,
  shell syntax, identity parsing and namespace checks.
- `reproducibility.log`: identical artifact hashes after rerunning the build
  workflow in the original workspace; not a separate clean-room build.

No iPad was connected and no hardware boot was attempted. No firmware,
device identifiers, private boot-session logs or compiled payloads are stored
in this evidence directory. New local builds write their own `MANIFEST.txt`
and `artifacts/SHA256SUMS`, which are ignored by Git.
