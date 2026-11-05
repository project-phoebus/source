/*
 * sau7.ld - the SAU7 kernel's link (`make TARGET_SAU=sau7', `-T sau7.ld'):
 * the SAU7's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU7's map lays out its
 * own way.  The values are the SAU7 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau7/domain_os.map) and the
 * SAU7 image's RFC header (load address 0x1001C00, start 0x1001C24,
 * machine type 7; info block 0x2000, 0x3C49A400, 0x3C401400, 0xFEED2B03,
 * 0x415F, 0x4200; no fixup table: the image ends at RELOC).
 */

/* The RFC load address: file byte 0 lands at physical 0x1001C00 (header
 * word 0); COLD's VMA, and COLD_PROC's (identity mapped). */
RFC_LOAD = 0x01001C00;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D26 3C400C00 DUMP loaded at 1003400', `I 5 3C401400 WIRED_PROC loaded
 * at 1003C00'). */
RFC_LOW_DELTA = 0x3B3FD800;

/* The physical split (info block +16 / +20 = 0x415F, 0x4200): the
 * kernel's bytes below file page 0x415F stay where they were loaded, the
 * rest go to the pages from MOVE_TO_PPN (0x1080000), which OS_$COLD_START
 * (os/cold.pas) maps from KERNEL_HI_VA. */
RFC_SPLIT_LOW = 0x01057C00;
RFC_KERNEL_LO_BYTES = 0x00054000;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD 0x1800 bytes
 * (`D25 1001C00 COLD size = D58': COLD_START and the OS_COLD module's
 * data, then `I 3 1002958 COLD_PROC size = 728', then zeros up to DUMP's
 * file offset), the DUMP page 0x800 at OS_BEGIN + 0xC00 (file 0x1800),
 * the kernel from OS_BEGIN + 0x1400 (file 0x2000, info block +0). */
RFC_COLD_SIZE = 0x1800;
RFC_DUMP_OFFSET = 0xC00;
RFC_DUMP_SIZE = 0x800;
RFC_KERNEL_OFFSET = 0x1400;

OS_BEGIN = 0x3C400000;              /* D01 3C400000 OS_BEGIN */

/* The low region below the kernel (map `D98 3C000000 OS_LOW' .. `D99
 * 3C0D8400 OS_LOW_END_'), fixed VAs not in the file: UNWIRED_STACKS,
 * DISK_BUFFERS, BUFFER_PAGES (the drivers' DMA pages: the Winchester's,
 * the rings' receive pages, the floppy's, the SCSI controller's
 * mailboxes and control blocks), the Ethernet's and the 802.5 ring's
 * buffers, PBU_TABLES (the page owners' tables), NETPOOL and AREA_PAGES,
 * back to back.  No object of the tree defines them; ETHERNET_$BUFFER
 * and RING8025_$AUX_DA are the drivers' overlay sections
 * (tools/gen_layout_ld.py LOW_OVERLAYS). */
OS_LOW = 0x3C000000;                /* 3C000000 OS_LOW */
OS_LOW_END = 0x3C0D8400;            /* 3C0D8400 OS_LOW_END */
GLOBAL_B = 0x3C000000;              /* 3C000000 (D00 GLOBAL_B_, size 0) */
OS_STACK = 0x3C000000;              /* 3C000000 UNWIRED_STACKS */
OS_STACK_END = 0x3C050000;          /* 3C050000 */
DBUF_BLKS = 0x3C050000;             /* 3C050000 DISK_BUFFERS */
RAW_BUF = 0x3C060000;               /* 3C060000 */
SM_ECC_BUF = 0x3C060400;            /* 3C060400 */
WIN_ECC_BUF = 0x3C060800;           /* 3C060800 */
DISK_BLK_POOL = 0x3C060C00;         /* 3C060C00 */
WIN_PAGE = 0x3C064C00;              /* 3C064C00 BUFFER_PAGES */
RING_RCV_PAGE = 0x3C065000;         /* 3C065000 */
RING2_RCV_PAGE = 0x3C065400;        /* 3C065400 */
WIN_IOMAP_PAGES = 0x3C065800;       /* 3C065800 */
FLP_PAGE = 0x3C066C00;              /* 3C066C00 */
FLP_OVRRUN_PAGE = 0x3C067000;       /* 3C067000 */
SCSI_MAILBOXES = 0x3C067400;        /* 3C067400 */
SCSI_SCBS = 0x3C067800;             /* 3C067800 */
"ETHERNET_$BUFFER" = 0x3C068000;    /* D62 3C068000 ETHERNET_$BUFFER, size 1000 */
"RING8025_$AUX_DA" = 0x3C069000;    /* D73 3C069000 RING8025_$AUX_DA, size 7C00 */
"PBU_$PPN_OWNERS" = 0x3C070C00;     /* 3C070C00 PBU_TABLES */
"SCSI_$PPN_OWNERS" = 0x3C080C00;    /* 3C080C00 */
"NETWORK_$BUFPOOL" = 0x3C088C00;    /* 3C088C00 NETPOOL */
OS_BUFFERS_END = 0x3C088C00;        /* 3C088C00 (D03 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x3C0B8C00;           /* 3C0B8C00 AREA_PAGES */
AREAS = 0x3C0B8C00;                 /* 3C0B8C00 */

INCLUDE kernel.ld

/* `D33 3C435DFC NET_PORT_TABLE': DCTE_$NULL, the map's third name of
 * ROUTE_$PORT (kernel.ld has NETWORK_$ME), as on the SAU8. */
"DCTE_$NULL" = "ROUTE_$PORT";

/* The first VA of the kernel's moved part, past its first
 * RFC_KERNEL_LO_BYTES (the high piece; the name is COLD's on the SAU4
 * and SAU6, cold/sau6/cold_start.s): OS_$COLD_START's boot map maps it
 * to MOVE_TO_PPN's pages. */
KERNEL_HI_VA = OS_PROC + RFC_KERNEL_LO_BYTES;

/* The header's kernel offset (cold/sau7/cold_start.s: the literal 0x2000)
 * and the boot map's constants: the kernel's first page at file 0x2000,
 * the DUMP page at OS_BEGIN + 0xC00 (COLD copies it to physical
 * 0x1000C00, the kernel's VA - 0x3B400000). */
ASSERT(OS_PROC - RFC_LOW_DELTA == RFC_LOAD + 0x2000, "the kernel starts at file 0x2000 (the header's word)")
ASSERT(ADDR(.dump) == 0x3C400C00 && ADDR(.text) == 0x3C401400, "DUMP and the kernel at the VAs COLD and OS_COLD map")

/* The physical split: the boot map's first kernel entry maps the low
 * piece's 336 pages, the second the rest from KERNEL_HI_VA (os/cold.pas,
 * os_cold_kernel_low); MMAP, the OS page maps, SMAPS and P1_STACK_BASE
 * in the high piece.  No fixup table. */
ASSERT(RFC_KERNEL_LO_BYTES == 336 * 0x400 && KERNEL_HI_VA % 0x400 == 0, "the low piece is the boot map's 336 pages")
ASSERT(MMAP >= KERNEL_HI_VA && MMAP < OS_PAGE_END, "MMAP must be in the high piece")
ASSERT(OS_PMAPS >= KERNEL_HI_VA && SMAPS < OS_PAGE_END, "OS_PMAPS and SMAPS must be in the high piece")
ASSERT(P1_STACK_BASE >= KERNEL_HI_VA && P1_STACK_BASE < OS_PAGE_END, "P1_STACK_BASE must be in the high piece")
ASSERT(DCTE_START == DCTE_END, "the dynamic DCTE area is empty")

/* The wired data ranges (kernel.ld's AUDIT and NETLOG checks): on the
 * SAU7 PEB has no wired data, then CT's (`D 3C4ADE34 CT'), AUDIT's and
 * NETLOG's, each end the next one's start. */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "CT_$DATA_START" && "CT_$DATA_START" < "CT_$DATA_END" && "CT_$DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the CT, AUDIT and NETLOG wired data ranges, back to back in map order")

/* What COLD maps (OS_$COLD_START, os/cold.pas): the kernel up to
 * OS_PAGE_END, which is SMAPS + 0x3B800 in the OS_PMAPS window (the
 * global segments' descriptors); the rest of OS_PMAPS (SMAPS_END = RARS,
 * the ASIDs' root tables, RARS_END), AUDIT_LIST, AST_AOT and VM_TABLES
 * are the run-time windows (layout_vm.ld), at the map's offsets. */
ASSERT(OS_PAGE_END == SMAPS + 0x3B800, "OS_PAGE_END ends the global SMAPS, as in the map")
ASSERT(SMAPS_END == OS_PAGE_END + 0xD3F800 && RARS == SMAPS_END && RARS_END == RARS + 0xE800, "SMAPS and RARS at the map's offsets")
ASSERT(AST == RARS_END + 0xC00 && AOT == AST + 0x27600 && AST_PMAPS == AST + 0x63800 && VM_TABLES == AST_PMAPS && AREA_$RPMAP_CACHE == AST_PMAPS + 0xB4000 && AST_PMAPS_END == AREA_$RPMAP_CACHE, "AUDIT_LIST, AST_AOT and AST_PMAPS at the map's offsets")
ASSERT(BST == AREA_$RPMAP_CACHE + 0xC00 && MST == BST + 0x6BD800 && PIT_PAGES == MST + 0xD800 && MSTE_PAGES == PIT_PAGES + 0x10000 && VM_TABLES_END == MSTE_PAGES + 0x4CCC00, "the VM tables at the map's offsets")

/* The VM tables' end below IODEFS (the physical cache's tags and the I/O
 * pages, arch/m68k/sau7/iodefs.s), which OS_$INIT compares IODEFS_GUARD
 * with. */
ASSERT(VM_TABLES_END <= IODEFS, "the VM tables must end below IODEFS")
