#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
fail() { echo "FAIL: $*" >&2; exit 1; }
for file in Image Image.gz kernel.config t7000-j96.dtb m1n1.bin Pongo.bin palera1n pongoterm busybox initramfs.cpio.gz m1n1-linux.bin; do
    [[ -s artifacts/$file ]] || fail "missing $file"
done
sha256sum -c config/downloads.sha256
gpg --batch --yes --dearmor --output build/vda-keyring.gpg downloads/vda_pubkey.gpg
gpgv --keyring "$PWD/build/vda-keyring.gpg" downloads/busybox-1.37.0.tar.bz2.sig downloads/busybox-1.37.0.tar.bz2
for option in ARCH_APPLE ARM64_4K_PAGES ARM64_VA_BITS_48 ARM64_PA_BITS_48 BLK_DEV_INITRD RD_GZIP BINFMT_ELF BINFMT_SCRIPT DEVTMPFS PROC_FS SYSFS TMPFS CONFIGFS_FS APPLE_AIC APPLE_PMGR_PWRSTATE APPLE_USBCOMPLEX PHY_APPLE_AUSB USB_DWC2 USB_DWC2_PERIPHERAL USB_GADGET USB_CONFIGFS USB_CONFIGFS_ACM USB_F_ACM FB_SIMPLE FRAMEBUFFER_CONSOLE VT_CONSOLE SERIAL_SAMSUNG SERIAL_SAMSUNG_CONSOLE PINCTRL_APPLE_GPIO; do
    grep -qx "CONFIG_${option}=y" artifacts/kernel.config || fail "$option is not built in"
done
for option in ARM64_16K_PAGES ARM64_64K_PAGES BLOCK MODULES; do
    grep -qx "# CONFIG_${option} is not set" artifacts/kernel.config || fail "$option must be disabled"
done
flags=$(od -An -tu8 -j24 -N8 artifacts/Image)
[[ $(((flags >> 1) & 3)) == 1 ]] || fail 'Image header does not encode 4KB pages'
[[ $(od -An -tx4 -j56 -N4 artifacts/Image | tr -d ' ') == 644d5241 ]] || fail 'ARM64 Image magic'
gzip -t artifacts/Image.gz artifacts/initramfs.cpio.gz
cmp artifacts/Image <(gzip -dc artifacts/Image.gz)
[[ $(fdtget -t s artifacts/t7000-j96.dtb / compatible) == 'apple,j96 apple,t7000 apple,arm-platform' ]] || fail 'wrong DT compatibility'
[[ $(fdtget -t s artifacts/t7000-j96.dtb / model) == 'Apple iPad mini 4 (Wi-Fi)' ]] || fail 'wrong DT model'
[[ $(fdtget -t s artifacts/t7000-j96.dtb /chosen stdout-path) == serial0 ]] || fail 'wrong UART alias'
[[ $(fdtget -t s artifacts/t7000-j96.dtb /soc/bus@20c000000/usbdev@20c100000 dr_mode) == peripheral ]] || fail 'USB not peripheral'
readelf -h artifacts/busybox | grep -q 'Machine:.*AArch64'
ldd artifacts/pongoterm > logs/pongoterm-runtime.txt
if grep -q 'not found' logs/pongoterm-runtime.txt; then fail 'missing pongoterm host library'; fi
if readelf -l artifacts/busybox | grep -q INTERP; then fail 'BusyBox needs a dynamic interpreter'; fi
if readelf -d artifacts/busybox 2>/dev/null | grep -q NEEDED; then fail 'BusyBox needs shared libraries'; fi
# The quoted expression intentionally runs in the emulated ARM64 shell.
# shellcheck disable=SC2016
qemu-aarch64-static -cpu cortex-a53 artifacts/busybox sh -c 'test "$((6 * 7))" = 42; printf "ARMv8 shell arithmetic OK\n"'
qemu-aarch64-static artifacts/busybox sh -n initramfs/init
qemu-aarch64-static artifacts/busybox sh -n initramfs/firstboot-shell
qemu-aarch64-static artifacts/busybox --list > logs/busybox-applets.txt
for applet in sh mount mkdir cat echo hostname getty sleep ln uname test; do
    grep -qx "$applet" logs/busybox-applets.txt || fail "missing applet $applet"
done
scratch=$(mktemp -d "$PWD/build/verify-XXXX")
gzip -dc artifacts/initramfs.cpio.gz | cpio -itv > logs/initramfs-contents.txt 2> logs/cpio.log
(cd "$scratch" && gzip -dc "$OLDPWD/artifacts/initramfs.cpio.gz" | cpio --quiet -id --no-preserve-owner 'init' 'bin/*')
[[ -x $scratch/init && -x $scratch/bin/busybox && -x $scratch/bin/firstboot-shell && -L $scratch/bin/sh ]] || fail 'initramfs permissions/shell'
[[ $(readlink "$scratch/bin/sh") == busybox ]] || fail 'shell symlink'
cmp initramfs/init "$scratch/init"
cmp initramfs/firstboot-shell "$scratch/bin/firstboot-shell"
cmp artifacts/busybox "$scratch/bin/busybox"
head -1 "$scratch/init" | grep -qx '#!/bin/sh'
grep -q '^crw-------.*5, *1.*dev/console$' logs/initramfs-contents.txt || fail 'missing early console node'
scripts/assemble.sh "$scratch/combined.bin"
cmp artifacts/m1n1-linux.bin "$scratch/combined.bin"
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck scripts/*.sh initramfs/init initramfs/firstboot-shell
# Pure identity fixtures: no USB enumeration or device operations.
# shellcheck source=scripts/identity.sh
source scripts/identity.sh
parse_identity 'CPID:7000 CPRV:11 BDID:08 ECID:000000001234ABCD SRTG:[iBoot-test]'
[[ $ID_ECID == 1234ABCD ]] || fail 'ECID normalization'
parse_identity 'CPID:7000 BDID:08 ECID:000000001234ABCD SRTG:[PongoOS-test]'
for bad in 'CPID:7000 BDID:09 ECID:1' 'CPID:7001 BDID:08 ECID:1' 'CPID:7000 BDID:08 ECID:0' 'CPID:7000 BDID:08' 'unidentified'; do
    if parse_identity "$bad"; then fail "accepted invalid identity: $bad"; fi
done
# This validates namespace availability without exposing any USB devices.
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-pid --die-with-parent /bin/true
file artifacts/Image artifacts/t7000-j96.dtb artifacts/busybox artifacts/palera1n artifacts/pongoterm
printf 'PASS: kernel/DTB, ARM64 static shell, initramfs, gzip, assembly, syntax, identity fixtures, namespace.\n'
printf 'NOT TESTED: an iPad boot, DFU/checkm8, display or USB gadget hardware.\n'
