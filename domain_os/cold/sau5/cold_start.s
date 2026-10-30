/*
 * cold/sau5/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU5)
 *
 * The SAU5's COLD, transcribed from the SAU5 image file (file 0..0x800,
 * loaded at 0x101400; sr10.2-install/.../sau5/domain_os) on the SAU2's
 * (cold/sau2/cold_start.s, whose analysis references and conventions this
 * file keeps: one section, A5 = COLD with the COLD_OFF_* displacements,
 * every RELOC cell a symbol reference, the Apollo assembler's <ea>=#imm
 * forms as `.short', the image's branch sizes).  The SAU5 map:
 *
 *   D22  101400  COLD               loaded at 101400, size = 7FC
 *   D    101400  COLD_START         size = 7FC
 *        101400  COLD
 *        101420  MOVE_TO_PPN
 *
 * A file of its own rather than `.if' arms in a shared one: 975 of the
 * 2048 bytes differ from the SAU2's; of the SAU2 code's 359 instructions
 * 279 are the same text here and 77 differ in an operand, and the SAU5
 * adds 61 instructions in 12 places; the MMU map table has 23 entries
 * against 16 (14 I/O pages against 9, different ones), and the cells
 * after it move by 0xDC.  Against the SAU2's:
 *   - the header's machine type is 5;
 *   - the 68020 fixup loop's I/O window starts at 0xF90000 (IODEFS on
 *     the SAU5);
 *   - boot flag bit 14 swaps the VAs of the DISP1_MEM and DISP2_MEM map
 *     entries (the second display as the first);
 *   - COLD probes the PBU controller (physical 0xA400, PBU_CTL's page)
 *     with the bus-error vector pointed past the probe, and records the
 *     answer in cold_pbu_present;
 *   - the memory sizing keeps the last present page's end in D7 and
 *     writes the memory size to the VME controller (physical 0xBC00 +
 *     0x30, VME_CTL's page), and with a PBU tells the PBU controller
 *     (0x10, or 0x30 when the page at MMAP index 0xA80 is present);
 *   - cold_map_pages clears physical 0x10000..0x10FFF when there is a
 *     PBU;
 *   - before OS_$INIT, 0x60 goes to VME_CTL + 0x41;
 *   - the I/O map entries are the SAU5's pages (arch/m68k/sau5/iodefs.s:
 *     PFT, MMU, SIO, TIMR, CALENDAR, VME_CTL, PBU_CTL, GPU, RING2,
 *     COLOR_SUP, DISP1 twice (PPN 0x3C and 0x3D), IOMAP, PBU_IO,
 *     DISP1_MEM, DISP2_MEM, KOLOR_CTL); the RFC fixup table lists 50 cells
 *     here (the SAU2's 41).
 * Addresses in the comments are the SAU5 image's; the notes on CPU models
 * (DN300, DN320, DN330) are the SAU2 file's, kept with the code they
 * describe, which the SAU5's image has unchanged.
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
        .extern MMU_$PID_PRIV           /* map 0xE24B84, mmu/m68k/mmu_data.s */
        .extern M68020                  /* map 0xE24B86, mmu/m68k/mmu_data.s */
        .extern P1_STACK_BASE           /* map 0xEBA000, the STACK window (layout) */
        .extern MMAP                    /* map 0xEBC800, the MMAP page table (layout) */

/* ---- the kernel's layout: symbols the linker script defines */
/*      OS_DATA      map 0xE7F800: VA of `.DATA' (ours: = OS_DATA_UNWIRED)     */
/*      OS_PROC      map 0xE00800: the first kernel page                      */
/*      RELOC        map 0xE92834: the first byte after the last loaded byte  */
/*      OS_BEGIN     map 0xE00000: the bottom of the kernel's VA window       */
/*      OS_PAGE_END  map 0xECC800: the end of the pages COLD maps             */
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
        .equ    IO_WINDOW,      0x00F90000  /* v >= this: I/O (IODEFS), += 0x3000000 */
        .equ    IO_WINDOW_020,  0x03F90000
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
        .equ    VME_CTL_PHYS,   0x0000BC00  /* PPN 0x2F, mapped at VME_CTL 0xFF9400 */
        .equ    PBU_CLEAR_PHYS, 0x00010000  /* the 4 KB cold_map_pages clears with a PBU */

/* ---- MMU map table entry flags (bits 31..29 of the VA field) ------------ */
        .equ    MAP_WIRED,      0x80000000  /* kernel page: MMAP wire_count 0x80 */
        .equ    MAP_COLD,       0x40000000  /* COLD's pages: MMAP wire_count 0x40 */
        .equ    MAP_PRIVATE,    0x20000000  /* clear: PFT bit 12 (global) is set */

/* ---- A5 = COLD: the cells COLD writes (asserted at the end) ------------- */
        .equ    COLD_OFF_DISP1_MEM_VA,    0x580 /* 0x101980 cold_map_disp1_mem + 4 */
        .equ    COLD_OFF_DISP2_MEM_VA,    0x58A /* 0x10198A cold_map_disp2_mem + 4 */
        .equ    COLD_OFF_KERNEL_LO_COUNT, 0x5C2 /* 0x1019C2 cold_map_kernel_lo_count */
        .equ    COLD_OFF_KERNEL_HI,       0x5CC /* 0x1019CC cold_map_kernel_hi_count_ppn */
        .equ    COLD_OFF_BOOT_PARAMS,     0x5D8 /* 0x1019D8 cold_boot_params */
        .equ    COLD_OFF_DISKLESS,        0x5E4 /* 0x1019E4 cold_diskless_info */
        .equ    COLD_OFF_SAVED_SP,        0x600 /* 0x101A00 cold_saved_sp */
        .equ    COLD_OFF_MMAP_PHYS,       0x604 /* 0x101A04 cold_mmap_phys */
        .equ    COLD_OFF_PBU_PRESENT,     0x610 /* 0x101A10 cold_pbu_present */
        .equ    COLD_OFF_VA_SHIFT,        0x612 /* 0x101A12 cold_va_shift */
        .equ    COLD_OFF_VA_MASK,         0x614 /* 0x101A14 cold_va_mask */
        .equ    COLD_OFF_PTT_ENTRIES,     0x618 /* 0x101A18 cold_ptt_entries */

/*
 * The RFC header, 0x101400 (12 bytes): load address, start
 * address, machine type WORD (SAU 2), zero word.  The loader reads them as
 * physical load addresses; the binder did not list them in RELOC, so they
 * are literals (asserted against the labels at the end of the file).
 */
COLD:
        .long   COLD_LOW                /* 101400  load: file byte 0 lands here */
        .long   COLD_LOW + 0x24         /* 101404  start: cold_start_entry */
        .short  0x0005                  /* 101408  machine type: SAU 5 */
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
        adda.l  #KERNEL_LOW,%a0         /* 1014a0  = 0x194034, RELOC's low address */
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
        .long   PTT_WINDOW_LO           /* 101524  (not a RELOC cell, so not PTT) */
        blt.s   cold_reloc_next         /* 101528 */
        .short  0xbebc                  /* 10152a  cmp.l #0x800000,%d7 */
        .long   PTT_WINDOW_END          /* 10152c */
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
        btst    #14,(cold_boot_params+6:w,%pc) /* 10157e  boot flag bit 14: */
        beq.s   cold_set_vbr            /* 101584  the second display as the first */
        move.l  (cold_map_disp1_mem+4:w,%pc),%d4 /* 101586  swap the VAs of the */
        move.l  (cold_map_disp2_mem+4:w,%pc),(COLD_OFF_DISP1_MEM_VA,%a5) /* 10158a  DISP1_MEM */
        move.l  %d4,(COLD_OFF_DISP2_MEM_VA,%a5) /* 101590  and DISP2_MEM entries */
cold_set_vbr:
        lea     TRAP_PAGE_PHYS,%a2      /* 101594 */
        movec   %a2,%vbr                /* 10159a */
        move.l  (BUS_ERROR_VEC_OFF,%a2),-(%sp) /* 10159e  save the bus-error vector */
        move.l  %sp,(COLD_OFF_SAVED_SP,%a5)    /* 1015a2  cold_saved_sp */

/* 0x1015A6: probe the PBU controller; a bus error (no PBU) lands past the
   `st'. */
cold_probe_pbu:
        lea     (cold_probe_pbu_done:w,%pc),%a0 /* 1015a6 */
        move.l  %a0,(BUS_ERROR_VEC_OFF,%a2) /* 1015aa */
        tst.w   (PBU_CTL_PHYS).l        /* 1015ae */
        move.w  #0,(PBU_CTL_PHYS).l     /* 1015b4 */
        st      (COLD_OFF_PBU_PRESENT,%a5) /* 1015bc  cold_pbu_present */
cold_probe_pbu_done:
        movea.l (cold_saved_sp:w,%pc),%sp /* 1015c0 */

/*
 * 0x1015C4: the kernel page count n = (roundup1K(OS_PAGE_END) - the first
 * kernel page) >> 10.  If it fits the low piece, store it as the count of
 * the "kernel low" map entry; otherwise store (n - 0x157) << 16 |
 * MOVE_TO_PPN as the count and PPN of the "kernel high" entry.
 */
cold_count_kernel_pages:
        move.l  #OS_PAGE_END,%d4        /* 1015c4  OS_PAGE_END; a RELOC cell */
        .short  0xd8bc                  /* 1015ca  add.l #0x3ff,%d4 (<ea>=#imm form) */
        .long   0x000003ff              /* 1015cc */
        .short  0xc87c, 0xfc00          /* 1015d0  and.w #0xfc00,%d4 (<ea>=#imm form) */
        .short  0x98bc                  /* 1015d4  sub.l #first kernel page,%d4 (<ea>=#imm form) */
        .long   OS_PROC                 /* 1015d6  first kernel page; a RELOC cell */
        .short  0xb8bc                  /* 1015da  cmp.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES         /* 1015dc */
        bhi.w   cold_count_kernel_hi    /* 1015e0 */
        lsr.l   #5,%d4                  /* 1015e4 */
        lsr.l   #5,%d4                  /* 1015e6 */
        move.w  %d4,(COLD_OFF_KERNEL_LO_COUNT,%a5) /* 1015e8 */
        bra.w   cold_clear_mmap         /* 1015ec */
cold_count_kernel_hi:
        .short  0x98bc                  /* 1015f0  sub.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES         /* 1015f2 */
        lsr.l   #5,%d4                  /* 1015f6 */
        lsr.l   #5,%d4                  /* 1015f8 */
        swap    %d4                     /* 1015fa */
        move.w  (MOVE_TO_PPN+2:w,%pc),%d4 /* 1015fc  the PPN word of MOVE_TO_PPN */
        move.l  %d4,(COLD_OFF_KERNEL_HI,%a5) /* 101600 */

/*
 * 0x101604: a4 = the physical address of MMAP (VA - first page - 0x55C00
 * + MOVE_TO_PPN << 10), saved in cold_mmap_phys; the bus-error vector
 * goes to cold_probe_buserr; the 0xE000 bytes of MMAP are cleared.
 */
cold_clear_mmap:
        move.l  (MOVE_TO_PPN:w,%pc),%d4 /* 101604 */
        lsl.l   #5,%d4                  /* 101608 */
        lsl.l   #5,%d4                  /* 10160a */
        .short  0x98bc                  /* 10160c  sub.l #first kernel page,%d4 (<ea>=#imm form) */
        .long   OS_PROC                 /* 10160e  first kernel page; a RELOC cell */
        .short  0x98bc                  /* 101612  sub.l #0x55c00,%d4 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES         /* 101614 */
        .short  0xd8bc                  /* 101618  add.l #MMAP,%d4 (<ea>=#imm form) */
        .long   MMAP                    /* 10161a  a RELOC cell */
        movea.l %d4,%a4                 /* 10161e */
        move.l  %a4,(COLD_OFF_MMAP_PHYS,%a5) /* 101620  cold_mmap_phys */
        lea     (cold_probe_buserr:w,%pc),%a0 /* 101624 */
        move.l  %a0,(BUS_ERROR_VEC_OFF,%a2) /* 101628 */
        move.w  #0xdff,%d0              /* 10162c  3584 entries of 16 bytes */
cold_clear_mmap_loop:
        clr.l   (%a4)+                  /* 101630 */
        clr.l   (%a4)+                  /* 101632 */
        clr.l   (%a4)+                  /* 101634 */
        clr.l   (%a4)+                  /* 101636 */
        dbf     %d0,cold_clear_mmap_loop /* 101638 */

/*
 * 0x10163C: memory sizing.  Every 1 KB page from 0x80000 to 0x400000 is
 * read and rewritten a longword at a time, then its MMAP entry (index
 * (PPN - 0x200) * 16) gets 0x40000000.  The trap page at 0x101000 is
 * skipped.  A bus error lands in cold_probe_buserr, which skips 256 KB.
 */
cold_size_memory:
        movea.l #MEM_PROBE_LO,%a0       /* 10163c */
        movea.l (cold_mmap_phys:w,%pc),%a4 /* 101642 */
        adda.l  #0,%a4                  /* 101646  (an add of 0, as in the image) */
cold_size_page:
        lea     (0x400,%a0),%a1         /* 10164c  the end of this page */
        cmpa.l  #MEM_PROBE_HI,%a0       /* 101650 */
        beq.s   cold_size_done          /* 101656 */
        cmpa.l  #TRAP_PAGE_PHYS,%a0     /* 101658 */
        beq.s   cold_size_skip_page     /* 10165e */
cold_size_rewrite:
        move.l  (%a0),%d4               /* 101660 */
        move.l  %d4,(%a0)+              /* 101662 */
        cmpa.l  %a0,%a1                 /* 101664 */
        bne.s   cold_size_rewrite       /* 101666 */
        move.l  #0x40000000,(%a4)       /* 101668  present: wire_count 0x40 */
        adda.l  #0x10,%a4               /* 10166e */
        move.l  %a0,%d7                 /* 101674  the end of the last present page */
        bra.s   cold_size_page          /* 101676 */
cold_probe_buserr:
        movea.l (cold_saved_sp:w,%pc),%sp /* 101678 */
        bsr.s   cold_probe_skip_256k    /* 10167c */
        bra.s   cold_size_page          /* 10167e */
cold_size_skip_page:
        adda.l  #0x10,%a4               /* 101680 */
        movea.l %a1,%a0                 /* 101686 */
        bra.s   cold_size_page          /* 101688 */
cold_probe_skip_256k:
        adda.l  #0x1000,%a4             /* 10168a  256 entries of MMAP */
        adda.l  #0x40000,%a0            /* 101690 */
        rts                             /* 101696 */
cold_size_done:
        swap    %d7                     /* 101698  (the end of memory >> 19) */
        lsr.w   #3,%d7                  /* 10169a      + 7, to the VME */
        addq.l  #7,%d7                  /* 10169c      controller's word +0x30 */
        lea     (VME_CTL_PHYS).l,%a0    /* 10169e */
        move.w  %d7,(0x30,%a0)          /* 1016a4 */
        tst.b   (COLD_OFF_PBU_PRESENT,%a5) /* 1016a8 */
        beq.s   cold_size_restore       /* 1016ac */
        move.w  #0x10,%d0               /* 1016ae  tell the PBU controller: 0x10, */
        movea.l (cold_mmap_phys:w,%pc),%a0 /* 1016b2  or 0x30 when the page at MMAP */
        lea     (0x3800,%a0),%a0        /* 1016b6  index 0xA80 is present */
        lea     (0x7000,%a0),%a0        /* 1016ba */
        cmpi.l  #0x40000000,(%a0)       /* 1016be */
        beq.s   cold_size_pbu_ctl       /* 1016c4 */
        .short  0xd07c, 0x0020          /* 1016c6  add.w #0x20,%d0 (<ea>=#imm form; gas: addi) */
cold_size_pbu_ctl:
        move.w  %d0,(PBU_CTL_PHYS).l    /* 1016ca */
cold_size_restore:
        move.l  (%sp)+,(BUS_ERROR_VEC_OFF,%a2) /* 1016d0  restore vector 2 */
        movea.l #0,%a2                  /* 1016d4 */
        movec   %a2,%vbr                /* 1016da  VBR = 0 */
        lea     (cold_map_table:w,%pc),%a0 /* 1016de */
        bsr.w   cold_map_pages          /* 1016e2  load the MMU and turn it on */

/* 0x1016E6: kernel VAs are live from here on. */
        move.w  #1,MMU_$PID_PRIV        /* 1016e6  a RELOC cell */
        btst    #1,(PROM_MACHINE_ID_LO).w /* 1016ee */
        beq.s   cold_fpu_linef_trap     /* 1016f4 */
        st      M68020                  /* 1016f6  a RELOC cell */
        move.l  %sp,(COLD_OFF_SAVED_SP,%a5) /* 1016fc */
        lea     (cold_fpu_linef_trap:w,%pc),%a1 /* 101700 */
        move.l  %a1,TRAP_PAGE + LINE_F_VEC /* 101704  a RELOC cell */
        move.b  #0,MMU + 2              /* 10170a  a RELOC cell (0xFFB402) */
        fmove.l #0,%fpcr                /* 101712  no FPU: line-F trap */
        st      M68881_EXISTS           /* 10171a  a RELOC cell */
cold_fpu_linef_trap:
        movea.l (cold_saved_sp:w,%pc),%sp /* 101720 */
        movea.l #MMU,%a0                /* 101724  a RELOC cell */
        clr.w   (2,%a0)                 /* 10172a */
        move.w  (2,%a0),MMU_$INIT_BSR   /* 10172e  a RELOC cell: the immediate of */
                                        /*         MMU_$POWER_OFF's eori.w */
        tst.b   M68020                  /* 101736  a RELOC cell */
        bne.s   cold_mmu_regs_020       /* 10173c */
        movea.l #MMU,%a0                /* 10173e  68010: a RELOC cell */
        clr.w   (6,%a0)                 /* 101744 */
        move.w  #1,(4,%a0)              /* 101748 */
        bra.s   cold_enter_kernel       /* 10174e */
cold_mmu_regs_020:
        movea.l #MMU,%a0                /* 101750  68020: a RELOC cell */
        clr.w   (2,%a0)                 /* 101756 */
        move.w  #0x40,(6,%a0)           /* 10175a */
        move.w  #0x4000,(0xa,%a0)       /* 101760  the parity register */

/*
 * 0x101766: VME_CTL + 0x41 = 0x60; SP = P1_STACK_BASE;
 * OS_$INIT(&cold_boot_params, &cold_diskless_info), after a trap to the
 * debugger if boot flag bit 15 is set.  OS_$INIT never returns.
 */
cold_enter_kernel:
        move.b  #0x60,(VME_CTL+0x41).l  /* 101766  a RELOC cell */
        movea.l #P1_STACK_BASE,%sp      /* 10176e  a RELOC cell */
        pea     (cold_diskless_info:w,%pc) /* 101774 */
        pea     (cold_boot_params:w,%pc) /* 101778 */
        movea.l #OS_$INIT,%a0           /* 10177c  a RELOC cell */
        btst    #15,(cold_boot_params+6:w,%pc) /* 101782  flags bit 15 */
        beq.s   cold_call_os_init       /* 101788 */
        trap    #15                     /* 10178a */
cold_call_os_init:
        jsr     (%a0)                   /* 10178c */

/*
 * cold_map_pages, 0x10178E: a0 = a map table.  Clears the
 * PTT and the PFT, then for every page of every entry builds its PFT entry
 * (prot << 16 | (va >> shift) & 0xF0000, bit 12 = global unless flag bit
 * 29), hashes it into the PTT word at PTT + (va & mask), records
 * MMU_$PTTX[ppn] = (va & mask) >> 6 and, for ppn >= 0x200, the MMAP
 * entry's first word = flag bits 31..30 >> 16.  Ends by turning the MMU
 * on (CSR = 1) and setting byte 0 of the new trap page.  Not called with
 * the compiled-code convention: a0 in, every register clobbered.
 */
cold_map_pages:
        move.w  #2,MMU_CSR_PHYS         /* 10178e  33fc abs.l: CSR = 2 (PTT access) */
        movea.l (cold_mmap_phys:w,%pc),%a4 /* 101796 */
        movea.l #PTT,%a2                /* 10179a  a RELOC cell */
        move.w  (cold_ptt_entries:w,%pc),%d1 /* 1017a0 */
        subq.w  #1,%d1                  /* 1017a4 */
cold_clear_ptt:
        clr.w   (%a2)                   /* 1017a6  one word per 1 KB of the window */
        lea     (0x400,%a2),%a2         /* 1017a8 */
        dbf     %d1,cold_clear_ptt      /* 1017ac */
        lea     (PFT_PHYS).w,%a3        /* 1017b0 */
        move.l  #PFT_ENTRY0,(%a3)+      /* 1017b4  PFT[0] */
        move.w  #0xffe,%d1              /* 1017ba  PFT[1..4095] = 0 */
cold_clear_pft:
        clr.l   (%a3)+                  /* 1017be */
        dbf     %d1,cold_clear_pft      /* 1017c0 */
        tst.b   (COLD_OFF_PBU_PRESENT,%a5) /* 1017c4 */
        beq.s   cold_map_pft_base       /* 1017c8 */
        lea     (PBU_CLEAR_PHYS).l,%a2  /* 1017ca  with a PBU: clear 4 KB at 0x10000 */
        move.w  #0x3ff,%d4              /* 1017d0 */
cold_clear_pbu_page:
        clr.l   (%a2)+                  /* 1017d4 */
        dbf     %d4,cold_clear_pbu_page /* 1017d6 */
cold_map_pft_base:
        lea     (PFT_PHYS).w,%a3        /* 1017da */
        move.l  (MOVE_TO_PPN:w,%pc),%d0 /* 1017de  a1 = the physical address */
        lsl.l   #5,%d0                  /* 1017e2      of MMU_$PTTX */
        lsl.l   #5,%d0                  /* 1017e4 */
        .short  0x90bc                  /* 1017e6  sub.l #first kernel page,%d0 (<ea>=#imm form) */
        .long   OS_PROC                 /* 1017e8  first kernel page; a RELOC cell */
        .short  0x90bc                  /* 1017ec  sub.l #0x55c00,%d0 (<ea>=#imm form) */
        .long   KERNEL_LO_BYTES         /* 1017ee */
        movea.l %d0,%a1                 /* 1017f2 */
        adda.l  #MMU_$PTTX,%a1          /* 1017f4  a RELOC cell */
        move.w  (cold_va_shift:w,%pc),%d7 /* 1017fa */
cold_map_entry_loop:
        move.w  (%a0)+,%d0              /* 1017fe  count (0 ends the table) */
        beq.w   cold_mmu_on             /* 101800 */
        subq.w  #1,%d0                  /* 101804 */
        move.w  (%a0)+,%d1              /* 101806  ppn */
        move.l  (%a0)+,%d2              /* 101808  flags | va */
        move.w  (%a0)+,%d6              /* 10180a  prot */
        swap    %d6                     /* 10180c */
        clr.w   %d6                     /* 10180e */
cold_map_page_loop:
        move.l  %d2,%d3                 /* 101810  PFT entry */
        lsr.l   %d7,%d3                 /* 101812 */
        .short  0xc6bc                  /* 101814  and.l #0xf0000,%d3 (<ea>=#imm form) */
        .long   0x000f0000              /* 101816 */
        or.l    %d6,%d3                 /* 10181a */
        btst    #29,%d2                 /* 10181c */
        bne.s   cold_map_hash           /* 101820 */
        bset    #12,%d3                 /* 101822  global */
cold_map_hash:
        move.l  %d2,%d4                 /* 101826 */
        and.l   (cold_va_mask:w,%pc),%d4 /* 101828 */
        .short  0xd8bc                  /* 10182c  add.l #PTT,%d4 (<ea>=#imm form) */
        .long   PTT                     /* 10182e  a RELOC cell */
        movea.l %d4,%a2                 /* 101832 */
        move.w  (%a2),%d4               /* 101834 */
        .short  0xc87c, 0x0fff          /* 101836  and.w #0xfff,%d4 (<ea>=#imm form) */
        bne.s   cold_map_chain          /* 10183a */
        bset    #15,%d3                 /* 10183c  an empty slot: end of chain, */
        add.w   %d1,%d3                 /* 101840      linked to itself */
        move.w  %d1,(%a2)               /* 101842 */
        bra.s   cold_map_store          /* 101844 */
cold_map_chain:
        lsl.w   #2,%d4                  /* 101846  insert after the head (eor swap */
        move.l  (0,%a3,%d4.w),%d5       /* 101848      of the 12-bit links) */
        .short  0xcabc                  /* 10184c  and.l #0xfff,%d5 (<ea>=#imm form) */
        .long   0x00000fff              /* 10184e */
        eor.w   %d5,%d3                 /* 101852 */
        eor.w   %d1,%d5                 /* 101854 */
        eor.l   %d5,(0,%a3,%d4.w)       /* 101856 */
cold_map_store:
        move.w  %d1,%d4                 /* 10185a */
        lsl.w   #2,%d4                  /* 10185c */
        move.l  %d3,(0,%a3,%d4.w)       /* 10185e  PFT[ppn] */
        lsr.w   #1,%d4                  /* 101862 */
        move.l  %d2,%d3                 /* 101864 */
        and.l   (cold_va_mask:w,%pc),%d3 /* 101866 */
        lsr.l   #6,%d3                  /* 10186a */
        move.w  %d3,(0,%a1,%d4.w)       /* 10186c  MMU_$PTTX[ppn] */
        move.l  %d2,%d5                 /* 101870 */
        .short  0xcabc                  /* 101872  and.l #0xc0000000,%d5 (<ea>=#imm form) */
        .long   0xc0000000              /* 101874 */
        swap    %d5                     /* 101878 */
        .short  0x987c, 0x0400          /* 10187a  sub.w #0x400,%d4 (<ea>=#imm form): */
        bcs.s   cold_map_next_page      /* 10187e      ppn < 0x200 has no MMAP entry */
        mulu.w  #8,%d4                  /* 101880 */
        move.w  %d5,(0,%a4,%d4.l)       /* 101884  MMAP[ppn - 0x200].w0 */
cold_map_next_page:
        addq.w  #1,%d1                  /* 101888 */
        .short  0xd4bc                  /* 10188a  add.l #0x400,%d2 (<ea>=#imm form) */
        .long   0x00000400              /* 10188c */
        dbf     %d0,cold_map_page_loop  /* 101890 */
        bra.w   cold_map_entry_loop     /* 101894 */
cold_mmu_on:
        move.w  #1,MMU_CSR_PHYS         /* 101898  33fc abs.l: the MMU on */
        move.b  #0xff,(0).w             /* 1018a0  byte 0 of the trap page */
        rts                             /* 1018a6 */

/*
 * 0x1018A8: a second map table in the same format, referenced by nothing
 * (not COLD, not RELOC, no absolute longword in the image): an identity
 * map of 0..0x400000.  Purpose unknown.
 * Entry: count.w, ppn.w, flags | va.l, prot.w.
 */
cold_ident_map_table:
        .short  0x0001, 0x0404          /* 1018a8  the trap page */
        .long   0x00000000              /* 1018ac */
        .short  0x0170                  /* 1018b0 */
        .short  0x004f, 0x0001          /* 1018b2 */
        .long   0x00000400              /* 1018b6 */
        .short  0x0170                  /* 1018ba */
        .short  0x0008, 0x0050          /* 1018bc */
        .long   0x00004000              /* 1018c0 */
        .short  0x0130                  /* 1018c4 */
        .short  0x03ac, 0x0058          /* 1018c6 */
        .long   0x00016000              /* 1018ca */
        .short  0x0170                  /* 1018ce */
        .short  0x0bfb, 0x0405          /* 1018d0 */
        .long   COLD_LOW                /* 1018d4 */
        .short  0x0170                  /* 1018d8 */
        .short  0x0000                  /* 1018da  end */

/*
 * 0x1018DC: the MMU map table cold_map_pages walks.
 * prot 0x130 = X+R, 0x160 = R+W (I/O), 0x170 = X+R+W.  The VA cells of the
 * I/O, CRASH_RECORD, DUMP and kernel entries are RELOC cells.
 */
cold_map_table:
        .short  0x000f, 0x0001          /* 1018dc  low memory identity */
        .long   0x00000400              /* 1018e0 */
        .short  0x0130                  /* 1018e4 */
        .short  0x0008, 0x0050          /* 1018e6 */
        .long   0x00004000              /* 1018ea */
        .short  0x0130                  /* 1018ee */
        .short  0x0010, 0x0010          /* 1018f0  PFT */
        .long   PFT                     /* 1018f4 */
        .short  0x0160                  /* 1018f8 */
        .short  0x0001, 0x0020          /* 1018fa  MMU */
        .long   MMU                     /* 1018fe */
        .short  0x0160                  /* 101902 */
        .short  0x0001, 0x0021          /* 101904  SIO */
        .long   SIO                     /* 101908 */
        .short  0x0160                  /* 10190c */
        .short  0x0001, 0x0022          /* 10190e  TIMR */
        .long   TIMR                    /* 101912 */
        .short  0x0160                  /* 101916 */
        .short  0x0001, 0x0027          /* 101918  CALENDAR / TAPE / WIN */
        .long   CALENDAR                /* 10191c */
        .short  0x0160                  /* 101920 */
        .short  0x0001, 0x002f          /* 101922  VME_CTL */
        .long   VME_CTL                 /* 101926 */
        .short  0x0160                  /* 10192a */
        .short  0x0001, 0x0029          /* 10192c  PBU_CTL */
        .long   PBU_CTL                 /* 101930 */
        .short  0x0160                  /* 101934 */
        .short  0x0001, 0x0025          /* 101936  GPU */
        .long   GPU                     /* 10193a */
        .short  0x0160                  /* 10193e */
        .short  0x0001, 0x0026          /* 101940  RING2 */
        .long   RING2                   /* 101944 */
        .short  0x0160                  /* 101948 */
        .short  0x0003, 0x0038          /* 10194a  COLOR_SUP .. COLOR_CSTORE */
        .long   COLOR_SUP               /* 10194e */
        .short  0x0160                  /* 101952 */
        .short  0x0001, 0x003c          /* 101954  DISP1 / DISP1_SUP / DISP2 */
        .long   DISP1                   /* 101958 */
        .short  0x0160                  /* 10195c */
        .short  0x0001, 0x003d          /* 10195e  the same VA, the next PPN */
        .long   DISP1                   /* 101962 */
        .short  0x0160                  /* 101966 */
        .short  0x0004, 0x0040          /* 101968  IOMAP */
        .long   IOMAP                   /* 10196c */
        .short  0x0160                  /* 101970 */
        .short  0x0040, 0x01c0          /* 101972  PBU_IO / PBU */
        .long   PBU_IO                  /* 101976 */
        .short  0x0160                  /* 10197a */
cold_map_disp1_mem:
        .short  0x0080, 0x0080          /* 10197c  DISP1_MEM */
        .long   DISP1_MEM               /* 101980 */
        .short  0x0160                  /* 101984 */
cold_map_disp2_mem:
        .short  0x0080, 0x0100          /* 101986  DISP2_MEM / DISP_MEM_2KX1K */
        .long   DISP2_MEM               /* 10198a */
        .short  0x0160                  /* 10198e */
        .short  0x0040, 0x0180          /* 101990  KOLOR_CTL / IODEFS; prot 0x60 */
        .long   KOLOR_CTL               /* 101994 */
        .short  0x0060                  /* 101998 */
        .short  0x0001, 0x0400          /* 10199a  CRASH_RECORD */
        .long   MAP_WIRED + CRASH_$RECORD /* 10199e */
        .short  0x0170                  /* 1019a2 */
        .short  0x0001, 0x0403          /* 1019a4  DUMP */
        .long   MAP_WIRED + DUMP        /* 1019a8 */
        .short  0x0170                  /* 1019ac */
        .short  0x0001, 0x0404          /* 1019ae  TRAP_PAGE (VA 0; not a RELOC cell) */
        .long   MAP_WIRED + 0x00000000  /* 1019b2 */
        .short  0x0170                  /* 1019b6 */
        .short  0x0002, 0x0405          /* 1019b8  COLD itself (not a RELOC cell) */
        .long   MAP_COLD + MAP_PRIVATE + COLD_LOW /* 1019bc */
        .short  0x0170                  /* 1019c0 */
cold_map_kernel_lo_count:
        .short  0x0157, 0x0408          /* 1019c2  kernel, low piece; the count is */
                                        /*         rewritten if the kernel fits */
        .long   MAP_WIRED + OS_PROC     /* 1019c6  a RELOC cell */
        .short  0x0170                  /* 1019ca */
cold_map_kernel_hi_count_ppn:
        .short  0x0000, 0x0000          /* 1019cc  kernel, high piece: count and */
                                        /*         PPN filled by COLD */
        .long   MAP_WIRED + KERNEL_HI_VA /* 1019d0  a RELOC cell */
        .short  0x0170                  /* 1019d4 */
        .short  0x0000                  /* 1019d6  end */

/*
 * 0x1019D8: the boot record OS_$INIT receives as its first argument (9
 * longwords, 0x1019D8..0x1019FB; d1 and d2 of the entry are its first
 * two), and 0x1019E4: the diskless record, its second argument (12
 * longwords, 0x1019E4..0x101A13).  They overlap, and the diskless
 * record's last five longwords are COLD's own cells.  All zero in the
 * file except the MMU geometry defaults.
 */
cold_boot_params:
        .long   0, 0, 0                 /* 1019d8 */
cold_diskless_info:
        .long   0, 0, 0, 0, 0, 0, 0     /* 1019e4  the 7 copied longwords */
cold_saved_sp:
        .long   0                       /* 101a00 */
cold_mmap_phys:
        .long   0                       /* 101a04  MMAP's physical address */
        .long   0, 0                    /* 101a08 */
cold_pbu_present:
        .byte   0, 0                    /* 101a10  st by the PBU probe; a pad byte */
cold_va_shift:
        .short  0x0004                  /* 101a12  VA shift (6 on a 68020) */
cold_va_mask:
        .long   0x000fffff              /* 101a14  VA mask (0x3fffff on a 68020) */
cold_ptt_entries:
        .short  0x0400                  /* 101a18  PTT entries (0x1000 on a 68020) */

/* 0x101A1A..0x101BFC: COLD's stack, zero in the file. */
        .space  0x1e2                   /* 101a1a */
cold_stack_top:                         /* 101bfc  the initial SP; COLD + 0x7FC, */
        .space  4                       /* 101bfc  the map's segment end; then the */
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
