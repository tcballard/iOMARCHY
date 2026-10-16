/* Bounded, read-only iBoot diagnostics. Caller MUST expose only the selected
 * recovery node in a private /dev/bus/usb namespace. No generic command input.
 * Protocol follows libimobiledevice/libirecovery at 93c117c29b1f6669bc4ceca8b84e1df06449fe33.
 * stdout contains PRIVATE raw device output; redirect to a mode-0600 file.
 */
#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <libirecovery.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static const char *port;
static unsigned expected_bus, expected_address;
static uint64_t expected_ecid;
static struct stat selected_inode;
static size_t console_bytes;
static double console_seconds;

static void deadline(int sig) {
    (void)sig;
    const char msg[] = "Diagnostic exceeded 20-second deadline; stopped.\n";
    (void)write(STDERR_FILENO, msg, sizeof(msg) - 1);
    _exit(124);
}

static double now(void) {
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC, &t)) exit(1);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static bool number(const char *s, int base, uint64_t *v) {
    if (!s || !*s || *s == '-' || *s == '+' || isspace((unsigned char)*s)) return false;
    errno = 0;
    char *end;
    unsigned long long x = strtoull(s, &end, base);
    if (errno || end == s) return false;
    while (isspace((unsigned char)*end)) ++end;
    if (*end) return false;
    *v = x;
    return true;
}

static bool read_fd(int fd, char *buf, size_t cap) {
    size_t used = 0;
    while (used < cap - 1) {
        ssize_t n = read(fd, buf + used, cap - 1 - used);
        if (n < 0) { if (errno == EINTR) continue; return false; }
        if (!n) { buf[used] = 0; return !memchr(buf, 0, used); }
        used += (size_t)n;
    }
    return false;
}

static bool attribute(int dir, const char *name, char *buf, size_t cap) {
    int fd = openat(dir, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return false;
    bool ok = read_fd(fd, buf, cap);
    close(fd);
    return ok;
}

static bool numeric_attribute(int dir, const char *name, int base, uint64_t expected) {
    char buf[64];
    uint64_t got;
    return attribute(dir, name, buf, sizeof(buf)) && number(buf, base, &got) && got == expected;
}

static bool serial_tag(const char *serial, const char *tag, uint64_t expected) {
    size_t len = strlen(tag);
    const char *match = NULL;
    for (const char *p = serial; (p = strstr(p, tag)); ++p) {
        if ((p == serial || isspace((unsigned char)p[-1])) && p[len] == ':') {
            if (match) return false;
            match = p + len + 1;
        }
    }
    if (!match) return false;
    char value[32];
    size_t n = 0;
    while (isxdigit((unsigned char)match[n])) {
        if (n >= sizeof(value) - 1) return false;
        value[n] = match[n];
        ++n;
    }
    if (!n || (match[n] && !isspace((unsigned char)match[n]))) return false;
    value[n] = 0;
    uint64_t got;
    return number(value, 16, &got) && got == expected;
}

static bool check_port(bool initial) {
    int fd = open(port, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return false;
    struct stat st;
    char serial[1024];
    bool ok = !fstat(fd, &st) &&
        (initial || (st.st_dev == selected_inode.st_dev && st.st_ino == selected_inode.st_ino)) &&
        numeric_attribute(fd, "idVendor", 16, 0x05ac) &&
        numeric_attribute(fd, "idProduct", 16, 0x1281) &&
        numeric_attribute(fd, "busnum", 10, expected_bus) &&
        numeric_attribute(fd, "devnum", 10, expected_address) &&
        attribute(fd, "serial", serial, sizeof(serial)) &&
        serial_tag(serial, "CPID", 0x7000) && serial_tag(serial, "BDID", 0x08) &&
        serial_tag(serial, "ECID", expected_ecid);
    if (ok && initial) selected_inode = st;
    close(fd);
    return ok;
}

static bool identity(irecv_client_t client) {
    int mode = 0;
    const struct irecv_device_info *d = irecv_get_device_info(client);
    return check_port(false) && d && d->have_cpid && d->have_bdid && d->have_ecid &&
        d->cpid == 0x7000 && d->bdid == 0x08 && d->ecid == expected_ecid &&
        irecv_get_mode(client, &mode) == IRECV_E_SUCCESS && mode == 0x1281;
}

/* Explicit transfer checks avoid irecv_getenv's swallowed transport errors.
 * Only fixed literal getters can reach here; no state-changing iBoot command.
 */
static bool getenv_fixed(irecv_client_t client, const char *name) {
    char command[64];
    if (strcmp(name, "auto-boot") && strcmp(name, "boot-command") && strcmp(name, "boot-args")) return false;
    snprintf(command, sizeof(command), "getenv %s", name);
    if (!identity(client)) return false;
    int want = (int)strlen(command) + 1;
    int sent = irecv_usb_control_transfer(client, 0x40, 0, 0, 0,
        (unsigned char *)command, (uint16_t)want, 2000);
    if (sent != want) {
        printf("getenv %s: UNKNOWN (send result %d, expected %d)\n", name, sent, want);
        return false;
    }
    if (!identity(client)) return false;
    unsigned char response[256] = {0};
    int got = irecv_usb_control_transfer(client, 0xc0, 0, 0, 0, response, 255, 2000);
    if (got <= 0 || got > 255) {
        printf("getenv %s: UNKNOWN (receive result %d)\n", name, got);
        return false;
    }
    printf("getenv %s: raw response (%d bytes; empty is not proof of absence)\n", name, got);
    fwrite(response, 1, (size_t)got, stdout);
    putchar('\n');
    return !ferror(stdout);
}

static bool receive_console(irecv_client_t client) {
    double start = now();
    bool ok = true;
    while (console_bytes < 65536 && console_seconds + now() - start < 2.0) {
        if (!identity(client)) { ok = false; break; }
        if (irecv_usb_set_interface(client, 1, 1) != IRECV_E_SUCCESS) {
            puts("Console unavailable: could not select interface 1 alternate 1.");
            ok = false;
            break;
        }
        unsigned char buf[4096];
        int length = (int)(65536 - console_bytes);
        if (length > (int)sizeof(buf)) length = (int)sizeof(buf);
        double left = 2.0 - console_seconds - (now() - start);
        unsigned timeout = left >= 0.5 ? 500 : left > 0 ? (unsigned)(left * 1000) : 0;
        if (!timeout) break;
        int bytes = 0;
        int r = irecv_usb_bulk_transfer(client, 0x81, buf, length, &bytes, timeout);
        if (bytes < 0 || bytes > length) { ok = false; break; }
        if (bytes) {
            fwrite(buf, 1, (size_t)bytes, stdout);
            console_bytes += (size_t)bytes;
        }
        if (irecv_usb_set_interface(client, 0, 0) != IRECV_E_SUCCESS) { ok = false; break; }
        if (r || !bytes) {
            printf("\nConsole read ended: transport=%d bytes=%d (no output is inconclusive).\n", r, bytes);
            break;
        }
    }
    console_seconds += now() - start;
    if (!identity(client) || irecv_usb_set_interface(client, 0, 0) != IRECV_E_SUCCESS) ok = false;
    return ok && !ferror(stdout);
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fputs("Usage: recovery-diagnostic PRIVATE_HEX_ECID_FILE /sys/bus/usb/devices/PORT BUS ADDRESS\n", stderr);
        return 2;
    }
    if (geteuid() != 0) { fputs("Root is required.\n", stderr); return 2; }
    port = argv[2];
    const char prefix[] = "/sys/bus/usb/devices/";
    if (strncmp(port, prefix, sizeof(prefix) - 1)) return 2;
    const char *suffix = port + sizeof(prefix) - 1;
    if (!isdigit((unsigned char)*suffix) || !strchr(suffix, '-') || strspn(suffix, "0123456789-.") != strlen(suffix)) return 2;
    uint64_t bus, addr;
    if (!number(argv[3], 10, &bus) || !bus || bus > 9999 ||
        !number(argv[4], 10, &addr) || !addr || addr > 127) return 2;
    expected_bus = (unsigned)bus;
    expected_address = (unsigned)addr;
    int fd = open(argv[1], O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    struct stat st;
    char ecid[64];
    bool ok = fd >= 0 && !fstat(fd, &st) && S_ISREG(st.st_mode) && !(st.st_mode & 0077) &&
        read_fd(fd, ecid, sizeof(ecid)) && number(ecid, 16, &expected_ecid) && expected_ecid;
    if (fd >= 0) close(fd);
    if (!ok) { fputs("Invalid/private ECID input required.\n", stderr); return 2; }
    setvbuf(stdout, NULL, _IONBF, 0);
    struct sigaction sa = {0};
    sa.sa_handler = deadline;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGALRM, &sa, NULL)) return 1;
    alarm(20);
    if (!check_port(true) || !check_port(false)) {
        fputs("Selected recovery identity/port mismatch; no USB opened.\n", stderr);
        return 1;
    }
    irecv_client_t client = NULL;
    irecv_error_t r = irecv_open_with_ecid(&client, expected_ecid);
    if (r != IRECV_E_SUCCESS) {
        fprintf(stderr, "Recovery open failed (%d); no retry.\n", r);
        return 1;
    }
    if (!identity(client)) {
        fputs("Opened recovery identity/port mismatch; no commands sent.\n", stderr);
        irecv_close(client);
        return 1;
    }
    puts("Selected J96 recovery identity verified. Initial queued console follows:");
    ok = receive_console(client);
    const char *names[] = {"auto-boot", "boot-command", "boot-args"};
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        if (!identity(client)) { ok = false; break; }
        if (!getenv_fixed(client, names[i])) { ok = false; break; }
    }
    if (identity(client)) {
        puts("Remaining queued diagnostic console follows:");
        if (!receive_console(client)) ok = false;
    } else ok = false;
    printf("Console capture: %zu bytes, %.3f seconds; result=%s.\n", console_bytes, console_seconds, ok ? "completed" : "partial/unknown");
    irecv_close(client);
    alarm(0);
    return ok ? 0 : 1;
}
