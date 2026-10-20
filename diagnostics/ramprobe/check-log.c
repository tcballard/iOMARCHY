/* SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "probe.h"

static int hexword(const char *s, probe_u64 *v) {
    *v = 0;
    for (unsigned i = 0; i < 16; ++i) {
        unsigned c = (unsigned char)s[i], n;
        if (c >= '0' && c <= '9') n = c - '0';
        else if (c >= 'a' && c <= 'f') n = c - 'a' + 10;
        else return 0;
        *v = (*v << 4) | n;
    }
    return 1;
}
int main(int argc, char **argv) {
    if (argc != 4 || (strcmp(argv[1], "mark") && strcmp(argv[1], "state")) || strlen(argv[2]) != 16) {
        fputs("Usage: check-log mark|state NONCE LOG\n", stderr); return 2;
    }
    probe_u64 nonce;
    if (!hexword(argv[2], &nonce) || !nonce) return 2;
    FILE *f = fopen(argv[3], "r");
    if (!f) { perror(argv[3]); return 2; }
    int state = !strcmp(argv[1], "state"), found = 0, bad = 0;
    const char *prefix = state ? "IOMARCHY_STATE_V1 " : "IOMARCHY_MARK_V1 ";
    char line[2048];
    probe_u64 result[PROBE_WORDS] = {0};
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "IOMARCHY_RAMPROBE_GUARD_FAILED")) bad = 1;
        char *p = strstr(line, prefix);
        if (!p) continue;
        if (++found > 1) { bad = 1; continue; }
        p += strlen(prefix);
        if (strlen(p) < PROBE_WORDS * 17 - 1) { bad = 1; continue; }
        for (unsigned i = 0; i < PROBE_WORDS; ++i) {
            if (!hexword(p, &result[i])) bad = 1;
            p += 16;
            if (i + 1 < PROBE_WORDS && *p++ != ' ') bad = 1;
        }
        while (*p == '\r' || *p == '\n') ++p;
        if (*p) bad = 1;
    }
    if (ferror(f)) bad = 1;
    fclose(f);
    if (found != 1 || bad || result[0] != PROBE_MAGIC || result[1] != 2 || result[2] != nonce ||
        !result[11] || (result[11] & 15)) {
        fputs("FAIL: no unique, complete RAM readback for this nonce\n", stderr); return 1;
    }
    for (unsigned i = 12; i < PROBE_WORDS; ++i) if (result[i]) return 1;
    if (state) {
        if ((result[3] != 4 && result[3] != 8 && result[3] != 12) || !result[6] ||
            (result[6] & 3) || !result[7] || (result[7] & 3) || !result[5] || (result[5] & 15)) return 1;
        printf("PASS: state readback nonce=%016llx EL%llu SCTLR=%016llx MMU=%llu D-cache=%llu I-cache=%llu\n",
               nonce, result[3] >> 2, result[4], result[4] & 1, (result[4] >> 2) & 1, (result[4] >> 12) & 1);
    } else {
        for (unsigned i = 3; i < 11; ++i) if (result[i]) return 1;
        printf("PASS: RAM marker readback nonce=%016llx\n", nonce);
    }
    return 0;
}
