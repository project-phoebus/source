|
| mmu/sau8/mmu_asm.s - MMU_ASM, the SAU8's MMU routines: the DN3000's
| MMU and the optional MC68851 PMMU, for the forward-table VM
|
| SAU8 map: "D 3C256A4 MMU_ASM size = 7EC" (WIRED_DATA).  This file
| holds the segment from its start to MMU_$MCR_CHANGE's end, 0x7DC bytes
| (0x3C256A4..0x3C25E80); the last 0x10 bytes are CACHE_$CLEAR and
| CACHE_$FLUSH_VIRTUAL, CACHE's (cache/m68k/clear.s, cache/m68k/
| flush_virtual.s, the SAU2's bytes).
|
| The SAU9's MMU_ASM (mmu/sau9/mmu_asm.s, whose description of the
| translation tree applies: a root table per ASID in RARS, 8-byte segment
| descriptors in SMAPS, 32 page descriptors per segment's page map) for
| a machine with or without the MC68851 (MMU_$HAVE_PMMU, set at boot):
| - the segment layout is the run-time one (`run_time_layout'): with the
|   PMMU the global segments' descriptors are 0x200 further into SMAPS,
|   the special segments' range and the per-ASID SMAPS stride (0xE800
|   against 0x3400) are the PMMU's, and the valid VA ranges end at
|   0x0F000000 (against GLOBAL_B's 0x03A00000);
| - without the PMMU the translations are the DN3000 MMU's: written and
|   flushed through the function-code space (`moves' at 0, 0x08000000,
|   0x0C000000; bit 22 of the MMU's control word around a descriptor's
|   update), the root table by its address shifted into the MMU's
|   register; with it, `pmove crp' and `pflusha' / `pflushs';
| - MMU_$INSTALL_ASID sets or clears the FPU's enable in the CPU control
|   register (MMU + 0x101) with its copy MMU_$PID_PRIV, as the FP owner
|   switch does (`fpu_enable_cpu_control'), then installs the root table;
| - MMU_$SET_SYSREV takes the revision from bit 14 of the CPU status
|   register, MMU_$NORMAL_MODE from bit 0 of MMU + 1, and MMU_$MCR_CHANGE
|   toggles MMU_$PID_PRIV's high byte into MMU + 0x100.
|
| Hand-written (an `_ASM' segment in a data section, code and data mixed,
| no frame, the arguments read off SP, register-called local entries,
| the saved SR kept in D6 across them).  The labels without a map name
| keep the image address they stand at, but for the entries the
| routines share (mmu_$locate and the like, the SAU9 file's names).
|
| The image's immediate-to-register `cmp', `and', `or', `add' and `sub'
| use the EA-immediate forms (0xB0BC and the like), its `mulu.l #imm,Dn'
| names Dn twice in the extension word, and `pflushs' (the MC68851's
| shared-globally flush) gas does not encode: those are `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau8 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU8 image's.
|

        .section ".text.MMU_ASM.WIRED_DATA","ax",@progbits
        .even

        .globl  MMU_$PID_PRIV
        .globl  MMU_$OS_PMAPS_PHADDR
        .globl  MMU_$RARS_PHADDR
        .globl  MMU_$HAVE_PMMU
        .globl  MMU_$INSTALL_SPECIAL
        .globl  MMU_$REMOVE_SPECIAL_SEG
        .globl  MMU_$REMOVE
        .globl  MMU_$CACHE_INHIBIT_VA
        .globl  MMU_$INSTALL
        .globl  MMU_$VTOP
        .globl  MMU_$GET_PMAPE_ADDR
        .globl  MMU_$SET_PMAPE
        .globl  MMU_$INSTALL_ASID
        .globl  MMU_$PAGE_WRITE_BIT
        .globl  MMU_$PURGE_TB
        .globl  MMU_$PURGE
        .globl  MMU_$SET_SEG_PROT
        .globl  MMU_$SYSTEM_REV
        .globl  MMU_$SET_SYSREV
        .globl  MMU_$NORMAL_MODE
        .globl  MMU_$POWER_OFF
        .globl  MMU_$MCR_CHANGE

| ---- The data -------------------------------------------------------

MMU_$PID_PRIV:                          | 0x3C256A4
        .word   0                       | the CPU control register's copy:
                                        |   the PID (high byte) and the
                                        |   control bits (low byte, at MMU
                                        |   + 0x101; bit 2 the FPU's enable,
                                        |   `fpu_enable_cpu_control')
mmu_$crp:                               | 0x3C256A6
        .long   0x007F0002              | the CPU root pointer for `pmove':
mmu_$crp_root:                          |   limit 0x7F, a valid 8-byte
        .long   0                       |   table; the current ASID's root
                                        |   table (MMU_$INSTALL_ASID)
MMU_$OS_PMAPS_PHADDR:                   | 0x3C256AE
        .long   0                       | OS_PMAPS's physical address (set
                                        |   at boot)
MMU_$RARS_PHADDR:                       | 0x3C256B2
        .fill   58, 4, 0                | each ASID's root table's physical
                                        |   address (MST_$INIT,
                                        |   MST_$ALLOC_ASID)
MMU_$HAVE_PMMU:                         | 0x3C2579A
        .byte   0                       | the MC68851 is fitted (a boolean,
        .byte   0                       |   set at boot), a pad byte


mmu_$locate:
        clr.l   %d1                             | 3c2579c  4281
        move.l  #-0x8000,%d2                    | 3c2579e  243c ffff 8000
        movea.l #OS_PMAPS,%a2                   | 3c257a4  247c 03ce c800
        movea.l #SMAPS+0x600,%a0                | 3c257aa  207c 03cf 3600
        tst.b   (MMU_$HAVE_PMMU).l              | 3c257b0  4a39 03c2 579a
        bne.w   mmu_$locate_pmmu                | 3c257b6  6600 0066
        and.l   %d4,%d2                         | 3c257ba  c484
        beq.s   .L3c257c8                       | 3c257bc  670a
        .short  0xb4bc, 0x03a0, 0x0000          | 3c257be  b4bc 03a0 0000  cmp.l #0x3a00000,%d2 (<ea>=#imm form)
        bge.s   .L3c257d8                       | 3c257c4  6c12
        bra.s   mmu_$bad_va                     | 3c257c6  603a
.L3c257c8:
        adda.l  #0x6000,%a2                     | 3c257c8  d5fc 0000 6000
        adda.l  #0x600,%a0                      | 3c257ce  d1fc 0000 0600
        bset    #0,%d1                          | 3c257d4  08c1 0000
.L3c257d8:
        move.l  %d4,%d2                         | 3c257d8  2404
        lsr.l   #8,%d2                          | 3c257da  e08a
        moveq   #0x7c,%d3                       | 3c257dc  767c
        and.w   %d2,%d3                         | 3c257de  c642
        lsr.l   #4,%d2                          | 3c257e0  e88a
        .short  0xc4bc, 0x0000, 0x07f8          | 3c257e2  c4bc 0000 07f8  and.l #0x7f8,%d2 (<ea>=#imm form)
        btst    #0,%d1                          | 3c257e8  0801 0000
        bne.s   .L3c257f4                       | 3c257ec  6606
        .short  0x94bc, 0x0000, 0x0200          | 3c257ee  94bc 0000 0200  sub.l #0x200,%d2 (<ea>=#imm form)
.L3c257f4:
        adda.l  %d2,%a0                         | 3c257f4  d1c2
        lsl.l   #4,%d2                          | 3c257f6  e98a
        adda.l  %d2,%a2                         | 3c257f8  d5c2
mmu_$locate_done:
        move.w  %sr,%d6                         | 3c257fa  40c6
        ori.w   #0x700,%sr                      | 3c257fc  007c 0700
        rts                                     | 3c25800  4e75
mmu_$bad_va:
        pea     (mmu_$st_bad_va,%pc)            | 3c25802  487a 0012
        bra.s   mmu_$crash                      | 3c25806  6006
mmu_$no_os_pmap:
        pea     (mmu_$st_no_os_pmap,%pc)        | 3c25808  487a 0010
        move.w  %d6,%sr                         | 3c2580c  46c6
mmu_$crash:
        jsr     (CRASH_SYSTEM).l                | 3c2580e  4eb9 03c1 ff00
        bra.s   mmu_$crash                      | 3c25814  60f8
mmu_$st_bad_va:
        .long   0x00070002                      | 3c25816  0007 0002
mmu_$st_no_os_pmap:
        .long   0x00070003                      | 3c2581a  0007 0003
mmu_$locate_pmmu:
        adda.l  #0x200,%a0                      | 3c2581e  d1fc 0000 0200
        and.l   %d4,%d2                         | 3c25824  c484
        beq.s   .L3c25832                       | 3c25826  670a
        .short  0xb4bc, 0x0f00, 0x0000          | 3c25828  b4bc 0f00 0000  cmp.l #0xf000000,%d2 (<ea>=#imm form)
        bge.s   .L3c25842                       | 3c2582e  6c12
        bra.s   mmu_$bad_va                     | 3c25830  60d0
.L3c25832:
        adda.l  #0x10000,%a2                    | 3c25832  d5fc 0001 0000
        adda.l  #0x1000,%a0                     | 3c25838  d1fc 0000 1000
        bset    #0,%d1                          | 3c2583e  08c1 0000
.L3c25842:
        move.l  %d4,%d2                         | 3c25842  2404
        lsr.l   #8,%d2                          | 3c25844  e08a
        moveq   #0x7c,%d3                       | 3c25846  767c
        and.w   %d2,%d3                         | 3c25848  c642
        lsr.l   #4,%d2                          | 3c2584a  e88a
        .short  0xc4bc, 0x0000, 0x0ff8          | 3c2584c  c4bc 0000 0ff8  and.l #0xff8,%d2 (<ea>=#imm form)
        btst    #0,%d1                          | 3c25852  0801 0000
        bne.s   .L3c2585e                       | 3c25856  6606
        .short  0x94bc, 0x0000, 0x0000          | 3c25858  94bc 0000 0000  sub.l #0,%d2 (<ea>=#imm form)
.L3c2585e:
        adda.l  %d2,%a0                         | 3c2585e  d1c2
        lsl.l   #4,%d2                          | 3c25860  e98a
        adda.l  %d2,%a2                         | 3c25862  d5c2
        bra.s   mmu_$locate_done                | 3c25864  6094
MMU_$INSTALL_SPECIAL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c25866  48e7 3b20
        move.l  (0x20,%sp),%d4                  | 3c2586a  282f 0020
        movea.l #SMAPS,%a0                      | 3c2586e  207c 03cf 3000
        clr.l   %d7                             | 3c25874  4287
        move.w  (0x24,%sp),%d7                  | 3c25876  3e2f 0024
        beq.s   mmu_$bad_va                     | 3c2587a  6786
        move.l  #-0x8000,%d2                    | 3c2587c  243c ffff 8000
        and.l   %d4,%d2                         | 3c25882  c484
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25884  4a39 03c2 579a
        beq.s   .L3c25892                       | 3c2588a  6706
        .short  0x94bc, 0x0b60, 0x0000          | 3c2588c  94bc 0b60 0000  sub.l #0xb600000,%d2 (<ea>=#imm form)
.L3c25892:
        .short  0x94bc, 0x0398, 0x0000          | 3c25892  94bc 0398 0000  sub.l #0x3980000,%d2 (<ea>=#imm form)
        lsr.l   #8,%d2                          | 3c25898  e08a
        lsr.l   #7,%d2                          | 3c2589a  ee8a
        .short  0xb4bc, 0x0000, 0x0008          | 3c2589c  b4bc 0000 0008  cmp.l #8,%d2 (<ea>=#imm form)
        bcc.w   mmu_$bad_va                     | 3c258a2  6400 ff5e
        lsl.l   #3,%d2                          | 3c258a6  e78a
        tst.b   (MMU_$HAVE_PMMU).l              | 3c258a8  4a39 03c2 579a
        beq.s   .L3c258c0                       | 3c258ae  6710
        .short  0x4c3c, 0x7007, 0x0000, 0xe800  | 3c258b0  4c3c 7007 0000 e800  mulu.l #0xe800,%d7
        .short  0xdebc, 0x0000, 0xe780          | 3c258b8  debc 0000 e780  add.l #0xe780,%d7 (<ea>=#imm form)
        bra.s   .L3c258ce                       | 3c258be  600e
.L3c258c0:
        .short  0x4c3c, 0x7007, 0x0000, 0x3400  | 3c258c0  4c3c 7007 0000 3400  mulu.l #0x3400,%d7
        .short  0xdebc, 0x0000, 0x3380          | 3c258c8  debc 0000 3380  add.l #0x3380,%d7 (<ea>=#imm form)
.L3c258ce:
        adda.l  %d7,%a0                         | 3c258ce  d1c7
        adda.l  %d2,%a0                         | 3c258d0  d1c2
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c258d2  247c 03cf 2880
        lsl.l   #4,%d2                          | 3c258d8  e98a
        adda.l  %d2,%a2                         | 3c258da  d5c2
        move.l  %d4,%d2                         | 3c258dc  2404
        lsr.l   #8,%d2                          | 3c258de  e08a
        move.w  #0x7c,%d3                       | 3c258e0  363c 007c
        and.w   %d2,%d3                         | 3c258e4  c642
        move.w  %sr,%d6                         | 3c258e6  40c6
        ori.w   #0x700,%sr                      | 3c258e8  007c 0700
        bra.w   mmu_$install_entry              | 3c258ec  6000 0102
MMU_$REMOVE_SPECIAL_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | 3c258f0  48e7 2b20
        move.l  (0x18,%sp),%d4                  | 3c258f4  282f 0018
        movea.l #SMAPS,%a0                      | 3c258f8  207c 03cf 3000
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c258fe  247c 03cf 2880
        move.l  %d4,%d2                         | 3c25904  2404
        lsr.l   #8,%d2                          | 3c25906  e08a
        lsr.l   #7,%d2                          | 3c25908  ee8a
        lsl.l   #3,%d2                          | 3c2590a  e78a
        clr.l   %d7                             | 3c2590c  4287
        move.w  (0x1c,%sp),%d7                  | 3c2590e  3e2f 001c
        beq.s   .L3c25964                       | 3c25912  6750
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25914  4a39 03c2 579a
        beq.s   .L3c2593c                       | 3c2591a  6720
        .short  0x94bc, 0x0000, 0xef80          | 3c2591c  94bc 0000 ef80  sub.l #0xef80,%d2 (<ea>=#imm form)
        .short  0xb4bc, 0x0000, 0x0040          | 3c25922  b4bc 0000 0040  cmp.l #0x40,%d2 (<ea>=#imm form)
        bcc.w   mmu_$bad_va                     | 3c25928  6400 fed8
        .short  0x4c3c, 0x7007, 0x0000, 0xe800  | 3c2592c  4c3c 7007 0000 e800  mulu.l #0xe800,%d7
        .short  0xdebc, 0x0000, 0xe780          | 3c25934  debc 0000 e780  add.l #0xe780,%d7 (<ea>=#imm form)
        bra.s   .L3c2595a                       | 3c2593a  601e
.L3c2593c:
        .short  0x94bc, 0x0000, 0x3980          | 3c2593c  94bc 0000 3980  sub.l #0x3980,%d2 (<ea>=#imm form)
        .short  0xb4bc, 0x0000, 0x0040          | 3c25942  b4bc 0000 0040  cmp.l #0x40,%d2 (<ea>=#imm form)
        bcc.w   mmu_$bad_va                     | 3c25948  6400 feb8
        .short  0x4c3c, 0x7007, 0x0000, 0x3400  | 3c2594c  4c3c 7007 0000 3400  mulu.l #0x3400,%d7
        .short  0xdebc, 0x0000, 0x3380          | 3c25954  debc 0000 3380  add.l #0x3380,%d7 (<ea>=#imm form)
.L3c2595a:
        add.l   %d2,%d7                         | 3c2595a  de82
        adda.l  %d7,%a0                         | 3c2595c  d1c7
        lsl.l   #4,%d2                          | 3c2595e  e98a
        adda.l  %d2,%a2                         | 3c25960  d5c2
        bra.s   .L3c25982                       | 3c25962  601e
.L3c25964:
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25964  4a39 03c2 579a
        beq.s   .L3c25974                       | 3c2596a  6708
        adda.l  #0x1800,%a0                     | 3c2596c  d1fc 0000 1800
        bra.s   .L3c2597a                       | 3c25972  6006
.L3c25974:
        adda.l  #0xc00,%a0                      | 3c25974  d1fc 0000 0c00
.L3c2597a:
        .short  0xc4bc, 0x0000, 0x01f8          | 3c2597a  c4bc 0000 01f8  and.l #0x1f8,%d2 (<ea>=#imm form)
        adda.l  %d2,%a0                         | 3c25980  d1c2
.L3c25982:
        move.w  %sr,%d6                         | 3c25982  40c6
        ori.w   #0x700,%sr                      | 3c25984  007c 0700
        andi.l  #-4,(%a0)                       | 3c25988  0290 ffff fffc
        move.w  (0x1e,%sp),%d0                  | 3c2598e  302f 001e
        bra.s   .L3c25996                       | 3c25992  6002
        nop                                     | 3c25994  4e71
.L3c25996:
        tst.w   %d0                             | 3c25996  4a40
        beq.s   .L3c259b2                       | 3c25998  6718
        move.w  #0x1f,%d1                       | 3c2599a  323c 001f
.L3c2599e:
        btst    #0,(3,%a2)                      | 3c2599e  082a 0000 0003
        beq.s   .L3c259ac                       | 3c259a4  6706
        bclr    #0,(3,%a2)                      | 3c259a6  08aa 0000 0003
.L3c259ac:
        addq.l  #4,%a2                          | 3c259ac  588a
        dbf     %d1,.L3c2599e                   | 3c259ae  51c9 ffee
.L3c259b2:
        bsr.w   MMU_$PURGE                      | 3c259b2  6100 03ec
        move.w  %d6,%sr                         | 3c259b6  46c6
        movem.l (%sp)+,%d2/%d4/%d6-%d7/%a2      | 3c259b8  4cdf 04d4
        rts                                     | 3c259bc  4e75
MMU_$REMOVE:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c259be  48e7 3a20
        move.l  (0x18,%sp),%d4                  | 3c259c2  282f 0018
        bsr.w   mmu_$locate                     | 3c259c6  6100 fdd4
        bsr.s   mmu_$invalidate                 | 3c259ca  6108
        move.w  %d6,%sr                         | 3c259cc  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c259ce  4cdf 045c
        rts                                     | 3c259d2  4e75
mmu_$invalidate:
        bclr    #0,(3,%a2,%d3.w)                | 3c259d4  08b2 0000 3003
        bra.w   MMU_$PURGE                      | 3c259da  6000 03c4
MMU_$CACHE_INHIBIT_VA:
        rts                                     | 3c259de  4e75
MMU_$INSTALL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c259e0  48e7 3b20
        move.l  (0x20,%sp),%d4                  | 3c259e4  282f 0020
        bsr.w   mmu_$locate                     | 3c259e8  6100 fdb2
        move.w  (0x24,%sp),%d7                  | 3c259ec  3e2f 0024
mmu_$install_entry:
        moveq   #3,%d1                          | 3c259f0  7203
        and.l   (%a0),%d1                       | 3c259f2  c290
        .short  0xb27c, 0x0002                  | 3c259f4  b27c 0002  cmp.w #2,%d1 (<ea>=#imm form)
        bne.s   .L3c25a08                       | 3c259f8  660e
        move.l  (4,%a0),%d2                     | 3c259fa  2428 0004
        .short  0xc4bc, 0xffff, 0xfff0          | 3c259fe  c4bc ffff fff0  and.l #-0x10,%d2 (<ea>=#imm form)
        movea.l %d2,%a1                         | 3c25a04  2242
        bra.s   .L3c25a14                       | 3c25a06  600c
.L3c25a08:
        movea.l %a2,%a1                         | 3c25a08  224a
        suba.l  #OS_PMAPS,%a1                   | 3c25a0a  93fc 03ce c800
        adda.l  (MMU_$OS_PMAPS_PHADDR,%pc),%a1  | 3c25a10  d3fa fc9c
.L3c25a14:
        clr.l   %d1                             | 3c25a14  4281
        clr.l   %d1                             | 3c25a16  4281
        move.b  (0x27,%sp),%d1                  | 3c25a18  122f 0027
        move.l  %d1,%d2                         | 3c25a1c  2401
        .short  0xc2bc, 0x0000, 0x000f          | 3c25a1e  c2bc 0000 000f  and.l #0xf,%d1 (<ea>=#imm form)
        add.l   %a1,%d1                         | 3c25a24  d289
        move.l  %d1,(4,%a0)                     | 3c25a26  2141 0004
        move.l  #0x1f0102,%d1                   | 3c25a2a  223c 001f 0102
        btst    #4,%d2                          | 3c25a30  0802 0004
        bne.s   .L3c25a3c                       | 3c25a34  6606
        move.l  #0x1f0002,%d1                   | 3c25a36  223c 001f 0002
.L3c25a3c:
        btst    #2,%d2                          | 3c25a3c  0802 0002
        bne.s   .L3c25a46                       | 3c25a40  6604
        bset    #2,%d1                          | 3c25a42  08c1 0002
.L3c25a46:
        tst.w   %d7                             | 3c25a46  4a47
        bne.s   .L3c25a4e                       | 3c25a48  6604
        bset    #9,%d1                          | 3c25a4a  08c1 0009
.L3c25a4e:
        move.l  %d1,(%a0)                       | 3c25a4e  2081
        btst    #0,(3,%a2,%d3.w)                | 3c25a50  0832 0000 3003
        beq.s   .L3c25a5c                       | 3c25a56  6704
        bsr.w   mmu_$invalidate                 | 3c25a58  6100 ff7a
.L3c25a5c:
        move.l  (0x1c,%sp),%d0                  | 3c25a5c  202f 001c
        lsl.l   #8,%d0                          | 3c25a60  e188
        lsl.l   #2,%d0                          | 3c25a62  e588
        bset    #0,%d0                          | 3c25a64  08c0 0000
        move.l  %d0,(0,%a2,%d3.w)               | 3c25a68  2580 3000
        move.w  %d6,%sr                         | 3c25a6c  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c25a6e  4cdf 04dc
        rts                                     | 3c25a72  4e75
MMU_$VTOP:
        movem.l %d2-%d7/%a2,-(%sp)              | 3c25a74  48e7 3f20
        move.l  (0x20,%sp),%d4                  | 3c25a78  282f 0020
        movea.l (0x24,%sp),%a0                  | 3c25a7c  206f 0024
        subq.w  #2,%sp                          | 3c25a80  554f
        move.w  (PROC1_$AS_ID).l,-(%sp)         | 3c25a82  3f39 03c2 1e42
        pea     (2,%sp)                         | 3c25a88  486f 0002
        move.l  %d4,-(%sp)                      | 3c25a8c  2f04
        jsr     (MST_$VA_TO_SEGNO).l            | 3c25a8e  4eb9 03c0 eccc
        lea     (0xa,%sp),%sp                   | 3c25a94  4fef 000a
        clr.l   %d5                             | 3c25a98  4285
        move.w  (%sp)+,%d5                      | 3c25a9a  3a1f
        .short  0xb07c, 0x003a                  | 3c25a9c  b07c 003a  cmp.w #0x3a,%d0 (<ea>=#imm form)
        bcs.s   .L3c25aac                       | 3c25aa0  650a
        move.l  #0x40004,%d3                    | 3c25aa2  263c 0004 0004
        bra.w   .L3c25ba0                       | 3c25aa8  6000 00f6
.L3c25aac:
        clr.l   %d1                             | 3c25aac  4281
        move.w  %d0,%d1                         | 3c25aae  3200
        move.l  %d1,%d2                         | 3c25ab0  2401
        move.l  (0x20,%sp),%d4                  | 3c25ab2  282f 0020
        move.w  %sr,%d6                         | 3c25ab6  40c6
        ori.w   #0x700,%sr                      | 3c25ab8  007c 0700
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25abc  4a39 03c2 579a
        bne.w   mmu_$vtop_pmmu                  | 3c25ac2  6600 00f2
        lsl.w   #7,%d2                          | 3c25ac6  ef4a
        lea     (SMAPS_END).l,%a0               | 3c25ac8  41f9 03da f800
        lea     (0,%a0,%d2.l),%a1               | 3c25ace  43f0 2800
        move.l  %d4,%d2                         | 3c25ad2  2404
        swap    %d2                             | 3c25ad4  4842
        .short  0xc47c, 0x03e0                  | 3c25ad6  c47c 03e0  and.w #0x3e0,%d2 (<ea>=#imm form)
        moveq   #3,%d3                          | 3c25ada  7603
        lsr.w   #3,%d2                          | 3c25adc  e64a
        and.b   (3,%a1,%d2.w),%d3               | 3c25ade  c631 2003
        .short  0xb67c, 0x0003                  | 3c25ae2  b67c 0003  cmp.w #3,%d3 (<ea>=#imm form)
        bne.w   mmu_$vtop_miss                  | 3c25ae6  6600 00c4
        .short  0x4c3c, 0x1001, 0x0000, 0x3400  | 3c25aea  4c3c 1001 0000 3400  mulu.l #0x3400,%d1
        movea.l #SMAPS,%a0                      | 3c25af2  207c 03cf 3000
        lea     (0,%a0,%d1.l),%a1               | 3c25af8  43f0 1800
        lsl.l   #3,%d5                          | 3c25afc  e78d
        moveq   #3,%d3                          | 3c25afe  7603
        and.b   (3,%a1,%d5.l),%d3               | 3c25b00  c631 5803
        .short  0xb67c, 0x0002                  | 3c25b04  b67c 0002  cmp.w #2,%d3 (<ea>=#imm form)
        bne.l   mmu_$vtop_miss                  | 3c25b08  66ff 0000 00a2
        moveq   #-0x10,%d7                      | 3c25b0e  7ef0
        and.l   (4,%a1,%d5.l),%d7               | 3c25b10  ceb1 5804
        move.l  %d7,%d2                         | 3c25b14  2407
        .short  0xc47c, 0xfc00                  | 3c25b16  c47c fc00  and.w #-0x400,%d2 (<ea>=#imm form)
        move.l  #0xfffc00,%d0                   | 3c25b1a  203c 00ff fc00
        move.l  #VM_TABLES-0x3A00000,%d3        | 3c25b20  263c 003b 7800  (a fixup-table cell)
        move.l  #0xc0,%d1                       | 3c25b26  223c 0000 00c0
        moveq   #-1,%d5                         | 3c25b2c  7aff
.L3c25b2e:
        movea.l #OS_PMAPS,%a2                   | 3c25b2e  247c 03ce c800
        lsr.l   #8,%d3                          | 3c25b34  e08b
        .short  0xc67c, 0xfffc                  | 3c25b36  c67c fffc  and.w #-4,%d3 (<ea>=#imm form)
        adda.l  %d3,%a2                         | 3c25b3a  d5c3
.L3c25b3c:
        move.l  (%a2)+,%d3                      | 3c25b3c  261a
        and.l   %d0,%d3                         | 3c25b3e  c680
        cmp.l   %d2,%d3                         | 3c25b40  b682
        dbeq    %d1,.L3c25b3c                   | 3c25b42  57c9 fff8
        bne.s   .L3c25b54                       | 3c25b46  660c
        btst    #0,(-1,%a2)                     | 3c25b48  082a 0000 ffff
        bne.s   .L3c25b64                       | 3c25b4e  6614
        dbf     %d1,.L3c25b3c                   | 3c25b50  51c9 ffea
.L3c25b54:
        addq.l  #1,%d5                          | 3c25b54  5285
        bne.w   mmu_$no_os_pmap                 | 3c25b56  6600 fcb0
        move.l  #OS_PMAPS-0x3A00000,%d3         | 3c25b5a  263c 002e c800  (a fixup-table cell)
        moveq   #0x18,%d1                       | 3c25b60  7218
        bra.s   .L3c25b2e                       | 3c25b62  60ca
.L3c25b64:
        move.l  %a2,%d1                         | 3c25b64  220a
        .short  0x92bc                          | 3c25b66  92bc 03ce c804  sub.l #OS_PMAPS+4,%d1 (<ea>=#imm form)
        .long   OS_PMAPS+4
        lsr.l   #2,%d1                          | 3c25b6c  e489
        lsl.l   #2,%d1                          | 3c25b6e  e589
        lsl.l   #8,%d1                          | 3c25b70  e189
        .short  0xd2bc, 0x03a0, 0x0000          | 3c25b72  d2bc 03a0 0000  add.l #0x3a00000,%d1 (<ea>=#imm form)
.L3c25b78:
        .short  0xcebc, 0x0000, 0x0380          | 3c25b78  cebc 0000 0380  and.l #0x380,%d7 (<ea>=#imm form)
        add.l   %d7,%d1                         | 3c25b7e  d287
        movea.l %d1,%a0                         | 3c25b80  2041
        lsr.l   #8,%d4                          | 3c25b82  e08c
        .short  0xc87c, 0x007c                  | 3c25b84  c87c 007c  and.w #0x7c,%d4 (<ea>=#imm form)
        move.l  (0,%a0,%d4.w),%d0               | 3c25b88  2030 4000
        btst    #0,%d0                          | 3c25b8c  0800 0000
        beq.s   mmu_$vtop_miss                  | 3c25b90  671a
        lsr.l   #8,%d0                          | 3c25b92  e088
        lsr.l   #2,%d0                          | 3c25b94  e488
        .short  0xc0bc, 0x0000, 0x3fff          | 3c25b96  c0bc 0000 3fff  and.l #0x3fff,%d0 (<ea>=#imm form)
        clr.l   %d3                             | 3c25b9c  4283
mmu_$vtop_done:
        move.w  %d6,%sr                         | 3c25b9e  46c6
.L3c25ba0:
        movea.l (0x24,%sp),%a0                  | 3c25ba0  206f 0024
        move.l  %d3,(%a0)                       | 3c25ba4  2083
        movem.l (%sp)+,%d2-%d7/%a2              | 3c25ba6  4cdf 04fc
        rts                                     | 3c25baa  4e75
mmu_$vtop_miss:
        move.l  #0x70001,%d3                    | 3c25bac  263c 0007 0001
        clr.l   %d0                             | 3c25bb2  4280
        bra.s   mmu_$vtop_done                  | 3c25bb4  60e8
mmu_$vtop_pmmu:
        lsl.l   #7,%d2                          | 3c25bb6  ef8a
        lsl.l   #2,%d2                          | 3c25bb8  e58a
        lea     (SMAPS_END).l,%a0               | 3c25bba  41f9 03da f800
        lea     (0,%a0,%d2.l),%a1               | 3c25bc0  43f0 2800
        move.l  %d4,%d2                         | 3c25bc4  2404
        swap    %d2                             | 3c25bc6  4842
        .short  0xc47c, 0x0fe0                  | 3c25bc8  c47c 0fe0  and.w #0xfe0,%d2 (<ea>=#imm form)
        moveq   #3,%d3                          | 3c25bcc  7603
        lsr.w   #3,%d2                          | 3c25bce  e64a
        and.b   (3,%a1,%d2.w),%d3               | 3c25bd0  c631 2003
        .short  0xb67c, 0x0003                  | 3c25bd4  b67c 0003  cmp.w #3,%d3 (<ea>=#imm form)
        bne.s   mmu_$vtop_miss                  | 3c25bd8  66d2
        .short  0x4c3c, 0x1001, 0x0000, 0xe800  | 3c25bda  4c3c 1001 0000 e800  mulu.l #0xe800,%d1
        movea.l #SMAPS,%a0                      | 3c25be2  207c 03cf 3000
        lea     (0,%a0,%d1.l),%a1               | 3c25be8  43f0 1800
        lsl.l   #3,%d5                          | 3c25bec  e78d
        moveq   #3,%d3                          | 3c25bee  7603
        and.b   (3,%a1,%d5.l),%d3               | 3c25bf0  c631 5803
        .short  0xb67c, 0x0002                  | 3c25bf4  b67c 0002  cmp.w #2,%d3 (<ea>=#imm form)
        bne.w   mmu_$vtop_miss                  | 3c25bf8  6600 ffb2
        moveq   #-0x10,%d7                      | 3c25bfc  7ef0
        and.l   (4,%a1,%d5.l),%d7               | 3c25bfe  ceb1 5804
        move.l  %d7,%d2                         | 3c25c02  2407
        .short  0xc47c, 0xfc00                  | 3c25c04  c47c fc00  and.w #-0x400,%d2 (<ea>=#imm form)
        move.l  #0xfffc00,%d0                   | 3c25c08  203c 00ff fc00
        move.l  #VM_TABLES,%d3                  | 3c25c0e  263c 03db 7800
        .short  0x96bc, 0x0f00, 0x0000          | 3c25c14  96bc 0f00 0000  sub.l #0xf000000,%d3 (<ea>=#imm form)
        move.l  #0xc0,%d1                       | 3c25c1a  223c 0000 00c0
        moveq   #-1,%d5                         | 3c25c20  7aff
.L3c25c22:
        movea.l #OS_PMAPS,%a2                   | 3c25c22  247c 03ce c800
        lsr.l   #8,%d3                          | 3c25c28  e08b
        .short  0xc67c, 0xfffc                  | 3c25c2a  c67c fffc  and.w #-4,%d3 (<ea>=#imm form)
        adda.l  %d3,%a2                         | 3c25c2e  d5c3
.L3c25c30:
        move.l  (%a2)+,%d3                      | 3c25c30  261a
        and.l   %d0,%d3                         | 3c25c32  c680
        cmp.l   %d2,%d3                         | 3c25c34  b682
        dbeq    %d1,.L3c25c30                   | 3c25c36  57c9 fff8
        bne.s   .L3c25c48                       | 3c25c3a  660c
        btst    #0,(-1,%a2)                     | 3c25c3c  082a 0000 ffff
        bne.s   .L3c25c5e                       | 3c25c42  661a
        dbf     %d1,.L3c25c30                   | 3c25c44  51c9 ffea
.L3c25c48:
        addq.l  #1,%d5                          | 3c25c48  5285
        bne.w   mmu_$no_os_pmap                 | 3c25c4a  6600 fbbc
        move.l  #OS_PMAPS,%d3                   | 3c25c4e  263c 03ce c800
        .short  0x96bc, 0x0f00, 0x0000          | 3c25c54  96bc 0f00 0000  sub.l #0xf000000,%d3 (<ea>=#imm form)
        moveq   #0x40,%d1                       | 3c25c5a  7240
        bra.s   .L3c25c22                       | 3c25c5c  60c4
.L3c25c5e:
        move.l  %a2,%d1                         | 3c25c5e  220a
        .short  0x92bc                          | 3c25c60  92bc 03ce c804  sub.l #OS_PMAPS+4,%d1 (<ea>=#imm form)
        .long   OS_PMAPS+4
        lsr.l   #2,%d1                          | 3c25c66  e489
        lsl.l   #2,%d1                          | 3c25c68  e589
        lsl.l   #8,%d1                          | 3c25c6a  e189
        .short  0xd2bc, 0x0f00, 0x0000          | 3c25c6c  d2bc 0f00 0000  add.l #0xf000000,%d1 (<ea>=#imm form)
        bra.w   .L3c25b78                       | 3c25c72  6000 ff04
MMU_$GET_PMAPE_ADDR:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c25c76  48e7 3b20
        move.l  (0x1c,%sp),%d4                  | 3c25c7a  282f 001c
        bsr.w   mmu_$locate                     | 3c25c7e  6100 fb1c
        lea     (0,%a2,%d3.w),%a0               | 3c25c82  41f2 3000
        move.w  %d6,%sr                         | 3c25c86  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c25c88  4cdf 04dc
        rts                                     | 3c25c8c  4e75
MMU_$SET_PMAPE:
        movea.l (4,%sp),%a0                     | 3c25c8e  206f 0004
        bsr.w   mmu_$flush_va                   | 3c25c92  6100 0016
        movea.l (8,%sp),%a0                     | 3c25c96  206f 0008
        move.l  (0xc,%sp),%d0                   | 3c25c9a  202f 000c
        lsl.l   #8,%d0                          | 3c25c9e  e188
        lsl.l   #2,%d0                          | 3c25ca0  e588
        bset    #0,%d0                          | 3c25ca2  08c0 0000
        move.l  %d0,(%a0)                       | 3c25ca6  2080
        rts                                     | 3c25ca8  4e75
mmu_$flush_va:
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25caa  4a39 03c2 579a
        beq.s   .L3c25cb8                       | 3c25cb0  6706
        .short  0xf010, 0x3c10                  | 3c25cb2  f010 3c10  pflushs #0,#0,(%a0)
        bra.s   .L3c25ce4                       | 3c25cb6  602c
.L3c25cb8:
        move.w  %sr,%d1                         | 3c25cb8  40c1
        ori.w   #0x700,%sr                      | 3c25cba  007c 0700
        moves.l (0x0).w,%d0                     | 3c25cbe  0eb8 0000 0000
        bclr    #0x16,%d0                       | 3c25cc4  0880 0016
        moves.l %d0,(0x0).w                     | 3c25cc8  0eb8 0800 0000
        adda.l  #0x4000000,%a0                  | 3c25cce  d1fc 0400 0000
        moves.l %d0,(%a0)                       | 3c25cd4  0e90 0800
        bset    #0x16,%d0                       | 3c25cd8  08c0 0016
        moves.l %d0,(0x0).w                     | 3c25cdc  0eb8 0800 0000
        move.w  %d1,%sr                         | 3c25ce2  46c1
.L3c25ce4:
        rts                                     | 3c25ce4  4e75
MMU_$INSTALL_ASID:
        clr.l   %d0                             | 3c25ce6  4280
        move.w  (4,%sp),%d0                     | 3c25ce8  302f 0004
        cmp.w   (PROC1_$AS_ID).l,%d0            | 3c25cec  b079 03c2 1e42
        beq.w   .L3c25d6a                       | 3c25cf2  6700 0076
        move.w  %d0,(PROC1_$AS_ID).l            | 3c25cf6  33c0 03c2 1e42
        move.w  (MMU_$PID_PRIV,%pc),%d1         | 3c25cfc  323a f9a6
        cmp.w   (FP_$OWNER).l,%d0               | 3c25d00  b079 03c2 3116
        bne.s   .L3c25d0e                       | 3c25d06  6606
        bclr    #2,%d1                          | 3c25d08  0881 0002
        bra.s   .L3c25d12                       | 3c25d0c  6004
.L3c25d0e:
        bset    #2,%d1                          | 3c25d0e  08c1 0002
.L3c25d12:
        move.w  %d1,(MMU_$PID_PRIV).l           | 3c25d12  33c1 03c2 56a4
        move.b  %d1,(MMU+0x101).l               | 3c25d18  13c1 03ff b501
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25d1e  4a39 03c2 579a
        bne.s   .L3c25d48                       | 3c25d24  6622
        moves.l %d1,(0x8000000).l               | 3c25d26  0eb9 1800 0800 0000
        lea     (MMU_$RARS_PHADDR,%pc),%a0      | 3c25d2e  41fa f982
        move.l  (0,%a0,%d0.w*4),%d0             | 3c25d32  2030 0400
        lsr.l   #7,%d0                          | 3c25d36  ee88
        .short  0x80bc, 0x00c0, 0x0000          | 3c25d38  80bc 00c0 0000  or.l #0xc00000,%d0 (<ea>=#imm form)
        moves.l %d0,(0x0).w                     | 3c25d3e  0eb8 0800 0000
        bra.w   CACHE_$CLEAR                    | 3c25d44  6000 013a
.L3c25d48:
        lea     (MMU_$RARS_PHADDR,%pc),%a0      | 3c25d48  41fa f968
        move.l  (0,%a0,%d0.w*4),%d0             | 3c25d4c  2030 0400
        move.w  %sr,%d1                         | 3c25d50  40c1
        ori.w   #0x700,%sr                      | 3c25d52  007c 0700
        move.l  %d0,(mmu_$crp_root).l           | 3c25d56  23c0 03c2 56aa
        lea     (mmu_$crp,%pc),%a0              | 3c25d5c  41fa f948
        pmove   (%a0),%crp                      | 3c25d60  f010 4c00
        move.w  %d1,%sr                         | 3c25d64  46c1
        bra.w   CACHE_$CLEAR                    | 3c25d66  6000 0118
.L3c25d6a:
        rts                                     | 3c25d6a  4e75
MMU_$PAGE_WRITE_BIT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c25d6c  48e7 3a20
        move.l  (0x18,%sp),%d4                  | 3c25d70  282f 0018
        bsr.w   mmu_$locate                     | 3c25d74  6100 fa26
        move.b  (0x1d,%sp),%d1                  | 3c25d78  122f 001d
        btst    #2,%d1                          | 3c25d7c  0801 0002
        bne.s   .L3c25d8a                       | 3c25d80  6608
        bset    #2,(3,%a2,%d3.w)                | 3c25d82  08f2 0002 3003
        bra.s   .L3c25d90                       | 3c25d88  6006
.L3c25d8a:
        bclr    #2,(3,%a2,%d3.w)                | 3c25d8a  08b2 0002 3003
.L3c25d90:
        bsr.w   MMU_$PURGE                      | 3c25d90  6100 000e
        move.w  %d6,%sr                         | 3c25d94  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c25d96  4cdf 045c
        rts                                     | 3c25d9a  4e75
MMU_$PURGE_TB:
        bra.s   MMU_$PURGE                      | 3c25d9c  6002
        rts                                     | 3c25d9e  4e75
MMU_$PURGE:
        tst.b   (MMU_$HAVE_PMMU).l              | 3c25da0  4a39 03c2 579a
        bne.s   .L3c25db2                       | 3c25da6  660a
        moves.l %d1,(0x8000000).l               | 3c25da8  0eb9 1800 0800 0000
        rts                                     | 3c25db0  4e75
.L3c25db2:
        pflusha                                 | 3c25db2  f000 2400
        rts                                     | 3c25db6  4e75
MMU_$SET_SEG_PROT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c25db8  48e7 3a20
        move.l  (0x18,%sp),%d4                  | 3c25dbc  282f 0018
        bsr.w   mmu_$locate                     | 3c25dc0  6100 f9da
        move.l  (%a0),%d1                       | 3c25dc4  2210
        move.l  (4,%a0),%d0                     | 3c25dc6  2028 0004
        .short  0xc0bc, 0x0000, 0x000f          | 3c25dca  c0bc 0000 000f  and.l #0xf,%d0 (<ea>=#imm form)
        btst    #2,%d1                          | 3c25dd0  0801 0002
        beq.s   .L3c25ddc                       | 3c25dd4  6706
        bclr    #2,%d0                          | 3c25dd6  0880 0002
        bra.s   .L3c25de0                       | 3c25dda  6004
.L3c25ddc:
        bset    #2,%d0                          | 3c25ddc  08c0 0002
.L3c25de0:
        btst    #8,%d1                          | 3c25de0  0801 0008
        beq.s   .L3c25dec                       | 3c25de4  6706
        bset    #4,%d0                          | 3c25de6  08c0 0004
        bra.s   .L3c25df0                       | 3c25dea  6004
.L3c25dec:
        bclr    #4,%d0                          | 3c25dec  0880 0004
.L3c25df0:
        move.b  (0x1d,%sp),%d2                  | 3c25df0  142f 001d
        move.l  %d2,%d3                         | 3c25df4  2602
        .short  0xc6bc, 0x0000, 0x000f          | 3c25df6  c6bc 0000 000f  and.l #0xf,%d3 (<ea>=#imm form)
        move.l  (4,%a0),%d4                     | 3c25dfc  2828 0004
        .short  0xc8bc, 0xffff, 0xfff0          | 3c25e00  c8bc ffff fff0  and.l #-0x10,%d4 (<ea>=#imm form)
        or.l    %d3,%d4                         | 3c25e06  8883
        move.l  %d4,(4,%a0)                     | 3c25e08  2144 0004
        btst    #4,%d2                          | 3c25e0c  0802 0004
        beq.s   .L3c25e18                       | 3c25e10  6706
        bset    #8,%d1                          | 3c25e12  08c1 0008
        bra.s   .L3c25e1c                       | 3c25e16  6004
.L3c25e18:
        bclr    #8,%d1                          | 3c25e18  0881 0008
.L3c25e1c:
        btst    #2,%d2                          | 3c25e1c  0802 0002
        beq.s   .L3c25e28                       | 3c25e20  6706
        bclr    #2,%d1                          | 3c25e22  0881 0002
        bra.s   .L3c25e2c                       | 3c25e26  6004
.L3c25e28:
        bset    #2,%d1                          | 3c25e28  08c1 0002
.L3c25e2c:
        move.l  %d1,(%a0)                       | 3c25e2c  2081
        bsr.w   MMU_$PURGE                      | 3c25e2e  6100 ff70
        move.w  %d6,%sr                         | 3c25e32  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c25e34  4cdf 045c
        rts                                     | 3c25e38  4e75
MMU_$SYSTEM_REV:                        | 3c25e3a
        .long   0                               | MMU_$SET_SYSREV's answer
MMU_$SET_SYSREV:
        lea     (MMU_$SYSTEM_REV,%pc),%a0       | 3c25e3e  41fa fffa
        moveq   #3,%d0                          | 3c25e42  7003
        btst    #0xe,(MMU).l                    | 3c25e44  0839 000e 03ff b400
        bne.s   .L3c25e50                       | 3c25e4c  6602
        moveq   #4,%d0                          | 3c25e4e  7004
.L3c25e50:
        move.l  %d0,(%a0)                       | 3c25e50  2080
        rts                                     | 3c25e52  4e75
MMU_$NORMAL_MODE:
        btst    #0,(MMU+0x1).l                  | 3c25e54  0839 0000 03ff b401
        sne     %d0                             | 3c25e5c  56c0
        rts                                     | 3c25e5e  4e75
MMU_$POWER_OFF:
        clr.l   %d0                             | 3c25e60  4280
        rts                                     | 3c25e62  4e75
MMU_$MCR_CHANGE:
        move.w  (4,%sp),%d0                     | 3c25e64  302f 0004
        .short  0xb07c, 0x0006                  | 3c25e68  b07c 0006  cmp.w #6,%d0 (<ea>=#imm form)
        bne.s   .L3c25e72                       | 3c25e6c  6604
        move.w  #2,%d0                          | 3c25e6e  303c 0002
.L3c25e72:
        lea     (MMU_$PID_PRIV,%pc),%a0         | 3c25e72  41fa f830
        eor.b   %d0,(%a0)                       | 3c25e76  b110
        move.b  (%a0),(MMU+0x100).l             | 3c25e78  13d0 03ff b500
        rts                                     | 3c25e7e  4e75
