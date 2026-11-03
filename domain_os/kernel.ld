/*
 * kernel.ld - the domain_os kernel, laid out as the RFC load image that
 * sysboot loads and COLD_START maps:
 * the output sections and the checks every SAU shares
 *
 * The SAU's own script (sau2.ld, sau5.ld, sau9.ld: `-T $(TARGET_SAU).ld')
 * defines the constants (the RFC load address, the sizes and offsets of
 * COLD, DUMP and the kernel, OS_BEGIN, the low region's fixed VAs),
 * INCLUDEs this file and adds the ASSERTs on what its map lays out its own
 * way.  The SAU5 is laid out like the SAU2 (the same load address, kernel
 * offset, kernel VA and split); the SAU9's COLD is
 * 0x1800 bytes (COLD_START, the OS_COLD module's data and its COLD_PROC
 * code), its DUMP page 0x800 at OS_BEGIN + 0x1400 and its kernel at
 * OS_BEGIN + 0x1C00, file 0x2000.  The text below is written for the
 * SAU2, with its map's addresses.
 *
 * The link produces an ELF (build/sau2/domain_os.elf, linked with
 * --emit-relocs); tools/gen_rfc_fixups.py turns it into the RFC file
 * dist/sau2/domain_os: the loadable sections by load address (LMA) from
 * file 0 = low address 0x101400, then the fixup table at RELOC.
 *
 * Addresses.  Every LMA here is the LOW address: where sysboot puts the
 * byte before the split, i.e. file offset + 0x101400, the
 * map's `loaded at'.  The file:
 *
 *   file    low       VMA          what
 *   0x000   0x101400  0x101400     .cold: RFC header (12 bytes), info block
 *                                  (24), COLD_START, its tables and stack
 *                                  (cold/sau2/cold_start.s, 0x800 bytes).
 *                                  VMA = LMA: COLD runs there, physically,
 *                                  before the MMU is on; its A5- and
 *                                  PC-relative cells and its `movea.l #COLD'
 *                                  are 0x101400-based.
 *   0x800   0x101C00  0xE00400     .dump: the DUMP page (dump/sau2/dump.s,
 *                                  0x400 bytes); COLD copies it to physical
 *                                  0x100C00 and maps it at its VMA.
 *   0xC00   0x102000  0xE00800     .text, .rodata, .data: the kernel, one
 *                                  stream, LMA = VMA - RFC_LOW_DELTA for
 *                                  every byte (holes included: they are
 *                                  zero bytes in the file); the first
 *                                  kernel page OS_PROC is page aligned.
 *   EOF-table  RELOC              the fixup table (count.w, then the low
 *                                  address of every 32-bit address cell),
 *                                  appended by gen_rfc_fixups.py; it is not
 *                                  a section of this link.
 *
 * Not in the file (NOBITS; `.vm_tables' past OS_PAGE_END is described
 * below):
 *   .crash_record  VMA OS_BEGIN 0xE00000: CRASH_$RECORD and
 *                  LOG_$LAST_ENTRY, the page COLD maps to PPN 0x400, which
 *                  survives a reboot (map `D41 E00000 CRASH_RECORD loaded
 *                  at E00000'); this script defines both (no module of
 *                  the tree owns them: log/log.pas declares them extern).
 *   .bss           VMA RELOC up: first the room for the fixup table
 *                  (RELOC..RFC_FIXUP_TABLE_END, sized from the inputs'
 *                  R_68K_32 relocations), then the image's own bss, in map
 *                  order (build/sau2/layout_bss.ld).  The image let its
 *                  43 KB table overlay ACL_$DATA (at RELOC), which
 *                  ACL_$INIT zeroes; ours is larger than ACL_$DATA and
 *                  would reach RINGLOG_$DATA, XPD_$DATA and PROC2_$DATA, so
 *                  it gets RAM of its own.
 *
 * The bss rule (tools/gen_layout_ld.py, IMAGE_BSS_START): NOBITS is exactly
 * what the image had no file bytes for.  Zero-filled module data blocks
 * (`.bss.moddata.<name>'), overlay sections (the Pascal's `var (name)',
 * COMMON symbols) and the map's windows that no object fills
 * (BSS_WINDOWS) keyed in the image's bss (RELOC 0xE88834 up to
 * IODEFS_GUARD 0xF4FC00) go to .bss (from AREA_$RPMAP_CACHE 0xEE4C00 up,
 * the VM tables' windows, to .vm_tables instead), a page-aligned image
 * address starting a page; every other zero-filled block or overlay
 * section stays among the code as zeros in the file (as the image had
 * them; layout_data.ld is empty).  So everything the image
 * had zeroed in its file is zeroed in ours, and the .bss part is what each
 * module's init zeroes itself in the image (ACL_$INIT ->
 * OS_$DATA_ZERO, ...; MMAP is cleared by COLD) - nothing clears it as a
 * whole.
 *
 * Symbols this script defines, read by COLD (cold/sau2/cold_start.s) and
 * named as in the map:
 *   OS_BEGIN     the bottom of the kernel's VAs, 0xE00000
 *   OS_PROC      the first kernel page, 0xE00800 (info block +8)
 *   OS_DATA      info block +4: the map's `.DATA' = OS_DATA_UNWIRED (the
 *                map has `D39 E78400 OS_DATA' there); nothing reads the
 *                cell, it is a fixup like the image's
 *   RELOC        the first byte after the last loaded byte: the fixup
 *                table's VMA, and the start of .bss
 *   OS_PAGE_END  the end of .bss rounded up to a page: COLD maps the kernel
 *                pages OS_PROC .. OS_PAGE_END
 * the VM tables' run-time windows, from
 * OS_PAGE_END up in the NOBITS `.vm_tables' (build/sau2/layout_vm.ld), at
 * the map's offsets, never mapped by COLD:
 *   AREA_$RPMAP_CACHE = AST_PMAPS_END, MST, PIT_PAGES, MSTE_PAGES,
 *   VM_TABLES_END = IODEFS_GUARD
 * the map's windows past OS_DATA_END that no object fills (BSS_WINDOWS in
 * tools/gen_layout_ld.py), NOBITS in `.bss' at their map
 * positions, each map symbol at the map's offset:
 *   STACK     NULL_STACK_GUARD (= OS_PAGE), NULL_STACK, NULL_PC,
 *             P1_STACK_GUARD, INT_STACK_GUARD = P1_STACK_BASE, and its end
 *             INT_STACK_BASE (map 0xEB0000, size 0x2C00)
 *   OS_PMAPS  MMAP, MMU_$PTTX (map 0xEB4800, size 0x10000)
 *   AST_AOT   AST, AOT (map `D EC5400 VM_TABLES', size 0xF960)
 *   VM_TABLES AST_PMAPS (and the map's VM_TABLES), up to AST_PMAPS_END
 * and the overlay sections of the Pascal (`var (name)', dpc's COMMON
 * symbols: ACL_$DATA, VTOC_CACHE, AUDIT_LIST, ...) at their map segments.
 * the boundaries OS_$INIT builds the address space from, defined
 * by tools/gen_layout_ld.py at their map positions in layout.ld and
 * layout_bss.ld under the map's names:
 *   OS_DATA_WIRED     the first wired data (map 0xE1DC00, page aligned)
 *   OS_INIT_START, OS_INIT_END  the boot-only code and data that
 *                     os_$start_proc2 frees (map 0xE2F000, page aligned,
 *                     and 0xE35380)
 *   OS_PROC_UNWIRED   the start of the unwired code (map .TEXT 0xE38000,
 *                     32 KB aligned as in the image: OS_INIT_END rounded up)
 *   OS_DISK_PROC_END  the end of the disk code kept wired (map 0xE3E746;
 *                     its start is the function OS_DISK_PROC)
 *   OS_DATA_UNWIRED   the start of the unwired data (map .DATA = OS_DATA
 *                     0xE78400, page aligned; OS_DATA is defined equal to
 *                     it below, as in the map)
 *   OS_DISK_DATA, OS_DISK_DATA_END  the disk data kept wired (map 0xE784D0,
 *                     0xE7B044)
 *   OS_LINK_UNPLACED  ours, no map name: the start of the catch-all at
 *                     the end of .text, then .rodata and .data, up to
 *                     RELOC; empty (the generator places every C object
 *                     and helper by its owning module and fails the check
 *                     if anything is left here), and not kept wired by
 *                     OS_$INIT
 *   OS_DATA_END       the end of the image's own bss blocks ACL_$DATA ..
 *                     PROC2_$DATA (map 0xEA9684)
 *   OS_PAGE           the stacks page NULL_STACK_GUARD (map 0xEB0000, 32
 *                     KB aligned: OS_$INIT rounds OS_DATA_END up to it)
 * and the constants of the physical split: the kernel
 * bytes below file page 0x55F stay at their low address, the rest are
 * loaded from PPN 0x600 (0x180000) up; COLD reaches MMAP, MMU_$PTTX and
 * P1_STACK_BASE through the high piece's formula, so they must lie at or
 * past OS_PROC + 0x55C00 (asserted below).
 *
 * Link order inside .text: the code and the module data blocks with file
 * bytes are in
 * the order of the SAU2 link map (domain_os.10.2.map), not at the image's
 * addresses.  layout.ld is build/sau2/layout.ld, written before every link
 * by tools/gen_layout_ld.py (make passes -L build/sau2 so INCLUDE finds
 * it and its two siblings; none is checked in).  It lists one input-section
 * statement per C function (`.text.<symbol>', -ffunction-sections), per
 * hand-written routine (`.section ".text.<symbol>"'), per C data object
 * (-fdata-sections) and per MODULE_DATA block, in map order (what the map
 * does not name, by its owning module), and ends with an
 * empty catch-all; ld assigns each input section to the first statement that
 * matches it, so the ordered list precedes the catch-all.  `make check'
 * links a scratch ELF and proves the order.
 *
 * The map order also gives the adjacencies that 16-bit and 8-bit
 * PC-relative references inside the image's hand-written segments need:
 *   SVC_CATCHER 0xE7B044: the eight trap dispatchers, then the nine
 *     dispatch tables (.text.svc_tables, anchored at 0xE7B2DE) reached with
 *     `lea (TABLE:w,%pc)';
 *   PROC1_ASM 0xE1EAC8: PROC1_$TSVV / PROC1_$CURRENT, EC_$WAIT .. ADVANCE /
 *     ADVANCE_INT, the PROC1 routines; `bsr.w' / `bsr.b' and `move.w
 *     (d,PC)' between them;
 *   SIO_INT 0xE2DF80: SIO2681_$PTRS, then the two 2681 stubs;
 *   SMD_WIRED 0xE26F20: SMD_$DISP1_INT, the cursor/scroll/BLT thunks,
 *     SMD_$DISPLAY_COM (C name SMD_DISPLAY_INFO, anchored) and SMD_TIME_$COM.
 *
 * OS_$INIT's layout boundaries come from the symbols above.
 */

OUTPUT_FORMAT("elf32-m68k")
OUTPUT_ARCH(m68k)
ENTRY(cold_start_entry)


SECTIONS {
    /* COLD_START (cold/<sau>/cold_start.s), then on the SAU9 the OS_COLD
     * module's data and code (os/cold.pas, the map's COLD and COLD_PROC
     * sections, identity mapped), up to RFC_COLD_SIZE. */
    .cold RFC_LOAD : AT(RFC_LOAD) {
        KEEP(*(".text.COLD"))
        KEEP(*(".moddata.OS_COLD.COLD"))
        KEEP(*(".text.OS_COLD.COLD_PROC"))
        . = RFC_COLD_SIZE;
    }

    /* `D41 E00000 CRASH_RECORD ... size = C' / `D E00000 CRASH_RECORD
     * size = C': CRASH_$RECORD (log/log.ins.pas crash_$record_t, 0xC
     * bytes), then LOG_$LAST_ENTRY at E0000C, listed after the segment's
     * 0xC bytes (log_$last_entry_t, 0xCC bytes: magic, size, type, time,
     * 96 data words).  The rest of the page is DUMP's stack (dump/sau2/
     * dump.s DUMP_STACK_TOP, CRASH_$RECORD + 0x100). */
    .crash_record OS_BEGIN (NOLOAD) : {
        "CRASH_$RECORD" = .;            /* E00000 */
        . = "CRASH_$RECORD" + 0xC;
        "LOG_$LAST_ENTRY" = .;          /* E0000C */
        . = "LOG_$LAST_ENTRY" + 0xCC;
    }

    .dump OS_BEGIN + RFC_DUMP_OFFSET : AT(OS_BEGIN + RFC_DUMP_OFFSET - RFC_LOW_DELTA) {
        KEEP(*(".text.DUMP"))
    }

    .text OS_BEGIN + RFC_KERNEL_OFFSET : AT(OS_BEGIN + RFC_KERNEL_OFFSET - RFC_LOW_DELTA) {
        OS_PROC = .;
        INCLUDE layout.ld
    }

    /* C .rodata/.data are placed in .text by layout.ld (by map symbol,
     * anchor or owning module); these two only catch what
     * the generator did not see, and are empty. */
    .rodata : AT(ADDR(.rodata) - RFC_LOW_DELTA) {
        *(.rodata .rodata.*)
    }

    .data : AT(ADDR(.data) - RFC_LOW_DELTA) {
        *(.data .data.*)
        /* C bss objects the image had in its file: zero bytes */
        INCLUDE layout_data.ld
        . = ALIGN(4);
    }

    /* The last loaded byte + 1: the fixup table's VMA (its low address is
     * RELOC - RFC_LOW_DELTA, the end of the file before the table). */
    RELOC = ADDR(.data) + SIZEOF(.data);

    /* Info block +4 (cold_start.s): the map's OS_DATA is `.DATA' (`D21
     * E78400 .DATA' / `D39 E78400 OS_DATA'), the start of the unwired data,
     * which layout.ld defines as OS_DATA_UNWIRED; the same here, not the
     * start of the C .data section.  sysboot and COLD
     * never read the cell; it is a fixup, as in the image. */
    OS_DATA = OS_DATA_UNWIRED;

    .bss RELOC (NOLOAD) : {
        INCLUDE layout_bss.ld
    }

    OS_PAGE_END = ALIGN(ADDR(.bss) + SIZEOF(.bss), 0x400);

    /* The VM tables' run-time windows: the map's VM_TABLES from
     * AREA_$RPMAP_CACHE (= its
     * AST_PMAPS_END) up to VM_TABLES_END = IODEFS_GUARD, at the map's
     * offsets (layout_vm.ld): AREA_$RPMAP_CACHE (3 pages, AREA_$INIT
     * 0x00E2F48A), MST (0xC00, MST_$INIT 0x00E30AE2), PIT_PAGES (0x40
     * pages, area_$alloc_seg_table 0x00E09D90), MSTE_PAGES (up to 0x166
     * pages, MST_$INIT / mst_$init_table_page 0x00E42D1A).  Virtual only:
     * not in the file and not mapped by COLD (it stops at OS_PAGE_END, as
     * the image's stops at its OS_PAGE_END 0xEC4800 below AUDIT_LIST /
     * AST_AOT / VM_TABLES); the kernel installs fresh pages at these VAs
     * unconditionally, so none of them may be a page COLD maps.  OS_$INIT's
     * canned map 5 covers them (OS_PAGE .. MSTE_PAGES + MST_PAGES_LIMIT
     * pages). */
    .vm_tables OS_PAGE_END (NOLOAD) : {
        INCLUDE layout_vm.ld
    }

    /* `D52 F4FC00 IODEFS_GUARD' = VM_TABLES_END: OS_$INIT's ceiling check
     * at 0x00E3397C (`move.l #IODEFS_GUARD,D0', a fixup cell).  A SAU
     * whose map puts it elsewhere gives IODEFS_GUARD_AT before INCLUDing
     * this script (the SAU4: the low region's end). */
    IODEFS_GUARD = DEFINED(IODEFS_GUARD_AT) ? IODEFS_GUARD_AT : VM_TABLES_END;

    /* NET_PORT_TABLE (`D28 E2E0A0 NET_PORT_TABLE size = 2E0', an overlay
     * section): route/route_wired.pas defines it as ROUTE_$PORT, the eight
     * port records.  The map gives the same address two more names,
     * NETWORK_$ME (the first record's network word, which NETWORK and OS
     * read by that name) and DCTE_$NULL; a Pascal variable has one name,
     * so these are aliases. */
    "NETWORK_$ME" = "ROUTE_$PORT";

    /* Discard debug sections and other unnecessary stuff */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.debug*)
    }
}

/* The RFC file's layout */
ASSERT(SIZEOF(.cold) == RFC_COLD_SIZE, "COLD must be RFC_COLD_SIZE bytes: DUMP follows it in the file")
ASSERT(SIZEOF(.crash_record) <= 0x400, "the crash record page is one page")
ASSERT(SIZEOF(.dump) == RFC_DUMP_SIZE, "the DUMP page is RFC_DUMP_SIZE bytes after COLD")
ASSERT(OS_BEGIN + RFC_DUMP_OFFSET + RFC_DUMP_SIZE == OS_BEGIN + RFC_KERNEL_OFFSET, "the kernel follows the DUMP page")
ASSERT(OS_PROC == OS_BEGIN + RFC_KERNEL_OFFSET, "the first kernel page is OS_BEGIN + RFC_KERNEL_OFFSET")
ASSERT(OS_PROC - RFC_LOW_DELTA == RFC_LOAD + RFC_COLD_SIZE + RFC_DUMP_SIZE, "the kernel starts in the file after COLD and DUMP")

/* OS_$INIT's address-space boundaries.
 * The two run-time roundings to a 32 KB segment must land where the image's
 * did: .TEXT's start rounded down is .TEXT's start (0x00E339A2), and
 * OS_DATA_END + 0x7FFF rounded down is OS_PAGE (0x00E339D6), so no wired
 * page is handed to the paging loop and the loop frees nothing past
 * OS_DATA_END that the kernel uses (stacks, MMAP, PTTX). */
ASSERT(OS_PROC_UNWIRED % 0x8000 == 0, "OS_PROC_UNWIRED must start a 32 KB segment")
ASSERT(OS_PAGE % 0x8000 == 0 && OS_PAGE == ALIGN(OS_DATA_END, 0x8000), "OS_PAGE must be OS_DATA_END rounded up to a 32 KB segment")
ASSERT(OS_PROC < OS_DATA_WIRED && OS_DATA_WIRED < OS_INIT_START && OS_INIT_START % 0x400 == 0 && OS_INIT_START < OS_INIT_END, "wired code, wired data, then the boot-only part")
ASSERT(OS_PROC_UNWIRED == ALIGN(OS_INIT_END, 0x8000), "os_$start_proc2 frees up to OS_INIT_END rounded to a segment, which must be .TEXT")
ASSERT(OS_PROC_UNWIRED <= OS_DISK_PROC && OS_DISK_PROC < OS_DISK_PROC_END && OS_DISK_PROC_END <= OS_DATA_UNWIRED, "OS_DISK_PROC..OS_DISK_PROC_END inside the unwired code")
ASSERT(OS_DATA_UNWIRED <= OS_DISK_DATA && OS_DISK_DATA <= OS_DISK_DATA_END && OS_DISK_DATA_END <= OS_LINK_UNPLACED, "OS_DISK_DATA..OS_DISK_DATA_END inside the unwired data")
/* Wired ranges whose bounds are link marks: each nonempty,
 * in map order, inside the placed part. */
ASSERT(OS_PROC_SHUTWIRED < OS_PROC_SHUTWIRED_END && OS_PROC_SHUTWIRED_END <= "PEB_$WIRED_PROC_START" && "PEB_$WIRED_PROC_START" < "PEB_$WIRED_PROC_END" && "PEB_$WIRED_PROC_END" <= NETLOG_$CNTL && NETLOG_$CNTL < NETLOG_$PROC_END && NETLOG_$PROC_END <= RING_PROC_START, "the shutdown, PEB and NETLOG wired code ranges in map order")
ASSERT(STOP_$WATCH < OS_DATA_SHUTWIRED && OS_DATA_SHUTWIRED < OS_DATA_SHUTWIRED_END && OS_DATA_SHUTWIRED_END <= RING_DATA_START, "STOP_$WATCH .. OS_DATA_SHUTWIRED .. OS_DATA_SHUTWIRED_END in map order")
ASSERT(RTWIRED_PROC_START % 0x400 == 0 && RING_DATA_END <= RTWIRED_PROC_START && RTWIRED_PROC_START < "ROUTE_$WIRED_PAGES" && "ROUTE_$WIRED_PAGES" < RTWIRED_DATA_END && RTWIRED_DATA_END <= OS_LINK_UNPLACED, "RTWIRED_PROC_START starts a page before the wired routing code, RTWIRED_DATA_END ends its data")
/* The AUDIT, NETLOG and PEB ranges whose bounds are the map's marks
 * in map order, each end the next one's start where the map
 * gives both names one address, NETLOG_$PROC_START at NETLOG_$CNTL (the map
 * gives both 0xE71914; netlog/cntl.pas passes the one for the other).  The
 * wired data ranges' order differs by SAU: the SAU's script asserts it. */
ASSERT("AUDIT_$PROC_START" < "AUDIT_$PROC_END" && "AUDIT_$PROC_END" <= "NETLOG_$PROC_START" && "NETLOG_$PROC_START" == NETLOG_$CNTL, "the AUDIT code range, then NETLOG's")
ASSERT(DCTE_START <= DCTE_END && DCTE_END < OS_INIT_START, "the dynamic DCTE area, in the wired data")
ASSERT(OS_LINK_UNPLACED <= RELOC && RELOC <= OS_DATA_END && OS_DATA_END < OS_PAGE, "the unplaced part and the image's bss blocks below OS_DATA_END")
ASSERT(NULL_STACK_GUARD == OS_PAGE && MMAP >= OS_PAGE, "the stacks and MMAP lie past the paging loop")

/* The VM tables' run-time windows: from OS_PAGE_END,
 * page aligned; the SAU's script checks their map order and offsets. */
ASSERT(OS_PAGE_END % 0x400 == 0 && VM_TABLES_END % 0x400 == 0 && OS_PAGE_END < VM_TABLES_END && IODEFS_GUARD == (DEFINED(IODEFS_GUARD_AT) ? IODEFS_GUARD_AT : VM_TABLES_END), "the VM-table windows from OS_PAGE_END to VM_TABLES_END, on pages; IODEFS_GUARD the SAU's or VM_TABLES_END")
