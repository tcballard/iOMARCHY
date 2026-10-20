/* SPDX-License-Identifier: MIT
 * Standalone declarations for the pinned Pongo module ABI. No Apple headers.
 */
#include "probe.h"
extern void command_register(const char *, const char *, void (*)(const char *, char *));
extern void command_puts(const char *);
struct pongo_exports { const char *name; void *value; };
char *module_name = "iOMARCHY RAM probe v1";
struct pongo_exports exported_symbols[] = {{0, 0}};
static _Alignas(16) volatile struct {
    probe_u64 before[2];
    struct probe_record record;
    probe_u64 after[2];
} capture;

static void hex64(char *out, probe_u64 n) {
    const char *digits = "0123456789abcdef";
    for (int i = 15; i >= 0; --i) { out[i] = digits[n & 15]; n >>= 4; }
}

static int nonce_arg(const char *s, probe_u64 *value) {
    *value = 0;
    for (unsigned i = 0; i < 16; ++i) {
        unsigned c = (unsigned char)s[i], v;
        if (c >= '0' && c <= '9') v = c - '0';
        else if (c >= 'a' && c <= 'f') v = c - 'a' + 10;
        else return 0;
        *value = (*value << 4) | v;
    }
    return s[16] == 0 && *value != 0;
}

static void run(char *args, int state) {
    probe_u64 nonce;
    if (!nonce_arg(args, &nonce)) {
        command_puts("rammark/ramstate require exactly 16 lowercase hex digits, nonzero");
        return;
    }
    capture.before[0] = capture.before[1] = PROBE_GUARD;
    capture.after[0] = capture.after[1] = PROBE_GUARD;
    for (unsigned i = 0; i < PROBE_WORDS; ++i) capture.record.word[i] = 0;
    if (state) ram_state(&capture.record, nonce);
    else ram_marker(&capture.record, nonce);
    if (capture.before[0] != PROBE_GUARD || capture.before[1] != PROBE_GUARD ||
        capture.after[0] != PROBE_GUARD || capture.after[1] != PROBE_GUARD) {
        command_puts("IOMARCHY_RAMPROBE_GUARD_FAILED");
        return;
    }
    /* Export actual readback words; the host validates marker and nonce. */
    char line[320];
    const char *prefix = state ? "IOMARCHY_STATE_V1 " : "IOMARCHY_MARK_V1 ";
    unsigned p = 0;
    while (*prefix) line[p++] = *prefix++;
    for (unsigned i = 0; i < PROBE_WORDS; ++i) {
        hex64(line + p, capture.record.word[i]);
        p += 16;
        if (i + 1 < PROBE_WORDS) line[p++] = ' ';
    }
    line[p] = 0;
    command_puts(line);
}
static void mark(const char *cmd, char *args) { (void)cmd; run(args, 0); }
static void state(const char *cmd, char *args) { (void)cmd; run(args, 1); }
void module_entry(void) {
    command_register("rammark", "Run returning RAM marker (16 hex nonce)", mark);
    command_register("ramstate", "Capture current CPU state (16 hex nonce)", state);
    command_puts("iOMARCHY RAM probe loaded; no UART initialized");
}
