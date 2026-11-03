/*
 * cold/sau4/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU4)
 *
 * The SAU4's COLD, transcribed from the SAU4 image file (file 0..0x7FC,
 * loaded at 0x201800; sr10.2-install/.../sau4/domain_os), with the
 * SAU2's and SAU3's conventions (cold/sau3/cold_start.s: one section,
 * A5 = COLD with the cells at fixed displacements, the Apollo
 * assembler's <ea>=#imm forms as `.short', the image's branch sizes).
 * The SAU4 map:
 *
 *   D22  201800  COLD               loaded at 201800, size = 7FC
 *   D    201800  COLD_START         size = 7FC
 *        201800  COLD
 *        201820  MOVE_TO_PPN
 *
 * The DNx60 has no PTT or PFT: COLD builds the in-memory translation
 * tables of the region MMU (`region_mmu', base/config.ins.pas; Domain
 * Engineering Handbook ch. 9, 9-2, 9-13) and turns translation on
 * through the CPU's control registers.  In order:
 *   - A5 = COLD, VBR = 0; the boot record's first two longwords are
 *     sysboot's d1 and d2, and with boot device 2 or 6 the diskless record
 *     is copied from the address it passed;
 *   - the DUMP page is copied from where it was loaded (DUMP_LOW) to
 *     DUMP_PHYS, a new trap page is built at TRAP_PAGE_PHYS from the
 *     PROM's vectors, bit 15 of physical 0x8000 is cleared and VBR moves
 *     to the new page;
 *   - the kernel's size (OS_PAGE_END rounded up to a page, less OS_PROC)
 *     sets the low piece's page count, or, when it does not fit below the
 *     split, the high piece's count and PPN (MOVE_TO_PPN);
 *   - MMAP is cleared at its physical address, and every longword of
 *     memory from 0x80000 to 16 MB but the trap page is read and
 *     written back (the ECC boards' check bits), its MMAP entry marked
 *     present; a bus error moves on 256 KB (and 256 MMAP entries);
 *   - cold_map_pages (the map table), with the trap page's bus error
 *     vector put back and VBR = 0 meanwhile; then each memory board's
 *     error-correcting controller in MEM's page is written 1 (a bus error
 *     clears the MMU status and moves on);
 *   - SP = P1_STACK_BASE; OS_$INIT(&cold_boot_params,
 *     &cold_diskless_info), after a trap to the debugger if boot flag
 *     bit 15 is set.
 * cold_map_pages sets the 256 words at physical 0x9000 to 0xFFFF, clears
 * COLD's RARS page and the OS page maps (OS_PMAPS to OS_PAGE_END) at their
 * physical addresses, enters every page of the map table in its segment's
 * page map and its segment map entry (SMAPS, the segments with VA bit 27
 * set from SMAPS + 0x400), records the page's MMAP entry
 * for PPNs from 0x200, points regions 29 and 31 at their segment maps,
 * makes ASID 0 and FP ASID 0 current, loads the RARS (control registers
 * 0x118, 0x117) and turns translation on (0x119 bit 0), marks byte 0 of
 * the trap page, and leaves the tables' physical addresses in
 * DUMP_$RARS_PHADDR, DUMP_$SMAP_PHADDR, MMU_$RARS_PHADDR and
 * MMU_$OS_PMAPS_PHADDR.
 *
 * The control registers are written as words with the instruction in the
 * comment (gas knows no names for them).  The image has no fixup table:
 * physical addresses are literals (the equates below), and kernel
 * addresses are symbol references.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau4 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  Addresses in the comments are the SAU4 image's.
 */

        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  MOVE_TO_PPN
        .globl  cold_start_entry
        .globl  cold_map_pages
        .globl  cold_map_table
        .globl  cold_boot_params
        .globl  cold_diskless_info

/* ---- physical layout of the loaded file (not relocated) ------------------ */
        .equ    COLD_LOW,       0x00201800  /* the RFC load address: file byte 0, COLD */
        .equ    DUMP_LOW,       0x00202000  /* file 0x800: the DUMP page as loaded */
        .equ    DUMP_PHYS,      0x00200C00  /* PPN 0x803: where COLD copies the DUMP page */
        .equ    RARS_PHYS,      0x00201000  /* PPN 0x804: COLD's RARS page (ASID 0) */
        .equ    TRAP_PAGE_PHYS, 0x00201400  /* PPN 0x805: the new trap page (VBR) */
        .equ    KERNEL_LO_BYTES, 0x00055800 /* (0x95F << 10) - 0x202400: kernel bytes below the split */
        .set    KERNEL_HI_VA,   OS_PROC + KERNEL_LO_BYTES /* map 0xF856400: the high piece's first VA */

/* ---- map table entry flags (bits 31..30 of the VA field) ---------------- */
        .equ    MAP_WIRED,      0x80000000  /* kernel page: MMAP wire_count 0x80 */
        .equ    MAP_COLD,       0x40000000  /* COLD's pages: MMAP wire_count 0x40 */

/*
 * The RFC header, 0x201800 (12 bytes): load address, start address,
 * machine type WORD (SAU 4), zero word.  Physical addresses, literals.
 */
COLD:
        .long   COLD_LOW                /* 201800  load: file byte 0 lands here */
        .long   COLD_LOW + 0x24         /* 201804  start: cold_start_entry */
        .short  0x0004                  /* 201808  machine type: SAU 4 */
        .short  0x0000                  /* 20180a  0 */

/*
 * The info block, 0x20180C (24 bytes).  COLD reads only MOVE_TO_PPN;
 * sysboot reads the magic, the split PPN and MOVE_TO_PPN.
 */
rfc_info_block:
        .long   0x00000C00              /* 20180c  file offset of the first kernel page (header + COLD + DUMP) */
        .long   OS_DATA                 /* 201810  OS_DATA */
        .long   OS_PROC                 /* 201814  the first kernel page */
        .long   0xFEED2B03              /* 201818  magic: word FEED, byte 2B, format version 0 */
        .long   0x0000095F              /* 20181c  split PPN (SPLIT_LOW >> 10) */
MOVE_TO_PPN:
        .long   0x00000A00              /* 201820  where the pages past the split go (0x280000) */

/*
 * cold_start_entry, 0x201824: entered from sysboot with d0..d2 and the
 * diskless record's address on the stack.
 */
cold_start_entry:
        movea.l #COLD,%a5                       | sau4 201824  2a7c 0020 1800
        movea.l #0,%a0                          | sau4 20182a  207c 0000 0000
        movec   %a0,%vbr                        | sau4 201830  4e7b 8801
        movem.l (%sp)+,%d0-%d2                  | sau4 201834  4cdf 0007
        movea.l (%sp)+,%a1                      | sau4 201838  225f
        movem.l %d1-%d2,(0x4b6,%a5)             | sau4 20183a  48ed 0006 04b6
        lea     (cold_stack_top:w,%pc),%sp      | sau4 201840  4ffa 07ba
        cmpi.w  #2,(0x4b6,%a5)                  | sau4 201844  0c6d 0002 04b6
        beq.s   .L201854                        | sau4 20184a  6708
        cmpi.w  #6,(0x4b6,%a5)                  | sau4 20184c  0c6d 0006 04b6
        bne.s   .L20185e                        | sau4 201852  660a
.L201854:
        movem.l (%a1)+,%d0-%d6                  | sau4 201854  4cd9 007f
        movem.l %d0-%d6,(0x4c2,%a5)             | sau4 201858  48ed 007f 04c2
.L20185e:
        movea.l #DUMP_PHYS,%a0                  | sau4 20185e  207c 0020 0c00
        move.l  #0xff,%d0                       | sau4 201864  203c 0000 00ff
        movea.l #DUMP_LOW,%a1                   | sau4 20186a  227c 0020 2000
.L201870:
        move.l  (%a1)+,(%a0)+                   | sau4 201870  20d9
        dbf     %d0,.L201870                    | sau4 201872  51c8 fffc
        lea     (TRAP_PAGE_PHYS).l,%a1          | sau4 201876  43f9 0020 1400
        move.l  (%a1),(%a1)+                    | sau4 20187c  22d1
        move.l  (%a1),(%a1)+                    | sau4 20187e  22d1
        lea     (0x8).w,%a0                     | sau4 201880  41f8 0008
        move.w  #0xfd,%d0                       | sau4 201884  303c 00fd
.L201888:
        move.l  (%a0)+,(%a1)+                   | sau4 201888  22d8
        dbf     %d0,.L201888                    | sau4 20188a  51c8 fffc
        move.w  (0x8000).l,%d0                  | sau4 20188e  3039 0000 8000
        .short  0xc07c, 0x7fff                  | sau4 201894  c07c 7fff  and.w   #0x7fff,%d0
        move.w  %d0,(0x8000).l                  | sau4 201898  33c0 0000 8000
        lea     (TRAP_PAGE_PHYS).l,%a2          | sau4 20189e  45f9 0020 1400
        movec   %a2,%vbr                        | sau4 2018a4  4e7b a801
        move.l  (0x8,%a2),-(%sp)                | sau4 2018a8  2f2a 0008
        move.l  %sp,(0x4de,%a5)                 | sau4 2018ac  2b4f 04de
        move.l  #OS_PAGE_END,%d4                | sau4 2018b0  283c 0f91 2400
        .short  0xd8bc, 0x0000, 0x03ff          | sau4 2018b6  d8bc 0000 03ff  add.l   #0x3ff,%d4
        .short  0xc87c, 0xfc00                  | sau4 2018bc  c87c fc00  and.w   #0xfc00,%d4
        .short  0x98bc; .long OS_PROC           | sau4 2018c0  98bc 0f80 0c00  sub.l #OS_PROC,%d4
        .short  0xb8bc; .long KERNEL_LO_BYTES   | sau4 2018c6  b8bc 0005 5800  cmp.l #KERNEL_LO_BYTES,%d4
        bhi.w   .L2018dc                        | sau4 2018cc  6200 000e
        lsr.l   #5,%d4                          | sau4 2018d0  ea8c
        lsr.l   #5,%d4                          | sau4 2018d2  ea8c
        move.w  %d4,(0x414,%a5)                 | sau4 2018d4  3b44 0414
        bra.w   .L2018f0                        | sau4 2018d8  6000 0016
.L2018dc:
        .short  0x98bc; .long KERNEL_LO_BYTES   | sau4 2018dc  98bc 0005 5800  sub.l #KERNEL_LO_BYTES,%d4
        lsr.l   #5,%d4                          | sau4 2018e2  ea8c
        lsr.l   #5,%d4                          | sau4 2018e4  ea8c
        swap    %d4                             | sau4 2018e6  4844
        move.w  (MOVE_TO_PPN+2:w,%pc),%d4       | sau4 2018e8  383a ff38
        move.l  %d4,(0x41e,%a5)                 | sau4 2018ec  2b44 041e
.L2018f0:
        move.l  (MOVE_TO_PPN:w,%pc),%d4         | sau4 2018f0  283a ff2e
        lsl.l   #5,%d4                          | sau4 2018f4  eb8c
        lsl.l   #5,%d4                          | sau4 2018f6  eb8c
        .short  0x98bc; .long OS_PROC           | sau4 2018f8  98bc 0f80 0c00  sub.l #OS_PROC,%d4
        .short  0x98bc; .long KERNEL_LO_BYTES   | sau4 2018fe  98bc 0005 5800  sub.l #KERNEL_LO_BYTES,%d4
        .short  0xd8bc; .long MMAP              | sau4 201904  d8bc 0f8c 4800  add.l #MMAP,%d4
        movea.l %d4,%a4                         | sau4 20190a  2844
        move.l  %a4,(0x4e2,%a5)                 | sau4 20190c  2b4c 04e2
        lea     (cold_mem_bus_err:w,%pc),%a0    | sau4 201910  41fa 0058
        move.l  %a0,(0x8,%a2)                   | sau4 201914  2548 0008
        move.w  #0x3dff,%d0                     | sau4 201918  303c 3dff
.L20191c:
        clr.l   (%a4)+                          | sau4 20191c  429c
        clr.l   (%a4)+                          | sau4 20191e  429c
        clr.l   (%a4)+                          | sau4 201920  429c
        clr.l   (%a4)+                          | sau4 201922  429c
        dbf     %d0,.L20191c                    | sau4 201924  51c8 fff6
        movea.l #0x80000,%a0                    | sau4 201928  207c 0008 0000
        movea.l (cold_mmap_phys:w,%pc),%a4      | sau4 20192e  287a 03b2
        adda.l  #0,%a4                          | sau4 201932  d9fc 0000 0000
cold_mem_page:
        lea     (0x400,%a0),%a1                 | sau4 201938  43e8 0400
        cmpa.l  #0x1000000,%a0                  | sau4 20193c  b1fc 0100 0000
        beq.s   cold_mem_done                   | sau4 201942  674e
        cmpa.l  #TRAP_PAGE_PHYS,%a0             | sau4 201944  b1fc 0020 1400
        beq.s   .L20197a                        | sau4 20194a  672e
        cmpa.l  #0x1000000,%a0                  | sau4 20194c  b1fc 0100 0000
        bge.s   .L20197a                        | sau4 201952  6c26
.L201954:
        move.l  (%a0),%d4                       | sau4 201954  2810
        move.l  %d4,(%a0)+                      | sau4 201956  20c4
        cmpa.l  %a0,%a1                         | sau4 201958  b3c8
        bne.s   .L201954                        | sau4 20195a  66f8
        move.l  #0x40000000,(%a4)               | sau4 20195c  28bc 4000 0000
        adda.l  #0x10,%a4                       | sau4 201962  d9fc 0000 0010
        bra.s   cold_mem_page                   | sau4 201968  60ce
cold_mem_bus_err:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau4 20196a  2e7a 0372
        move.w  #0,(0x8002).l                   | sau4 20196e  33fc 0000 0000 8002
        bsr.s   .L201984                        | sau4 201976  610c
        bra.s   cold_mem_page                   | sau4 201978  60be
.L20197a:
        adda.l  #0x10,%a4                       | sau4 20197a  d9fc 0000 0010
        movea.l %a1,%a0                         | sau4 201980  2049
        bra.s   cold_mem_page                   | sau4 201982  60b4
.L201984:
        adda.l  #0x1000,%a4                     | sau4 201984  d9fc 0000 1000
        adda.l  #0x40000,%a0                    | sau4 20198a  d1fc 0004 0000
        rts                                     | sau4 201990  4e75
cold_mem_done:
        move.l  (%sp)+,(0x8,%a2)                | sau4 201992  255f 0008
        movea.l #0,%a2                          | sau4 201996  247c 0000 0000
        movec   %a2,%vbr                        | sau4 20199c  4e7b a801
        lea     (cold_map_table:w,%pc),%a0      | sau4 2019a0  41fa 0240
        bsr.w   cold_map_pages                  | sau4 2019a4  6100 006c
        lea     (cold_ecc_bus_err:w,%pc),%a0    | sau4 2019a8  41fa 0032
        move.l  (0x8).w,-(%sp)                  | sau4 2019ac  2f38 0008
        move.l  %a0,(0x8).w                     | sau4 2019b0  21c8 0008
        move.l  %sp,(0x4de,%a5)                 | sau4 2019b4  2b4f 04de
        move.w  #1,%d0                          | sau4 2019b8  303c 0001
        movea.l #MEM,%a0                        | sau4 2019bc  207c 0fff 9000
        addq.w  #2,%a0                          | sau4 2019c2  5448
        movea.l %a0,%a1                         | sau4 2019c4  2248
        adda.w  #0x3e0,%a1                      | sau4 2019c6  d2fc 03e0
.L2019ca:
        move.w  %d0,(%a0)                       | sau4 2019ca  3080
        tst.w   (0x400).w                       | sau4 2019cc  4a78 0400
.L2019d0:
        adda.l  #0x20,%a0                       | sau4 2019d0  d1fc 0000 0020
        cmpa.l  %a0,%a1                         | sau4 2019d6  b3c8
        bne.s   .L2019ca                        | sau4 2019d8  66f0
        bra.s   cold_enter_kernel               | sau4 2019da  6012
cold_ecc_bus_err:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau4 2019dc  2e7a 0300
        movea.l #MMU,%a4                        | sau4 2019e0  287c 0fff b400
        move.w  #0,(0x2,%a4)                    | sau4 2019e6  397c 0000 0002
        bra.s   .L2019d0                        | sau4 2019ec  60e2
cold_enter_kernel:
        move.l  (%sp)+,(0x8).w                  | sau4 2019ee  21df 0008
        movea.l #P1_STACK_BASE,%sp              | sau4 2019f2  2e7c 0f8c 2000
        pea     (cold_diskless_info:w,%pc)      | sau4 2019f8  487a 02c8
        pea     (cold_boot_params:w,%pc)        | sau4 2019fc  487a 02b8
        movea.l #OS_$INIT,%a0                   | sau4 201a00  207c 0f83 6a38
        btst    #0xf,(cold_boot_params+6:w,%pc) | sau4 201a06  083a 000f 02b2
        beq.s   cold_call_os_init               | sau4 201a0c  6702
        trap    #0xf                            | sau4 201a0e  4e4f
cold_call_os_init:
        jsr     (%a0)                           | sau4 201a10  4e90
cold_map_pages:
        lea     (0x9000).l,%a3                  | sau4 201a12  47f9 0000 9000
        move.w  #0xff,%d4                       | sau4 201a18  383c 00ff
        move.w  #0xffff,%d0                     | sau4 201a1c  303c ffff
.L201a20:
        move.w  %d0,(%a3)+                      | sau4 201a20  36c0
        dbf     %d4,.L201a20                    | sau4 201a22  51cc fffc
        move.l  (MOVE_TO_PPN:w,%pc),%d0         | sau4 201a26  203a fdf8
        lsl.l   #5,%d0                          | sau4 201a2a  eb88
        lsl.l   #5,%d0                          | sau4 201a2c  eb88
        .short  0x90bc; .long OS_PROC           | sau4 201a2e  90bc 0f80 0c00  sub.l #OS_PROC,%d0
        .short  0x90bc; .long KERNEL_LO_BYTES   | sau4 201a34  90bc 0005 5800  sub.l #KERNEL_LO_BYTES,%d0
        move.l  %d0,%d1                         | sau4 201a3a  2200
        .short  0xd2bc; .long SMAPS             | sau4 201a3c  d2bc 0f90 ac00  add.l #SMAPS,%d1
        move.l  %d1,(0x4e6,%a5)                 | sau4 201a42  2b41 04e6
        move.l  %d0,%d1                         | sau4 201a46  2200
        .short  0xd2bc; .long OS_PMAPS          | sau4 201a48  d2bc 0f90 2800  add.l #OS_PMAPS,%d1
        move.l  %d1,(0x4ea,%a5)                 | sau4 201a4e  2b41 04ea
        movea.l #RARS_PHYS,%a2                  | sau4 201a52  247c 0020 1000
        move.l  #0xff,%d4                       | sau4 201a58  283c 0000 00ff
.L201a5e:
        clr.l   (%a2)+                          | sau4 201a5e  429a
        dbf     %d4,.L201a5e                    | sau4 201a60  51cc fffc
        movea.l (cold_os_pmaps_phys:w,%pc),%a2  | sau4 201a64  247a 0284
        move.l  #OS_PAGE_END+3,%d4              | sau4 201a68  283c 0f91 2403
        .short  0x98bc; .long OS_PMAPS          | sau4 201a6e  98bc 0f90 2800  sub.l #OS_PMAPS,%d4
        lsr.l   #2,%d4                          | sau4 201a74  e48c
        subq.l  #1,%d4                          | sau4 201a76  5384
.L201a78:
        clr.l   (%a2)+                          | sau4 201a78  429a
        dbf     %d4,.L201a78                    | sau4 201a7a  51cc fffc
        clr.w   %d4                             | sau4 201a7e  4244
        subq.l  #1,%d4                          | sau4 201a80  5384
        bcc.s   .L201a78                        | sau4 201a82  64f4
        movea.l (cold_mmap_phys:w,%pc),%a4      | sau4 201a84  287a 025c
        clr.l   %d1                             | sau4 201a88  4281
        clr.l   %d3                             | sau4 201a8a  4283
.L201a8c:
        move.w  (%a0)+,%d0                      | sau4 201a8c  3018
        beq.w   .L201b3e                        | sau4 201a8e  6700 00ae
        move.w  (%a0)+,%d1                      | sau4 201a92  3218
        move.l  (%a0)+,%d2                      | sau4 201a94  2418
        move.l  %d2,%d5                         | sau4 201a96  2a02
        lsr.l   #8,%d5                          | sau4 201a98  e08d
        lsr.l   #5,%d5                          | sau4 201a9a  ea8d
        .short  0xcabc, 0x0000, 0x03fc          | sau4 201a9c  cabc 0000 03fc  and.l   #0x3fc,%d5
        btst    #0x1b,%d2                       | sau4 201aa2  0802 001b
        bne.s   .L201ad0                        | sau4 201aa6  6628
        movea.l (cold_smaps_phys:w,%pc),%a2     | sau4 201aa8  247a 023c
        movea.l (cold_os_pmaps_phys:w,%pc),%a3  | sau4 201aac  267a 023c
        adda.l  #0x800,%a2                      | sau4 201ab0  d5fc 0000 0800
        adda.l  #0x8000,%a3                     | sau4 201ab6  d7fc 0000 8000
        tst.w   %d5                             | sau4 201abc  4a45
        beq.s   .L201ae4                        | sau4 201abe  6724
        adda.w  #0x80,%a3                       | sau4 201ac0  d6fc 0080
        .short  0xcabc, 0x0000, 0x03fc          | sau4 201ac4  cabc 0000 03fc  and.l   #0x3fc,%d5
        adda.l  %d5,%a2                         | sau4 201aca  d5c5
        bra.w   .L201ae4                        | sau4 201acc  6000 0016
.L201ad0:
        movea.l (cold_smaps_phys:w,%pc),%a2     | sau4 201ad0  247a 0214
        movea.l (cold_os_pmaps_phys:w,%pc),%a3  | sau4 201ad4  267a 0214
        adda.l  #0x400,%a2                      | sau4 201ad8  d5fc 0000 0400
        adda.l  %d5,%a2                         | sau4 201ade  d5c5
        lsl.l   #5,%d5                          | sau4 201ae0  eb8d
        adda.l  %d5,%a3                         | sau4 201ae2  d7c5
.L201ae4:
        move.w  (%a0)+,%d4                      | sau4 201ae4  3818
        swap    %d4                             | sau4 201ae6  4844
        move.l  %d2,%d3                         | sau4 201ae8  2602
        clr.w   %d4                             | sau4 201aea  4244
        adda.l  %d4,%a3                         | sau4 201aec  d7c4
        move.w  #0x7c00,%d3                     | sau4 201aee  363c 7c00
        and.w   %d2,%d3                         | sau4 201af2  c642
        bra.w   .L201b08                        | sau4 201af4  6000 0012
.L201af8:
        move.w  #0x7c00,%d3                     | sau4 201af8  363c 7c00
        and.w   %d2,%d3                         | sau4 201afc  c642
        bne.s   .L201b0a                        | sau4 201afe  660a
        addq.l  #4,%a2                          | sau4 201b00  588a
        adda.l  #0x80,%a3                       | sau4 201b02  d7fc 0000 0080
.L201b08:
        move.l  %a3,(%a2)                       | sau4 201b08  248b
.L201b0a:
        lsr.w   #8,%d3                          | sau4 201b0a  e04b
        .short  0x82bc, 0x8000, 0x0000          | sau4 201b0c  82bc 8000 0000  or.l    #0x80000000,%d1
        move.l  %d1,(0x0,%a3,%d3.w)             | sau4 201b12  2781 3000
        .short  0xc6bc, 0xc000, 0x0000          | sau4 201b16  c6bc c000 0000  and.l   #0xc0000000,%d3
        clr.l   %d4                             | sau4 201b1c  4284
        move.w  %d1,%d4                         | sau4 201b1e  3801
        .short  0x987c, 0x0200                  | sau4 201b20  987c 0200  sub.w   #0x200,%d4
        bcs.s   .L201b2e                        | sau4 201b24  6508
        mulu.w  #0x10,%d4                       | sau4 201b26  c8fc 0010
        move.l  %d3,(0x0,%a4,%d4.l)             | sau4 201b2a  2983 4800
.L201b2e:
        addq.w  #1,%d1                          | sau4 201b2e  5241
        .short  0xd4bc, 0x0000, 0x0400          | sau4 201b30  d4bc 0000 0400  add.l   #0x400,%d2
        subq.w  #1,%d0                          | sau4 201b36  5340
        bne.s   .L201af8                        | sau4 201b38  66be
        bra.w   .L201a8c                        | sau4 201b3a  6000 ff50
.L201b3e:
        movea.l (cold_os_pmaps_phys:w,%pc),%a0  | sau4 201b3e  207a 01aa
        adda.l  #0x8000,%a0                     | sau4 201b42  d1fc 0000 8000
        bset    #0x1b,(%a0)                     | sau4 201b48  08d0 001b
        movea.l #RARS_PHYS+0x74,%a1             | sau4 201b4c  227c 0020 1074
        move.l  (cold_smaps_phys:w,%pc),%d4     | sau4 201b52  283a 0192
        .short  0x88bc, 0xc000, 0x0000          | sau4 201b56  88bc c000 0000  or.l    #0xc0000000,%d4
        move.w  #0,%d1                          | sau4 201b5c  323c 0000
.L201b60:
        move.l  %d4,(%a1)+                      | sau4 201b60  22c4
        .short  0xd8bc, 0x0000, 0x0400          | sau4 201b62  d8bc 0000 0400  add.l   #0x400,%d4
        dbf     %d1,.L201b60                    | sau4 201b68  51c9 fff6
        movea.l #RARS_PHYS+0x7c,%a1             | sau4 201b6c  227c 0020 107c
        move.w  #0,%d1                          | sau4 201b72  323c 0000
.L201b76:
        move.l  %d4,(%a1)+                      | sau4 201b76  22c4
        .short  0xd8bc, 0x0000, 0x0400          | sau4 201b78  d8bc 0000 0400  add.l   #0x400,%d4
        dbf     %d1,.L201b76                    | sau4 201b7e  51c9 fff6
        eori.l  #0x40000000,%d4                 | sau4 201b82  0a84 4000 0000
        movea.l #RARS_PHYS,%a1                  | sau4 201b88  227c 0020 1000
        move.l  %d4,(%a1)                       | sau4 201b8e  2284
        clr.l   %d4                             | sau4 201b90  4284
        .short  0x4e7b, 0x411f                  | sau4 201b92  4e7b 411f  movec %d4,0x11f
        .short  0x4e7b, 0x411e                  | sau4 201b96  4e7b 411e  movec %d4,0x11e
        .short  0x4e7b, 0x9118                  | sau4 201b9a  4e7b 9118  movec %a1,0x118
        move.l  #0xa0000001,%d4                 | sau4 201b9e  283c a000 0001
        .short  0x4e7b, 0x4117                  | sau4 201ba4  4e7b 4117  movec %d4,0x117
        .short  0x4e7a, 0x4119                  | sau4 201ba8  4e7a 4119  movec 0x119,%d4
        bset    #0,%d4                          | sau4 201bac  08c4 0000
        .short  0x4e7b, 0x4119                  | sau4 201bb0  4e7b 4119  movec %d4,0x119
        move.b  #0xff,(EC_$NIL_EC).l            | sau4 201bb4  13fc 00ff 0000 0000
        move.l  #RARS_PHYS,(DUMP_$RARS_PHADDR).l | sau4 201bbc  23fc 0020 1000 0f80 0be8
        move.l  (cold_smaps_phys:w,%pc),(DUMP_$SMAP_PHADDR).l | sau4 201bc6  23fa 011e 0f80 0be4
        move.l  #RARS_PHYS,(MMU_$RARS_PHADDR).l | sau4 201bce  23fc 0020 1000 0f82 60b8
        move.l  (cold_os_pmaps_phys:w,%pc),(MMU_$OS_PMAPS_PHADDR).l | sau4 201bd8  23fa 0110 0f82 60b4
        rts                                     | sau4 201be0  4e75
/*
 * cold_map_table, 0x201BE2: what cold_map_pages maps, 10 bytes an entry
 * (page count, first PPN, VA with the flag bits 31..30, the protection
 * word), ended by a zero count.
 */
cold_map_table:
        .short  0x0002, 0x0800          /* 201be2  the CRASH_RECORD page and the next */
        .long   MAP_WIRED + OS_BEGIN
        .short  0xdc00
        .short  0x0001, 0x0803          /* 201bec  DUMP, where COLD copied it */
        .long   MAP_WIRED + DUMP
        .short  0xdc00
        .short  0x0001, 0x0805          /* 201bf6  the new trap page */
        .long   MAP_WIRED + TRAP_PAGE
        .short  0xcc00
        .short  0x001f, 0x0001          /* 201c00  low memory identity */
        .long   0x00000400
        .short  0xcc00
        .short  0x0002, 0x0806          /* 201c0a  COLD itself */
        .long   MAP_COLD + COLD_LOW
        .short  0xdc00
cold_map_kernel_lo_count:
        .short  0x0156, 0x0809          /* 201c14  kernel, low piece; the count is */
                                        /*         rewritten if the kernel fits */
        .long   MAP_WIRED + OS_PROC
        .short  0xdc00
cold_map_kernel_hi_count_ppn:
        .short  0x0000, 0x0000          /* 201c1e  kernel, high piece: count and */
                                        /*         PPN filled by COLD */
        .long   MAP_WIRED + KERNEL_HI_VA
        .short  0xdc00
        .short  0x0001, 0x0804          /* 201c28  RARS: COLD's ASID 0 root page */
        .long   MAP_WIRED + RARS
        .short  0xd800
        .short  0x0001, 0x0024          /* 201c32  IOMAP */
        .long   IOMAP
        .short  0xd800
        .short  0x0001, 0x0023          /* 201c3c  FLOP */
        .long   FLOP
        .short  0xd800
        .short  0x0001, 0x002f          /* 201c46  RING2 (the Winchester's page) */
        .long   RING2
        .short  0xd800
        .short  0x0001, 0x0020          /* 201c50  MMU */
        .long   MMU
        .short  0xd800
        .short  0x0001, 0x0021          /* 201c5a  SIO */
        .long   SIO
        .short  0xd800
        .short  0x0001, 0x0022          /* 201c64  TIMR (and CALENDAR) */
        .long   TIMR
        .short  0xd800
        .short  0x0003, 0x0038          /* 201c6e  the color board's three pages */
        .long   COLOR_SUP
        .short  0xd800
        .short  0x0001, 0x003c          /* 201c78  DISP1 */
        .long   DISP1
        .short  0xd800
        .short  0x0001, 0x003d          /* 201c82  DISP2 */
        .long   DISP2
        .short  0xd800
        .short  0x0001, 0x003f          /* 201c8c  MEM */
        .long   MEM
        .short  0xd800
        .short  0x0040, 0x0040          /* 201c96  the PBU's window, 64 pages */
        .long   PBU
        .short  0xd800
        .short  0x0080, 0x0080          /* 201ca0  DISP1_MEM, 128 pages */
        .long   DISP1_MEM
        .short  0xd800
        .short  0x0080, 0x0100          /* 201caa  DISP2_MEM, 128 pages */
        .long   DISP2_MEM
        .short  0xd800
        .short  0x0000                  /* 201cb4  end */

/*
 * 0x201CB6: the boot record OS_$INIT receives as its first argument
 * (d1 and d2 of the entry are its first two longwords) and 0x201CC2:
 * the diskless record, its second argument (the 7 copied longwords),
 * then COLD's own cells.  All zero in the file.
 */
cold_boot_params:
        .long   0, 0, 0                 /* 201cb6 */
cold_diskless_info:
        .long   0, 0, 0, 0, 0, 0, 0     /* 201cc2 */
cold_saved_sp:
        .long   0                       /* 201cde */
cold_mmap_phys:
        .long   0                       /* 201ce2  MMAP's physical address */
cold_smaps_phys:
        .long   0                       /* 201ce6  SMAPS's physical address */
cold_os_pmaps_phys:
        .long   0                       /* 201cea  OS_PMAPS's physical address */

/* 0x201CEE..0x201FFC: COLD's stack, zero in the file. */
        .space  0x30e
cold_stack_top:                         /* 201ffc  the initial SP; COLD + 0x7FC, */
                                        /*         the map's segment end */
        .space  4                       /*         the file's pad up to DUMP at 0x800 */
