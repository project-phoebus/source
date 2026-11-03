|
| mmu/sau4/mmu_asm.s - MMU_ASM, the SAU4's MMU routines: the DNx60's
| region registers and in-memory segment and page maps
|
| SAU4 map: "D F8260B4 MMU_ASM size = 4B8" (WIRED_DATA).  This file holds
| the segment from its start to MMU_$MCR_CHANGE's end, 0x4B2 bytes
| (0xF8260B4..0xF826565); the last 6 bytes are CACHE_$CLEAR and
| CACHE_$FLUSH_VIRTUAL, CACHE's (cache/m68k/clear.s with
| `cache_clear_stub', cache/m68k/flush_virtual.s).
|
| The DNx60 translates forward through in-memory tables
| (Domain Engineering Handbook ch. 9, 9-2, 9-13; `region_mmu',
| base/config.ins.pas):
| 32 region registers, control registers 0x120..0x13F, each a valid and a
| global bit and the physical address of the region's page of segment
| map entries; a segment map entry is a longword, its valid bit (31),
| the MST entry's protection bits and the physical address of the
| segment's page map; the page map's entries are longwords, their valid
| bit 31.  The current ASID is control register 0x11F and its RARS
| (MMU_$RARS_PHADDR, per ASID) is loaded through 0x117 and 0x118;
| translations are purged through 0x11C (a VA) and 0x11D (1: that VA, 2:
| all); 0x115 and 0x116 read and write a region register by number
| (0x120 + region), and 0x11A / 0x11B read the longword at a physical
| address (MMU_$VTOP walks the tables with them); 0x113 holds the
| hardware and microcode revisions.
| gas knows no names for these registers: those `movec's are words with
| the instruction in the comment.
|
|   MMU_$OS_PMAPS_PHADDR   OS_PMAPS's physical address (COLD stores it)
|   MMU_$RARS_PHADDR       58 longwords, each ASID's RARS (zero here)
|   mmu_$locate            the VA in D4 to its segment map entry (A0, in
|                          SMAPS: the global ones from SMAPS + 0x400,
|                          D1 bit 0 set for those) and the OS page map
|                          (A2, in OS_PMAPS) with the entry's offset in D3;
|                          at IPL 7, the old SR in D6.  A VA between 0x8000
|                          and GLOBAL_B crashes the system ("va not in valid
|                          mmu manager range")
|   MMU_$INSTALL_SPECIAL, MMU_$REMOVE_SPECIAL_SEG, MMU_$PURGE_SEG: the
|                          special segments' entries, from SMAPS + 0x77DC
|                          per ASID (0x7800 bytes each) and OS_PMAP_SPECIAL
|   MMU_$REMOVE, MMU_$INSTALL, MMU_$CACHE_INHIBIT_VA (a return), MMU_$VTOP,
|   MMU_$INSTALL_REGION, MMU_$SET_CSR (the CSR word MMU + 0),
|   MMU_$INSTALL_ASID, MMU_$PAGE_WRITE_BIT, MMU_$PURGE_TB, MMU_$PURGE,
|   MMU_$SET_SEG_PROT, MMU_$SYSTEM_REV and MMU_$SET_SYSREV, MMU_$NORMAL_MODE
|   (MMU + 3 bit 5), MMU_$POWER_OFF (MMU + 2 bit 7), MMU_$MCR_CHANGE (the
|   MCR copy, its low byte to MMU + 5)
|
| Hand-written (an `_ASM' segment in a data section, code and data mixed,
| no frame, the arguments read off SP, register-called local entries,
| the saved SR kept in D6 across them).  The labels without a map name
| keep the image address they stand at, but for the entries the routines
| share (mmu_$locate and the like, the SAU8's and SAU9's names).  The
| image's immediate-to-register `cmp', `and', `or', `add' and `sub' use
| the EA-immediate forms (0xB0BC and the like): those are `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau4 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU4 image's.
|

        .section ".text.MMU_ASM.WIRED_DATA","ax",@progbits
        .even

        .globl  MMU_$OS_PMAPS_PHADDR
        .globl  MMU_$RARS_PHADDR
        .globl  MMU_$INSTALL_SPECIAL
        .globl  MMU_$REMOVE_SPECIAL_SEG
        .globl  MMU_$PURGE_SEG
        .globl  MMU_$REMOVE
        .globl  MMU_$CACHE_INHIBIT_VA
        .globl  MMU_$INSTALL
        .globl  MMU_$VTOP
        .globl  MMU_$INSTALL_REGION
        .globl  MMU_$SET_CSR
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

MMU_$OS_PMAPS_PHADDR:
        .long   0x00000000                      | sau4 f8260b4  00000000
MMU_$RARS_PHADDR:
        .long   0x00000000                      | sau4 f8260b8  00000000
        .space  0xe4                            | sau4 f8260bc  zero to f8261a0
mmu_$locate:
        clr.l   %d1                             | sau4 f8261a0  4281
        move.l  #0xffff8000,%d2                 | sau4 f8261a2  243c ffff 8000
        movea.l #OS_PMAPS,%a2                   | sau4 f8261a8  247c 0f90 2800
        movea.l #SMAPS+0x400,%a0                | sau4 f8261ae  207c 0f90 b000
        and.l   %d4,%d2                         | sau4 f8261b4  c484
        beq.s   .Lf8261c2                       | sau4 f8261b6  670a
        .short  0xb4bc; .long GLOBAL_B          | sau4 f8261b8  b4bc 0f80 0000  cmp.l   #GLOBAL_B,%d2
        bge.s   .Lf8261d2                       | sau4 f8261be  6c12
        bra.s   mmu_$bad_va                     | sau4 f8261c0  602e
.Lf8261c2:
        adda.l  #0x8000,%a2                     | sau4 f8261c2  d5fc 0000 8000
        adda.l  #0x400,%a0                      | sau4 f8261c8  d1fc 0000 0400
        bset    #0,%d1                          | sau4 f8261ce  08c1 0000
.Lf8261d2:
        move.l  %d4,%d2                         | sau4 f8261d2  2404
        lsr.l   #8,%d2                          | sau4 f8261d4  e08a
        moveq   #124,%d3                        | sau4 f8261d6  767c
        and.w   %d2,%d3                         | sau4 f8261d8  c642
        lsr.l   #5,%d2                          | sau4 f8261da  ea8a
        .short  0xc4bc, 0x0000, 0x03fc          | sau4 f8261dc  c4bc 0000 03fc  and.l   #0x3fc,%d2
        adda.l  %d2,%a0                         | sau4 f8261e2  d1c2
        lsl.l   #5,%d2                          | sau4 f8261e4  eb8a
        adda.l  %d2,%a2                         | sau4 f8261e6  d5c2
        move.w  %sr,%d6                         | sau4 f8261e8  40c6
        ori.w   #0x700,%sr                      | sau4 f8261ea  007c 0700
        rts                                     | sau4 f8261ee  4e75
mmu_$bad_va:
        pea     (mmu_$st_bad_va:w,%pc)          | sau4 f8261f0  487a 0012
        bra.s   mmu_$crash                      | sau4 f8261f4  6006
mmu_$no_os_pmap:
        pea     (mmu_$st_no_os_pmap:w,%pc)      | sau4 f8261f6  487a 0010
        move.w  %d6,%sr                         | sau4 f8261fa  46c6
mmu_$crash:
        jsr     (CRASH_SYSTEM).l                | sau4 f8261fc  4eb9 0f81 faf8
        bra.s   mmu_$crash                      | sau4 f826202  60f8
mmu_$st_bad_va:
        .long   0x00070002                      | sau4 f826204  00070002
mmu_$st_no_os_pmap:
        .long   0x00070003                      | sau4 f826208  00070003
MMU_$INSTALL_SPECIAL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | sau4 f82620c  48e7 3b20
        move.l  (0x20,%sp),%d4                  | sau4 f826210  282f 0020
        movea.l #SMAPS,%a0                      | sau4 f826214  207c 0f90 ac00
        clr.l   %d7                             | sau4 f82621a  4287
        move.w  (0x24,%sp),%d7                  | sau4 f82621c  3e2f 0024
        beq.s   mmu_$bad_va                     | sau4 f826220  67ce
        move.l  #0xffff8000,%d2                 | sau4 f826222  243c ffff 8000
        and.l   %d4,%d2                         | sau4 f826228  c484
        .short  0x94bc, 0x0f7b, 0x8000          | sau4 f82622a  94bc 0f7b 8000  sub.l   #0xf7b8000,%d2
        lsr.l   #8,%d2                          | sau4 f826230  e08a
        lsr.l   #7,%d2                          | sau4 f826232  ee8a
        .short  0xb4bc, 0x0000, 0x0001          | sau4 f826234  b4bc 0000 0001  cmp.l   #1,%d2
        bcc.s   mmu_$bad_va                     | sau4 f82623a  64b4
        lsl.l   #2,%d2                          | sau4 f82623c  e58a
        mulu.w  #0x7800,%d7                     | sau4 f82623e  cefc 7800
        .short  0xdebc, 0x0000, 0x77dc          | sau4 f826242  debc 0000 77dc  add.l   #0x77dc,%d7
        adda.l  %d7,%a0                         | sau4 f826248  d1c7
        adda.l  %d2,%a0                         | sau4 f82624a  d1c2
        movea.l #OS_PMAP_SPECIAL,%a2            | sau4 f82624c  247c 0f90 a880
        lsl.l   #5,%d2                          | sau4 f826252  eb8a
        adda.l  %d2,%a2                         | sau4 f826254  d5c2
        move.l  %d4,%d2                         | sau4 f826256  2404
        lsr.l   #8,%d2                          | sau4 f826258  e08a
        move.w  #0x7c,%d3                       | sau4 f82625a  363c 007c
        and.w   %d2,%d3                         | sau4 f82625e  c642
        move.w  %sr,%d6                         | sau4 f826260  40c6
        ori.w   #0x700,%sr                      | sau4 f826262  007c 0700
        bra.w   mmu_$install_entry              | sau4 f826266  6000 00e2
MMU_$REMOVE_SPECIAL_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | sau4 f82626a  48e7 2b20
        move.l  (0x18,%sp),%d4                  | sau4 f82626e  282f 0018
        movea.l #SMAPS,%a0                      | sau4 f826272  207c 0f90 ac00
        movea.l #OS_PMAP_SPECIAL,%a2            | sau4 f826278  247c 0f90 a880
        move.l  %d4,%d2                         | sau4 f82627e  2404
        lsr.l   #8,%d2                          | sau4 f826280  e08a
        lsr.l   #7,%d2                          | sau4 f826282  ee8a
        lsl.l   #2,%d2                          | sau4 f826284  e58a
        clr.l   %d7                             | sau4 f826286  4287
        move.w  (0x1c,%sp),%d7                  | sau4 f826288  3e2f 001c
        beq.s   .Lf8262b2                       | sau4 f82628c  6724
        .short  0x94bc, 0x0000, 0x7bdc          | sau4 f82628e  94bc 0000 7bdc  sub.l   #0x7bdc,%d2
        .short  0xb4bc, 0x0000, 0x0004          | sau4 f826294  b4bc 0000 0004  cmp.l   #4,%d2
        bcc.w   mmu_$bad_va                     | sau4 f82629a  6400 ff54
        mulu.w  #0x7800,%d7                     | sau4 f82629e  cefc 7800
        .short  0xdebc, 0x0000, 0x77dc          | sau4 f8262a2  debc 0000 77dc  add.l   #0x77dc,%d7
        add.l   %d2,%d7                         | sau4 f8262a8  de82
        adda.l  %d7,%a0                         | sau4 f8262aa  d1c7
        lsl.l   #5,%d2                          | sau4 f8262ac  eb8a
        adda.l  %d2,%a2                         | sau4 f8262ae  d5c2
        bra.s   .Lf8262c0                       | sau4 f8262b0  600e
.Lf8262b2:
        adda.l  #0x800,%a0                      | sau4 f8262b2  d1fc 0000 0800
        .short  0xc4bc, 0x0000, 0x03fc          | sau4 f8262b8  c4bc 0000 03fc  and.l   #0x3fc,%d2
        adda.l  %d2,%a0                         | sau4 f8262be  d1c2
.Lf8262c0:
        move.w  %sr,%d6                         | sau4 f8262c0  40c6
        ori.w   #0x700,%sr                      | sau4 f8262c2  007c 0700
        bclr    #7,(%a0)                        | sau4 f8262c6  0890 0007
        move.w  (0x1e,%sp),%d0                  | sau4 f8262ca  302f 001e
        bra.s   .Lf8262e0                       | sau4 f8262ce  6010
MMU_$PURGE_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | sau4 f8262d0  48e7 2b20
        movea.l (0x1c,%sp),%a2                  | sau4 f8262d4  246f 001c
        clr.w   %d0                             | sau4 f8262d8  4240
        move.w  %sr,%d6                         | sau4 f8262da  40c6
        ori.w   #0x700,%sr                      | sau4 f8262dc  007c 0700
.Lf8262e0:
        tst.w   %d0                             | sau4 f8262e0  4a40
        beq.s   .Lf8262f8                       | sau4 f8262e2  6714
        move.w  #0x1f,%d1                       | sau4 f8262e4  323c 001f
.Lf8262e8:
        btst    #7,(%a2)                        | sau4 f8262e8  0812 0007
        beq.s   .Lf8262f2                       | sau4 f8262ec  6704
        bclr    #7,(%a2)                        | sau4 f8262ee  0892 0007
.Lf8262f2:
        addq.l  #4,%a2                          | sau4 f8262f2  588a
        dbf     %d1,.Lf8262e8                   | sau4 f8262f4  51c9 fff2
.Lf8262f8:
        movea.l #2,%a1                          | sau4 f8262f8  227c 0000 0002
        .short  0x4e7b, 0x911c                  | sau4 f8262fe  4e7b 911c  movec %a1,0x11c
        .short  0x4e7b, 0x911d                  | sau4 f826302  4e7b 911d  movec %a1,0x11d
        move.w  %d6,%sr                         | sau4 f826306  46c6
        movem.l (%sp)+,%d2/%d4/%d6-%d7/%a2      | sau4 f826308  4cdf 04d4
        rts                                     | sau4 f82630c  4e75
MMU_$REMOVE:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau4 f82630e  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau4 f826312  282f 0018
        bsr.w   mmu_$locate                     | sau4 f826316  6100 fe88
        bsr.s   mmu_$invalidate                 | sau4 f82631a  6108
        move.w  %d6,%sr                         | sau4 f82631c  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau4 f82631e  4cdf 045c
        rts                                     | sau4 f826322  4e75
mmu_$invalidate:
        bclr    #7,(0x0,%a2,%d3.w)              | sau4 f826324  08b2 0007 3000
        movea.w #1,%a1                          | sau4 f82632a  327c 0001
        .short  0x4e7b, 0x411c                  | sau4 f82632e  4e7b 411c  movec %d4,0x11c
        .short  0x4e7b, 0x911d                  | sau4 f826332  4e7b 911d  movec %a1,0x11d
        rts                                     | sau4 f826336  4e75
MMU_$CACHE_INHIBIT_VA:
        rts                                     | sau4 f826338  4e75
MMU_$INSTALL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | sau4 f82633a  48e7 3b20
        move.l  (0x20,%sp),%d4                  | sau4 f82633e  282f 0020
        bsr.w   mmu_$locate                     | sau4 f826342  6100 fe5c
        move.w  (0x24,%sp),%d7                  | sau4 f826346  3e2f 0024
mmu_$install_entry:
        btst    #7,(%a0)                        | sau4 f82634a  0810 0007
        beq.s   .Lf82635c                       | sau4 f82634e  670c
        move.l  (%a0),%d2                       | sau4 f826350  2410
        .short  0xc4bc, 0x00ff, 0xffff          | sau4 f826352  c4bc 00ff ffff  and.l   #0xffffff,%d2
        movea.l %d2,%a1                         | sau4 f826358  2242
        bra.s   .Lf826368                       | sau4 f82635a  600c
.Lf82635c:
        movea.l %a2,%a1                         | sau4 f82635c  224a
        suba.l  #OS_PMAPS,%a1                   | sau4 f82635e  93fc 0f90 2800
        adda.l  (MMU_$OS_PMAPS_PHADDR:w,%pc),%a1 | sau4 f826364  d3fa fd4e
.Lf826368:
        clr.l   %d1                             | sau4 f826368  4281
        move.b  (0x27,%sp),%d1                  | sau4 f82636a  122f 0027
        lsl.w   #8,%d1                          | sau4 f82636e  e149
        lsl.w   #2,%d1                          | sau4 f826370  e549
        swap    %d1                             | sau4 f826372  4841
        bset    #0x1f,%d1                       | sau4 f826374  08c1 001f
        add.l   %a1,%d1                         | sau4 f826378  d289
        move.l  %d1,(%a0)                       | sau4 f82637a  2081
        btst    #7,(0x0,%a2,%d3.w)              | sau4 f82637c  0832 0007 3000
        beq.s   .Lf826386                       | sau4 f826382  6702
        bsr.s   mmu_$invalidate                 | sau4 f826384  619e
.Lf826386:
        move.l  (0x1c,%sp),%d0                  | sau4 f826386  202f 001c
        btst    #2,(0x27,%sp)                   | sau4 f82638a  082f 0002 0027
        beq.s   .Lf82639c                       | sau4 f826390  670a
        btst    #0x1c,(%a0)                     | sau4 f826392  0810 001c
        bne.s   .Lf82639c                       | sau4 f826396  6604
        bset    #0x1b,%d0                       | sau4 f826398  08c0 001b
.Lf82639c:
        bset    #0x1f,%d0                       | sau4 f82639c  08c0 001f
        move.l  %d0,(0x0,%a2,%d3.w)             | sau4 f8263a0  2580 3000
        move.w  %d6,%sr                         | sau4 f8263a4  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | sau4 f8263a6  4cdf 04dc
        rts                                     | sau4 f8263aa  4e75
MMU_$VTOP:
        movem.l %d2-%d7/%a2,-(%sp)              | sau4 f8263ac  48e7 3f20
        move.l  (0x20,%sp),%d4                  | sau4 f8263b0  282f 0020
        clr.l   %d0                             | sau4 f8263b4  4280
        move.w  %sr,%d6                         | sau4 f8263b6  40c6
        ori.w   #0x700,%sr                      | sau4 f8263b8  007c 0700
        move.l  %d4,%d2                         | sau4 f8263bc  2404
        swap    %d2                             | sau4 f8263be  4842
        lsr.w   #7,%d2                          | sau4 f8263c0  ee4a
        .short  0xc4bc, 0x0000, 0x001f          | sau4 f8263c2  c4bc 0000 001f  and.l   #0x1f,%d2
        .short  0xd47c, 0x0120                  | sau4 f8263c8  d47c 0120  add.w   #0x120,%d2
        .short  0x4e7b, 0x2116                  | sau4 f8263cc  4e7b 2116  movec %d2,0x116
        .short  0x4e7a, 0x1115                  | sau4 f8263d0  4e7a 1115  movec 0x115,%d1
        tst.l   %d1                             | sau4 f8263d4  4a81
        bge.s   .Lf826428                       | sau4 f8263d6  6c50
        .short  0xc2bc, 0x00ff, 0xffff          | sau4 f8263d8  c2bc 00ff ffff  and.l   #0xffffff,%d1
        move.l  %d4,%d3                         | sau4 f8263de  2604
        moveq   #13,%d5                         | sau4 f8263e0  7a0d
        lsr.l   %d5,%d3                         | sau4 f8263e2  eaab
        .short  0xc6bc, 0x0000, 0x03fc          | sau4 f8263e4  c6bc 0000 03fc  and.l   #0x3fc,%d3
        add.l   %d3,%d1                         | sau4 f8263ea  d283
        .short  0x4e7b, 0x111a                  | sau4 f8263ec  4e7b 111a  movec %d1,0x11a
        .short  0x4e7a, 0x111b                  | sau4 f8263f0  4e7a 111b  movec 0x11b,%d1
        tst.l   %d1                             | sau4 f8263f4  4a81
        bge.s   .Lf826428                       | sau4 f8263f6  6c30
        .short  0xc2bc, 0x00ff, 0xffff          | sau4 f8263f8  c2bc 00ff ffff  and.l   #0xffffff,%d1
        move.b  (0x22,%sp),%d4                  | sau4 f8263fe  182f 0022
        .short  0xc8bc, 0x0000, 0x007c          | sau4 f826402  c8bc 0000 007c  and.l   #0x7c,%d4
        add.l   %d4,%d1                         | sau4 f826408  d284
        .short  0x4e7b, 0x111a                  | sau4 f82640a  4e7b 111a  movec %d1,0x11a
        .short  0x4e7a, 0x111b                  | sau4 f82640e  4e7a 111b  movec 0x11b,%d1
        tst.l   %d1                             | sau4 f826412  4a81
        bge.s   .Lf826428                       | sau4 f826414  6c12
        move.w  %d1,%d0                         | sau4 f826416  3001
        clr.l   %d3                             | sau4 f826418  4283
.Lf82641a:
        move.w  %d6,%sr                         | sau4 f82641a  46c6
        movea.l (0x24,%sp),%a0                  | sau4 f82641c  206f 0024
        move.l  %d3,(%a0)                       | sau4 f826420  2083
        movem.l (%sp)+,%d2-%d7/%a2              | sau4 f826422  4cdf 04fc
        rts                                     | sau4 f826426  4e75
.Lf826428:
        move.l  #0x70001,%d3                    | sau4 f826428  263c 0007 0001
        clr.l   %d0                             | sau4 f82642e  4280
        bra.s   .Lf82641a                       | sau4 f826430  60e8
MMU_$INSTALL_REGION:
        movea.l #0x120,%a1                      | sau4 f826432  227c 0000 0120
        move.w  (0x4,%sp),%d0                   | sau4 f826438  302f 0004
        .short  0xc07c, 0x001f                  | sau4 f82643c  c07c 001f  and.w   #0x1f,%d0
        adda.w  %d0,%a1                         | sau4 f826440  d2c0
        .short  0x4e7b, 0x9116                  | sau4 f826442  4e7b 9116  movec %a1,0x116
        movea.l (0x6,%sp),%a1                   | sau4 f826446  226f 0006
        .short  0x4e7b, 0x9115                  | sau4 f82644a  4e7b 9115  movec %a1,0x115
        rts                                     | sau4 f82644e  4e75
MMU_$SET_CSR:
        move.w  (0x4,%sp),%d0                   | sau4 f826450  302f 0004
        move.w  %d0,(MMU).l                     | sau4 f826454  33c0 0fff b400
        rts                                     | sau4 f82645a  4e75
MMU_$INSTALL_ASID:
        clr.l   %d0                             | sau4 f82645c  4280
        move.w  (0x4,%sp),%d0                   | sau4 f82645e  302f 0004
        cmp.w   (PROC1_$AS_ID).l,%d0            | sau4 f826462  b079 0f82 1c1a
        beq.w   .Lf82649e                       | sau4 f826468  6700 0034
        move.w  %d0,(PROC1_$AS_ID).l            | sau4 f82646c  33c0 0f82 1c1a
        .short  0x4e7b, 0x011f                  | sau4 f826472  4e7b 011f  movec %d0,0x11f
        lsl.w   #2,%d0                          | sau4 f826476  e548
        lea     (MST_$REGIONS_ACTIVE).l,%a1     | sau4 f826478  43f9 0f82 6614
        move.l  (0x0,%a1,%d0.w),%d1             | sau4 f82647e  2231 0000
        .short  0x82bc, 0x8000, 0x0001          | sau4 f826482  82bc 8000 0001  or.l    #0x80000001,%d1
        lsl.w   #5,%d0                          | sau4 f826488  eb48
        lea     (RARS).l,%a1                    | sau4 f82648a  43f9 0fab dc00
        adda.l  %d0,%a1                         | sau4 f826490  d3c0
        .short  0x4e7b, 0x9118                  | sau4 f826492  4e7b 9118  movec %a1,0x118
        .short  0x4e7b, 0x1117                  | sau4 f826496  4e7b 1117  movec %d1,0x117
        andi.w  #0xf7ff,%sr                     | sau4 f82649a  027c f7ff
.Lf82649e:
        rts                                     | sau4 f82649e  4e75
MMU_$PAGE_WRITE_BIT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau4 f8264a0  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau4 f8264a4  282f 0018
        bsr.w   mmu_$locate                     | sau4 f8264a8  6100 fcf6
        move.b  (0x1d,%sp),%d1                  | sau4 f8264ac  122f 001d
        btst    #2,%d1                          | sau4 f8264b0  0801 0002
        beq.s   .Lf8264be                       | sau4 f8264b4  6708
        bset    #0x1b,(0x0,%a2,%d3.w)           | sau4 f8264b6  08f2 001b 3000
        bra.s   .Lf8264c4                       | sau4 f8264bc  6006
.Lf8264be:
        bclr    #0x1b,(0x0,%a2,%d3.w)           | sau4 f8264be  08b2 001b 3000
.Lf8264c4:
        move.w  %d6,%sr                         | sau4 f8264c4  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau4 f8264c6  4cdf 045c
        rts                                     | sau4 f8264ca  4e75
MMU_$PURGE_TB:
        movea.l (0x6,%sp),%a1                   | sau4 f8264cc  226f 0006
        move.w  (0x4,%sp),%d1                   | sau4 f8264d0  322f 0004
        .short  0xc27c, 0x0007                  | sau4 f8264d4  c27c 0007  and.w   #7,%d1
        bne.s   .Lf8264de                       | sau4 f8264d8  6604
        move.w  #2,%d1                          | sau4 f8264da  323c 0002
.Lf8264de:
        .short  0x4e7b, 0x911c                  | sau4 f8264de  4e7b 911c  movec %a1,0x11c
        .short  0x4e7b, 0x111d                  | sau4 f8264e2  4e7b 111d  movec %d1,0x11d
        rts                                     | sau4 f8264e6  4e75
MMU_$PURGE:
        move.w  #2,%d1                          | sau4 f8264e8  323c 0002
        .short  0x4e7b, 0x111d                  | sau4 f8264ec  4e7b 111d  movec %d1,0x11d
        rts                                     | sau4 f8264f0  4e75
MMU_$SET_SEG_PROT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau4 f8264f2  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau4 f8264f6  282f 0018
        bsr.w   mmu_$locate                     | sau4 f8264fa  6100 fca4
        clr.w   %d0                             | sau4 f8264fe  4240
        move.b  (%a0),%d0                       | sau4 f826500  1010
        andi.b  #0x1f,(%a0)                     | sau4 f826502  0210 001f
        lsr.w   #2,%d0                          | sau4 f826506  e448
        move.b  (0x1d,%sp),%d1                  | sau4 f826508  122f 001d
        lsl.w   #2,%d1                          | sau4 f82650c  e549
        or.b    %d1,(%a0)                       | sau4 f82650e  8310
        move.w  %d6,%sr                         | sau4 f826510  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau4 f826512  4cdf 045c
        rts                                     | sau4 f826516  4e75
MMU_$SYSTEM_REV:
        .long   0x00000000                      | sau4 f826518  00000000
MMU_$SET_SYSREV:
        lea     (MMU_$SYSTEM_REV:w,%pc),%a0     | sau4 f82651c  41fa fffa
        .short  0x4e7a, 0x0113                  | sau4 f826520  4e7a 0113  movec 0x113,%d0
        move.l  %d0,(%a0)                       | sau4 f826524  2080
        rts                                     | sau4 f826526  4e75
MMU_$NORMAL_MODE:
        btst    #5,(MMU+0x3).l                  | sau4 f826528  0839 0005 0fff b403
        sne     %d0                             | sau4 f826530  56c0
        rts                                     | sau4 f826532  4e75
MMU_$POWER_OFF:
        btst    #7,(MMU+0x2).l                  | sau4 f826534  0839 0007 0fff b402
        seq     %d0                             | sau4 f82653c  57c0
        rts                                     | sau4 f82653e  4e75
MMU_$MCR_CHANGE:
        move.w  (0x4,%sp),%d0                   | sau4 f826540  302f 0004
        .short  0xb07c, 0x0006                  | sau4 f826544  b07c 0006  cmp.w   #6,%d0
        bne.s   .Lf82654e                       | sau4 f826548  6604
        move.w  #2,%d0                          | sau4 f82654a  303c 0002
.Lf82654e:
        .short  0xb07c, 0x00ff                  | sau4 f82654e  b07c 00ff  cmp.w   #0xff,%d0
        bge.s   .Lf826556                       | sau4 f826552  6c02
        lsl.b   #4,%d0                          | sau4 f826554  e908
.Lf826556:
        lea     (.Lf826564:w,%pc),%a0           | sau4 f826556  41fa 000c
        eor.b   %d0,(%a0)                       | sau4 f82655a  b110
        move.b  (%a0),(MMU+0x5).l               | sau4 f82655c  13d0 0fff b405
        rts                                     | sau4 f826562  4e75
.Lf826564:
        .short  0x0000                          | sau4 f826564
