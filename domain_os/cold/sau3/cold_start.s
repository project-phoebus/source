/*
 * cold/sau3/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU3)
 *
 * The SAU3's COLD, transcribed from the SAU3 image file (file 0..0x800,
 * loaded at 0x101400; sr10.2-install/.../sau3/domain_os) on the SAU2's
 * (cold/sau2/cold_start.s, whose analysis references and conventions this
 * file keeps: one section, A5 = COLD with the COLD_OFF_* displacements,
 * every RELOC cell a symbol reference, the Apollo assembler's <ea>=#imm
 * forms as `.short', the image's branch sizes).  The SAU3 map:
 *
 *   D22  101400  COLD               loaded at 101400, size = 7FC
 *   D    101400  COLD_START         size = 7FC
 *        101400  COLD
 *        101420  MOVE_TO_PPN
 *
 * A file of its own rather than `.if' arms in a shared one, as the
 * SAU5's: the SAU3's code is the SAU2's with three additions, and its
 * MMU map table has 19 entries against 17 (other I/O pages), so the
 * cells after the table move by 0x54.  Against the SAU2's:
 *   - the header's machine type is 3;
 *   - after the trap page is set up, COLD reads and clears the PBU
 *     controller (physical 0xA400, PBU_CTL's page; the SAU5 probes it
 *     with the bus-error vector pointed past the access, the SAU3 does
 *     not);
 *   - at the end of the memory sizing it tells the PBU controller 0x10,
 *     or 0x30 when the page at MMAP index 0xA80 is not present (the
 *     SAU5's test, without the SAU5's `with a PBU');
 *   - cold_map_pages clears physical 0x10000..0x10FFF, again always;
 *   - the I/O map entries are the SAU3's pages (arch/m68k/sau3/iodefs.s:
 *     PFT, MMU, SIO, TIMR, CALENDAR, PBU_CTL, LPR, RING2, IOMAP, PBU_IO,
 *     DMA): no display (DISP1, DISP1_MEM) and no disk page.
 * The 68020 fixup loop and its windows are the SAU2's unchanged.
 * Addresses in the comments are the SAU3 image's; the notes on CPU
 * models (DN300, DN320, DN330) are the SAU2 file's, kept with the code
 * they describe, which the SAU3's image has unchanged.
 */


        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  MOVE_TO_PPN
        .globl  cold_start_entry
        .globl  cold_map_pages
        .globl  cold_ident_map_table
        .globl  cold_map_table
        .globl  cold_boot_params
        .globl  cold_diskless_info

/* ---- kernel objects (map names) ------------------------------------------ */
        .extern MMU_$PID_PRIV           /* map 0xE22D00, mmu/m68k/mmu_data.s */
        .extern M68020                  /* map 0xE22D02, mmu/m68k/mmu_data.s */
        .extern P1_STACK_BASE           /* map 0xEB2000, the STACK window (layout) */
        .extern MMAP                    /* map 0xEB4800, the MMAP page table (layout) */

/* ---- the kernel's layout: symbols the linker script defines */
/*      OS_DATA      map 0xE79C00: VA of `.DATA' (ours: = OS_DATA_UNWIRED)     */
/*      OS_PROC      map 0xE00800: the first kernel page                      */
/*      RELOC        map 0xE8A434: the first byte after the last loaded byte  */
/*      OS_BEGIN     map 0xE00000: the bottom of the kernel's VA window       */
/*      OS_PAGE_END  map 0xEC4800: the end of the pages COLD maps             */
/*      KERNEL_HI_VA OS_PROC + KERNEL_LO_BYTES (0xE56400): the high piece,    */
/*                   defined below KERNEL_LO_BYTES                            */

/* ---- physical layout of the loaded file (not relocated) ------------------ */
        .equ    COLD_LOW,       0x00101400  /* the RFC load address: file byte 0, COLD */
        .equ    KERNEL_LOW,     0x00102000  /* file 0xC00: the first kernel page, PPN 0x408 */
        .equ    SPLIT_LOW,      0x00157C00  /* 0x55F << 10: file pages from here on are loaded at MOVE_TO_PPN */
        .equ    KERNEL_LO_BYTES, 0x00055C00 /* SPLIT_LOW - KERNEL_LOW: kernel bytes in the low piece */
        .set    KERNEL_HI_VA,   OS_PROC + KERNEL_LO_BYTES /* map 0xE56400: the first VA of the high piece */
        .equ    DUMP_PHYS,      0x00100C00  /* PPN 0x403: where COLD copies the DUMP page */
        .equ    TRAP_PAGE_PHYS, 0x00101000  /* PPN 0x404: the new trap page (VBR) */
        .equ    DUMP_LOW,       0x00101C00  /* file 0x800: the DUMP page as loaded */
        .equ    MEM_PROBE_LO,   0x00080000  /* the memory sizing loop: first page */
        .equ    MEM_PROBE_HI,   0x00400000  /*                         end      */

/* ---- the 68020 fixup windows (not relocated) ----- */
        .equ    VA_MASK_26,     0x03FFFFFF
        .equ    IO_WINDOW,      0x00FA0000  /* v >= this: I/O, += 0x3000000 */
        .equ    IO_WINDOW_020,  0x03FA0000
        .equ    PROT_WINDOW_020, 0x03AC0000 /* PROT 0xCC0000 -> 0x3AC0000 */
        .equ    OS_WINDOW_020,  0x03D00000  /* OS_BEGIN 0xE00000 -> 0x3D00000 */
        .equ    PTT_WINDOW_LO,  0x00700000  /* PTT 0x700000..0x800000 -= 0x300000 */
        .equ    PTT_WINDOW_END, 0x00800000
        .equ    PTT_WINDOW_MOVE, 0x00300000

/* ---- PROM and the MMU before it is on (physical; the PROM's            */
/*      definitions)                                                          */
        .equ    PROM_MACHINE_ID_LO, 0x00000103  /* low byte of PROM_$MACHINE_ID (0x100, ARCH_PROM_MACHINE_ID); bit 1 = 68020 (DN330) */
        .equ    PROM_ABORT,     0x00000414  /* PROM error/abort entry (CPU sanity check failed) */
        .equ    LINE_F_VEC,     0x0000002C  /* trap-page vector 11, line 1111 (the map names 0x28 UNIMP_VEC only) */
        .equ    BUS_ERROR_VEC_OFF, 0x8      /* map BUS_ERROR_VEC, as an offset from a VBR */
        .equ    PFT_PHYS,       0x00004000  /* the page frame table, physical (PPN 0x10; mapped at PFT 0xFFB800) */
        .equ    MMU_CSR_PHYS,   0x00008000  /* the MMU control register, physical (PPN 0x20; mapped at MMU 0xFFB400) */
        .equ    PFT_ENTRY0,     0xFE008000  /* PFT[0]: end of chain, elaccess, ASID 0x7F */
        .equ    PBU_CTL_PHYS,   0x0000A400  /* PPN 0x29, mapped at PBU_CTL 0xFF7C00 */
        .equ    PBU_CLEAR_PHYS, 0x00010000  /* the 4 KB cold_map_pages clears */

/* ---- MMU map table entry flags (bits 31..29 of the VA field) ------------ */
        .equ    MAP_WIRED,      0x80000000  /* kernel page: MMAP wire_count 0x80 */
        .equ    MAP_COLD,       0x40000000  /* COLD's pages: MMAP wire_count 0x40 */
        .equ    MAP_PRIVATE,    0x20000000  /* clear: PFT bit 12 (global) is set */

/* ---- A5 = COLD: the cells COLD writes (asserted at the end) ------------- */
        .equ    COLD_OFF_KERNEL_LO_COUNT, 0x53A /* 0x10193A cold_map_kernel_lo_count */
        .equ    COLD_OFF_KERNEL_HI,       0x544 /* 0x101944 cold_map_kernel_hi_count_ppn */
        .equ    COLD_OFF_BOOT_PARAMS,     0x550 /* 0x101950 cold_boot_params */
        .equ    COLD_OFF_DISKLESS,        0x55C /* 0x10195C cold_diskless_info */
        .equ    COLD_OFF_SAVED_SP,        0x578 /* 0x101978 cold_saved_sp */
        .equ    COLD_OFF_MMAP_PHYS,       0x57C /* 0x10197C cold_mmap_phys */
        .equ    COLD_OFF_VA_SHIFT,        0x588 /* 0x101988 cold_va_shift */
        .equ    COLD_OFF_VA_MASK,         0x58A /* 0x10198A cold_va_mask */
        .equ    COLD_OFF_PTT_ENTRIES,     0x58E /* 0x10198E cold_ptt_entries */

/*
 * The RFC header, 0x101400 (12 bytes): load address, start
 * address, machine type WORD (SAU 3), zero word.  The loader reads them as
 * physical load addresses; the binder did not list them in RELOC, so they
 * are literals (asserted against the labels at the end of the file).
 */
COLD:
        .long   COLD_LOW                /* 101400  load: file byte 0 lands here */
        .long   COLD_LOW + 0x24         /* 101404  start: cold_start_entry */
        .short  0x0003                  /* 101408  machine type: SAU 3 */
        .short  0x0000                  /* 10140a  0 */

/*
 * The info block, 0x10140C (24 bytes).  COLD reads only
 * MOVE_TO_PPN; sysboot reads the magic, the split PPN and MOVE_TO_PPN.
 */
rfc_info_block:
        .long   0x00000C00              /* 10140c  file offset of the first kernel page (header + COLD + DUMP) */
        .long   OS_DATA                 /* 101410  OS_DATA; a RELOC cell */
        .long   OS_PROC                 /* 101414  the first kernel page; a RELOC cell */
        .long   0xFEED2B03              /* 101418  magic: word FEED, byte 2B, format version 0 */
        .long   0x0000055F              /* 10141c  split PPN (SPLIT_LOW >> 10) */
MOVE_TO_PPN:
        .long   0x00000600              /* 101420  where the pages past the split go (0x180000) */

/*
 * COLD_START, 0x101424.  Entered by sysboot's exec helper
 * with a return address and the boot words on the stack:
 *   (SP)    return address (discarded)
 *   4(SP)   d1: boot_params longword 0 (device.w, ctlr.w)
 *   8(SP)   d2: boot_params longword 1 (unit.w, flags.w; flags bit 15 =
 *           enter the debugger before OS_$INIT)
 *   12(SP)  a1: the 7-longword diskless block
 * Never returns: it ends in OS_$INIT.
 */
cold_start_entry:
        movea.l #COLD,%a5               /* 101424  2a7c: A5 = COLD (a RELOC cell) */
        movea.l #0,%a0                  /* 10142a  207c */
        movec   %a0,%vbr                /* 101430  VBR = 0: the PROM's vectors */
        movem.l (%sp)+,%d0-%d2          /* 101434  d0 = return address (discarded) */
        movea.l (%sp)+,%a1              /* 101438  the diskless block */
        movem.l %d1-%d2,(COLD_OFF_BOOT_PARAMS,%a5) /* 10143a  cold_boot_params */
        lea     (cold_stack_top:w,%pc),%sp /* 101440  SP = 0x101BFC */
        cmpi.w  #2,(COLD_OFF_BOOT_PARAMS,%a5) /* 101444  boot device 2 or 6: */
        beq.s   cold_copy_diskless      /* 10144a      a diskless boot */
        cmpi.w  #6,(COLD_OFF_BOOT_PARAMS,%a5) /* 10144c */
        bne.s   cold_check_cpu          /* 101452 */
cold_copy_diskless:
        movem.l (%a1)+,%d0-%d6          /* 101454  7 longwords */
        movem.l %d0-%d6,(COLD_OFF_DISKLESS,%a5) /* 101458  cold_diskless_info */
cold_check_cpu:
        btst    #1,(PROM_MACHINE_ID_LO).w /* 10145e  68020 (DN330)? */
        beq.w   cold_68010_mmu_off      /* 101464  no: DN300/DN320 */
        moveq   #31,%d1                 /* 101468  CPU sanity check: a byte >> 31 */
        lsr.b   %d1,%d0                 /* 10146a      is 0 with C = X = 0, so CCR */
        move.w  %ccr,%d0                /* 10146c      reads Z alone (4); a 68000 */
        .short  0xb07c, 0x0004          /* 10146e  cmp.w #4,%d0 (<ea>=#imm form; gas: cmpi) */
        beq.s   cold_enable_cache       /* 101472      traps on move ccr instead */
        jmp     (PROM_ABORT).w          /* 101474 */
cold_enable_cache:
        movea.l #9,%a0                  /* 101478  CACR = 9: enable and clear */
        movec   %a0,%cacr               /* 10147e      the instruction cache */
        move.w  #6,(COLD_OFF_VA_SHIFT,%a5)      /* 101482  DN330 26-bit VA: shift 6 */
        move.w  #0x3f,(COLD_OFF_VA_MASK,%a5)    /* 101488      mask 0x003FFFFF */
        move.w  #0x1000,(COLD_OFF_PTT_ENTRIES,%a5) /* 10148e   0x1000 PTT entries */

/*
 * The RELOC fixups, 0x101494..0x101542 (68020 only): a0 = the low address
 * of RELOC, moved past the split; count.w, then count low addresses of
 * 32-bit VA cells, each moved into the DN330's 26-bit windows.
 */
cold_reloc_fixup:
        movea.l #RELOC,%a0              /* 101494  RELOC; a RELOC cell */
        suba.l  #OS_PROC,%a0            /* 10149a  first kernel page; a RELOC cell */
        adda.l  #KERNEL_LOW,%a0         /* 1014a0  = 0x18BC34, RELOC's low address */
        cmpa.l  #SPLIT_LOW,%a0          /* 1014a6  the table must lie past the split */
        bgt.s   cold_reloc_phys         /* 1014ac */
        trap    #15                     /* 1014ae */
cold_reloc_phys:
        suba.l  #SPLIT_LOW,%a0          /* 1014b0  low -> physical: */
        move.l  (MOVE_TO_PPN:w,%pc),%d2 /* 1014b6      - SPLIT_LOW + MOVE_TO_PPN << 10 */
        lsl.l   #5,%d2                  /* 1014ba */
        lsl.l   #5,%d2                  /* 1014bc */
        adda.l  %d2,%a0                 /* 1014be */
        move.w  (%a0)+,%d0              /* 1014c0  count (dbf) */
        subq.w  #1,%d0                  /* 1014c2 */
        move.l  #VA_MASK_26,%d1         /* 1014c4 */
        move.l  #IO_WINDOW,%d5          /* 1014ca  I/O: */
        movea.l #IO_WINDOW_020,%a4      /* 1014d0      a4 = 0x3000000 */
        suba.l  %d5,%a4                 /* 1014d6 */
        move.l  #PROT,%d3               /* 1014d8  PROT window (a RELOC cell): */
        move.l  #PROT_WINDOW_020,%d6    /* 1014de      d6 = 0x2E00000 */
        sub.l   %d3,%d6                 /* 1014e4 */
        move.l  #OS_BEGIN,%d4           /* 1014e6  OS_BEGIN; a RELOC cell */
        move.l  #OS_WINDOW_020,%d7      /* 1014ec  kernel window: */
        sub.l   %d4,%d7                 /* 1014f2      a3 = 0x2F00000 */
        movea.l %d7,%a3                 /* 1014f4 */
cold_reloc_loop:
        movea.l (%a0)+,%a1              /* 1014f6  the low address of a cell */
        cmpa.l  #SPLIT_LOW,%a1          /* 1014f8 */
        blt.s   cold_reloc_cell         /* 1014fe */
        suba.l  #SPLIT_LOW,%a1          /* 101500  past the split: move it */
        adda.l  %d2,%a1                 /* 101506 */
cold_reloc_cell:
        movea.l (%a1),%a2               /* 101508  v = cell & 0x03FFFFFF */
        move.l  %a2,%d7                 /* 10150a */
        and.l   %d1,%d7                 /* 10150c */
        cmp.l   %d4,%d7                 /* 10150e */
        blt.s   cold_reloc_below_os     /* 101510 */
        cmp.l   %d5,%d7                 /* 101512 */
        blt.s   cold_reloc_os           /* 101514  0xE00000 <= v < 0xFA0000 */
        adda.l  %a4,%a2                 /* 101516  v >= 0xFA0000: I/O */
        bra.s   cold_reloc_store        /* 101518 */
cold_reloc_below_os:
        cmp.l   %d3,%d7                 /* 10151a */
        blt.s   cold_reloc_ptt          /* 10151c */
        adda.l  %d6,%a2                 /* 10151e  0xCC0000 <= v < 0xE00000 */
        bra.s   cold_reloc_store        /* 101520 */
cold_reloc_ptt:
        .short  0xbebc                  /* 101522  cmp.l #PTT,%d7 (<ea>=#imm form; */
        .long   PTT_WINDOW_LO           /*         (not a RELOC cell, so not PTT) */
        blt.s   cold_reloc_next         /* 101528 */
        .short  0xbebc                  /* 10152a  cmp.l #0x800000,%d7 */
        .long   PTT_WINDOW_END
        bge.s   cold_reloc_next         /* 101530 */
        suba.l  #PTT_WINDOW_MOVE,%a2    /* 101532  0x700000 <= v < 0x800000 */
        bra.s   cold_reloc_store        /* 101538 */
cold_reloc_os:
        adda.l  %a3,%a2                 /* 10153a */
cold_reloc_store:
        move.l  %a2,(%a1)               /* 10153c  the add keeps flag bits 31..26 */
cold_reloc_next:
        dbf     %d0,cold_reloc_loop     /* 10153e */
        bra.s   cold_copy_dump          /* 101542 */

/* 0x101544 (68010: DN300/DN320): clear the MMU control register. */
cold_68010_mmu_off:
        movea.l #MMU,%a0                /* 101544  a RELOC cell */
        move.w  #0,(%a0)                /* 10154a */

/* 0x10154E: copy the DUMP page (256 longwords) to physical 0x100C00. */
cold_copy_dump:
        movea.l #DUMP_PHYS,%a0          /* 10154e */
        move.l  #0xff,%d0               /* 101554 */
        movea.l #DUMP_LOW,%a1           /* 10155a */
cold_copy_dump_loop:
        move.l  (%a1)+,(%a0)+           /* 101560 */
        dbf     %d0,cold_copy_dump_loop /* 101562 */

/*
 * 0x101566: the trap page at physical 0x101000: vectors 0 and 1 stay as
 * they are, 2..255 are copied from the PROM's (0x8..); VBR = 0x101000.
 */
cold_build_trap_page:
        lea     TRAP_PAGE_PHYS,%a1      /* 101566  43f9 (abs.l) */
        move.l  (%a1),(%a1)+            /* 10156c */
        move.l  (%a1),(%a1)+            /* 10156e */
        lea     (BUS_ERROR_VEC_OFF).w,%a0 /* 101570 */
        move.w  #0xfd,%d0               /* 101574  254 vectors */
cold_build_trap_page_loop:
        move.l  (%a0)+,(%a1)+           /* 101578 */
        dbf     %d0,cold_build_trap_page_loop /* 10157a */
        lea     TRAP_PAGE_PHYS,%a2      /* 10157e */
        movec   %a2,%vbr                /* 101584 */
        move.l  (BUS_ERROR_VEC_OFF,%a2),-(%sp) /* 101588  save the bus-error vector */
        move.l  %sp,(COLD_OFF_SAVED_SP,%a5)    /* 10158c  cold_saved_sp */

/* 0x101590: read and clear the PBU controller. */
cold_reset_pbu:
        tst.w   (PBU_CTL_PHYS).l        /* 101590 */
        move.w  #0,(PBU_CTL_PHYS).l     /* 101596 */

/*
 * 0x10159E: the kernel page count n = (roundup1K(OS_PAGE_END) - the first
 * kernel page) >> 10.  If it fits the low piece, store it as the count of
 * the "kernel low" map entry; otherwise store (n - 0x157) << 16 |
 * MOVE_TO_PPN as the count and PPN of the "kernel high" entry.
 */
cold_count_kernel_pages:
        move.l  #OS_PAGE_END,%d4        /* 10159e  OS_PAGE_END; a RELOC cell */
        .short  0xd8bc                  /* 1015a4  add.l #0x3ff,%d4 (<ea>=#imm form) */
        .long   0x000003ff
        .short  0xc87c, 0xfc00          /* 1015aa  and.w #0xfc00,%d4 (<ea>=#imm form) */
        .short  0x98bc                  /* 1015ae  sub.l #first kernel page,%d4 (<ea>=#imm form) */
        .long   OS_PROC                 /*         first kernel page; a RELOC cell */
        .short  0xb8bc                  /* 1015b4  cmp.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES
        bhi.w   cold_count_kernel_hi    /* 1015ba */
        lsr.l   #5,%d4                  /* 1015be */
        lsr.l   #5,%d4                  /* 1015c0 */
        move.w  %d4,(COLD_OFF_KERNEL_LO_COUNT,%a5) /* 1015c2 */
        bra.w   cold_clear_mmap         /* 1015c6 */
cold_count_kernel_hi:
        .short  0x98bc                  /* 1015ca  sub.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES
        lsr.l   #5,%d4                  /* 1015d0 */
        lsr.l   #5,%d4                  /* 1015d2 */
        swap    %d4                     /* 1015d4 */
        move.w  (MOVE_TO_PPN+2:w,%pc),%d4 /* 1015d6  the PPN word of MOVE_TO_PPN */
        move.l  %d4,(COLD_OFF_KERNEL_HI,%a5) /* 1015da */

/*
 * 0x1015DE: a4 = the physical address of MMAP (VA - first page - 0x55C00
 * + MOVE_TO_PPN << 10), saved in cold_mmap_phys; the bus-error vector
 * goes to cold_probe_buserr; the 0xE000 bytes of MMAP are cleared.
 */
cold_clear_mmap:
        move.l  (MOVE_TO_PPN:w,%pc),%d4 /* 1015de */
        lsl.l   #5,%d4                  /* 1015e2 */
        lsl.l   #5,%d4                  /* 1015e4 */
        .short  0x98bc                  /* 1015e6  sub.l #first kernel page,%d4 (<ea>=#imm form) */
        .long   OS_PROC                 /*         first kernel page; a RELOC cell */
        .short  0x98bc                  /* 1015ec  sub.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES
        .short  0xd8bc                  /* 1015f2  add.l #MMAP,%d4 (<ea>=#imm form) */
        .long   MMAP                    /*         a RELOC cell */
        movea.l %d4,%a4                 /* 1015f8 */
        move.l  %a4,(COLD_OFF_MMAP_PHYS,%a5) /* 1015fa  cold_mmap_phys */
        lea     (cold_probe_buserr:w,%pc),%a0 /* 1015fe */
        move.l  %a0,(BUS_ERROR_VEC_OFF,%a2) /* 101602 */
        move.w  #0xdff,%d0              /* 101606  3584 entries of 16 bytes */
cold_clear_mmap_loop:
        clr.l   (%a4)+                  /* 10160a */
        clr.l   (%a4)+                  /* 10160c */
        clr.l   (%a4)+                  /* 10160e */
        clr.l   (%a4)+                  /* 101610 */
        dbf     %d0,cold_clear_mmap_loop /* 101612 */

/*
 * 0x101616: memory sizing.  Every 1 KB page from 0x80000 to 0x400000 is
 * read and rewritten a longword at a time, then its MMAP entry (index
 * (PPN - 0x200) * 16) gets 0x40000000.  The trap page at 0x101000 is
 * skipped.  A bus error lands in cold_probe_buserr, which skips 256 KB.
 */
cold_size_memory:
        movea.l #MEM_PROBE_LO,%a0       /* 101616 */
        movea.l (cold_mmap_phys:w,%pc),%a4 /* 10161c */
        adda.l  #0,%a4                  /* 101620  (an add of 0, as in the image) */
cold_size_page:
        lea     (0x400,%a0),%a1         /* 101626  the end of this page */
        cmpa.l  #MEM_PROBE_HI,%a0       /* 10162a */
        beq.s   cold_size_done          /* 101630 */
        cmpa.l  #TRAP_PAGE_PHYS,%a0     /* 101632 */
        beq.s   cold_size_skip_page     /* 101638 */
cold_size_rewrite:
        move.l  (%a0),%d4               /* 10163a */
        move.l  %d4,(%a0)+              /* 10163c */
        cmpa.l  %a0,%a1                 /* 10163e */
        bne.s   cold_size_rewrite       /* 101640 */
        move.l  #0x40000000,(%a4)       /* 101642  present: wire_count 0x40 */
        adda.l  #0x10,%a4               /* 101648 */
        bra.s   cold_size_page          /* 10164e */
cold_probe_buserr:
        movea.l (cold_saved_sp:w,%pc),%sp /* 101650 */
        bsr.s   cold_probe_skip_256k    /* 101654 */
        bra.s   cold_size_page          /* 101656 */
cold_size_skip_page:
        adda.l  #0x10,%a4               /* 101658 */
        movea.l %a1,%a0                 /* 10165e */
        bra.s   cold_size_page          /* 101660 */
cold_probe_skip_256k:
        adda.l  #0x1000,%a4             /* 101662  256 entries of MMAP */
        adda.l  #0x40000,%a0            /* 101668 */
        rts                             /* 10166e */
cold_size_done:
        move.w  #0x10,%d0               /* 101670  tell the PBU controller: 0x10, */
        movea.l (cold_mmap_phys:w,%pc),%a0 /* 101674  or 0x30 when the page at MMAP */
        lea     (0x3800,%a0),%a0        /* 101678  index 0xA80 is not present */
        lea     (0x7000,%a0),%a0        /* 10167c */
        cmpi.l  #0x40000000,(%a0)       /* 101680 */
        beq.s   cold_size_pbu_ctl       /* 101686 */
        .short  0xd07c, 0x0020          /* 101688  add.w #0x20,%d0 (<ea>=#imm form; gas: addi) */
cold_size_pbu_ctl:
        move.w  %d0,(PBU_CTL_PHYS).l    /* 10168c */
        move.l  (%sp)+,(BUS_ERROR_VEC_OFF,%a2) /* 101692  restore vector 2 */
        movea.l #0,%a2                  /* 101696 */
        movec   %a2,%vbr                /* 10169c  VBR = 0 */
        lea     (cold_map_table:w,%pc),%a0 /* 1016a0 */
        bsr.w   cold_map_pages          /* 1016a4  load the MMU and turn it on */

/* 0x1016A8: kernel VAs are live from here on. */
        move.w  #1,MMU_$PID_PRIV        /* 1016a8  a RELOC cell */
        btst    #1,(PROM_MACHINE_ID_LO).w /* 1016b0 */
        beq.s   cold_fpu_linef_trap     /* 1016b6 */
        st      M68020                  /* 1016b8  a RELOC cell */
        move.l  %sp,(COLD_OFF_SAVED_SP,%a5) /* 1016be */
        lea     (cold_fpu_linef_trap:w,%pc),%a1 /* 1016c2 */
        move.l  %a1,TRAP_PAGE + LINE_F_VEC /* 1016c6  a RELOC cell */
        move.b  #0,MMU + 2              /* 1016cc  a RELOC cell (0xFFB402) */
        fmove.l #0,%fpcr                /* 1016d4  no FPU: line-F trap */
        st      M68881_EXISTS           /* 1016dc  a RELOC cell */
cold_fpu_linef_trap:
        movea.l (cold_saved_sp:w,%pc),%sp /* 1016e2 */
        movea.l #MMU,%a0                /* 1016e6  a RELOC cell */
        clr.w   (2,%a0)                 /* 1016ec */
        move.w  (2,%a0),MMU_$INIT_BSR   /* 1016f0  a RELOC cell: the immediate of */
                                        /*         MMU_$POWER_OFF's eori.w */
        tst.b   M68020                  /* 1016f8  a RELOC cell */
        bne.s   cold_mmu_regs_020       /* 1016fe */
        movea.l #MMU,%a0                /* 101700  68010: a RELOC cell */
        clr.w   (6,%a0)                 /* 101706 */
        move.w  #1,(4,%a0)              /* 10170a */
        bra.s   cold_enter_kernel       /* 101710 */
cold_mmu_regs_020:
        movea.l #MMU,%a0                /* 101712  68020: a RELOC cell */
        clr.w   (2,%a0)                 /* 101718 */
        move.w  #0x40,(6,%a0)           /* 10171c */
        move.w  #0x4000,(0xa,%a0)       /* 101722  the parity register */

/*
 * 0x101728: SP = P1_STACK_BASE; OS_$INIT(&cold_boot_params,
 * &cold_diskless_info), after a trap to the debugger if boot flag bit 15
 * is set.  OS_$INIT never returns.
 */
cold_enter_kernel:
        movea.l #P1_STACK_BASE,%sp      /* 101728  a RELOC cell */
        pea     (cold_diskless_info:w,%pc) /* 10172e */
        pea     (cold_boot_params:w,%pc) /* 101732 */
        movea.l #OS_$INIT,%a0           /* 101736  a RELOC cell */
        btst    #15,(cold_boot_params+6:w,%pc) /* 10173c  flags bit 15 */
        beq.s   cold_call_os_init       /* 101742 */
        trap    #15                     /* 101744 */
cold_call_os_init:
        jsr     (%a0)                   /* 101746 */

/*
 * cold_map_pages, 0x101748: a0 = a map table.  Clears the
 * PTT and the PFT, then for every page of every entry builds its PFT entry
 * (prot << 16 | (va >> shift) & 0xF0000, bit 12 = global unless flag bit
 * 29), hashes it into the PTT word at PTT + (va & mask), records
 * MMU_$PTTX[ppn] = (va & mask) >> 6 and, for ppn >= 0x200, the MMAP
 * entry's first word = flag bits 31..30 >> 16.  Ends by turning the MMU
 * on (CSR = 1) and setting byte 0 of the new trap page.  Not called with
 * the compiled-code convention: a0 in, every register clobbered.
 */
cold_map_pages:
        move.w  #2,MMU_CSR_PHYS         /* 101748  33fc abs.l: CSR = 2 (PTT access) */
        movea.l (cold_mmap_phys:w,%pc),%a4 /* 101750 */
        movea.l #PTT,%a2                /* 101754  a RELOC cell */
        move.w  (cold_ptt_entries:w,%pc),%d1 /* 10175a */
        subq.w  #1,%d1                  /* 10175e */
cold_clear_ptt:
        clr.w   (%a2)                   /* 101760  one word per 1 KB of the window */
        lea     (0x400,%a2),%a2         /* 101762 */
        dbf     %d1,cold_clear_ptt      /* 101766 */
        lea     (PFT_PHYS).w,%a3        /* 10176a */
        move.l  #PFT_ENTRY0,(%a3)+      /* 10176e  PFT[0] */
        move.w  #0xffe,%d1              /* 101774  PFT[1..4095] = 0 */
cold_clear_pft:
        clr.l   (%a3)+                  /* 101778 */
        dbf     %d1,cold_clear_pft      /* 10177a */
        lea     (PBU_CLEAR_PHYS).l,%a2  /* 10177e  clear 4 KB at 0x10000 */
        move.w  #0x3ff,%d4              /* 101784 */
cold_clear_pbu_page:
        clr.l   (%a2)+                  /* 101788 */
        dbf     %d4,cold_clear_pbu_page /* 10178a */
        lea     (PFT_PHYS).w,%a3        /* 10178e */
        move.l  (MOVE_TO_PPN:w,%pc),%d0 /* 101792  a1 = the physical address */
        lsl.l   #5,%d0                  /* 101796      of MMU_$PTTX */
        lsl.l   #5,%d0                  /* 101798 */
        .short  0x90bc                  /* 10179a  sub.l #first kernel page,%d0 (<ea>=#imm form) */
        .long   OS_PROC                 /*         first kernel page; a RELOC cell */
        .short  0x90bc                  /* 1017a0  sub.l #0x55c00,%d0 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES
        movea.l %d0,%a1                 /* 1017a6 */
        adda.l  #MMU_$PTTX,%a1          /* 1017a8  a RELOC cell */
        move.w  (cold_va_shift:w,%pc),%d7 /* 1017ae */
cold_map_entry_loop:
        move.w  (%a0)+,%d0              /* 1017b2  count (0 ends the table) */
        beq.w   cold_mmu_on             /* 1017b4 */
        subq.w  #1,%d0                  /* 1017b8 */
        move.w  (%a0)+,%d1              /* 1017ba  ppn */
        move.l  (%a0)+,%d2              /* 1017bc  flags | va */
        move.w  (%a0)+,%d6              /* 1017be  prot */
        swap    %d6                     /* 1017c0 */
        clr.w   %d6                     /* 1017c2 */
cold_map_page_loop:
        move.l  %d2,%d3                 /* 1017c4  PFT entry */
        lsr.l   %d7,%d3                 /* 1017c6 */
        .short  0xc6bc                  /* 1017c8  and.l #0xf0000,%d3 (<ea>=#imm form) */
        .long   0x000f0000
        or.l    %d6,%d3                 /* 1017ce */
        btst    #29,%d2                 /* 1017d0 */
        bne.s   cold_map_hash           /* 1017d4 */
        bset    #12,%d3                 /* 1017d6  global */
cold_map_hash:
        move.l  %d2,%d4                 /* 1017da */
        and.l   (cold_va_mask:w,%pc),%d4 /* 1017dc */
        .short  0xd8bc                  /* 1017e0  add.l #PTT,%d4 (<ea>=#imm form) */
        .long   PTT                     /*         a RELOC cell */
        movea.l %d4,%a2                 /* 1017e6 */
        move.w  (%a2),%d4               /* 1017e8 */
        .short  0xc87c, 0x0fff          /* 1017ea  and.w #0xfff,%d4 (<ea>=#imm form) */
        bne.s   cold_map_chain          /* 1017ee */
        bset    #15,%d3                 /* 1017f0  an empty slot: end of chain, */
        add.w   %d1,%d3                 /* 1017f4      linked to itself */
        move.w  %d1,(%a2)               /* 1017f6 */
        bra.s   cold_map_store          /* 1017f8 */
cold_map_chain:
        lsl.w   #2,%d4                  /* 1017fa  insert after the head (eor swap */
        move.l  (0,%a3,%d4.w),%d5       /* 1017fc      of the 12-bit links) */
        .short  0xcabc                  /* 101800  and.l #0xfff,%d5 (<ea>=#imm form) */
        .long   0x00000fff
        eor.w   %d5,%d3                 /* 101806 */
        eor.w   %d1,%d5                 /* 101808 */
        eor.l   %d5,(0,%a3,%d4.w)       /* 10180a */
cold_map_store:
        move.w  %d1,%d4                 /* 10180e */
        lsl.w   #2,%d4                  /* 101810 */
        move.l  %d3,(0,%a3,%d4.w)       /* 101812  PFT[ppn] */
        lsr.w   #1,%d4                  /* 101816 */
        move.l  %d2,%d3                 /* 101818 */
        and.l   (cold_va_mask:w,%pc),%d3 /* 10181a */
        lsr.l   #6,%d3                  /* 10181e */
        move.w  %d3,(0,%a1,%d4.w)       /* 101820  MMU_$PTTX[ppn] */
        move.l  %d2,%d5                 /* 101824 */
        .short  0xcabc                  /* 101826  and.l #0xc0000000,%d5 (<ea>=#imm form) */
        .long   0xc0000000
        swap    %d5                     /* 10182c */
        .short  0x987c, 0x0400          /* 10182e  sub.w #0x400,%d4 (<ea>=#imm form): */
        bcs.s   cold_map_next_page      /* 101832      ppn < 0x200 has no MMAP entry */
        mulu.w  #8,%d4                  /* 101834 */
        move.w  %d5,(0,%a4,%d4.l)       /* 101838  MMAP[ppn - 0x200].w0 */
cold_map_next_page:
        addq.w  #1,%d1                  /* 10183c */
        .short  0xd4bc                  /* 10183e  add.l #0x400,%d2 (<ea>=#imm form) */
        .long   0x00000400
        dbf     %d0,cold_map_page_loop  /* 101844 */
        bra.w   cold_map_entry_loop     /* 101848 */
cold_mmu_on:
        move.w  #1,MMU_CSR_PHYS         /* 10184c  33fc abs.l: the MMU on */
        move.b  #0xff,(0).w             /* 101854  byte 0 of the trap page */
        rts                             /* 10185a */

/*
 * 0x10185C: a second map table in the same format, referenced by nothing
 * (not COLD, not RELOC, no absolute longword in the image): an identity
 * map of 0..0x400000.  Purpose unknown.
 * Entry: count.w, ppn.w, flags | va.l, prot.w.
 */
cold_ident_map_table:
        .short  0x0001, 0x0404          /* 10185c  the trap page */
        .long   0x00000000
        .short  0x0170
        .short  0x004f, 0x0001          /* 101866 */
        .long   0x00000400
        .short  0x0170
        .short  0x0008, 0x0050          /* 101870 */
        .long   0x00004000
        .short  0x0130
        .short  0x03ac, 0x0058          /* 10187a */
        .long   0x00016000
        .short  0x0170
        .short  0x0bfb, 0x0405          /* 101884 */
        .long   COLD_LOW
        .short  0x0170
        .short  0x0000                  /* 10188e  end */

/*
 * 0x101890: the MMU map table cold_map_pages walks.
 * prot 0x130 = X+R, 0x160 = R+W (I/O), 0x170 = X+R+W.  The VA cells of the
 * I/O, CRASH_RECORD, DUMP and kernel entries are RELOC cells.
 */
cold_map_table:
        .short  0x000f, 0x0001          /* 101890  low memory identity */
        .long   0x00000400
        .short  0x0130
        .short  0x0008, 0x0050          /* 10189a */
        .long   0x00004000
        .short  0x0130
        .short  0x0010, 0x0010          /* 1018a4  PFT */
        .long   PFT
        .short  0x0160
        .short  0x0001, 0x0020          /* 1018ae  MMU */
        .long   MMU
        .short  0x0160
        .short  0x0001, 0x0021          /* 1018b8  SIO */
        .long   SIO
        .short  0x0160
        .short  0x0001, 0x0022          /* 1018c2  TIMR */
        .long   TIMR
        .short  0x0160
        .short  0x0001, 0x0028          /* 1018cc  CALENDAR */
        .long   CALENDAR
        .short  0x0160
        .short  0x0001, 0x0029          /* 1018d6  PBU_CTL */
        .long   PBU_CTL
        .short  0x0160
        .short  0x0001, 0x002a          /* 1018e0  LPR */
        .long   LPR
        .short  0x0160
        .short  0x0001, 0x0026          /* 1018ea  RING2 */
        .long   RING2
        .short  0x0160
        .short  0x0004, 0x0040          /* 1018f4  IOMAP */
        .long   IOMAP
        .short  0x0160
        .short  0x0040, 0x01c0          /* 1018fe  PBU_IO / PBU */
        .long   PBU_IO
        .short  0x0160
        .short  0x0001, 0x0024          /* 101908  DMA */
        .long   DMA
        .short  0x0160
        .short  0x0001, 0x0400          /* 101912  CRASH_RECORD */
        .long   MAP_WIRED + CRASH_$RECORD
        .short  0x0170
        .short  0x0001, 0x0403          /* 10191c  DUMP */
        .long   MAP_WIRED + DUMP
        .short  0x0170
        .short  0x0001, 0x0404          /* 101926  TRAP_PAGE (VA 0; not a RELOC cell) */
        .long   MAP_WIRED + 0x00000000
        .short  0x0170
        .short  0x0002, 0x0405          /* 101930  COLD itself (not a RELOC cell) */
        .long   MAP_COLD + MAP_PRIVATE + COLD_LOW
        .short  0x0170
cold_map_kernel_lo_count:
        .short  0x0157, 0x0408          /* 10193a  kernel, low piece; the count is */
                                        /*         rewritten if the kernel fits */
        .long   MAP_WIRED + OS_PROC     /*         a RELOC cell */
        .short  0x0170
cold_map_kernel_hi_count_ppn:
        .short  0x0000, 0x0000          /* 101944  kernel, high piece: count and */
                                        /*         PPN filled by COLD */
        .long   MAP_WIRED + KERNEL_HI_VA /*        a RELOC cell */
        .short  0x0170
        .short  0x0000                  /* 10194e  end */

/*
 * 0x101950: the boot record OS_$INIT receives as its first argument (9
 * longwords, 0x101950..0x101973; d1 and d2 of the entry are its first
 * two), and 0x10195C: the diskless record, its second argument (12
 * longwords, 0x10195C..0x10198B).  They overlap, and the diskless
 * record's last five longwords are COLD's own cells.  All zero in the
 * file except the MMU geometry defaults.
 */
cold_boot_params:
        .long   0, 0, 0                 /* 101950 */
cold_diskless_info:
        .long   0, 0, 0, 0, 0, 0, 0     /* 10195c  the 7 copied longwords */
cold_saved_sp:
        .long   0                       /* 101978 */
cold_mmap_phys:
        .long   0                       /* 10197c  MMAP's physical address */
        .long   0, 0                    /* 101980 */
cold_va_shift:
        .short  0x0004                  /* 101988  VA shift (6 on a 68020) */
cold_va_mask:
        .long   0x000fffff              /* 10198a  VA mask (0x3fffff on a 68020) */
cold_ptt_entries:
        .short  0x0400                  /* 10198e  PTT entries (0x1000 on a 68020) */

/* 0x101990..0x101BFC: COLD's stack, zero in the file. */
        .space  0x26c
cold_stack_top:                         /* 101bfc  the initial SP; COLD + 0x7FC, */
        .space  4                       /*         the map's segment end; then the */
                                        /*         file's pad up to DUMP at 0x800 */

/*
 * The layout this file assumes.  The header's start address and COLD's
 * A5 displacements (COLD_OFF_*) are constants the labels must match;
 * gas can check only the labels ahead of the first relaxable operand
 * here, so the rest is proved by the byte gate (tools/asm_compare.py
 * compares the whole 0x800 bytes with the image, every displacement and
 * every (d16,PC) operand included).
 */
        .ifne   cold_start_entry - COLD - 0x24
        .error  "cold_start_entry is not COLD + 0x24 (the header's start address)"
        .endif
        .ifne   MOVE_TO_PPN - COLD - 0x20
        .error  "MOVE_TO_PPN is not COLD + 0x20"
        .endif

        .size   COLD, . - COLD
