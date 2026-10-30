|
| mmu/sau9/mmu_asm.s - MMU_ASM, the SAU9's MMU routines: the MC68030
| PMMU's segment and page descriptors for the forward-table VM
|
| SAU9 map: "D 3C426C44 MMU_ASM size = 634" (WIRED_DATA).  This file
| holds the segment from its start to MMU_$MCR_CHANGE's end, 0x618 bytes
| (0x3C426C44..0x3C42725C); the last 0x1C bytes are CACHE_$CLEAR and
| CACHE_$FLUSH_VIRTUAL, CACHE's (cache/m68k/clear.s, the SAU2's bytes;
| cache/m68k/flush_virtual.s, its `cacr_clear_data' arm).
|
| The SAU9's MMU is the MC68030's own: no PFT, no PTT.  A process's
| translation tree is its ASID's root table (RARS, 1 KB per ASID, the
| CPU root pointer loaded by MMU_$INSTALL_ASID), whose entries point at
| 8-byte segment descriptors in SMAPS (0x3B800 bytes per ASID; the
| global segments at SMAPS + 0x800), each of which points at a segment's
| page map: 32 page descriptors of 4 bytes (OS_PMAPS for the global
| segments, OS_PMAP_SPECIAL for the eight special segments, AST_PMAPS for
| an object's segment).  A page descriptor holds the frame in bits
| 31..10, cache inhibit (bit 6), modified (4), used (3), write protect
| (2) and its type in bits 1..0, resident when 1 (ast/ast.ins.pas,
| ast_$pmap_entry_t).
|
| Hand-written (an `_ASM' segment in a data section, code and data mixed,
| no frame, the arguments read off SP, register-called local entries,
| the saved SR kept in D6 across them).  The routines run with the
| interrupts masked (SR | 0x700) while they change a descriptor, and
| flush the translations with MMU_$PURGE after it.
|
| Byte check: the build has no SAU9 target yet (no sau9.ld, no SAU9
| tables in tools/asm_compare.py).  The file was assembled with
| `m68k-elf-as -m68030', linked at 0x3C426C44 together with the two
| CACHE_ routines (the SAU9 forms of cache/m68k/*.s) and the map's
| addresses for the external symbols, and the 0x634 bytes compared with
| the image's MMU_ASM: identical.  The address and byte columns are the
| SAU9 image's.
|
| The image's immediate-to-register `cmp', `and', `or', `add' and `sub'
| use the EA-immediate forms (0xB0BC and the like), and its `mulu.l
| #imm,Dn' names Dn twice in the extension word; gas spells the first as
| CMPI/ANDI/... and the second with Dh = 0, so the macros below give the
| image's encodings (as svc/m68k/svc_macros.inc's cmp_l_imm).  The
| register operand is the register number.
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

        .globl  MMU_$IMR_COPY
        .globl  MMU_$OS_PMAPS_PHADDR
        .globl  MMU_$RARS_PHADDR
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
        |   OS_PMAPS 0x3C5D4800, OS_PMAP_SPECIAL 0x3C614880, SMAPS
        |   0x3C615000, RARS 0x3D390000, GLOBAL_B 0x3C000000 (the global
        |   segments' first address), PROC1_$AS_ID, FP_$OWNER,
        |   MST_$VA_TO_SEGNO, CRASH_SYSTEM, CACHE_$CLEAR,
        |   CACHE_$FLUSH_VIRTUAL; the I/O registers MMU_ISR 0x3FF9F2C0,
        |   MMU_CCR 0x3FF9F2D0, MMU_LEDR 0x3FF9F800.

| ---- The data -------------------------------------------------------

MMU_$IMR_COPY:                          | 0x3C426C44
        .byte   0                       | the interrupt mask register's copy
        .byte   0                       |   (mmu/mmu.ins.pas), a pad byte
mmu_$crp:                               | 0x3C426C46
        .long   0x00FF0002              | the CPU root pointer for `pmove':
mmu_$crp_root:                          |   limit 0xFF, a valid 8-byte
        .long   0                       |   table; the current ASID's root
                                        |   table (MMU_$INSTALL_ASID)
MMU_$OS_PMAPS_PHADDR:                   | 0x3C426C4E
        .long   0                       | OS_PMAPS's physical address (set
                                        |   at boot)
MMU_$RARS_PHADDR:                       | 0x3C426C52
        .fill   58, 4, 0                | each ASID's root table's physical
                                        |   address (MST_$INIT,
                                        |   MST_$ALLOC_ASID)


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
        clr.l   %d1                             | 3c426d3a  4281
        move.l  #0xFFFF8000,%d2                 | 3c426d3c  243c ffff 8000
        movea.l #OS_PMAPS,%a2                   | 3c426d42  247c 3c5d 4800
        movea.l #SMAPS+0x800,%a0                | 3c426d48  207c 3c61 5800
        and.l   %d4,%d2                         | 3c426d4e  c484
        beq.s   .L6D5C                          | 3c426d50  670a
        cmp_l_imm GLOBAL_B, 2                   | 3c426d52  b4bc 3c00 0000
        bge.s   .L6D6C                          | 3c426d58  6c12
        bra.s   mmu_$bad_va                     | 3c426d5a  603a
.L6D5C:
        adda.l  #0x40000,%a2                    | 3c426d5c  d5fc 0004 0000
        adda.l  #0x4000,%a0                     | 3c426d62  d1fc 0000 4000
        bset    #0,%d1                          | 3c426d68  08c1 0000
.L6D6C:
        move.l  %d4,%d2                         | 3c426d6c  2404
        lsr.l   #8,%d2                          | 3c426d6e  e08a
        moveq   #124,%d3                        | 3c426d70  767c
        and.w   %d2,%d3                         | 3c426d72  c642
        lsr.l   #4,%d2                          | 3c426d74  e88a
        and_l_imm 0x3FF8, 2                     | 3c426d76  c4bc 0000 3ff8
        btst    #0,%d1                          | 3c426d7c  0801 0000
        bne.s   .L6D88                          | 3c426d80  6606
        sub_l_imm 0, 2                          | 3c426d82  94bc 0000 0000
.L6D88:
        adda.l  %d2,%a0                         | 3c426d88  d1c2
        lsl.l   #4,%d2                          | 3c426d8a  e98a
        adda.l  %d2,%a2                         | 3c426d8c  d5c2
        move.w  %sr,%d6                         | 3c426d8e  40c6
        ori.w   #0x700,%sr                      | 3c426d90  007c 0700
        rts                                     | 3c426d94  4e75

| The two crashes: "va not in valid mmu manager range" (16#00070002), and
| "va does not have os_pmap" (16#00070003) with the caller's SR back.
| CRASH_SYSTEM does not return; the loop is the image's.
mmu_$bad_va:
        pea     (mmu_$st_bad_va,%pc)            | 3c426d96  487a 0012
        bra.s   .L6DA2                          | 3c426d9a  6006
mmu_$no_os_pmap:
        pea     (mmu_$st_no_os_pmap,%pc)        | 3c426d9c  487a 0010
        move.w  %d6,%sr                         | 3c426da0  46c6
.L6DA2:
        jsr     CRASH_SYSTEM                    | 3c426da2  4eb9 3c42 1300
        bra.s   .L6DA2                          | 3c426da8  60f8
mmu_$st_bad_va:
        .long   0x00070002                      | 3c426daa  0007 0002
mmu_$st_no_os_pmap:
        .long   0x00070003                      | 3c426dae  0007 0003

| MMU_$INSTALL_SPECIAL - install a physical page at a page of one of an
| ASID's eight special segments (0x3BF80000..0x3BFFFFFF).
|   (28,SP) the page number   (32,SP) the address
|   (36,SP) the ASID, a word  (39,SP) the protection, a byte
| (after the six saved registers).  ASID 0 or an address outside the
| special segments crashes the system.  The segment descriptor is the
| ASID's (SMAPS + ASID * 0x3B800 + 0x3B780 + segment * 8), the page map
| OS_PMAP_SPECIAL + segment * 0x80; then MMU_$INSTALL's code.
MMU_$INSTALL_SPECIAL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c426db2  48e7 3b20
        move.l  (32,%sp),%d4                    | 3c426db6  282f 0020
        movea.l #SMAPS,%a0                      | 3c426dba  207c 3c61 5000
        clr.l   %d7                             | 3c426dc0  4287
        move.w  (36,%sp),%d7                    | 3c426dc2  3e2f 0024
        beq.s   mmu_$bad_va                     | 3c426dc6  67ce
        move.l  #0xFFFF8000,%d2                 | 3c426dc8  243c ffff 8000
        and.l   %d4,%d2                         | 3c426dce  c484
        sub_l_imm 0x3BF80000, 2                 | 3c426dd0  94bc 3bf8 0000
        lsr.l   #8,%d2                          | 3c426dd6  e08a
        lsr.l   #7,%d2                          | 3c426dd8  ee8a
        cmp_l_imm 8, 2                          | 3c426dda  b4bc 0000 0008
        bcc.s   mmu_$bad_va                     | 3c426de0  64b4
        lsl.l   #3,%d2                          | 3c426de2  e78a
        mulu_l_imm 0x3B800, 7                   | 3c426de4  4c3c 7007 0003 b800
        add_l_imm 0x3B780, 7                    | 3c426dec  debc 0003 b780
        adda.l  %d7,%a0                         | 3c426df2  d1c7
        adda.l  %d2,%a0                         | 3c426df4  d1c2
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c426df6  247c 3c61 4880
        lsl.l   #4,%d2                          | 3c426dfc  e98a
        adda.l  %d2,%a2                         | 3c426dfe  d5c2
        move.l  %d4,%d2                         | 3c426e00  2404
        lsr.l   #8,%d2                          | 3c426e02  e08a
        move.w  #124,%d3                        | 3c426e04  363c 007c
        and.w   %d2,%d3                         | 3c426e08  c642
        move.w  %sr,%d6                         | 3c426e0a  40c6
        ori.w   #0x700,%sr                      | 3c426e0c  007c 0700
        bra.w   mmu_$install_entry              | 3c426e10  6000 00e6

| MMU_$REMOVE_SPECIAL_SEG - invalidate a special segment of an ASID.
|   (24,SP) the address  (28,SP) the ASID, a word  (30,SP) a flag word
| ASID 0 names the descriptor at SMAPS + 0x4800 + (segment & 0x7F) * 8
| and OS_PMAP_SPECIAL's first page map; else the address must be in the
| special segments.
| The descriptor's type is cleared (invalid); with the flag set the 32
| page descriptors' resident bits are cleared too.  Then MMU_$PURGE.
MMU_$REMOVE_SPECIAL_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | 3c426e14  48e7 2b20
        move.l  (24,%sp),%d4                    | 3c426e18  282f 0018
        movea.l #SMAPS,%a0                      | 3c426e1c  207c 3c61 5000
        movea.l #OS_PMAP_SPECIAL,%a2            | 3c426e22  247c 3c61 4880
        move.l  %d4,%d2                         | 3c426e28  2404
        lsr.l   #8,%d2                          | 3c426e2a  e08a
        lsr.l   #7,%d2                          | 3c426e2c  ee8a
        lsl.l   #3,%d2                          | 3c426e2e  e78a
        clr.l   %d7                             | 3c426e30  4287
        move.w  (28,%sp),%d7                    | 3c426e32  3e2f 001c
        beq.s   .L6E60                          | 3c426e36  6728
        sub_l_imm 0x3BF80, 2                    | 3c426e38  94bc 0003 bf80
        cmp_l_imm 64, 2                         | 3c426e3e  b4bc 0000 0040
        bcc.w   mmu_$bad_va                     | 3c426e44  6400 ff50
        mulu_l_imm 0x3B800, 7                   | 3c426e48  4c3c 7007 0003 b800
        add_l_imm 0x3B780, 7                    | 3c426e50  debc 0003 b780
        add.l   %d2,%d7                         | 3c426e56  de82
        adda.l  %d7,%a0                         | 3c426e58  d1c7
        lsl.l   #4,%d2                          | 3c426e5a  e98a
        adda.l  %d2,%a2                         | 3c426e5c  d5c2
        bra.s   .L6E6E                          | 3c426e5e  600e
.L6E60:
        adda.l  #0x4800,%a0                     | 3c426e60  d1fc 0000 4800
        and_l_imm 1016, 2                       | 3c426e66  c4bc 0000 03f8
        adda.l  %d2,%a0                         | 3c426e6c  d1c2
.L6E6E:
        move.w  %sr,%d6                         | 3c426e6e  40c6
        ori.w   #0x700,%sr                      | 3c426e70  007c 0700
        andi.l  #-4,(%a0)                       | 3c426e74  0290 ffff fffc
        move.w  (30,%sp),%d0                    | 3c426e7a  302f 001e
        bra.s   .L6E82                          | 3c426e7e  6002
        nop                                     | 3c426e80  4e71
.L6E82:
        tst.w   %d0                             | 3c426e82  4a40
        beq.s   .L6E9E                          | 3c426e84  6718
        move.w  #31,%d1                         | 3c426e86  323c 001f
.L6E8A:
        btst    #0,(3,%a2)                      | 3c426e8a  082a 0000 0003
        beq.s   .L6E98                          | 3c426e90  6706
        bclr    #0,(3,%a2)                      | 3c426e92  08aa 0000 0003
.L6E98:
        addq.l  #4,%a2                          | 3c426e98  588a
        dbf     %d1,.L6E8A                      | 3c426e9a  51c9 ffee
.L6E9E:
        bsr.w   MMU_$PURGE                      | 3c426e9e  6100 02f2
        move.w  %d6,%sr                         | 3c426ea2  46c6
        movem.l (%sp)+,%d2/%d4/%d6-%d7/%a2      | 3c426ea4  4cdf 04d4
        rts                                     | 3c426ea8  4e75

| MMU_$REMOVE - make a virtual address's page not resident.
|   (24,SP) the address
| The page descriptor's resident bit is cleared and the translations
| flushed (mmu_$invalidate, below).
MMU_$REMOVE:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c426eaa  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c426eae  282f 0018
        bsr.w   mmu_$locate                     | 3c426eb2  6100 fe86
        bsr.s   mmu_$invalidate                 | 3c426eb6  6108
        move.w  %d6,%sr                         | 3c426eb8  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c426eba  4cdf 045c
        rts                                     | 3c426ebe  4e75

| mmu_$invalidate (local, `bsr'): clear the resident bit of the page
| descriptor at (A2, D3.w) and flush (MMU_$PURGE's `rts' returns).
mmu_$invalidate:
        bclr    #0,(3,%a2,%d3.w)                | 3c426ec0  08b2 0000 3003
        bra.w   MMU_$PURGE                      | 3c426ec6  6000 02ca

| MMU_$CACHE_INHIBIT_VA - stop caching a virtual address's page.
|   (24,SP) the address
| The page descriptor's cache-inhibit bit (6) is set; MMU_$PURGE.
MMU_$CACHE_INHIBIT_VA:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c426eca  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c426ece  282f 0018
        bsr.w   mmu_$locate                     | 3c426ed2  6100 fe66
        bset    #6,(3,%a2,%d3.w)                | 3c426ed6  08f2 0006 3003
        bsr.w   MMU_$PURGE                      | 3c426edc  6100 02b4
        move.w  %d6,%sr                         | 3c426ee0  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c426ee2  4cdf 045c
        rts                                     | 3c426ee6  4e75

| MMU_$INSTALL - install a physical page at a virtual address.
|   (28,SP) the page number   (32,SP) the address
|   (36,SP) the ASID, a word  (39,SP) the protection, a byte
| (after the six saved registers).
MMU_$INSTALL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c426ee8  48e7 3b20
        move.l  (32,%sp),%d4                    | 3c426eec  282f 0020
        bsr.w   mmu_$locate                     | 3c426ef0  6100 fe48
        move.w  (36,%sp),%d7                    | 3c426ef4  3e2f 0024

| mmu_$install_entry: MMU_$INSTALL's and MMU_$INSTALL_SPECIAL's common
| code, A0 the segment descriptor, A2 the page map, D3.w the page's
| offset, D6 the saved SR.  A valid segment descriptor (type 2) keeps
| its table's address; else the page map's physical address is formed
| from MMU_$OS_PMAPS_PHADDR.  The descriptor is rewritten: the table
| address with the protection's low four bits in its unused low bits;
| limit 31 (bits 30..16), bits 15..10 set, the supervisor bit (8) from
| protection bit 4, write protect (2) unless protection bit 2, type 2.
| A resident page descriptor is invalidated first; the new one is the
| frame (page number * 1024), type 1.
mmu_$install_entry:
        moveq   #3,%d1                          | 3c426ef8  7203
        and.l   (%a0),%d1                       | 3c426efa  c290
        cmp_w_imm 2, 1                          | 3c426efc  b27c 0002
        bne.s   .L6F10                          | 3c426f00  660e
        move.l  (4,%a0),%d2                     | 3c426f02  2428 0004
        and_l_imm -16, 2                        | 3c426f06  c4bc ffff fff0
        movea.l %d2,%a1                         | 3c426f0c  2242
        bra.s   .L6F1C                          | 3c426f0e  600c
.L6F10:
        movea.l %a2,%a1                         | 3c426f10  224a
        suba.l  #OS_PMAPS,%a1                   | 3c426f12  93fc 3c5d 4800
        adda.l  (MMU_$OS_PMAPS_PHADDR,%pc),%a1  | 3c426f18  d3fa fd34
.L6F1C:
        clr.l   %d1                             | 3c426f1c  4281
        clr.l   %d1                             | 3c426f1e  4281
        move.b  (39,%sp),%d1                    | 3c426f20  122f 0027
        move.l  %d1,%d2                         | 3c426f24  2401
        and_l_imm 15, 1                         | 3c426f26  c2bc 0000 000f
        add.l   %a1,%d1                         | 3c426f2c  d289
        move.l  %d1,(4,%a0)                     | 3c426f2e  2141 0004
        move.l  #0x1F0102,%d1                   | 3c426f32  223c 001f 0102
        btst    #4,%d2                          | 3c426f38  0802 0004
        bne.s   .L6F44                          | 3c426f3c  6606
        move.l  #0x1F0002,%d1                   | 3c426f3e  223c 001f 0002
.L6F44:
        btst    #2,%d2                          | 3c426f44  0802 0002
        bne.s   .L6F4E                          | 3c426f48  6604
        bset    #2,%d1                          | 3c426f4a  08c1 0002
.L6F4E:
        or_w_imm -1024, 1                       | 3c426f4e  827c fc00
        move.l  %d1,(%a0)                       | 3c426f52  2081
        btst    #0,(3,%a2,%d3.w)                | 3c426f54  0832 0000 3003
        beq.s   .L6F60                          | 3c426f5a  6704
        bsr.w   mmu_$invalidate                 | 3c426f5c  6100 ff62
.L6F60:
        move.l  (28,%sp),%d0                    | 3c426f60  202f 001c
        lsl.l   #8,%d0                          | 3c426f64  e188
        lsl.l   #2,%d0                          | 3c426f66  e588
        bset    #0,%d0                          | 3c426f68  08c0 0000
        move.l  %d0,(0,%a2,%d3.w)               | 3c426f6c  2580 3000
        move.w  %d6,%sr                         | 3c426f70  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c426f72  4cdf 04dc
        rts                                     | 3c426f76  4e75

| MMU_$VTOP - the physical page number that maps a virtual address.
|   (32,SP) the address  (36,SP) the status's address
| (after the seven saved registers).  MST_$VA_TO_SEGNO gives the
| address's ASID-relative segment table and segment (from PROC1_$AS_ID);
| a table number of 58 or more is "reference to illegal address"
| (16#00040004).  The root table entry must be a valid pointer (type 3)
| and the segment descriptor valid (type 2), else "mmu miss"
| (16#00070001, D0 = 0).  The page map is found by its
| physical page among the OS page-map entries of AST_PMAPS' pages (from
| the entry of AST_PMAPS - GLOBAL_B, 0x1402C00; 721 examined), then of
| OS_PMAPS' (from OS_PMAPS - GLOBAL_B, 0x5D4800; 257); not found, "va
| does not have os_pmap".
| A resident page descriptor gives the page number in D0, status 0.
MMU_$VTOP:
        movem.l %d2-%d7/%a2,-(%sp)              | 3c426f78  48e7 3f20
        move.l  (32,%sp),%d4                    | 3c426f7c  282f 0020
        movea.l (36,%sp),%a0                    | 3c426f80  206f 0024
        subq.w  #2,%sp                          | 3c426f84  554f
        move.w  PROC1_$AS_ID,-(%sp)             | 3c426f86  3f39 3c42 3206
        pea     (2,%sp)                         | 3c426f8c  486f 0002
        move.l  %d4,-(%sp)                      | 3c426f90  2f04
        jsr     MST_$VA_TO_SEGNO                | 3c426f92  4eb9 3c40 fda8
        lea     (10,%sp),%sp                    | 3c426f98  4fef 000a
        clr.l   %d5                             | 3c426f9c  4285
        move.w  (%sp)+,%d5                      | 3c426f9e  3a1f
        cmp_w_imm 58, 0                         | 3c426fa0  b07c 003a
        bcs.s   .L6FB0                          | 3c426fa4  650a
        move.l  #0x40004,%d3                    | 3c426fa6  263c 0004 0004
        bra.w   .L70A0                          | 3c426fac  6000 00f2
.L6FB0:
        clr.l   %d1                             | 3c426fb0  4281
        move.w  %d0,%d1                         | 3c426fb2  3200
        move.l  %d1,%d2                         | 3c426fb4  2401
        move.l  (32,%sp),%d4                    | 3c426fb6  282f 0020
        move.w  %sr,%d6                         | 3c426fba  40c6
        ori.w   #0x700,%sr                      | 3c426fbc  007c 0700
        lsl.l   #7,%d2                          | 3c426fc0  ef8a
        lsl.l   #3,%d2                          | 3c426fc2  e78a
        lea     RARS,%a0                        | 3c426fc4  41f9 3d39 0000
        lea     (0,%a0,%d2.l),%a1               | 3c426fca  43f0 2800
        move.l  %d4,%d2                         | 3c426fce  2404
        swap    %d2                             | 3c426fd0  4842
        and_w_imm 0x3FC0, 2                     | 3c426fd2  c47c 3fc0
        moveq   #3,%d3                          | 3c426fd6  7603
        lsr.w   #4,%d2                          | 3c426fd8  e84a
        and.b   (3,%a1,%d2.w),%d3               | 3c426fda  c631 2003
        cmp_w_imm 3, 3                          | 3c426fde  b67c 0003
        bne.w   mmu_$vtop_miss                  | 3c426fe2  6600 00c8
        mulu_l_imm 0x3B800, 1                   | 3c426fe6  4c3c 1001 0003 b800
        movea.l #SMAPS,%a0                      | 3c426fee  207c 3c61 5000
        lea     (0,%a0,%d1.l),%a1               | 3c426ff4  43f0 1800
        lsl.l   #3,%d5                          | 3c426ff8  e78d
        moveq   #3,%d3                          | 3c426ffa  7603
        and.b   (3,%a1,%d5.l),%d3               | 3c426ffc  c631 5803
        cmp_w_imm 2, 3                          | 3c427000  b67c 0002
        bne.l   mmu_$vtop_miss                  | 3c427004  66ff 0000 00a6
        moveq   #-16,%d7                        | 3c42700a  7ef0
        and.l   (4,%a1,%d5.l),%d7               | 3c42700c  ceb1 5804
        move.l  %d7,%d2                         | 3c427010  2407
        and_w_imm -1024, 2                      | 3c427012  c47c fc00
        move.l  #0x7FFFC00,%d0                  | 3c427016  203c 07ff fc00
        move.l  #0x1402C00,%d3                  | 3c42701c  263c 0140 2c00
        move.l  #720,%d1                        | 3c427022  223c 0000 02d0
        moveq   #-1,%d5                         | 3c427028  7aff
.L702A:
        movea.l #OS_PMAPS,%a2                   | 3c42702a  247c 3c5d 4800
        lsr.l   #8,%d3                          | 3c427030  e08b
        and_w_imm -4, 3                         | 3c427032  c67c fffc
        adda.l  %d3,%a2                         | 3c427036  d5c3
.L7038:
        move.l  (%a2)+,%d3                      | 3c427038  261a
        and.l   %d0,%d3                         | 3c42703a  c680
        cmp.l   %d2,%d3                         | 3c42703c  b682
        dbeq    %d1,.L7038                      | 3c42703e  57c9 fff8
        bne.s   .L7050                          | 3c427042  660c
        btst    #0,(-1,%a2)                     | 3c427044  082a 0000 ffff
        bne.s   .L7064                          | 3c42704a  6618
        dbf     %d1,.L7038                      | 3c42704c  51c9 ffea
.L7050:
        addq.l  #1,%d5                          | 3c427050  5285
        bne.w   mmu_$no_os_pmap                 | 3c427052  6600 fd48
        move.l  #0x5D4800,%d3                   | 3c427056  263c 005d 4800
        move.l  #256,%d1                        | 3c42705c  223c 0000 0100
        bra.s   .L702A                          | 3c427062  60c6
.L7064:
        move.l  %a2,%d1                         | 3c427064  220a
        sub_l_imm OS_PMAPS+4, 1                 | 3c427066  92bc 3c5d 4804
        lsr.l   #2,%d1                          | 3c42706c  e489
        lsl.l   #2,%d1                          | 3c42706e  e589
        lsl.l   #8,%d1                          | 3c427070  e189
        add_l_imm GLOBAL_B, 1                   | 3c427072  d2bc 3c00 0000
        and_l_imm 896, 7                        | 3c427078  cebc 0000 0380
        add.l   %d7,%d1                         | 3c42707e  d287
        movea.l %d1,%a0                         | 3c427080  2041
        lsr.l   #8,%d4                          | 3c427082  e08c
        and_w_imm 124, 4                        | 3c427084  c87c 007c
        move.l  (0,%a0,%d4.w),%d0               | 3c427088  2030 4000
        btst    #0,%d0                          | 3c42708c  0800 0000
        beq.s   mmu_$vtop_miss                  | 3c427090  671a
        lsr.l   #8,%d0                          | 3c427092  e088
        lsr.l   #2,%d0                          | 3c427094  e488
        and_l_imm 0x1FFFF, 0                    | 3c427096  c0bc 0001 ffff
        clr.l   %d3                             | 3c42709c  4283
mmu_$vtop_done:
        move.w  %d6,%sr                         | 3c42709e  46c6
.L70A0:
        movea.l (36,%sp),%a0                    | 3c4270a0  206f 0024
        move.l  %d3,(%a0)                       | 3c4270a4  2083
        movem.l (%sp)+,%d2-%d7/%a2              | 3c4270a6  4cdf 04fc
        rts                                     | 3c4270aa  4e75
mmu_$vtop_miss:
        move.l  #0x70001,%d3                    | 3c4270ac  263c 0007 0001
        clr.l   %d0                             | 3c4270b2  4280
        bra.s   mmu_$vtop_done                  | 3c4270b4  60e8

| MMU_$GET_PMAPE_ADDR - the address of a virtual address's page
| descriptor, in A0.
|   (28,SP) the address
| The descriptor's cache-inhibit bit is set and the translations
| flushed on the way.
MMU_$GET_PMAPE_ADDR:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | 3c4270b6  48e7 3b20
        move.l  (28,%sp),%d4                    | 3c4270ba  282f 001c
        bsr.w   mmu_$locate                     | 3c4270be  6100 fc7a
        lea     (0,%a2,%d3.w),%a0               | 3c4270c2  41f2 3000
        bset    #6,(3,%a0)                      | 3c4270c6  08e8 0006 0003
        bsr.w   MMU_$PURGE                      | 3c4270cc  6100 00c4
        move.w  %d6,%sr                         | 3c4270d0  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | 3c4270d2  4cdf 04dc
        rts                                     | 3c4270d6  4e75

| MMU_$SET_PMAPE - set a page descriptor to a page.
|   (4,SP) the virtual address  (8,SP) the descriptor's address
|   (12,SP) the page number
| The address's translation is flushed (pflush) and the descriptor set
| to the frame, cache inhibited, type 1.  No interrupt mask.
MMU_$SET_PMAPE:
        movea.l (4,%sp),%a0                     | 3c4270d8  206f 0004
        bsr.w   mmu_$flush_va                   | 3c4270dc  6100 001a
        movea.l (8,%sp),%a0                     | 3c4270e0  206f 0008
        move.l  (12,%sp),%d0                    | 3c4270e4  202f 000c
        lsl.l   #8,%d0                          | 3c4270e8  e188
        lsl.l   #2,%d0                          | 3c4270ea  e588
        bset    #0,%d0                          | 3c4270ec  08c0 0000
        bset    #6,%d0                          | 3c4270f0  08c0 0006
        move.l  %d0,(%a0)                       | 3c4270f4  2080
        rts                                     | 3c4270f6  4e75

| mmu_$flush_va (local, `bsr'): flush the translation of the address in
| A0 (function code 0).
mmu_$flush_va:
        pflush  #0,#0,(%a0)                     | 3c4270f8  f010 3810
        rts                                     | 3c4270fc  4e75

| MMU_$INSTALL_ASID - make an ASID the current address space.
|   (4,SP) the ASID, a word
| Nothing for the current ASID.  Else PROC1_$AS_ID is set; MMU_CCR bit
| 7 is cleared when the ASID is FP_$OWNER's and set otherwise; the root
| pointer gets the ASID's MMU_$RARS_PHADDR entry and is loaded with
| `pmove' (the translations go with it), the data cache cleared (CACR
| bit 11) with the interrupts masked, and CACHE_$CLEAR clears the
| instruction cache (a `bra': its `rts' returns).
MMU_$INSTALL_ASID:
        clr.l   %d0                             | 3c4270fe  4280
        move.w  (4,%sp),%d0                     | 3c427100  302f 0004
        cmp.w   PROC1_$AS_ID,%d0                | 3c427104  b079 3c42 3206
        beq.w   .L715C                          | 3c42710a  6700 0050
        move.w  %d0,PROC1_$AS_ID                | 3c42710e  33c0 3c42 3206
        cmp.w   FP_$OWNER,%d0                   | 3c427114  b079 3c42 44e4
        bne.s   .L7126                          | 3c42711a  660a
        bclr    #7,MMU_CCR                      | 3c42711c  08b9 0007 3ff9 f2d0
        bra.s   .L712E                          | 3c427124  6008
.L7126:
        bset    #7,MMU_CCR                      | 3c427126  08f9 0007 3ff9 f2d0
.L712E:
        lea     (MMU_$RARS_PHADDR,%pc),%a0      | 3c42712e  41fa fb22
        move.l  (0,%a0,%d0.w*4),%d0             | 3c427132  2030 0400
        move.w  %sr,%d1                         | 3c427136  40c1
        ori.w   #0x700,%sr                      | 3c427138  007c 0700
        move.l  %d0,mmu_$crp_root               | 3c42713c  23c0 3c42 6c4a
        lea     (mmu_$crp,%pc),%a0              | 3c427142  41fa fb02
        pmove   (%a0),%crp                      | 3c427146  f010 4c00
        movec   %cacr,%d0                       | 3c42714a  4e7a 0002
        bset    #11,%d0                         | 3c42714e  08c0 000b
        movec   %d0,%cacr                       | 3c427152  4e7b 0002
        move.w  %d1,%sr                         | 3c427156  46c1
        bra.w   CACHE_$CLEAR                    | 3c427158  6000 0102
.L715C:
        rts                                     | 3c42715c  4e75

| MMU_$PAGE_WRITE_BIT - write-protect a page or not.
|   (24,SP) the address  (29,SP) the protection, the low byte of a word
| The page descriptor's write-protect bit is set unless protection bit
| 2 is; MMU_$PURGE.
MMU_$PAGE_WRITE_BIT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c42715e  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c427162  282f 0018
        bsr.w   mmu_$locate                     | 3c427166  6100 fbd2
        move.b  (29,%sp),%d1                    | 3c42716a  122f 001d
        btst    #2,%d1                          | 3c42716e  0801 0002
        bne.s   .L717C                          | 3c427172  6608
        bset    #2,(3,%a2,%d3.w)                | 3c427174  08f2 0002 3003
        bra.s   .L7182                          | 3c42717a  6006
.L717C:
        bclr    #2,(3,%a2,%d3.w)                | 3c42717c  08b2 0002 3003
.L7182:
        bsr.w   MMU_$PURGE                      | 3c427182  6100 000e
        move.w  %d6,%sr                         | 3c427186  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c427188  4cdf 045c
        rts                                     | 3c42718c  4e75

| MMU_$PURGE_TB - flush the translations: MMU_$PURGE.  Its arguments
| are not read; the `rts' after the branch is never reached.
MMU_$PURGE_TB:
        bra.s   MMU_$PURGE                      | 3c42718e  6002
        rts                                     | 3c427190  4e75

| MMU_$PURGE - flush the address translation cache and the virtual
| cache (CACHE_$FLUSH_VIRTUAL: the data cache).
MMU_$PURGE:
        pflusha                                 | 3c427192  f000 2400
        bsr.w   CACHE_$FLUSH_VIRTUAL            | 3c427196  6100 00d2
        rts                                     | 3c42719a  4e75

| MMU_$SET_SEG_PROT - set a segment's protection; the old one in D0.
|   (24,SP) an address in the segment  (29,SP) the protection, a byte
| The old protection is the descriptor's low four table-address bits
| with bit 2 the inverse of write protect and bit 4 the supervisor bit;
| the new one goes in the same way.  MMU_$PURGE.
MMU_$SET_SEG_PROT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | 3c42719c  48e7 3a20
        move.l  (24,%sp),%d4                    | 3c4271a0  282f 0018
        bsr.w   mmu_$locate                     | 3c4271a4  6100 fb94
        move.l  (%a0),%d1                       | 3c4271a8  2210
        move.l  (4,%a0),%d0                     | 3c4271aa  2028 0004
        and_l_imm 15, 0                         | 3c4271ae  c0bc 0000 000f
        btst    #2,%d1                          | 3c4271b4  0801 0002
        beq.s   .L71C0                          | 3c4271b8  6706
        bclr    #2,%d0                          | 3c4271ba  0880 0002
        bra.s   .L71C4                          | 3c4271be  6004
.L71C0:
        bset    #2,%d0                          | 3c4271c0  08c0 0002
.L71C4:
        btst    #8,%d1                          | 3c4271c4  0801 0008
        beq.s   .L71D0                          | 3c4271c8  6706
        bset    #4,%d0                          | 3c4271ca  08c0 0004
        bra.s   .L71D4                          | 3c4271ce  6004
.L71D0:
        bclr    #4,%d0                          | 3c4271d0  0880 0004
.L71D4:
        move.b  (29,%sp),%d2                    | 3c4271d4  142f 001d
        move.l  %d2,%d3                         | 3c4271d8  2602
        and_l_imm 15, 3                         | 3c4271da  c6bc 0000 000f
        move.l  (4,%a0),%d4                     | 3c4271e0  2828 0004
        and_l_imm -16, 4                        | 3c4271e4  c8bc ffff fff0
        or.l    %d3,%d4                         | 3c4271ea  8883
        move.l  %d4,(4,%a0)                     | 3c4271ec  2144 0004
        btst    #4,%d2                          | 3c4271f0  0802 0004
        beq.s   .L71FC                          | 3c4271f4  6706
        bset    #8,%d1                          | 3c4271f6  08c1 0008
        bra.s   .L7200                          | 3c4271fa  6004
.L71FC:
        bclr    #8,%d1                          | 3c4271fc  0881 0008
.L7200:
        btst    #2,%d2                          | 3c427200  0802 0002
        beq.s   .L720C                          | 3c427204  6706
        bclr    #2,%d1                          | 3c427206  0881 0002
        bra.s   .L7210                          | 3c42720a  6004
.L720C:
        bset    #2,%d1                          | 3c42720c  08c1 0002
.L7210:
        move.l  %d1,(%a0)                       | 3c427210  2081
        bsr.w   MMU_$PURGE                      | 3c427212  6100 ff7e
        move.w  %d6,%sr                         | 3c427216  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | 3c427218  4cdf 045c
        rts                                     | 3c42721c  4e75

| MMU_$SYSTEM_REV, a longword (zero); MMU_$SET_SYSREV does nothing on
| the SAU9.
MMU_$SYSTEM_REV:
        .long   0                               | 3c42721e  0000 0000
MMU_$SET_SYSREV:
        rts                                     | 3c427222  4e75

| MMU_$NORMAL_MODE - true when MMU_ISR's bit 0 is set (the boolean in
| D0, `sne').
MMU_$NORMAL_MODE:
        btst    #0,MMU_ISR                      | 3c427224  0839 0000 3ff9 f2c0
        sne     %d0                             | 3c42722c  56c0
        rts                                     | 3c42722e  4e75

| MMU_$POWER_OFF - false (D0 cleared): the SAU9 reads no keyswitch.
MMU_$POWER_OFF:
        clr.l   %d0                             | 3c427230  4280
        rts                                     | 3c427232  4e75

| MMU_$MCR_CHANGE - toggle bits of MMU_LEDR, the LED register.
|   (4,SP) a word (6 taken as 2)
| Its low four bits, in reverse order, are exclusive-ored into the
| register.
MMU_$MCR_CHANGE:
        move.w  (4,%sp),%d0                     | 3c427234  302f 0004
        cmp_w_imm 6, 0                          | 3c427238  b07c 0006
        bne.s   .L7242                          | 3c42723c  6604
        move.w  #2,%d0                          | 3c42723e  303c 0002
.L7242:
        clr.b   %d1                             | 3c427242  4201
        roxr.w  #1,%d0                          | 3c427244  e250
        roxl.w  #1,%d1                          | 3c427246  e351
        roxr.w  #1,%d0                          | 3c427248  e250
        roxl.w  #1,%d1                          | 3c42724a  e351
        roxr.w  #1,%d0                          | 3c42724c  e250
        roxl.w  #1,%d1                          | 3c42724e  e351
        roxr.w  #1,%d0                          | 3c427250  e250
        roxl.w  #1,%d1                          | 3c427252  e351
        eor.b   %d1,MMU_LEDR                    | 3c427254  b339 3ff9 f800
        rts                                     | 3c42725a  4e75
