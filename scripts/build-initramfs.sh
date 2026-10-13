#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
cc -O2 -Wall src/linux/usr/gen_init_cpio.c -o build/gen_init_cpio
install -m755 src/busybox-1.37.0/busybox artifacts/busybox
qemu-aarch64-static artifacts/busybox --list > build/busybox-applets.txt
grep -qx sh build/busybox-applets.txt
{
    for d in bin sbin usr usr/bin usr/sbin dev proc sys tmp run root etc; do
        printf 'dir /%s 0755 0 0\n' "$d"
    done
    echo 'nod /dev/console 0600 0 0 c 5 1'
    echo 'nod /dev/null 0666 0 0 c 1 3'
    printf 'file /bin/busybox %s/artifacts/busybox 0755 0 0\n' "$PWD"
    printf 'file /init %s/initramfs/init 0755 0 0\n' "$PWD"
    printf 'file /bin/firstboot-shell %s/initramfs/firstboot-shell 0755 0 0\n' "$PWD"
    while read -r applet; do
        [[ $applet == busybox ]] && continue
        printf 'slink /bin/%s busybox 0777 0 0\n' "$applet"
    done < build/busybox-applets.txt
} > build/initramfs.list
build/gen_init_cpio -t 0 build/initramfs.list | gzip -n -9 > artifacts/initramfs.cpio.gz
