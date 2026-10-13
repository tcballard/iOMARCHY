#!/usr/bin/env bash
# Boot a fresh disposable disk image on QEMU virt, without networking or USB.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for command in qemu-system-aarch64 mkfs.ext4 timeout sha256sum; do command -v "$command" >/dev/null; done
[[ -x build/rootfs/tree/usr/local/sbin/iomarchy-qemu-init ]]
sha256sum -c artifacts/qemu/SHA256SUMS
mkdir -p build/qemu logs
# mke2fs copies the source tree without modifying it. This disk is emulator
# scratch, not a distributable or reproducibility claim about ext4 bytes.
truncate -s "${QEMU_DISK_SIZE:-3G}" build/qemu/rootfs.ext4
mkfs.ext4 -q -F -d build/rootfs/tree build/qemu/rootfs.ext4
status=0
timeout --signal=TERM --kill-after=10 "${QEMU_TIMEOUT:-300}" \
  qemu-system-aarch64 -machine virt -cpu cortex-a53 -accel tcg -smp 2 \
  -m "${QEMU_MEMORY:-1536}" -kernel artifacts/qemu/Image \
  -append 'console=ttyAMA0 root=/dev/vda rw rootwait init=/usr/local/sbin/iomarchy-qemu-init panic=5' \
  -drive if=none,file=build/qemu/rootfs.ext4,format=raw,id=root \
  -device virtio-blk-device,drive=root -device virtio-gpu-device \
  -device virtio-keyboard-device -device virtio-tablet-device \
  -nic none -display none -monitor none -serial stdio -no-reboot \
  > logs/qemu-rootfs.log 2>&1 || status=$?
cat logs/qemu-rootfs.log
[[ $status == 0 ]] || { echo "QEMU failed/timed out: $status" >&2; exit "$status"; }
grep -q 'IOMARCHY_QEMU_USERSPACE_PASS' logs/qemu-rootfs.log
printf '%s\n' 'PASS: ARM64 userspace on QEMU virt. J96 hardware compatibility remains untested.'
