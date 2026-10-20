/* SPDX-License-Identifier: MIT
 * Execute the actual packed module using the pinned loader's segment/symbol/
 * relocation algorithm and simulated Pongo console exports. QEMU virt only;
 * PL011 at 0x09000000 below is emphatically NOT an A8 UART driver.
 */
#include "probe.h"
typedef unsigned int u32;
extern const unsigned char packed_module[], packed_module_end[];
static _Alignas(16384) unsigned char module_memory[16384];
static void (*mark_handler)(const char *, char *);
static void (*state_handler)(const char *, char *);
static unsigned lines;
static unsigned long long get64(const unsigned char *p) {
    unsigned long long n=0; for (unsigned i=0;i<8;++i) n|=(unsigned long long)p[i]<<(8*i); return n;
}
static u32 get32(const unsigned char *p) {
    u32 n=0; for (unsigned i=0;i<4;++i) n|=(u32)p[i]<<(8*i); return n;
}
static void put64(unsigned char *p, probe_u64 n) { for (unsigned i=0;i<8;++i) p[i]=(unsigned char)(n>>(8*i)); }
static int same(const char *a, const char *b) { while (*a && *a==*b) {++a;++b;} return *a==*b; }
static void output(const char *s) {
    while (*s) {
        while (*(volatile u32 *)0x09000018 & 0x20) {}
        *(volatile u32 *)0x09000000=(unsigned char)*s++;
    }
    *(volatile u32 *)0x09000000='\n';
}
static void console(const char *s) { output(s); ++lines; }
static void reg(const char *name, const char *help, void (*fn)(const char *,char *)) {
    (void)help;
    if (same(name,"rammark")) mark_handler=fn;
    if (same(name,"ramstate")) state_handler=fn;
}
static __attribute__((noreturn)) void finish(int bad) {
    output(bad?"EMULATION_ONLY_FAIL":"EMULATION_ONLY_PASS");
    probe_u64 args[2]={0x20026,(unsigned)bad};
    register probe_u64 x0 __asm__("x0")=0x20;
    register probe_u64 x1 __asm__("x1")=(probe_u64)args;
    __asm__ volatile("hlt #0xf000" : "+r"(x0),"+r"(x1) :: "memory");
    for (;;) {}
}
static void require(int ok) { if (!ok) finish(1); }
static int range(probe_u64 offset, probe_u64 size, probe_u64 limit) { return offset<=limit && size<=limit-offset; }
void test_main(void) {
    const unsigned char *f=packed_module;
    probe_u64 file_size=(probe_u64)(packed_module_end-packed_module);
    require(file_size>=0x4000 && get32(f)==0xfeedfacf && get32(f+12)==0xb && get32(f+16)==3);
    const unsigned char *seg=f+32, *sym=seg+72, *dys=sym+24;
    require(get32(seg)==0x19 && get32(sym)==2 && get32(dys)==0xb);
    probe_u64 vm=get64(seg+24), memsz=get64(seg+32), off=get64(seg+40), len=get64(seg+48);
    require(!vm && memsz==sizeof(module_memory) && len<=memsz && range(off,len,file_size));
    for (unsigned i=0;i<sizeof(module_memory);++i) module_memory[i]=0;
    for (unsigned i=0;i<len;++i) module_memory[i]=f[off+i];
    probe_u64 symoff=get32(sym+8), count=get32(sym+12), stroff=get32(sym+16), strsize=get32(sym+20);
    require(count==5 && range(symoff,count*16,file_size) && range(stroff,strsize,file_size));
    probe_u64 entry=0, module_name=0, exports=0;
    for (unsigned i=0;i<count;++i) {
        const unsigned char *n=f+symoff+i*16;
        u32 strx=get32(n); require(strx<strsize);
        const char *name=(const char *)(f+stroff+strx);
        if (same(name,"_module_entry")) entry=get64(n+8);
        if (same(name,"_module_name")) module_name=get64(n+8);
        if (same(name,"_exported_symbols")) exports=get64(n+8);
    }
    for (unsigned type=0;type<2;++type) {
        u32 rel_off=get32(dys+(type?72:64)), rel_count=get32(dys+(type?76:68));
        require(rel_count==(type?1:2) && range(rel_off,rel_count*8,file_size));
        for (unsigned i=0;i<rel_count;++i) {
            const unsigned char *r=f+rel_off+i*8;
            u32 address=get32(r), flags=get32(r+4);
            require(range(address,8,memsz) && ((flags>>25)&3)==3 && ((flags>>27)&1)==!type);
            if (type) put64(module_memory+address,get64(module_memory+address)+(probe_u64)module_memory);
            else {
                u32 index=flags&0xffffff; require(index<count);
                const unsigned char *n=f+symoff+index*16;
                const char *name=(const char *)(f+stroff+get32(n));
                probe_u64 value=0;
                if (same(name,"_command_puts")) value=(probe_u64)console;
                if (same(name,"_command_register")) value=(probe_u64)reg;
                require(value!=0); put64(module_memory+address,value);
            }
        }
    }
    require(range(module_name,8,memsz) && range(exports,16,memsz) && entry<len);
    require(same((const char *)get64(module_memory+module_name),"iOMARCHY RAM probe v1"));
    require(!get64(module_memory+exports) && !get64(module_memory+exports+8));
    __asm__ volatile("dsb sy; ic iallu; dsb sy; isb" ::: "memory");
    ((void (*)(void))(module_memory+entry))();
    require(mark_handler && state_handler);
    unsigned before=lines;
    mark_handler("rammark","0123456789abcdef");
    require(lines==before+1);
    state_handler("ramstate","0123456789abcdef");
    require(lines==before+2);
    /* Invalid/short/zero/trailing nonce must be rejected without execution. */
    mark_handler("rammark","");
    mark_handler("rammark","0000000000000000");
    mark_handler("rammark","0123456789abcdefx");
    finish(0);
}
