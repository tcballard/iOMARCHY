// Diskless emulator bootstrap. The original J96 initramfs is not changed.
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/loop.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <unistd.h>

static void fail(const char *step) {
    fprintf(stderr, "IOMARCHY_RAM_FAIL %s: %s\n", step, strerror(errno));
    fflush(NULL);
    reboot(RB_POWER_OFF);
    for (;;) pause();
}

static void directory(const char *path) {
    if (mkdir(path, 0755) && errno != EEXIST) fail(path);
}

static void mounted(const char *source, const char *target, const char *type,
                    unsigned long flags, const char *data) {
    if (mount(source, target, type, flags, data)) fail(target);
}

static void memory(const char *phase) {
    printf("IOMARCHY_RAM_MEMORY %s\n", phase);
    FILE *file = fopen("/proc/meminfo", "r");
    if (!file) fail("meminfo");
    char line[256];
    while (fgets(line, sizeof(line), file)) {
        if (!strncmp(line, "Mem", 3) || !strncmp(line, "Shmem:", 6)) fputs(line, stdout);
    }
    fclose(file);
}

int main(void) {
    setbuf(stdout, NULL);
    if (getpid() != 1) { fputs("RAM bootstrap must run as PID 1.\n", stderr); return 2; }
    directory("/proc"); directory("/sys"); directory("/dev");
    mounted("proc", "/proc", "proc", 0, NULL);
    mounted("sysfs", "/sys", "sysfs", 0, NULL);
    mounted("devtmpfs", "/dev", "devtmpfs", 0, NULL);
    mounted(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL);
    memory("after-initrd-unpack");

    // LOOP_SET_FD retains the original initramfs inode. Never copy the image
    // into a second tmpfs or inflate its 2.3 GiB contents into RAM.
    int image = open("/rootfs.squashfs", O_RDONLY | O_CLOEXEC);
    if (image < 0) fail("rootfs image");
    int control = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
    if (control < 0) fail("loop control");
    int number = ioctl(control, LOOP_CTL_GET_FREE);
    if (number < 0) fail("free loop");
    close(control);
    char device[64];
    snprintf(device, sizeof(device), "/dev/loop%d", number);
    int loop = open(device, O_RDWR | O_CLOEXEC);
    if (loop < 0) fail("loop device");
    if (ioctl(loop, LOOP_SET_FD, image)) fail("attach image");
    struct loop_info64 info = { .lo_flags = LO_FLAGS_READ_ONLY | LO_FLAGS_AUTOCLEAR };
    if (ioctl(loop, LOOP_SET_STATUS64, &info)) fail("read-only loop");
    close(image);
    directory("/lower"); directory("/writable"); directory("/newroot");
    mounted(device, "/lower", "squashfs", MS_RDONLY | MS_NODEV, NULL);
    close(loop);
    mounted("tmpfs", "/writable", "tmpfs", MS_NOSUID | MS_NODEV, "size=256M,mode=0755");
    directory("/writable/upper"); directory("/writable/work");
    mounted("overlay", "/newroot", "overlay", 0,
            "lowerdir=/lower,upperdir=/writable/upper,workdir=/writable/work");
    directory("/newroot/.ram-lower"); directory("/newroot/.ram-writable");
    mounted("/lower", "/newroot/.ram-lower", NULL, MS_MOVE, NULL);
    mounted("/writable", "/newroot/.ram-writable", NULL, MS_MOVE, NULL);
    if (unlink("/rootfs.squashfs")) fail("unlink attached image");
    memory("before-switch-root");
    const char *names[] = { "proc", "sys", "dev" };
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        char from[32], to[64];
        snprintf(from, sizeof(from), "/%s", names[i]);
        snprintf(to, sizeof(to), "/newroot/%s", names[i]);
        directory(to);
        mounted(from, to, NULL, MS_MOVE, NULL);
    }
    // Only this small bootstrap remains in the old root; its executable pages
    // can be released on exec. The loop retains the unlinked compressed image.
    if (unlink("/init")) fail("unlink bootstrap");
    if (chdir("/newroot")) fail("newroot cwd");
    mounted("/newroot", "/", NULL, MS_MOVE, NULL);
    if (chroot(".") || chdir("/")) fail("switch root");
    puts("IOMARCHY_RAM_ROOT_READY squashfs + bounded tmpfs overlay, no disk");
    execl("/usr/local/sbin/iomarchy-qemu-init", "iomarchy-qemu-init", NULL);
    fail("guest init");
}
