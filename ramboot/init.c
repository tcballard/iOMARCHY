// Diskless emulator bootstrap. The original J96 initramfs is not changed.
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/loop.h>
#include <linux/if_alg.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#include "rootfs-pin.h"

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

static void receive_image(void) {
    directory("/payload");
    mounted("tmpfs", "/payload", "tmpfs", MS_NOSUID | MS_NODEV, "size=1G,mode=0700");
    int stream = -1;
    for (int attempt = 0; attempt < 30; ++attempt) {
        stream = open("/dev/vport0p1", O_RDWR | O_CLOEXEC);
        if (stream >= 0) break;
        sleep(1);
    }
    if (stream < 0) fail("virtual payload channel");
    int hash = socket(AF_ALG, SOCK_SEQPACKET | SOCK_CLOEXEC, 0);
    if (hash < 0) fail("hash socket");
    struct sockaddr_alg algorithm = { .salg_family = AF_ALG, .salg_type = "hash", .salg_name = "sha256" };
    if (bind(hash, (struct sockaddr *)&algorithm, sizeof(algorithm))) fail("sha256 algorithm");
    int operation = accept4(hash, NULL, NULL, SOCK_CLOEXEC);
    if (operation < 0) fail("hash operation");
    close(hash);
    int image = open("/payload/rootfs.squashfs", O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0400);
    if (image < 0) fail("create payload");
    if (dprintf(stream, "READY %llu %s\n", (unsigned long long)ROOTFS_BYTES, ROOTFS_SHA256) < 0) fail("payload handshake");
    puts("IOMARCHY_RAM_UPLOAD_READY");
    unsigned char buffer[65536];
    unsigned long long remaining = ROOTFS_BYTES;
    while (remaining) {
        struct pollfd pfd = { .fd = stream, .events = POLLIN };
        if (poll(&pfd, 1, 60000) <= 0) { errno = ETIMEDOUT; fail("payload stalled"); }
        size_t want = remaining < sizeof(buffer) ? (size_t)remaining : sizeof(buffer);
        ssize_t count = read(stream, buffer, want);
        if (count <= 0) { errno = EIO; fail("payload disconnected"); }
        size_t done = 0;
        while (done < (size_t)count) {
            ssize_t written = write(image, buffer + done, (size_t)count - done);
            if (written <= 0) fail("payload write");
            done += (size_t)written;
        }
        if (send(operation, buffer, (size_t)count, remaining == (unsigned long long)count ? 0 : MSG_MORE) != count)
            fail("payload hash update");
        remaining -= (unsigned long long)count;
    }
    close(image);
    unsigned char digest[32];
    if (read(operation, digest, sizeof(digest)) != sizeof(digest)) fail("payload hash result");
    close(operation);
    char hex[65];
    for (size_t i = 0; i < sizeof(digest); ++i) snprintf(hex + i * 2, 3, "%02x", digest[i]);
    if (strcmp(hex, ROOTFS_SHA256)) { errno = EBADMSG; fail("payload digest mismatch"); }
    if (dprintf(stream, "VERIFIED %s\n", hex) < 0) fail("payload acknowledgement");
    close(stream);
    printf("IOMARCHY_RAM_PAYLOAD_VERIFIED %s\n", hex);
    memory("after-streamed-payload");
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
    receive_image();

    // LOOP_SET_FD retains the original payload inode. Never copy the image
    // into a second tmpfs or inflate its 2.3 GiB contents into RAM.
    int image = open("/payload/rootfs.squashfs", O_RDONLY | O_CLOEXEC);
    if (image < 0) fail("rootfs image");
    int control = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
    if (control < 0) fail("loop control");
    int number = ioctl(control, LOOP_CTL_GET_FREE);
    if (number < 0) fail("free loop");
    close(control);
    char device[64];
    snprintf(device, sizeof(device), "/dev/loop%d", number);
    // A read-only filesystem mount refuses a block device with open writers.
    // Keep a read-only descriptor until mount holds the AUTOCLEAR loop alive.
    int loop = open(device, O_RDONLY | O_CLOEXEC);
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
    if (unlink("/payload/rootfs.squashfs")) fail("unlink attached image");
    directory("/newroot/.ram-image");
    mounted("/payload", "/newroot/.ram-image", NULL, MS_MOVE, NULL);
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
