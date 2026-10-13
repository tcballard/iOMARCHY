# Staged RAM filesystem and visible-output tests

This is a separate QEMU experiment. `scripts/start.sh` continues to select
the verified minimal J96 firstboot bundle. No iPad has booted this profile.

## Why the payload is streamed

The pinned [PongoOS USB loader](https://github.com/checkra1n/PongoOS/blob/bb492b004265ce91123caa23b8bc04b2eff6d2b7/src/shell/usbloader.c)
limits one upload to 128 MiB (`UPLOADSZ_MAX`). The measured original SquashFS
is about 845 MiB. Concatenating that filesystem into the m1n1 upload cannot
work with this loader. An initramfs containing the entire image also creates
a large temporary copy during kernel unpacking.

The experimental path starts a small static ARM64 bootstrap, then streams
the already compressed filesystem over a separate virtual serial channel.
Its expected byte count and SHA-256 are compiled into the bootstrap. The
guest hashes the incoming bytes using the kernel's SHA-256 implementation
and refuses to mount a mismatched or incomplete payload. The QMP harness
also checks the guest handshake against the image's recorded pin.

After verification, a read-only loop device holds the compressed image in
RAM. SquashFS supplies the lower filesystem; a tmpfs overlay, limited to
256 MiB, holds writes. The image's own tmpfs has a 1 GiB size limit. Neither
limit reserves its whole capacity up front. The original image inode stays
open through the loop device, avoiding another full copy during root switch.
There is no emulated disk, NIC, host USB passthrough or swap device.

The bootstrap prints memory values after the small initramfs unpacks and
after the payload arrives. Userspace samples `MemAvailable` once per second.
The minimum sample is useful evidence, not an exact instantaneous peak or
an estimate of Apple bootloader/reserved-memory use.

## Graphics experiment

The pinned packaged Aquamarine rejects a software EGL device without a
matching DRM device path, even though Hyprland can create a llvmpipe context.
`scripts/build-graphics-candidate.sh` builds a separately pinned candidate
that also tries the output's existing GBM allocator. The patch and source
revisions are preserved with its binary and upstream license.

The original signed package and the entire upstream Omarchy source stay
intact. The candidate is copied under `/opt/iomarchy/graphics-candidate` in
the experimental deployment tree, after comparing the two original rootfs
archives. Only an explicit `iomarchy.graphics=gbm` kernel argument selects
it for the Hyprland probe. The ordinary disk test keeps the packaged library.
The SquashFS candidate and rootfs archive consequently have different scopes.

This is a local diagnostic patch, not an upstream release or an established
J96 fix. Its output must pass the scanout test; successful compilation alone
does not establish any rendering improvement.

## Test contract

`scripts/qemu-evidence.mjs` uses QMP to inspect the actual virtual display:

1. Verify that the RAM VM has zero block devices.
2. Require a verified payload, overlay root and untouched read-only lower tree.
3. Run the genuine ARM64 userspace checks and start Hyprland.
4. Capture a Wayland Foot terminal containing the expected red background.
5. Inject `x` through the virtual keyboard. The terminal's application must
   receive it and change its background to green.
6. Require more than 10% of captured pixels to match each expected colour.
7. Close the fixture, launch the real upstream Omarchy shell and capture it.
8. Require successful guest/session results and preserve memory readings.

The colour test rejects a black frame, a boot console, or a process that is
alive without displaying its buffers. A shell screenshot still needs visual
inspection; it does not establish every Omarchy service or application.
Corrupted and interrupted payload tests must stop before mounting the root.
Failure captures and serial/renderer logs are preserved, not counted as passes.

The workflow tests nominal 2 GiB and reduced 1536 MiB RAM configurations.
Every run's results identify which of these checks actually passed. Existing
disk-only evidence must not be described as passing this stronger contract.

## Reproduce

Use the dependencies in `.github/workflows/offline-build.yml`, including a
host C++ compiler, ARM64 cross compiler, CMake/Ninja, pugixml, SquashFS tools,
QEMU system emulation and Node.js. Build the locked userspace and separate
QEMU kernel as described in [arm64-rootfs.md](arm64-rootfs.md), then:

```bash
./scripts/build-graphics-candidate.sh
sudo mkdir -p build/rootfs/tree/opt/iomarchy/graphics-candidate
sudo cp -a artifacts/graphics-candidate/. build/rootfs/tree/opt/iomarchy/graphics-candidate/
sudo ./scripts/build-rootfs-squashfs.sh
./scripts/build-ramboot.sh
sudo env "PATH=$PATH" ./scripts/emulate-ramboot.sh
sudo env "PATH=$PATH" QEMU_MEMORY=1536 ./scripts/emulate-ramboot.sh
sudo env "PATH=$PATH" node scripts/qemu-evidence.mjs ram-corrupt 1536
sudo env "PATH=$PATH" node scripts/qemu-evidence.mjs ram-truncated 1536
```

Each test writes `logs/qemu-<mode>-<memory>/`: the exact QEMU invocation,
block-device query, serial log, transfer handshake, result JSON and display
captures when reached. The emulator uses a virtual serial port, not the
physical iPad's USB ACM driver. Adapting and validating that transport,
native simpledrm scanout and useful physical input remain separate hardware
work. Nothing here assembles or uploads a desktop J96 image.
