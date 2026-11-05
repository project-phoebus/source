|
| mmu/sau7/mmu_asm.s - MMU_ASM, the SAU7's MMU routines: the paged
| memory management unit's segment and page descriptors for the
| forward-table VM, on an MC68030 or on an MC68020 with the MC68851
|
| SAU7 map: "D 3C428FF4 MMU_ASM size = 6B8" (WIRED_DATA).  This file
| holds the segment from its start to MMU_$MCR_CHANGE's end, 0x66C bytes
| (0x3C428FF4..0x3C429660); the rest is CACHE's: CACHE_$CLEAR
| (cache/m68k/clear.s, the SAU2's bytes), CACHE_$FLUSH_VIRTUAL
| (cache/m68k/flush_virtual.s, its `flush_virtual_68030' arm) and the
| physical cache's routines (cache/sau7/physical.s).
|
| The SAU9's routines (mmu/sau9/mmu_asm.s, whose description of the
| translation tree applies: a root table per ASID in RARS, 8-byte segment
| descriptors in SMAPS, 32 page descriptors per segment's page map) for
| either PMMU.  M68030, a byte of the data below set at boot, says which:
| - MMU_$INSTALL sets the segment descriptor's bit 9 for ASID 0 when the
|   CPU is not an MC68030;
| - mmu_$flush_va flushes one address with the MC68851's `pflushs' or the
|   MC68030's `pflush';
| - MMU_$INSTALL_ASID keeps the FPU's and the FPA's enables (bits 2 and
|   1) in MMU_$PID_PRIV and the CPU control register (MMU + 0x101), as
|   the FP owner switch does (`fpu_enable_cpu_control'), then loads the
|   root pointer; with the MC68851 it stores the PMMU's cache status
|   (`pmove pcsr') at MMU + 0x300, clears the byte at SC_PAGE + 0xE and
|   flushes every translation, with the MC68030 it clears the data cache;
| - MMU_$NORMAL_MODE takes bit 0 of MMU + 1, and MMU_$MCR_CHANGE toggles
|   MMU_$PID_PRIV's high byte into MMU + 0x100.
| ROADRUNNER, the byte after M68030, is set at boot on a board with the
| physical cache (CACHE_$ENABLE_PHYSICAL); no routine here reads it.
|
| Hand-written (an `_ASM' segment in a data section, code and data mixed,
| no frame, the arguments read off SP, register-called local entries,
| the saved SR kept in D6 across them).  The routines run with the
| interrupts masked (SR | 0x700) while they change a descriptor, and
| flush the translations with MMU_$PURGE after it.
|
| The image's immediate-to-register `cmp', `and', `or', `add' and `sub'
| use the EA-immediate forms (0xB0BC and the like), and its `mulu.l
| #imm,Dn' names Dn twice in the extension word; gas spells the first as
| CMPI/ANDI/... and the second with Dh = 0, so the macros below give the
| image's encodings (as svc/m68k/svc_macros.inc's cmp_l_imm).  The
| register operand is the register number.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau7 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU7 image's.
|

        .section ".text.MMU_ASM.WIRED_DATA","ax",@progbits
        .even

        .macro  cmp_w_imm imm, dreg
        .short  0xb07c + (\dreg << 9)   | CMP.W #imm,Dn
        .short  \imm
        .endm
        .macro  cmp_l_imm imm, dreg
        .short  0xb0bc + (\dreg << 9)   | CMP.L #imm,Dn
        .long   \imm
        .endm
        .macro  and_w_imm imm, dreg
        .short  0xc07c + (\dreg << 9)   | AND.W #imm,Dn
        .short  \imm
        .endm
        .macro  and_l_imm imm, dreg
        .short  0xc0bc + (\dreg << 9)   | AND.L #imm,Dn
        .long   \imm
        .endm
        .macro  or_w_imm imm, dreg
        .short  0x807c + (\dreg << 9)   | OR.W #imm,Dn
        .short  \imm
        .endm
        .macro  add_l_imm imm, dreg
        .short  0xd0bc + (\dreg << 9)   | ADD.L #imm,Dn
        .long   \imm
        .endm
        .macro  sub_l_imm imm, dreg
        .short  0x90bc + (\dreg << 9)   | SUB.L #imm,Dn
        .long   \imm
        .endm
        .macro  mulu_l_imm imm, dreg
        .short  0x4c3c                  | MULU.L #imm,Dn (32 bits;
        .short  (\dreg << 12) + \dreg   | Dh = Dl)
        .long   \imm
        .endm

        .globl  MMU_$PID_PRIV
        .globl  MMU_$OS_PMAPS_PHADDR
        .globl  MMU_$RARS_PHADDR
        .globl  M68030
        .globl  ROADRUNNER
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

        | The map's objects these routines use (absolute addresses, cells
        | relocated with the kernel):
        |   OS_PMAPS 0x3C564800, OS_PMAP_SPECIAL 0x3C5A4880, SMAPS
        |   0x3C5A5000, RARS 0x3D320000, GLOBAL_B 0x3C000000 (the global
        |   segments' first address), PROC1_$AS_ID, FP_$OWNER,
        |   FPA_$SAVEP, FPA_$OWNER, MST_$VA_TO_SEGNO, CRASH_SYSTEM,
        |   CACHE_$CLEAR, CACHE_$FLUSH_VIRTUAL; the I/O pages MMU
        |   0x3FFFB400 (the CPU's registers) and SC_PAGE 0x3FFB0000.

| ---- The data -------------------------------------------------------

MMU_$PID_PRIV:                          | 0x3C428FF4
        .word   0                       | the CPU control register's copy:
                                        |   the PID (high byte) and the
                                        |   control bits (low byte, at MMU
                                        |   + 0x101; bit 2 the FPU's enable,
                                        |   bit 1 the FPA's)
mmu_$crp:                               | 0x3C428FF6
        .long   0x00FF0002              | the CPU root pointer for `pmove':
mmu_$crp_root:                          |   limit 0xFF, a valid 8-byte
        .long   0                       |   table; the current ASID's root
                                        |   table (MMU_$INSTALL_ASID)
MMU_$OS_PMAPS_PHADDR:                   | 0x3C428FFE
        .long   0                       | OS_PMAPS's physical address (set
                                        |   at boot)
MMU_$RARS_PHADDR:                       | 0x3C429002
        .fill   58, 4, 0                | each ASID's root table's physical
                                        |   address (MST_$INIT,
                                        |   MST_$ALLOC_ASID)
M68030:                                 | 0x3C4290EA
        .byte   0                       | the CPU is an MC68030 (a boolean,
        .byte   0                       |   set at boot), a pad byte
ROADRUNNER:                             | 0x3C4290EC
        .byte   0                       | the board has the physical cache
        .byte   0                       |   (a boolean, set at boot), a pad
                                        |   byte


| mmu_$locate (local, `bsr'): a virtual address's descriptors.
|   in:  D4 the address
|   out: A0 its segment descriptor (SMAPS + 0x800 + segment * 8 for a
|        global segment; segment 0, the low 32 KB, at SMAPS + 0x4800),
|        A2 its segment's page map (OS_PMAPS + segment * 0x80; segment 0
|        at OS_PMAPS + 0x40000), D3.w the page's offset in it (page * 4),
|        D6 the caller's SR, the interrupts masked
|   An address between 32 KB and GLOBAL_B crashes the system ("va not in
|   valid mmu manager range").  Uses D1, D2.
mmu_$locate:
        clr.l   %d1                             | 3c4290ee  4281
        move.l  #0xFFFF8000,%d2                 | 3c4290f0  243c ffff 8000
        movea.l #OS_PMAPS,%a2                   | 3c4290f6  247c 3c56 4800
        movea.l #SMAPS+0x800,%a0                | 3c4290fc  207c 3c5a 5800
        and.l   %d4,%d2                         | 3c429102  c484
        beq.s   .L9110                          | 3c429104  670a
        cmp_l_imm GLOBAL_B, 2                   | 3c429106  b4bc 3c00 0000
        bge.s   .L9120                          | 3c42910c  6c12
        bra.s   mmu_$bad_va                     | 3c42910e  603a
.L9110:
        adda.l  #0x40000,%a2                    | 3c429110  d5fc 0004 0000
        adda.l  #0x4000,%a0                     | 3c429116  d1fc 0000 4000
        bset    #0,%d1                          | 3c42911c  08c1 0000
.L9120:
        move.l  %d4,%d2                         | 3c429120  2404
        lsr.l   #8,%d2                          | 3c429122  e08a
        moveq   #124,%d3                        | 3c429124  767c
        and.w   %d2,%d3                         | 3c429126  c642
        lsr.l   #4,%d2                          | 3c429128  e88a
        and_l_imm 0x3FF8, 2                     | 3c42912a  c4bc 0000 3ff8
        btst    #0,%d1                          | 3c429130  0801 0000
        bne.s   .L913C                          | 3c429134  6606
        sub_l_imm 0, 2                          | 3c429136  94bc 0000 0000
.L913C:
        adda.l  %d2,%a0                         | 3c42913c  d1c2
        lsl.l   #4,%d2                          | 3c42913e  e98a
        adda.l  %d2,%a2                         | 3c429140  d5c2
        move.w  %sr,%d6                         | 3c429142  40c6
        ori.w   #0x700,%sr                      | 3c429144  007c 0700
        rts                                     | 3c429148  4e75

| The two crashes: "va not in valid mmu manager range" (16#00070002), and
| "va does not have os_pmap" (16#00070003) with the caller's SR back.
| CRASH_SYSTEM does not return; the loop is the image's.
mmu_$bad_va:
        pea     (mmu_$st_bad_va,%pc)            | 3c42914a  487a 0012
        bra.s   .L9156                          | 3c42914e  6006
mmu_$no_os_pmap:
        pea     (mmu_$st_no_os_pmap,%pc)        | 3c429150  487a 0010
        move.w  %d6,%sr                         | 3c429154  46c6
.L9156:
        jsr     CRASH_SYSTEM                    | 3c429156  4eb9 3c42 2b00
        bra.s   .L9156                          | 3c42915c  60f8
mmu_$st_bad_va:
        .long   0x00070002                      | 3c42915e  0007 0002
mmu_$st_no_os_pmap:
        .long   0x00070003                      | 3c429162  0007 0003

| MMU_$INSTALL_SPECIAL - install a physical page at a page of one of an
| ASID's eight special segments (0x3BF80000..0x3BFFFFFF).
|   (28,SP) the page number   (32,SP) the address
|   (36,SP) the ASID, a word  (39,SP) the protection, a byte
| (after the six saved registers).  ASID 0 or an address outside the
| special segments crashes the system.  The segment descriptor is the
| ASID's (SMAPS + ASID * 0x3B800 + 0x3B780 + segment * 8), the page map
| OS_PMAP_SPECIAL + segment * 0x80; then MMU_$INSTALL's code.
MMU_$INSTALL_SPECIAL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c429166  48e7 3b20
        move.l  (32,%sp),%d4                    | 3c42916a  282f 0020
        movea.l #SMAPS,%a0                      | 3c42916e  207c 3c5a 5000
        clr.l   %d7                             | 3c429174  4287
        move.w  (36,%sp),%d7                    | 3c429176  3e2f 0024
        beq.s   mmu_$bad_va                     | 3c42917a  67ce
        move.l  #0xFFFF8000,%d2                 | 3c42917c  243c ffff 8000
        and.l   %d4,%d2                         | 3c429182  c484
        sub_l_imm 0x3BF80000, 2                 | 3c429184  94bc 3bf8 0000
        lsr.l   #8,%d2                          | 3c42918a  e08a
        lsr.l   #7,%d2                          | 3c42918c  ee8a
        cmp_l_imm 8, 2                          | 3c42918e  b4bc 0000 0008
        bcc.s   mmu_$bad_va                     | 3c429194  64b4
        lsl.l   #3,%d2                          | 3c429196  e78a
        mulu_l_imm 0x3B800, 7                   | 3c429198  4c3c 7007 0003 b800
        add_l_imm 0x3B780, 7                    | 3c4291a0  debc 0003 b780
        adda.l  %d7,%a0                         | 3c4291a6  d1c7
        adda.l  %d2,%a0                         | 3c4291a8  d1c2
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c4291aa  247c 3c5a 4880
        lsl.l   #4,%d2                          | 3c4291b0  e98a
        adda.l  %d2,%a2                         | 3c4291b2  d5c2
        move.l  %d4,%d2                         | 3c4291b4  2404
        lsr.l   #8,%d2                          | 3c4291b6  e08a
        move.w  #124,%d3                        | 3c4291b8  363c 007c
        and.w   %d2,%d3                         | 3c4291bc  c642
        move.w  %sr,%d6                         | 3c4291be  40c6
        ori.w   #0x700,%sr                      | 3c4291c0  007c 0700
        bra.w   mmu_$install_entry              | 3c4291c4  6000 00e6

| MMU_$REMOVE_SPECIAL_SEG - invalidate a special segment of an ASID.
|   (24,SP) the address  (28,SP) the ASID, a word  (30,SP) a flag word
| ASID 0 names the descriptor at SMAPS + 0x4800 + (segment & 0x7F) * 8
| and OS_PMAP_SPECIAL's first page map; else the address must be in the
| special segments.
| The descriptor's type is cleared (invalid); with the flag set the 32
| page descriptors' resident bits are cleared too.  Then MMU_$PURGE.
MMU_$REMOVE_SPECIAL_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | 3c4291c8  48e7 2b20
        move.l  (24,%sp),%d4                    | 3c4291cc  282f 0018
        movea.l #SMAPS,%a0                      | 3c4291d0  207c 3c5a 5000
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c4291d6  247c 3c5a 4880
        move.l  %d4,%d2                         | 3c4291dc  2404
        lsr.l   #8,%d2                          | 3c4291de  e08a
        lsr.l   #7,%d2                          | 3c4291e0  ee8a
        lsl.l   #3,%d2                          | 3c4291e2  e78a
        clr.l   %d7                             | 3c4291e4  4287
        move.w  (28,%sp),%d7                    | 3c4291e6  3e2f 001c
        beq.s   .L9214                          | 3c4291ea  6728
        sub_l_imm 0x3BF80, 2                    | 3c4291ec  94bc 0003 bf80
        cmp_l_imm 64, 2                         | 3c4291f2  b4bc 0000 0040
        bcc.w   mmu_$bad_va                     | 3c4291f8  6400 ff50
        mulu_l_imm 0x3B800, 7                   | 3c4291fc  4c3c 7007 0003 b800
        add_l_imm 0x3B780, 7                    | 3c429204  debc 0003 b780
        add.l   %d2,%d7                         | 3c42920a  de82
        adda.l  %d7,%a0                         | 3c42920c  d1c7
        lsl.l   #4,%d2                          | 3c42920e  e98a
        adda.l  %d2,%a2                         | 3c429210  d5c2
        bra.s   .L9222                          | 3c429212  600e
.L9214:
        adda.l  #0x4800,%a0                     | 3c429214  d1fc 0000 4800
        and_l_imm 1016, 2                       | 3c42921a  c4bc 0000 03f8
        adda.l  %d2,%a0                         | 3c429220  d1c2
.L9222:
        move.w  %sr,%d6                         | 3c429222  40c6
        ori.w   #0x700,%sr                      | 3c429224  007c 0700
        andi.l  #-4,(%a0)                       | 3c429228  0290 ffff fffc
        move.w  (30,%sp),%d0                    | 3c42922e  302f 001e
        bra.s   .L9236                          | 3c429232  6002
        nop                                     | 3c429234  4e71
.L9236:
        tst.w   %d0                             | 3c429236  4a40
        beq.s   .L9252                          | 3c429238  6718
        move.w  #31,%d1                         | 3c42923a  323c 001f
.L923E:
        btst    #0,(3,%a2)                      | 3c42923e  082a 0000 0003
        beq.s   .L924C                          | 3c429244  6706
        bclr    #0,(3,%a2)                      | 3c429246  08aa 0000 0003
.L924C:
        addq.l  #4,%a2                          | 3c42924c  588a
        dbf     %d1,.L923E                      | 3c42924e  51c9 ffee
.L9252:
        bsr.w   MMU_$PURGE                      | 3c429252  6100 034e
        move.w  %d6,%sr                         | 3c429256  46c6
        movem.l (%sp)+,%d2/%d4/%d6-%d7/%a2      | 3c429258  4cdf 04d4
        rts                                     | 3c42925c  4e75

| MMU_$REMOVE - make a virtual address's page not resident.
|   (24,SP) the address
| The page descriptor's resident bit is cleared and the translations
| flushed (mmu_$invalidate, below).
MMU_$REMOVE:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c42925e  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c429262  282f 0018
        bsr.w   mmu_$locate                     | 3c429266  6100 fe86
        bsr.s   mmu_$invalidate                 | 3c42926a  6108
        move.w  %d6,%sr                         | 3c42926c  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c42926e  4cdf 045c
        rts                                     | 3c429272  4e75

| mmu_$invalidate (local, `bsr'): clear the resident bit of the page
| descriptor at (A2, D3.w) and flush (MMU_$PURGE's `rts' returns).
mmu_$invalidate:
        bclr    #0,(3,%a2,%d3.w)                | 3c429274  08b2 0000 3003
        bra.w   MMU_$PURGE                      | 3c42927a  6000 0326

| MMU_$CACHE_INHIBIT_VA - stop caching a virtual address's page.
|   (24,SP) the address
| The page descriptor's cache-inhibit bit (6) is set; MMU_$PURGE.
MMU_$CACHE_INHIBIT_VA:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c42927e  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c429282  282f 0018
        bsr.w   mmu_$locate                     | 3c429286  6100 fe66
        bset    #6,(3,%a2,%d3.w)                | 3c42928a  08f2 0006 3003
        bsr.w   MMU_$PURGE                      | 3c429290  6100 0310
        move.w  %d6,%sr                         | 3c429294  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c429296  4cdf 045c
        rts                                     | 3c42929a  4e75

| MMU_$INSTALL - install a physical page at a virtual address.
|   (28,SP) the page number   (32,SP) the address
|   (36,SP) the ASID, a word  (39,SP) the protection, a byte
| (after the six saved registers).
MMU_$INSTALL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c42929c  48e7 3b20
        move.l  (32,%sp),%d4                    | 3c4292a0  282f 0020
        bsr.w   mmu_$locate                     | 3c4292a4  6100 fe48
        move.w  (36,%sp),%d7                    | 3c4292a8  3e2f 0024

| mmu_$install_entry: MMU_$INSTALL's and MMU_$INSTALL_SPECIAL's common
| code, A0 the segment descriptor, A2 the page map, D3.w the page's
| offset, D6 the saved SR.  A valid segment descriptor (type 2) keeps
| its table's address; else the page map's physical address is formed
| from MMU_$OS_PMAPS_PHADDR.  The descriptor is rewritten: the table
| address with the protection's low four bits in its unused low bits;
| limit 31 (bits 30..16), bits 15..10 set, the supervisor bit (8) from
| protection bit 4, write protect (2) unless protection bit 2, type 2;
| bit 9 too for ASID 0 (D7) without an MC68030.
| A resident page descriptor is invalidated first; the new one is the
| frame (page number * 1024), type 1.
mmu_$install_entry:
        moveq   #3,%d1                          | 3c4292ac  7203
        and.l   (%a0),%d1                       | 3c4292ae  c290
        cmp_w_imm 2, 1                          | 3c4292b0  b27c 0002
        bne.s   .L92C4                          | 3c4292b4  660e
        move.l  (4,%a0),%d2                     | 3c4292b6  2428 0004
        and_l_imm -16, 2                        | 3c4292ba  c4bc ffff fff0
        movea.l %d2,%a1                         | 3c4292c0  2242
        bra.s   .L92D0                          | 3c4292c2  600c
.L92C4:
        movea.l %a2,%a1                         | 3c4292c4  224a
        suba.l  #OS_PMAPS,%a1                   | 3c4292c6  93fc 3c56 4800
        adda.l  (MMU_$OS_PMAPS_PHADDR,%pc),%a1  | 3c4292cc  d3fa fd30
.L92D0:
        clr.l   %d1                             | 3c4292d0  4281
        clr.l   %d1                             | 3c4292d2  4281
        move.b  (39,%sp),%d1                    | 3c4292d4  122f 0027
        move.l  %d1,%d2                         | 3c4292d8  2401
        and_l_imm 15, 1                         | 3c4292da  c2bc 0000 000f
        add.l   %a1,%d1                         | 3c4292e0  d289
        move.l  %d1,(4,%a0)                     | 3c4292e2  2141 0004
        move.l  #0x1F0102,%d1                   | 3c4292e6  223c 001f 0102
        btst    #4,%d2                          | 3c4292ec  0802 0004
        bne.s   .L92F8                          | 3c4292f0  6606
        move.l  #0x1F0002,%d1                   | 3c4292f2  223c 001f 0002
.L92F8:
        btst    #2,%d2                          | 3c4292f8  0802 0002
        bne.s   .L9302                          | 3c4292fc  6604
        bset    #2,%d1                          | 3c4292fe  08c1 0002
.L9302:
        tst.b   (M68030).l                      | 3c429302  4a39 3c42 90ea
        bne.s   .L9312                          | 3c429308  6608
        tst.w   %d7                             | 3c42930a  4a47  the ASID
        bne.s   .L9312                          | 3c42930c  6604
        bset    #9,%d1                          | 3c42930e  08c1 0009
.L9312:
        or_w_imm -1024, 1                       | 3c429312  827c fc00
        move.l  %d1,(%a0)                       | 3c429316  2081
        btst    #0,(3,%a2,%d3.w)                | 3c429318  0832 0000 3003
        beq.s   .L9324                          | 3c42931e  6704
        bsr.w   mmu_$invalidate                 | 3c429320  6100 ff52
.L9324:
        move.l  (28,%sp),%d0                    | 3c429324  202f 001c
        lsl.l   #8,%d0                          | 3c429328  e188
        lsl.l   #2,%d0                          | 3c42932a  e588
        bset    #0,%d0                          | 3c42932c  08c0 0000
        move.l  %d0,(0,%a2,%d3.w)               | 3c429330  2580 3000
        move.w  %d6,%sr                         | 3c429334  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c429336  4cdf 04dc
        rts                                     | 3c42933a  4e75

| MMU_$VTOP - the physical page number that maps a virtual address.
|   (32,SP) the address  (36,SP) the status's address
| (after the seven saved registers).  MST_$VA_TO_SEGNO gives the
| address's ASID-relative segment table and segment (from PROC1_$AS_ID);
| a table number of 58 or more is "reference to illegal address"
| (16#00040004).  The root table entry must be a valid pointer (type 3)
| and the segment descriptor valid (type 2), else "mmu miss"
| (16#00070001, D0 = 0).  The page map is found by its
| physical page among the OS page-map entries of AST_PMAPS' pages (from
| the entry of AST_PMAPS - GLOBAL_B, 0x1392C00; 721 examined), then of
| OS_PMAPS' (from OS_PMAPS - GLOBAL_B, 0x564800; 257); not found, "va
| does not have os_pmap".
| A resident page descriptor gives the page number in D0, status 0.
MMU_$VTOP:
        movem.l %d2-%d7/%a2,-(%sp)              | 3c42933c  48e7 3f20
        move.l  (32,%sp),%d4                    | 3c429340  282f 0020
        movea.l (36,%sp),%a0                    | 3c429344  206f 0024
        subq.w  #2,%sp                          | 3c429348  554f
        move.w  PROC1_$AS_ID,-(%sp)             | 3c42934a  3f39 3c42 4aa2
        pea     (2,%sp)                         | 3c429350  486f 0002
        move.l  %d4,-(%sp)                      | 3c429354  2f04
        jsr     MST_$VA_TO_SEGNO                | 3c429356  4eb9 3c40 f7e0
        lea     (10,%sp),%sp                    | 3c42935c  4fef 000a
        clr.l   %d5                             | 3c429360  4285
        move.w  (%sp)+,%d5                      | 3c429362  3a1f
        cmp_w_imm 58, 0                         | 3c429364  b07c 003a
        bcs.s   .L9374                          | 3c429368  650a
        move.l  #0x40004,%d3                    | 3c42936a  263c 0004 0004
        bra.w   .L9464                          | 3c429370  6000 00f2
.L9374:
        clr.l   %d1                             | 3c429374  4281
        move.w  %d0,%d1                         | 3c429376  3200
        move.l  %d1,%d2                         | 3c429378  2401
        move.l  (32,%sp),%d4                    | 3c42937a  282f 0020
        move.w  %sr,%d6                         | 3c42937e  40c6
        ori.w   #0x700,%sr                      | 3c429380  007c 0700
        lsl.l   #7,%d2                          | 3c429384  ef8a
        lsl.l   #3,%d2                          | 3c429386  e78a
        lea     RARS,%a0                        | 3c429388  41f9 3d32 0000
        lea     (0,%a0,%d2.l),%a1               | 3c42938e  43f0 2800
        move.l  %d4,%d2                         | 3c429392  2404
        swap    %d2                             | 3c429394  4842
        and_w_imm 0x3FC0, 2                     | 3c429396  c47c 3fc0
        moveq   #3,%d3                          | 3c42939a  7603
        lsr.w   #4,%d2                          | 3c42939c  e84a
        and.b   (3,%a1,%d2.w),%d3               | 3c42939e  c631 2003
        cmp_w_imm 3, 3                          | 3c4293a2  b67c 0003
        bne.w   mmu_$vtop_miss                  | 3c4293a6  6600 00c8
        mulu_l_imm 0x3B800, 1                   | 3c4293aa  4c3c 1001 0003 b800
        movea.l #SMAPS,%a0                      | 3c4293b2  207c 3c5a 5000
        lea     (0,%a0,%d1.l),%a1               | 3c4293b8  43f0 1800
        lsl.l   #3,%d5                          | 3c4293bc  e78d
        moveq   #3,%d3                          | 3c4293be  7603
        and.b   (3,%a1,%d5.l),%d3               | 3c4293c0  c631 5803
        cmp_w_imm 2, 3                          | 3c4293c4  b67c 0002
        bne.l   mmu_$vtop_miss                  | 3c4293c8  66ff 0000 00a6
        moveq   #-16,%d7                        | 3c4293ce  7ef0
        and.l   (4,%a1,%d5.l),%d7               | 3c4293d0  ceb1 5804
        move.l  %d7,%d2                         | 3c4293d4  2407
        and_w_imm -1024, 2                      | 3c4293d6  c47c fc00
        move.l  #0x3FFFC00,%d0                  | 3c4293da  203c 03ff fc00
        move.l  #0x1392C00,%d3                  | 3c4293e0  263c 0139 2c00
        move.l  #720,%d1                        | 3c4293e6  223c 0000 02d0
        moveq   #-1,%d5                         | 3c4293ec  7aff
.L93EE:
        movea.l #OS_PMAPS,%a2                   | 3c4293ee  247c 3c56 4800
        lsr.l   #8,%d3                          | 3c4293f4  e08b
        and_w_imm -4, 3                         | 3c4293f6  c67c fffc
        adda.l  %d3,%a2                         | 3c4293fa  d5c3
.L93FC:
        move.l  (%a2)+,%d3                      | 3c4293fc  261a
        and.l   %d0,%d3                         | 3c4293fe  c680
        cmp.l   %d2,%d3                         | 3c429400  b682
        dbeq    %d1,.L93FC                      | 3c429402  57c9 fff8
        bne.s   .L9414                          | 3c429406  660c
        btst    #0,(-1,%a2)                     | 3c429408  082a 0000 ffff
        bne.s   .L9428                          | 3c42940e  6618
        dbf     %d1,.L93FC                      | 3c429410  51c9 ffea
.L9414:
        addq.l  #1,%d5                          | 3c429414  5285
        bne.w   mmu_$no_os_pmap                 | 3c429416  6600 fd38
        move.l  #0x564800,%d3                   | 3c42941a  263c 0056 4800
        move.l  #256,%d1                        | 3c429420  223c 0000 0100
        bra.s   .L93EE                          | 3c429426  60c6
.L9428:
        move.l  %a2,%d1                         | 3c429428  220a
        sub_l_imm OS_PMAPS+4, 1                 | 3c42942a  92bc 3c56 4804
        lsr.l   #2,%d1                          | 3c429430  e489
        lsl.l   #2,%d1                          | 3c429432  e589
        lsl.l   #8,%d1                          | 3c429434  e189
        add_l_imm GLOBAL_B, 1                   | 3c429436  d2bc 3c00 0000
        and_l_imm 896, 7                        | 3c42943c  cebc 0000 0380
        add.l   %d7,%d1                         | 3c429442  d287
        movea.l %d1,%a0                         | 3c429444  2041
        lsr.l   #8,%d4                          | 3c429446  e08c
        and_w_imm 124, 4                        | 3c429448  c87c 007c
        move.l  (0,%a0,%d4.w),%d0               | 3c42944c  2030 4000
        btst    #0,%d0                          | 3c429450  0800 0000
        beq.s   mmu_$vtop_miss                  | 3c429454  671a
        lsr.l   #8,%d0                          | 3c429456  e088
        lsr.l   #2,%d0                          | 3c429458  e488
        and_l_imm 0xFFFF, 0                     | 3c42945a  c0bc 0000 ffff
        clr.l   %d3                             | 3c429460  4283
mmu_$vtop_done:
        move.w  %d6,%sr                         | 3c429462  46c6
.L9464:
        movea.l (36,%sp),%a0                    | 3c429464  206f 0024
        move.l  %d3,(%a0)                       | 3c429468  2083
        movem.l (%sp)+,%d2-%d7/%a2              | 3c42946a  4cdf 04fc
        rts                                     | 3c42946e  4e75
mmu_$vtop_miss:
        move.l  #0x70001,%d3                    | 3c429470  263c 0007 0001
        clr.l   %d0                             | 3c429476  4280
        bra.s   mmu_$vtop_done                  | 3c429478  60e8

| MMU_$GET_PMAPE_ADDR - the address of a virtual address's page
| descriptor, in A0.
|   (28,SP) the address
| The descriptor's cache-inhibit bit is set and the translations
| flushed on the way.
MMU_$GET_PMAPE_ADDR:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c42947a  48e7 3b20
        move.l  (28,%sp),%d4                    | 3c42947e  282f 001c
        bsr.w   mmu_$locate                     | 3c429482  6100 fc6a
        lea     (0,%a2,%d3.w),%a0               | 3c429486  41f2 3000
        bset    #6,(3,%a0)                      | 3c42948a  08e8 0006 0003
        bsr.w   MMU_$PURGE                      | 3c429490  6100 0110
        move.w  %d6,%sr                         | 3c429494  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c429496  4cdf 04dc
        rts                                     | 3c42949a  4e75

| MMU_$SET_PMAPE - set a page descriptor to a page.
|   (4,SP) the virtual address  (8,SP) the descriptor's address
|   (12,SP) the page number
| The address's translation is flushed (pflush) and the descriptor set
| to the frame, cache inhibited, type 1.  No interrupt mask.
MMU_$SET_PMAPE:
        movea.l (4,%sp),%a0                     | 3c42949c  206f 0004
        bsr.w   mmu_$flush_va                   | 3c4294a0  6100 001a
        movea.l (8,%sp),%a0                     | 3c4294a4  206f 0008
        move.l  (12,%sp),%d0                    | 3c4294a8  202f 000c
        lsl.l   #8,%d0                          | 3c4294ac  e188
        lsl.l   #2,%d0                          | 3c4294ae  e588
        bset    #0,%d0                          | 3c4294b0  08c0 0000
        bset    #6,%d0                          | 3c4294b4  08c0 0006
        move.l  %d0,(%a0)                       | 3c4294b8  2080
        rts                                     | 3c4294ba  4e75

| mmu_$flush_va (local, `bsr'): flush the translation of the address in
| A0 (function code 0, mask 0): the MC68851's `pflushs' (the shared
| entries too) without an MC68030, else the MC68030's `pflush'.
mmu_$flush_va:
        tst.b   (M68030).l                      | 3c4294bc  4a39 3c42 90ea
        bne.s   .L94CA                          | 3c4294c2  6606
        pflushs #0,#0,(%a0)                     | 3c4294c4  f010 3c10
        bra.s   .L94CE                          | 3c4294c8  6004
.L94CA:
        pflush  #0,#0,(%a0)                     | 3c4294ca  f010 3810
.L94CE:
        rts                                     | 3c4294ce  4e75

| MMU_$INSTALL_ASID - make an ASID the current address space.
|   (4,SP) the ASID, a word
| Nothing for the current ASID.  Else PROC1_$AS_ID is set and the
| control bits in MMU_$PID_PRIV's copy: with an FPA save area
| (FPA_$SAVEP) bit 1 cleared when the ASID is FPA_$OWNER's and set
| otherwise, bit 2 the same for FP_$OWNER; the copy goes back and to
| the CPU control register (MMU + 0x101).  The root pointer gets the
| ASID's MMU_$RARS_PHADDR entry and is loaded with `pmove', the
| interrupts masked.  Without an MC68030 the MC68851's cache status
| goes to MMU + 0x300, a zero byte to SC_PAGE + 0xE, and `pflusha'
| flushes the translations; with one the data cache is cleared (CACR
| bit 11).  CACHE_$CLEAR clears the instruction cache (a `bra': its
| `rts' returns).
MMU_$INSTALL_ASID:
        clr.l   %d0                             | 3c4294d0  4280
        move.w  (4,%sp),%d0                     | 3c4294d2  302f 0004
        cmp.w   PROC1_$AS_ID,%d0                | 3c4294d6  b079 3c42 4aa2
        beq.w   .L956C                          | 3c4294dc  6700 008e
        move.w  %d0,PROC1_$AS_ID                | 3c4294e0  33c0 3c42 4aa2
        move.w  (MMU_$PID_PRIV,%pc),%d1         | 3c4294e6  323a fb0c
        tst.l   FPA_$SAVEP                      | 3c4294ea  4ab9 3c42 638e
        beq.s   .L9504                          | 3c4294f0  6712
        cmp.w   FPA_$OWNER,%d0                  | 3c4294f2  b079 3c42 6392
        bne.s   .L9500                          | 3c4294f8  6606
        bclr    #1,%d1                          | 3c4294fa  0881 0001
        bra.s   .L9504                          | 3c4294fe  6004
.L9500:
        bset    #1,%d1                          | 3c429500  08c1 0001
.L9504:
        cmp.w   FP_$OWNER,%d0                   | 3c429504  b079 3c42 637a
        bne.s   .L9512                          | 3c42950a  6606
        bclr    #2,%d1                          | 3c42950c  0881 0002
        bra.s   .L9516                          | 3c429510  6004
.L9512:
        bset    #2,%d1                          | 3c429512  08c1 0002
.L9516:
        move.w  %d1,MMU_$PID_PRIV               | 3c429516  33c1 3c42 8ff4
        move.b  %d1,MMU+0x101                   | 3c42951c  13c1 3fff b501
        lea     (MMU_$RARS_PHADDR,%pc),%a0      | 3c429522  41fa fade
        move.l  (0,%a0,%d0.w*4),%d0             | 3c429526  2030 0400
        move.w  %sr,%d1                         | 3c42952a  40c1
        ori.w   #0x700,%sr                      | 3c42952c  007c 0700
        move.l  %d0,mmu_$crp_root               | 3c429530  23c0 3c42 8ffa
        lea     (mmu_$crp,%pc),%a0              | 3c429536  41fa fabe
        pmove   (%a0),%crp                      | 3c42953a  f010 4c00
        move.b  (M68030,%pc),%d0                | 3c42953e  103a fbaa
        bne.s   .L955A                          | 3c429542  6616
        pmove   %pcsr,(MMU+0x300).l             | 3c429544  f039 6600 3fff b700
        move.b  #0,SC_PAGE+0xE                  | 3c42954c  13fc 0000 3ffb 000e
        pflusha                                 | 3c429554  f000 2400
        bra.s   .L9566                          | 3c429558  600c
.L955A:
        movec   %cacr,%d0                       | 3c42955a  4e7a 0002
        bset    #11,%d0                         | 3c42955e  08c0 000b
        movec   %d0,%cacr                       | 3c429562  4e7b 0002
.L9566:
        move.w  %d1,%sr                         | 3c429566  46c1
        bra.w   CACHE_$CLEAR                    | 3c429568  6000 00f6
.L956C:
        rts                                     | 3c42956c  4e75

| MMU_$PAGE_WRITE_BIT - write-protect a page or not.
|   (24,SP) the address  (29,SP) the protection, the low byte of a word
| The page descriptor's write-protect bit is set unless protection bit
| 2 is; MMU_$PURGE.
MMU_$PAGE_WRITE_BIT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c42956e  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c429572  282f 0018
        bsr.w   mmu_$locate                     | 3c429576  6100 fb76
        move.b  (29,%sp),%d1                    | 3c42957a  122f 001d
        btst    #2,%d1                          | 3c42957e  0801 0002
        bne.s   .L958C                          | 3c429582  6608
        bset    #2,(3,%a2,%d3.w)                | 3c429584  08f2 0002 3003
        bra.s   .L9592                          | 3c42958a  6006
.L958C:
        bclr    #2,(3,%a2,%d3.w)                | 3c42958c  08b2 0002 3003
.L9592:
        bsr.w   MMU_$PURGE                      | 3c429592  6100 000e
        move.w  %d6,%sr                         | 3c429596  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c429598  4cdf 045c
        rts                                     | 3c42959c  4e75

| MMU_$PURGE_TB - flush the translations: MMU_$PURGE.  Its arguments
| are not read; the `rts' after the branch is never reached.
MMU_$PURGE_TB:
        bra.s   MMU_$PURGE                      | 3c42959e  6002
        rts                                     | 3c4295a0  4e75

| MMU_$PURGE - flush the address translation cache and the virtual
| cache (CACHE_$FLUSH_VIRTUAL: the data cache).
MMU_$PURGE:
        pflusha                                 | 3c4295a2  f000 2400
        bsr.w   CACHE_$FLUSH_VIRTUAL            | 3c4295a6  6100 00c6
        rts                                     | 3c4295aa  4e75

| MMU_$SET_SEG_PROT - set a segment's protection; the old one in D0.
|   (24,SP) an address in the segment  (29,SP) the protection, a byte
| The old protection is the descriptor's low four table-address bits
| with bit 2 the inverse of write protect and bit 4 the supervisor bit;
| the new one goes in the same way.  MMU_$PURGE.
MMU_$SET_SEG_PROT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c4295ac  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c4295b0  282f 0018
        bsr.w   mmu_$locate                     | 3c4295b4  6100 fb38
        move.l  (%a0),%d1                       | 3c4295b8  2210
        move.l  (4,%a0),%d0                     | 3c4295ba  2028 0004
        and_l_imm 15, 0                         | 3c4295be  c0bc 0000 000f
        btst    #2,%d1                          | 3c4295c4  0801 0002
        beq.s   .L95D0                          | 3c4295c8  6706
        bclr    #2,%d0                          | 3c4295ca  0880 0002
        bra.s   .L95D4                          | 3c4295ce  6004
.L95D0:
        bset    #2,%d0                          | 3c4295d0  08c0 0002
.L95D4:
        btst    #8,%d1                          | 3c4295d4  0801 0008
        beq.s   .L95E0                          | 3c4295d8  6706
        bset    #4,%d0                          | 3c4295da  08c0 0004
        bra.s   .L95E4                          | 3c4295de  6004
.L95E0:
        bclr    #4,%d0                          | 3c4295e0  0880 0004
.L95E4:
        move.b  (29,%sp),%d2                    | 3c4295e4  142f 001d
        move.l  %d2,%d3                         | 3c4295e8  2602
        and_l_imm 15, 3                         | 3c4295ea  c6bc 0000 000f
        move.l  (4,%a0),%d4                     | 3c4295f0  2828 0004
        and_l_imm -16, 4                        | 3c4295f4  c8bc ffff fff0
        or.l    %d3,%d4                         | 3c4295fa  8883
        move.l  %d4,(4,%a0)                     | 3c4295fc  2144 0004
        btst    #4,%d2                          | 3c429600  0802 0004
        beq.s   .L960C                          | 3c429604  6706
        bset    #8,%d1                          | 3c429606  08c1 0008
        bra.s   .L9610                          | 3c42960a  6004
.L960C:
        bclr    #8,%d1                          | 3c42960c  0881 0008
.L9610:
        btst    #2,%d2                          | 3c429610  0802 0002
        beq.s   .L961C                          | 3c429614  6706
        bclr    #2,%d1                          | 3c429616  0881 0002
        bra.s   .L9620                          | 3c42961a  6004
.L961C:
        bset    #2,%d1                          | 3c42961c  08c1 0002
.L9620:
        move.l  %d1,(%a0)                       | 3c429620  2081
        bsr.w   MMU_$PURGE                      | 3c429622  6100 ff7e
        move.w  %d6,%sr                         | 3c429626  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c429628  4cdf 045c
        rts                                     | 3c42962c  4e75

| MMU_$SYSTEM_REV, a longword (zero); MMU_$SET_SYSREV does nothing on
| the SAU7.
MMU_$SYSTEM_REV:
        .long   0                               | 3c42962e  0000 0000
MMU_$SET_SYSREV:
        rts                                     | 3c429632  4e75

| MMU_$NORMAL_MODE - true when bit 0 of MMU + 1 is set (the boolean in
| D0, `sne').
MMU_$NORMAL_MODE:
        btst    #0,MMU+1                        | 3c429634  0839 0000 3fff b401
        sne     %d0                             | 3c42963c  56c0
        rts                                     | 3c42963e  4e75

| MMU_$POWER_OFF - false (D0 cleared): the SAU7 reads no keyswitch.
MMU_$POWER_OFF:
        clr.l   %d0                             | 3c429640  4280
        rts                                     | 3c429642  4e75

| MMU_$MCR_CHANGE - toggle bits of the memory control register (MMU +
| 0x100), whose copy is MMU_$PID_PRIV's high byte.
|   (4,SP) a word (6 taken as 2)
| Its low byte is exclusive-ored into the copy, and the copy stored.
MMU_$MCR_CHANGE:
        move.w  (4,%sp),%d0                     | 3c429644  302f 0004
        cmp_w_imm 6, 0                          | 3c429648  b07c 0006
        bne.s   .L9652                          | 3c42964c  6604
        move.w  #2,%d0                          | 3c42964e  303c 0002
.L9652:
        lea     (MMU_$PID_PRIV,%pc),%a0         | 3c429652  41fa f9a0
        eor.b   %d0,(%a0)                       | 3c429656  b110
        move.b  (%a0),MMU+0x100                 | 3c429658  13d0 3fff b500
        rts                                     | 3c42965e  4e75
