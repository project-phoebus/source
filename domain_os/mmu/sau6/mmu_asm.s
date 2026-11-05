|
| mmu/sau6/mmu_asm.s - MMU_ASM, the SAU6's MMU routines: the DN5xxT's
| in-memory root, segment and page maps
|
| SAU6 map: "D 7802689C MMU_ASM size = 598" (WIRED_DATA).  This file holds
| the segment from its start to MMU_$MCR_CHANGE's end, 0x588 bytes
| (0x7802689C..0x78026E23); the last 16 bytes are CACHE_$CLEAR and
| CACHE_$FLUSH_VIRTUAL, CACHE's (cache/m68k/clear.s,
| cache/m68k/flush_virtual.s).
|
| The MMU translates through tables in memory (`region_mmu',
| `vm_65536_segs', base/config.ins.pas): the current ASID's root table
| (its RARS, MMU_$RARS_PHADDR, per ASID), whose page number the MMU
| takes in its word at MMU + 0x12, gives each region's page of segment
| map entries; a segment map entry is a longword, its valid bit (31),
| the MST entry's protection bits and the physical address of the
| segment's page map (bits 25..0); the page map's entries are longwords,
| their valid bit 31, the write bit 27, the page number in the low word.
| The kernel keeps every ASID's segment map entries in SMAPS (0x3BC00
| bytes each), the global ones from SMAPS + 0x400 (4096 segments of
| 32 Kbytes from GLOBAL_B, and the low segment's at + 0x4000), and the
| global segments' page maps in OS_PMAPS (0x80 bytes each; OS_PMAP0 the
| low segment's).  The MMU's registers are at MMU: + 2 the status (bit 10
| power off), + 3 the control (bit 6 normal mode, bits 5 and 4 the
| translation purges, cleared to purge), + 4 the system revision, + 6
| the ASID (its low byte), + 9 bit 7 the FPU's enable, + 0x11 the MCR.
|
|   MMU_$OS_PMAPS_PHADDR   OS_PMAPS's physical address (COLD stores it)
|   MMU_$RARS_PHADDR       58 longwords, each ASID's RARS (zero here)
|   mmu_$locate            the VA in D4 to its segment map entry (A0) and
|                          the OS page map (A2) with the entry's offset in
|                          D3, D1 bit 0 set for the low segment; at IPL 7,
|                          the old SR in D6.  A VA between 0x8000 and
|                          GLOBAL_B crashes the system ("va not in valid
|                          mmu manager range")
|   MMU_$INSTALL_SPECIAL, MMU_$REMOVE_SPECIAL_SEG, MMU_$PURGE_SEG: the
|                          two special segments below PROT (0x77FB0000),
|                          from SMAPS + 0x3BBD8 per ASID and
|                          OS_PMAP_SPECIAL; with ASID 0 the segment
|                          removed is the one at 0x1018000 (SMAPS +
|                          0x4800)
|   MMU_$REMOVE, MMU_$INSTALL, MMU_$CACHE_INHIBIT_VA (a return),
|   MMU_$VTOP (through MST_$VA_TO_SEGNO, the ASID's RARS entry for the
|   region in RARS, 0x800 bytes per ASID, then a search of the page maps
|   for the frame's page),
|   MMU_$INSTALL_ASID (the ASID, the FPU's enable for FP_$OWNER and the
|   RARS), MMU_$PAGE_WRITE_BIT, MMU_$PURGE_TB, MMU_$PURGE,
|   MMU_$SET_SEG_PROT, MMU_$SYSTEM_REV and MMU_$SET_SYSREV,
|   MMU_$NORMAL_MODE, MMU_$POWER_OFF, MMU_$MCR_CHANGE (the MCR copy, its
|   high nibble to MMU + 0x11)
|
| Hand-written (an `_ASM' segment in a data section, code and data mixed,
| no frame, the arguments read off SP, register-called local entries,
| the saved SR kept in D6 across them).  The labels without a map name
| keep the image address they stand at, but for the entries the routines
| share (the SAU4's names, mmu/sau4/mmu_asm.s).  The image's
| immediate-to-register `cmp', `and', `add' and `sub' use the
| EA-immediate forms (0xB0BC and the like), and its `mulu.l #imm,Dl'
| repeats Dl in the unused Dh field: those are `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau6 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU6 image's.
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
        .long   0x00000000                      | sau6 7802689c  0000 0000
MMU_$RARS_PHADDR:
        .long   0x00000000                      | sau6 780268a0  0000 0000
        .space  0xe4                            | sau6 780268a4  zero to 78026988
mmu_$locate:
        clr.l   %d1                             | sau6 78026988  4281
        move.l  #0xffff8000,%d2                 | sau6 7802698a  243c ffff 8000
        movea.l #OS_PMAPS,%a2                   | sau6 78026990  247c 7819 4800
        movea.l #SMAPS+0x400,%a0                | sau6 78026996  207c 7821 5000
        and.l   %d4,%d2                         | sau6 7802699c  c484
        beq.s   .L780269aa                      | sau6 7802699e  670a
        .short  0xb4bc; .long GLOBAL_B          | sau6 780269a0  b4bc 7800 0000  cmp.l   #GLOBAL_B,%d2
        bge.s   .L780269ba                      | sau6 780269a6  6c12
        bra.s   mmu_$bad_va                     | sau6 780269a8  602e
.L780269aa:
        adda.l  #0x80000,%a2                    | sau6 780269aa  d5fc 0008 0000
        adda.l  #0x4000,%a0                     | sau6 780269b0  d1fc 0000 4000
        bset    #0,%d1                          | sau6 780269b6  08c1 0000
.L780269ba:
        move.l  %d4,%d2                         | sau6 780269ba  2404
        lsr.l   #8,%d2                          | sau6 780269bc  e08a
        moveq   #0x7c,%d3                       | sau6 780269be  767c
        and.w   %d2,%d3                         | sau6 780269c0  c642
        lsr.l   #5,%d2                          | sau6 780269c2  ea8a
        .short  0xc4bc, 0x0000, 0x3ffc          | sau6 780269c4  c4bc 0000 3ffc  and.l   #0x3ffc,%d2
        adda.l  %d2,%a0                         | sau6 780269ca  d1c2
        lsl.l   #5,%d2                          | sau6 780269cc  eb8a
        adda.l  %d2,%a2                         | sau6 780269ce  d5c2
        move.w  %sr,%d6                         | sau6 780269d0  40c6
        ori.w   #0x700,%sr                      | sau6 780269d2  007c 0700
        rts                                     | sau6 780269d6  4e75
mmu_$bad_va:
        pea     (mmu_$st_bad_va:w,%pc)          | sau6 780269d8  487a 0012
        bra.s   mmu_$crash                      | sau6 780269dc  6006
mmu_$no_os_pmap:
        pea     (mmu_$st_no_os_pmap:w,%pc)      | sau6 780269de  487a 0010
        move.w  %d6,%sr                         | sau6 780269e2  46c6
mmu_$crash:
        jsr     (CRASH_SYSTEM).l                | sau6 780269e4  4eb9 7802 0af8
        bra.s   mmu_$crash                      | sau6 780269ea  60f8
mmu_$st_bad_va:
        .long   0x00070002                      | sau6 780269ec  0007 0002
mmu_$st_no_os_pmap:
        .long   0x00070003                      | sau6 780269f0  0007 0003
MMU_$INSTALL_SPECIAL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | sau6 780269f4  48e7 3b20
        move.l  (0x20,%sp),%d4                  | sau6 780269f8  282f 0020
        movea.l #SMAPS,%a0                      | sau6 780269fc  207c 7821 4c00
        clr.l   %d7                             | sau6 78026a02  4287
        move.w  (0x24,%sp),%d7                  | sau6 78026a04  3e2f 0024
        beq.s   mmu_$bad_va                     | sau6 78026a08  67ce
        move.l  #0xffff8000,%d2                 | sau6 78026a0a  243c ffff 8000
        and.l   %d4,%d2                         | sau6 78026a10  c484
        .short  0x94bc, 0x77fb, 0x0000          | sau6 78026a12  94bc 77fb 0000  sub.l   #0x77fb0000,%d2
        lsr.l   #8,%d2                          | sau6 78026a18  e08a
        lsr.l   #7,%d2                          | sau6 78026a1a  ee8a
        .short  0xb4bc, 0x0000, 0x0002          | sau6 78026a1c  b4bc 0000 0002  cmp.l   #2,%d2
        bcc.s   mmu_$bad_va                     | sau6 78026a22  64b4
        lsl.l   #2,%d2                          | sau6 78026a24  e58a
        .short  0x4c3c, 0x7007, 0x0003, 0xbc00  | sau6 78026a26  4c3c 7007 0003 bc00  mulu.l  #0x3bc00,%d7
        .short  0xdebc, 0x0003, 0xbbd8          | sau6 78026a2e  debc 0003 bbd8  add.l   #0x3bbd8,%d7
        adda.l  %d7,%a0                         | sau6 78026a34  d1c7
        adda.l  %d2,%a0                         | sau6 78026a36  d1c2
        movea.l #OS_PMAP_SPECIAL,%a2            | sau6 78026a38  247c 7821 4880
        lsl.l   #5,%d2                          | sau6 78026a3e  eb8a
        adda.l  %d2,%a2                         | sau6 78026a40  d5c2
        move.l  %d4,%d2                         | sau6 78026a42  2404
        lsr.l   #8,%d2                          | sau6 78026a44  e08a
        move.w  #0x7c,%d3                       | sau6 78026a46  363c 007c
        and.w   %d2,%d3                         | sau6 78026a4a  c642
        move.w  %sr,%d6                         | sau6 78026a4c  40c6
        ori.w   #0x700,%sr                      | sau6 78026a4e  007c 0700
        bra.w   mmu_$install_entry              | sau6 78026a52  6000 00e2
MMU_$REMOVE_SPECIAL_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | sau6 78026a56  48e7 2b20
        move.l  (0x18,%sp),%d4                  | sau6 78026a5a  282f 0018
        movea.l #SMAPS,%a0                      | sau6 78026a5e  207c 7821 4c00
        movea.l #OS_PMAP_SPECIAL,%a2            | sau6 78026a64  247c 7821 4880
        move.l  %d4,%d2                         | sau6 78026a6a  2404
        lsr.l   #8,%d2                          | sau6 78026a6c  e08a
        lsr.l   #7,%d2                          | sau6 78026a6e  ee8a
        lsl.l   #2,%d2                          | sau6 78026a70  e58a
        clr.l   %d7                             | sau6 78026a72  4287
        move.w  (0x1c,%sp),%d7                  | sau6 78026a74  3e2f 001c
        beq.s   .L78026aa2                      | sau6 78026a78  6728
        .short  0x94bc, 0x0003, 0xbfd8          | sau6 78026a7a  94bc 0003 bfd8  sub.l   #0x3bfd8,%d2
        .short  0xb4bc, 0x0000, 0x0008          | sau6 78026a80  b4bc 0000 0008  cmp.l   #8,%d2
        bcc.w   mmu_$bad_va                     | sau6 78026a86  6400 ff50
        .short  0x4c3c, 0x7007, 0x0003, 0xbc00  | sau6 78026a8a  4c3c 7007 0003 bc00  mulu.l  #0x3bc00,%d7
        .short  0xdebc, 0x0003, 0xbbd8          | sau6 78026a92  debc 0003 bbd8  add.l   #0x3bbd8,%d7
        add.l   %d2,%d7                         | sau6 78026a98  de82
        adda.l  %d7,%a0                         | sau6 78026a9a  d1c7
        lsl.l   #5,%d2                          | sau6 78026a9c  eb8a
        adda.l  %d2,%a2                         | sau6 78026a9e  d5c2
        bra.s   .L78026ac0                      | sau6 78026aa0  601e
.L78026aa2:
        .short  0xc8bc, 0xffff, 0x8000          | sau6 78026aa2  c8bc ffff 8000  and.l   #-0x8000,%d4
        .short  0xb8bc, 0x0101, 0x8000          | sau6 78026aa8  b8bc 0101 8000  cmp.l   #0x1018000,%d4
        bne.w   mmu_$bad_va                     | sau6 78026aae  6600 ff28
        adda.l  #0x4800,%a0                     | sau6 78026ab2  d1fc 0000 4800
        .short  0xc4bc, 0x0000, 0x03fc          | sau6 78026ab8  c4bc 0000 03fc  and.l   #0x3fc,%d2
        adda.l  %d2,%a0                         | sau6 78026abe  d1c2
.L78026ac0:
        move.w  %sr,%d6                         | sau6 78026ac0  40c6
        ori.w   #0x700,%sr                      | sau6 78026ac2  007c 0700
        bclr    #7,(%a0)                        | sau6 78026ac6  0890 0007
        move.w  (0x1e,%sp),%d0                  | sau6 78026aca  302f 001e
        bra.s   .L78026ae0                      | sau6 78026ace  6010
MMU_$PURGE_SEG:
        movem.l %d2/%d4/%d6-%d7/%a2,-(%sp)      | sau6 78026ad0  48e7 2b20
        movea.l (0x1c,%sp),%a2                  | sau6 78026ad4  246f 001c
        clr.w   %d0                             | sau6 78026ad8  4240
        move.w  %sr,%d6                         | sau6 78026ada  40c6
        ori.w   #0x700,%sr                      | sau6 78026adc  007c 0700
.L78026ae0:
        tst.w   %d0                             | sau6 78026ae0  4a40
        beq.s   .L78026af8                      | sau6 78026ae2  6714
        move.w  #0x1f,%d1                       | sau6 78026ae4  323c 001f
.L78026ae8:
        btst    #7,(%a2)                        | sau6 78026ae8  0812 0007
        beq.s   .L78026af2                      | sau6 78026aec  6704
        bclr    #7,(%a2)                        | sau6 78026aee  0892 0007
.L78026af2:
        addq.l  #4,%a2                          | sau6 78026af2  588a
        dbf     %d1,.L78026ae8                  | sau6 78026af4  51c9 fff2
.L78026af8:
        bsr.w   MMU_$PURGE                      | sau6 78026af8  6100 029c
        move.w  %d6,%sr                         | sau6 78026afc  46c6
        movem.l (%sp)+,%d2/%d4/%d6-%d7/%a2      | sau6 78026afe  4cdf 04d4
        rts                                     | sau6 78026b02  4e75
MMU_$REMOVE:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau6 78026b04  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau6 78026b08  282f 0018
        bsr.w   mmu_$locate                     | sau6 78026b0c  6100 fe7a
        bsr.s   mmu_$invalidate                 | sau6 78026b10  6108
        move.w  %d6,%sr                         | sau6 78026b12  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau6 78026b14  4cdf 045c
        rts                                     | sau6 78026b18  4e75
mmu_$invalidate:
        bclr    #0x1f,(0x0,%a2,%d3.l)           | sau6 78026b1a  08b2 001f 3800
        bra.w   MMU_$PURGE                      | sau6 78026b20  6000 0274
MMU_$CACHE_INHIBIT_VA:
        rts                                     | sau6 78026b24  4e75
MMU_$INSTALL:
        movem.l %d2-%d4/%d6-%d7/%a2,-(%sp)      | sau6 78026b26  48e7 3b20
        move.l  (0x20,%sp),%d4                  | sau6 78026b2a  282f 0020
        bsr.w   mmu_$locate                     | sau6 78026b2e  6100 fe58
        move.w  (0x24,%sp),%d7                  | sau6 78026b32  3e2f 0024
mmu_$install_entry:
        btst    #7,(%a0)                        | sau6 78026b36  0810 0007
        beq.s   .L78026b48                      | sau6 78026b3a  670c
        move.l  (%a0),%d2                       | sau6 78026b3c  2410
        .short  0xc4bc, 0x03ff, 0xffff          | sau6 78026b3e  c4bc 03ff ffff  and.l   #0x3ffffff,%d2
        movea.l %d2,%a1                         | sau6 78026b44  2242
        bra.s   .L78026b72                      | sau6 78026b46  602a
.L78026b48:
        move.l  %a2,%d2                         | sau6 78026b48  240a
        .short  0x94bc; .long GLOBAL_B          | sau6 78026b4a  94bc 7800 0000  sub.l   #GLOBAL_B,%d2
        lsr.l   #8,%d2                          | sau6 78026b50  e08a
        .short  0xc47c, 0xfffc                  | sau6 78026b52  c47c fffc  and.w   #-0x4,%d2
        movea.l #OS_PMAPS,%a1                   | sau6 78026b56  227c 7819 4800
        btst    #7,(0x0,%a1,%d2.l)              | sau6 78026b5c  0831 0007 2800
        beq.w   mmu_$no_os_pmap                 | sau6 78026b62  6700 fe7a
        movea.l %a2,%a1                         | sau6 78026b66  224a
        suba.l  #OS_PMAPS,%a1                   | sau6 78026b68  93fc 7819 4800
        adda.l  (MMU_$OS_PMAPS_PHADDR:w,%pc),%a1 | sau6 78026b6e  d3fa fd2c
.L78026b72:
        clr.l   %d1                             | sau6 78026b72  4281
        move.b  (0x27,%sp),%d1                  | sau6 78026b74  122f 0027
        lsl.w   #8,%d1                          | sau6 78026b78  e149
        lsl.w   #2,%d1                          | sau6 78026b7a  e549
        swap    %d1                             | sau6 78026b7c  4841
        bset    #0x1f,%d1                       | sau6 78026b7e  08c1 001f
        add.l   %a1,%d1                         | sau6 78026b82  d289
        move.l  %d1,(%a0)                       | sau6 78026b84  2081
        btst    #7,(0x0,%a2,%d3.w)              | sau6 78026b86  0832 0007 3000
        beq.s   .L78026b90                      | sau6 78026b8c  6702
        bsr.s   mmu_$invalidate                 | sau6 78026b8e  618a
.L78026b90:
        move.l  (0x1c,%sp),%d0                  | sau6 78026b90  202f 001c
        btst    #2,(0x27,%sp)                   | sau6 78026b94  082f 0002 0027
        beq.s   .L78026ba6                      | sau6 78026b9a  670a
        btst    #0x1c,(%a0)                     | sau6 78026b9c  0810 001c
        bne.s   .L78026ba6                      | sau6 78026ba0  6604
        bset    #0x1b,%d0                       | sau6 78026ba2  08c0 001b
.L78026ba6:
        bset    #0x1f,%d0                       | sau6 78026ba6  08c0 001f
        move.l  %d0,(0x0,%a2,%d3.w)             | sau6 78026baa  2580 3000
        move.w  %d6,%sr                         | sau6 78026bae  46c6
        movem.l (%sp)+,%d2-%d4/%d6-%d7/%a2      | sau6 78026bb0  4cdf 04dc
        rts                                     | sau6 78026bb4  4e75
MMU_$VTOP:
        movem.l %d2-%d7/%a2,-(%sp)              | sau6 78026bb6  48e7 3f20
        move.l  (0x20,%sp),%d4                  | sau6 78026bba  282f 0020
        movea.l (0x24,%sp),%a0                  | sau6 78026bbe  206f 0024
        subq.w  #2,%sp                          | sau6 78026bc2  554f
        move.w  (PROC1_$AS_ID).l,-(%sp)         | sau6 78026bc4  3f39 7802 2baa
        pea     (0x2,%sp)                       | sau6 78026bca  486f 0002
        move.l  %d4,-(%sp)                      | sau6 78026bce  2f04
        jsr     (MST_$VA_TO_SEGNO).l            | sau6 78026bd0  4eb9 7800 e444
        lea     (0xa,%sp),%sp                   | sau6 78026bd6  4fef 000a
        clr.l   %d5                             | sau6 78026bda  4285
        move.w  (%sp)+,%d5                      | sau6 78026bdc  3a1f
        .short  0xb07c, 0x003a                  | sau6 78026bde  b07c 003a  cmp.w   #0x3a,%d0
        bcs.s   .L78026bee                      | sau6 78026be2  650a
        move.l  #0x40004,%d3                    | sau6 78026be4  263c 0004 0004
        bra.w   .L78026cd4                      | sau6 78026bea  6000 00e8
.L78026bee:
        clr.l   %d1                             | sau6 78026bee  4281
        move.w  %d0,%d1                         | sau6 78026bf0  3200
        move.l  %d1,%d2                         | sau6 78026bf2  2401
        move.l  (0x20,%sp),%d4                  | sau6 78026bf4  282f 0020
        move.w  %sr,%d6                         | sau6 78026bf8  40c6
        ori.w   #0x700,%sr                      | sau6 78026bfa  007c 0700
        lsl.l   #8,%d2                          | sau6 78026bfe  e18a
        lsl.l   #3,%d2                          | sau6 78026c00  e78a
        lea     (RARS).l,%a0                    | sau6 78026c02  41f9 78f9 e400
        lea     (0x0,%a0,%d2.l),%a1             | sau6 78026c08  43f0 2800
        move.l  %d4,%d2                         | sau6 78026c0c  2404
        swap    %d2                             | sau6 78026c0e  4842
        .short  0xc47c, 0x7f80                  | sau6 78026c10  c47c 7f80  and.w   #0x7f80,%d2
        lsr.w   #5,%d2                          | sau6 78026c14  ea4a
        btst    #7,(0x0,%a1,%d2.w)              | sau6 78026c16  0831 0007 2000
        beq.w   .L78026ce0                      | sau6 78026c1c  6700 00c2
        .short  0x4c3c, 0x1001, 0x0003, 0xbc00  | sau6 78026c20  4c3c 1001 0003 bc00  mulu.l  #0x3bc00,%d1
        movea.l #SMAPS,%a0                      | sau6 78026c28  207c 7821 4c00
        lea     (0x0,%a0,%d1.l),%a1             | sau6 78026c2e  43f0 1800
        lsl.l   #2,%d5                          | sau6 78026c32  e58d
        btst    #7,(0x0,%a1,%d5.l)              | sau6 78026c34  0831 0007 5800
        beq.w   .L78026ce0                      | sau6 78026c3a  6700 00a4
        move.l  #0x3fffff0,%d7                  | sau6 78026c3e  2e3c 03ff fff0
        and.l   (0x0,%a1,%d5.l),%d7             | sau6 78026c44  ceb1 5800
        move.l  %d7,%d2                         | sau6 78026c48  2407
        lsr.l   #8,%d2                          | sau6 78026c4a  e08a
        lsr.l   #2,%d2                          | sau6 78026c4c  e48a
        move.l  #0xffff,%d0                     | sau6 78026c4e  203c 0000 ffff
        move.l  #0x101f800,%d3                  | sau6 78026c54  263c 0101 f800
        move.l  #0x2d0,%d1                      | sau6 78026c5a  223c 0000 02d0
        moveq   #-1,%d5                         | sau6 78026c60  7aff
.L78026c62:
        movea.l #OS_PMAPS,%a2                   | sau6 78026c62  247c 7819 4800
        lsr.l   #8,%d3                          | sau6 78026c68  e08b
        .short  0xc67c, 0xfffc                  | sau6 78026c6a  c67c fffc  and.w   #-0x4,%d3
        adda.l  %d3,%a2                         | sau6 78026c6e  d5c3
.L78026c70:
        move.l  (%a2)+,%d3                      | sau6 78026c70  261a
        and.l   %d0,%d3                         | sau6 78026c72  c680
        cmp.l   %d2,%d3                         | sau6 78026c74  b682
        dbeq    %d1,.L78026c70                  | sau6 78026c76  57c9 fff8
        bne.s   .L78026c88                      | sau6 78026c7a  660c
        btst    #7,(-0x4,%a2)                   | sau6 78026c7c  082a 0007 fffc
        bne.s   .L78026c9c                      | sau6 78026c82  6618
        dbf     %d1,.L78026c70                  | sau6 78026c84  51c9 ffea
.L78026c88:
        addq.l  #1,%d5                          | sau6 78026c88  5285
        bne.w   mmu_$no_os_pmap                 | sau6 78026c8a  6600 fd52
        move.l  #0x194800,%d3                   | sau6 78026c8e  263c 0019 4800
        move.l  #0x200,%d1                      | sau6 78026c94  223c 0000 0200
        bra.s   .L78026c62                      | sau6 78026c9a  60c6
.L78026c9c:
        move.l  %a2,%d1                         | sau6 78026c9c  220a
        .short  0x92bc; .long OS_PMAPS+4        | sau6 78026c9e  92bc 7819 4804  sub.l   #OS_PMAPS+4,%d1
        lsr.l   #2,%d1                          | sau6 78026ca4  e489
        lsl.l   #2,%d1                          | sau6 78026ca6  e589
        lsl.l   #8,%d1                          | sau6 78026ca8  e189
        .short  0xd2bc; .long GLOBAL_B          | sau6 78026caa  d2bc 7800 0000  add.l   #GLOBAL_B,%d1
        .short  0xcebc, 0x0000, 0x0380          | sau6 78026cb0  cebc 0000 0380  and.l   #0x380,%d7
        add.l   %d7,%d1                         | sau6 78026cb6  d287
        movea.l %d1,%a0                         | sau6 78026cb8  2041
        lsr.l   #8,%d4                          | sau6 78026cba  e08c
        .short  0xc87c, 0x007c                  | sau6 78026cbc  c87c 007c  and.w   #0x7c,%d4
        move.l  (0x0,%a0,%d4.w),%d0             | sau6 78026cc0  2030 4000
        btst    #0x1f,%d0                       | sau6 78026cc4  0800 001f
        beq.s   .L78026ce0                      | sau6 78026cc8  6716
        .short  0xc0bc, 0x0000, 0xffff          | sau6 78026cca  c0bc 0000 ffff  and.l   #0xffff,%d0
        clr.l   %d3                             | sau6 78026cd0  4283
.L78026cd2:
        move.w  %d6,%sr                         | sau6 78026cd2  46c6
.L78026cd4:
        movea.l (0x24,%sp),%a0                  | sau6 78026cd4  206f 0024
        move.l  %d3,(%a0)                       | sau6 78026cd8  2083
        movem.l (%sp)+,%d2-%d7/%a2              | sau6 78026cda  4cdf 04fc
        rts                                     | sau6 78026cde  4e75
.L78026ce0:
        move.l  #0x70001,%d3                    | sau6 78026ce0  263c 0007 0001
        clr.l   %d0                             | sau6 78026ce6  4280
        bra.s   .L78026cd2                      | sau6 78026ce8  60e8
MMU_$INSTALL_ASID:
        clr.l   %d0                             | sau6 78026cea  4280
        move.w  (0x4,%sp),%d0                   | sau6 78026cec  302f 0004
        cmp.w   (PROC1_$AS_ID).l,%d0            | sau6 78026cf0  b079 7802 2baa
        beq.w   .L78026d44                      | sau6 78026cf6  6700 004c
        move.w  %d0,(PROC1_$AS_ID).l            | sau6 78026cfa  33c0 7802 2baa
        move.w  (MMU+0x6).l,%d1                 | sau6 78026d00  3239 7fff b406
        move.b  %d0,%d1                         | sau6 78026d06  1200
        move.w  %d1,(MMU+0x6).l                 | sau6 78026d08  33c1 7fff b406
        .short  0xb03c, 0x0000                  | sau6 78026d0e  b03c 0000  cmp.b   #0,%d0
        beq.s   .L78026d1c                      | sau6 78026d12  6708
        cmp.w   (FP_$OWNER).l,%d0               | sau6 78026d14  b079 7802 3ee2
        beq.s   .L78026d26                      | sau6 78026d1a  670a
.L78026d1c:
        bset    #7,(MMU+0x9).l                  | sau6 78026d1c  08f9 0007 7fff b409
        bra.s   .L78026d2e                      | sau6 78026d24  6008
.L78026d26:
        bclr    #7,(MMU+0x9).l                  | sau6 78026d26  08b9 0007 7fff b409
.L78026d2e:
        lea     (MMU_$RARS_PHADDR:w,%pc),%a0    | sau6 78026d2e  41fa fb70
        move.l  (0x0,%a0,%d0.w*4),%d0           | sau6 78026d32  2030 0400
        lsr.l   #8,%d0                          | sau6 78026d36  e088
        lsr.l   #2,%d0                          | sau6 78026d38  e488
        move.w  %d0,(MMU+0x12).l                | sau6 78026d3a  33c0 7fff b412
        bra.w   CACHE_$CLEAR                    | sau6 78026d40  6000 00e2
.L78026d44:
        rts                                     | sau6 78026d44  4e75
MMU_$PAGE_WRITE_BIT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau6 78026d46  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau6 78026d4a  282f 0018
        bsr.w   mmu_$locate                     | sau6 78026d4e  6100 fc38
        move.b  (0x1d,%sp),%d1                  | sau6 78026d52  122f 001d
        btst    #2,%d1                          | sau6 78026d56  0801 0002
        beq.s   .L78026d64                      | sau6 78026d5a  6708
        bset    #0x1b,(0x0,%a2,%d3.w)           | sau6 78026d5c  08f2 001b 3000
        bra.s   .L78026d6a                      | sau6 78026d62  6006
.L78026d64:
        bclr    #0x1b,(0x0,%a2,%d3.w)           | sau6 78026d64  08b2 001b 3000
.L78026d6a:
        move.w  %d6,%sr                         | sau6 78026d6a  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau6 78026d6c  4cdf 045c
        rts                                     | sau6 78026d70  4e75
MMU_$PURGE_TB:
        move.w  (0x4,%sp),%d1                   | sau6 78026d72  322f 0004
        btst    #5,%d1                          | sau6 78026d76  0801 0005
        beq.s   .L78026d8e                      | sau6 78026d7a  6712
        btst    #4,%d1                          | sau6 78026d7c  0801 0004
        beq.s   .L78026d8e                      | sau6 78026d80  670c
        move.b  #0xff,%d1                       | sau6 78026d82  123c 00ff
        bclr    #5,%d1                          | sau6 78026d86  0881 0005
        bclr    #4,%d1                          | sau6 78026d8a  0881 0004
.L78026d8e:
        and.b   %d1,(MMU+0x3).l                 | sau6 78026d8e  c339 7fff b403
        rts                                     | sau6 78026d94  4e75
MMU_$PURGE:
        andi.b  #0xcf,(MMU+0x3).l               | sau6 78026d96  0239 00cf 7fff b403
        rts                                     | sau6 78026d9e  4e75
MMU_$SET_SEG_PROT:
        movem.l %d2-%d4/%d6/%a2,-(%sp)          | sau6 78026da0  48e7 3a20
        move.l  (0x18,%sp),%d4                  | sau6 78026da4  282f 0018
        bsr.w   mmu_$locate                     | sau6 78026da8  6100 fbde
        clr.w   %d0                             | sau6 78026dac  4240
        move.b  (%a0),%d0                       | sau6 78026dae  1010
        andi.b  #0x50,(%a0)                     | sau6 78026db0  0210 0050
        lsr.w   #2,%d0                          | sau6 78026db4  e448
        move.b  (0x1d,%sp),%d1                  | sau6 78026db6  122f 001d
        lsl.w   #2,%d1                          | sau6 78026dba  e549
        or.b    %d1,(%a0)                       | sau6 78026dbc  8310
        move.w  %d6,%sr                         | sau6 78026dbe  46c6
        movem.l (%sp)+,%d2-%d4/%d6/%a2          | sau6 78026dc0  4cdf 045c
        rts                                     | sau6 78026dc4  4e75
MMU_$SYSTEM_REV:
        .long   0x00000000                      | sau6 78026dc6  0000 0000
MMU_$SET_SYSREV:
        clr.l   %d0                             | sau6 78026dca  4280
        move.w  (MMU+0x4).l,%d0                 | sau6 78026dcc  3039 7fff b404
        move.w  %d0,(MMU_$SYSTEM_REV).l         | sau6 78026dd2  33c0 7802 6dc6
        rts                                     | sau6 78026dd8  4e75
MMU_$NORMAL_MODE:
        btst    #6,(MMU+0x3).l                  | sau6 78026dda  0839 0006 7fff b403
        sne     %d0                             | sau6 78026de2  56c0
        rts                                     | sau6 78026de4  4e75
MMU_$POWER_OFF:
        btst    #0xa,(MMU+0x2).l                | sau6 78026de6  0839 000a 7fff b402
        seq     %d0                             | sau6 78026dee  57c0
        rts                                     | sau6 78026df0  4e75
MMU_$MCR_CHANGE:
        move.w  (0x4,%sp),%d0                   | sau6 78026df2  302f 0004
        .short  0xb07c, 0x0006                  | sau6 78026df6  b07c 0006  cmp.w   #6,%d0
        bne.s   .L78026e00                      | sau6 78026dfa  6604
        move.w  #2,%d0                          | sau6 78026dfc  303c 0002
.L78026e00:
        clr.w   %d1                             | sau6 78026e00  4241
        roxr.w  #1,%d0                          | sau6 78026e02  e250
        roxl.w  #1,%d1                          | sau6 78026e04  e351
        roxr.w  #1,%d0                          | sau6 78026e06  e250
        roxl.w  #1,%d1                          | sau6 78026e08  e351
        roxr.w  #1,%d0                          | sau6 78026e0a  e250
        roxl.w  #1,%d1                          | sau6 78026e0c  e351
        roxr.w  #1,%d0                          | sau6 78026e0e  e250
        roxl.w  #1,%d1                          | sau6 78026e10  e351
        lsl.b   #4,%d1                          | sau6 78026e12  e909
        lea     (mmu_$mcr_copy:w,%pc),%a0       | sau6 78026e14  41fa 000c
        eor.b   %d1,(%a0)                       | sau6 78026e18  b310
        move.b  (%a0),(MMU+0x11).l              | sau6 78026e1a  13d0 7fff b411
        rts                                     | sau6 78026e20  4e75
mmu_$mcr_copy:
        .short  0x0000                          | sau6 78026e22  0000
