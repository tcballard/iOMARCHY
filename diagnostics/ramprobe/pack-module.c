/* SPDX-License-Identifier: MIT
 * Minimal MH_KEXT_BUNDLE writer for the pinned Pongo loader, not a general
 * Mach-O linker. Takes a fully linked position-independent ELF-derived binary
 * and symbol offsets. The diagnostic deliberately uses one RWX allocation.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
static unsigned char image[0xc000];
static void put32(size_t p, uint32_t v) { for (unsigned i=0; i<4; ++i) image[p+i]=(unsigned char)(v>>(8*i)); }
static void put64(size_t p, uint64_t v) { for (unsigned i=0; i<8; ++i) image[p+i]=(unsigned char)(v>>(8*i)); }
static uint64_t get64(size_t p) { uint64_t v=0; for (unsigned i=0; i<8; ++i) v|=(uint64_t)image[p+i]<<(8*i); return v; }
static void fail(const char *s) { fprintf(stderr,"pack-module: %s\n",s); exit(1); }
static uint64_t number(const char *s) {
    char *end; errno=0; unsigned long long n=strtoull(s,&end,16);
    if (!*s || *end || errno) fail("invalid symbol value");
    return n;
}
int main(int argc, char **argv) {
    if (argc!=10) fail("usage: INPUT OUTPUT ENTRY NAME EXPORTS PUTS REGISTER END CODE_END");
    uint64_t entry=number(argv[3]), name=number(argv[4]), exports=number(argv[5]);
    uint64_t puts_slot=number(argv[6]), register_slot=number(argv[7]);
    uint64_t mem_end=number(argv[8]), code_end=number(argv[9]);
    FILE *in=fopen(argv[1],"rb"); if (!in) fail("cannot open input");
    size_t size=fread(image+0x4000,1,0x4000,in);
    if (ferror(in) || !feof(in) || !size) fail("empty or oversized module");
    fclose(in);
    if (mem_end>0x4000 || mem_end<size || entry>=code_end || code_end>size || (entry&3) ||
        name+8>size || (name&7) || exports+16>mem_end || (exports&7) ||
        puts_slot+8>size || (puts_slot&7) || register_slot+8>size || (register_slot&7) ||
        puts_slot==register_slot || puts_slot==name || register_slot==name ||
        get64(0x4000+name)>=size || get64(0x4000+puts_slot) || get64(0x4000+register_slot)) fail("bad module layout");
    put32(0,0xfeedfacf); put32(4,0x100000c); put32(8,0); put32(12,0xb);
    put32(16,3); put32(20,72+24+80);
    size_t p=32;
    put32(p,0x19); put32(p+4,72); memcpy(image+p+8,"__TEXT",6);
    put64(p+24,0); put64(p+32,0x4000); put64(p+40,0x4000); put64(p+48,size);
    put32(p+56,7); put32(p+60,7);
    p+=72;
    const size_t symoff=0x8000, stroff=symoff+5*16, reloff=0x8400;
    const char *symbols[]={"_module_entry","_module_name","_exported_symbols","_command_puts","_command_register"};
    uint64_t values[]={entry,name,exports,0,0};
    size_t strsize=1;
    for (unsigned i=0; i<5; ++i) {
        size_t n=symoff+i*16;
        put32(n,(uint32_t)strsize); image[n+4]=i<3?0x0f:0x01; image[n+5]=i<3?1:0;
        put64(n+8,values[i]);
        size_t len=strlen(symbols[i])+1;
        memcpy(image+stroff+strsize,symbols[i],len); strsize+=len;
    }
    put32(p,2); put32(p+4,24); put32(p+8,symoff); put32(p+12,5);
    put32(p+16,stroff); put32(p+20,(uint32_t)strsize); p+=24;
    put32(p,0xb); put32(p+4,80);
    put32(p+16,0); put32(p+20,3); put32(p+24,3); put32(p+28,2);
    put32(p+64,reloff); put32(p+68,2); put32(p+72,reloff+16); put32(p+76,1);
    /* Absolute 64-bit external pointers and one local pointer slide. */
    put32(reloff,(uint32_t)puts_slot); put32(reloff+4,3|(3u<<25)|(1u<<27));
    put32(reloff+8,(uint32_t)register_slot); put32(reloff+12,4|(3u<<25)|(1u<<27));
    put32(reloff+16,(uint32_t)name); put32(reloff+20,1|(3u<<25));
    FILE *out=fopen(argv[2],"wb"); if (!out) fail("cannot open output");
    if (fwrite(image,1,reloff+24,out)!=reloff+24 || fclose(out)) fail("write failed");
    return 0;
}
