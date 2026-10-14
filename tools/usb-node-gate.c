#define FUSE_USE_VERSION 31
#define _GNU_SOURCE
#include <fuse3/fuse.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Only the launcher's validated backing nodes can become visible. Missing
 * USB-address lookups wait briefly for publication; they never invent nodes.
 * Device I/O goes directly to the kernel after lookup, not through this process.
 */
static int backing_fd, test_null;
static double seconds(clockid_t clock) {
    struct timespec t;
    clock_gettime(clock, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void event(const char *action, const char *path) {
    fprintf(stderr, "%.9f %s %s\n", seconds(CLOCK_REALTIME), action, path);
}
static int number(const char *p) {
    if (p[0] < '0' || p[0] > '9' || p[1] < '0' || p[1] > '9' ||
        p[2] < '0' || p[2] > '9') return 0;
    return (p[0]-'0')*100 + (p[1]-'0')*10 + p[2]-'0';
}
static int shape(const char *path) {
    size_t n = strlen(path);
    if (n == 1 && path[0] == '/') return 0;
    if (path[0] != '/' || (n != 4 && n != 8) || !number(path+1)) return -1;
    if (n == 4) return 1;
    if (path[4] != '/' || !number(path+5) || number(path+5) > 127) return -1;
    return 2;
}
static int snapshot(const char *path, struct stat *st) {
    int kind = shape(path), result;
    if (kind < 0) return -ENOENT;
    if (!kind) result = fstat(backing_fd, st);
    else if (kind == 1) result = fstatat(backing_fd, path+1, st, AT_SYMLINK_NOFOLLOW);
    else {
        char bus[4];
        memcpy(bus, path+1, 3); bus[3] = 0;
        int fd = openat(backing_fd, bus, O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
        if (fd < 0) return -errno;
        result = fstatat(fd, path+5, st, AT_SYMLINK_NOFOLLOW);
        int saved_errno = errno;
        close(fd);
        errno = saved_errno;
    }
    if (result < 0) return -errno;
    if (st->st_uid != 0 || (st->st_mode & 0777) != (kind == 2 ? 0600 : 0700)) return -EACCES;
    if (kind < 2) return S_ISDIR(st->st_mode) ? 0 : -EACCES;
    if (!S_ISCHR(st->st_mode)) return -EACCES;
    unsigned expected_minor = (unsigned)(number(path+1)-1)*128 + (unsigned)number(path+5)-1;
    if (test_null) return st->st_rdev == makedev(1, 3) ? 0 : -EACCES;
    return major(st->st_rdev) == 189 && minor(st->st_rdev) == expected_minor ? 0 : -EACCES;
}
static int gate_getattr(const char *path, struct stat *st, struct fuse_file_info *fi) {
    (void)fi;
    int result = snapshot(path, st);
    if (result != -ENOENT || shape(path) != 2) return result;
    const double deadline = seconds(CLOCK_MONOTONIC) + 2.0;
    const struct timespec interval = {.tv_nsec = 10000000};
    event("wait", path);
    do {
        nanosleep(&interval, NULL);
        result = snapshot(path, st);
    } while (result == -ENOENT && seconds(CLOCK_MONOTONIC) < deadline);
    event(result == 0 ? "published" : "denied", path);
    return result;
}
static int gate_readdir(const char *path, void *buf, fuse_fill_dir_t fill,
                        off_t offset, struct fuse_file_info *fi, enum fuse_readdir_flags flags) {
    (void)offset; (void)fi; (void)flags;
    struct stat st;
    int result = snapshot(path, &st);
    if (result) return result;
    if (!S_ISDIR(st.st_mode)) return -ENOTDIR;
    int fd = openat(backing_fd, path[1] ? path+1 : ".", O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    if (fd < 0) return -errno;
    DIR *dir = fdopendir(fd);
    if (!dir) { result = -errno; close(fd); return result; }
    fill(buf, ".", NULL, 0, 0); fill(buf, "..", NULL, 0, 0);
    struct dirent *entry;
    while ((entry = readdir(dir))) {
        char child[16];
        if (strlen(entry->d_name) != 3) continue;
        int size = snprintf(child, sizeof child, "%s%s%s", path, path[1] ? "/" : "", entry->d_name);
        if (size < 0 || (size_t)size >= sizeof child) continue;
        if (!snapshot(child, &st) && fill(buf, entry->d_name, &st, 0, 0)) break;
    }
    closedir(dir);
    return 0;
}
static void *gate_init(struct fuse_conn_info *conn, struct fuse_config *cfg) {
    (void)conn;
    cfg->entry_timeout = cfg->attr_timeout = cfg->negative_timeout = 0;
    return NULL;
}
int main(int argc, char **argv) {
    if (argc > 1 && !strcmp(argv[1], "--test-null")) { test_null = 1; argc--; argv++; }
    if (argc != 3 || geteuid() != 0) {
        fprintf(stderr, "Usage (root): usb-node-gate [--test-null] BACKING MOUNTPOINT\n"); return 2;
    }
    backing_fd = open(argv[1], O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    struct stat st;
    if (backing_fd < 0 || snapshot("/", &st)) { fprintf(stderr, "Backing directory must be root-owned mode 0700.\n"); return 2; }
    struct fuse_operations ops = {.init=gate_init, .getattr=gate_getattr, .readdir=gate_readdir};
    char *args[] = {"usb-node-gate", "-f", "-o", "dev,nosuid,noexec,default_permissions", argv[2], NULL};
    int result = fuse_main(5, args, &ops, NULL);
    close(backing_fd);
    return result;
}
