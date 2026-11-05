/*
 * sau6.ld - the SAU6 kernel's link (`make TARGET_SAU=sau6', `-T sau6.ld'):
 * the SAU6's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU6's map lays out its
 * own way.  The values are the SAU6 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau6/domain_os.map) and the
 * SAU6 image's RFC header (load address 0x101EC00, start 0x101EC24,
 * machine type 6; info block 0x1000, 0x7808B400, 0x78001000, 0xFEED2B03,
 * 0x415F, 0x4200; no fixup table: the image ends at RELOC).
 */

/* The RFC load address: file byte 0 lands at physical 0x101EC00 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x0101EC00;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D23 78000800 DUMP loaded at 101F400', `I 4 78001000 WIRED_PROC loaded
 * at 101FC00'). */
RFC_LOW_DELTA = 0x76FE1400;

/* The physical split (info block +16 / +20 = 0x415F, 0x4200, and
 * cold/sau6/cold_start.s's KERNEL_LO_BYTES). */
RFC_SPLIT_LOW = 0x01057C00;
RFC_KERNEL_LO_BYTES = 0x00038000;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x78000000;              /* D96 78000000 OS_BEGIN */
GLOBAL_B = 0x78000000;              /* 78000000 (D95 GLOBAL_B_, size 0) */

/* The low region (map `D93 7F520000 OS_LOW' .. `D94 7F5EC400
 * OS_LOW_END_'), fixed VAs not in the file, which on the SAU6 lie above
 * the kernel's VM tables (VM_TABLES_END 0x7A7BC000) and below the I/O
 * space: the segments of `D97 7F520000 UNWIRED_STACKS' (size 50000), `D51
 * 7F570000 DISK_BUFFERS' (14C00), `D74 7F584C00 PBU_TABLES' (18000), `D02
 * 7F59CC00 NETPOOL' (30000) and `D00 7F5CCC00 AREA_PAGES' (`D 7F5CCC00
 * VM_TABLES', 1F800), up to OS_LOW_END.  No object of the tree defines
 * them. */
OS_LOW = 0x7F520000;                /* 7F520000 OS_LOW */
OS_LOW_END = 0x7F5EC400;            /* 7F5EC400 OS_LOW_END */
OS_STACK = 0x7F520000;              /* 7F520000 UNWIRED_STACKS */
OS_STACK_END = 0x7F570000;          /* 7F570000 */
DBUF_BLKS = 0x7F570000;             /* 7F570000 DISK_BUFFERS */
RAW_BUF = 0x7F580000;               /* 7F580000 */
SM_ECC_BUF = 0x7F580400;            /* 7F580400 */
WIN_ECC_BUF = 0x7F580800;           /* 7F580800 */
DISK_BLK_POOL = 0x7F580C00;         /* 7F580C00 */
"PBU_$PPN_OWNERS" = 0x7F584C00;     /* 7F584C00 PBU_TABLES */
"NETWORK_$BUFPOOL" = 0x7F59CC00;    /* 7F59CC00 NETPOOL */
OS_BUFFERS_END = 0x7F59CC00;        /* 7F59CC00 (D98 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x7F5CCC00;           /* 7F5CCC00 AREA_PAGES */
AREAS = 0x7F5CCC00;                 /* 7F5CCC00 */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD_START 0x800
 * bytes at file 0 (`D22 101EC00 COLD size = 7FC' and four zero bytes),
 * the DUMP page 0x800 at OS_BEGIN + 0x800 (file 0x800), the kernel from
 * OS_BEGIN + 0x1000 (file 0x1000). */
RFC_COLD_SIZE = 0x800;
RFC_DUMP_OFFSET = 0x800;
RFC_DUMP_SIZE = 0x800;
RFC_KERNEL_OFFSET = 0x1000;

/* `D57 7F5EC400 IODEFS_GUARD' is the low region's end on the SAU6 (the
 * map's OS_LOW_END), not VM_TABLES_END: the low region lies above the
 * kernel's tables, as on the SAU4.  OS_$INIT's ceiling check reads it. */
IODEFS_GUARD_AT = OS_LOW_END;

INCLUDE kernel.ld

/* `D 78032DCC DCTE_END': DCTE_$NULL is the map's name of the empty
 * dynamic DCTE area's address (DCTE_START = DCTE_END), not ROUTE_$PORT's. */
"DCTE_$NULL" = DCTE_START;

/* The physical split, and MMAP, the OS page maps, SMAPS and P1_STACK_BASE
 * in the high piece, which COLD reaches them through.  No fixup table. */
ASSERT(MMAP >= OS_PROC + RFC_KERNEL_LO_BYTES && MMAP < OS_PAGE_END, "MMAP must be in the high piece")
ASSERT(OS_PMAPS >= OS_PROC + RFC_KERNEL_LO_BYTES && SMAPS < OS_PAGE_END, "OS_PMAPS and SMAPS must be in the high piece")
ASSERT(P1_STACK_BASE >= OS_PROC + RFC_KERNEL_LO_BYTES && P1_STACK_BASE < OS_PAGE_END, "P1_STACK_BASE must be in the high piece")
ASSERT(DCTE_START == DCTE_END, "the dynamic DCTE area is empty")

/* What COLD maps: the kernel up to OS_PAGE_END, ASID 0's segment map
 * entries (SMAPS + 0x3BC00) in the OS_PMAPS window; the rest of OS_PMAPS
 * (SMAPS_END = RARS, the ASIDs' root tables, RARS_END), AUDIT_LIST,
 * AST_AOT and VM_TABLES are the run-time windows (layout_vm.ld), at the
 * map's offsets. */
ASSERT(OS_PAGE_END == SMAPS + 0x3BC00, "OS_PAGE_END ends ASID 0's SMAPS, as in the map")
ASSERT(SMAPS_END == OS_PAGE_END + 0xD4DC00 && RARS == SMAPS_END && RARS_END == RARS + 0x1D000, "SMAPS and RARS at the map's offsets")
ASSERT(AST == RARS_END + 0xC00 && AOT == AST + 0x27600 && AST_PMAPS == AST + 0x63800 && VM_TABLES == AST_PMAPS, "AUDIT_LIST, AST_AOT and AST_PMAPS at the map's offsets")
ASSERT(AREA_$RPMAP_CACHE == AST_PMAPS + 0xB4000 && AST_PMAPS_END == AREA_$RPMAP_CACHE && BST == AREA_$RPMAP_CACHE + 0xC00 && MST == BST + 0xD89800 && PIT_PAGES == MST + 0x1B400 && MSTE_PAGES == PIT_PAGES + 0x10000 && VM_TABLES_END == MSTE_PAGES + 0x933000, "the VM tables at the map's offsets")

/* The wired data ranges of PEB, LPR, CT, AUDIT and NETLOG (kernel.ld's
 * AUDIT and NETLOG checks): no PEB, LPR, SM_C or MT wired data
 * (PEB_$WIRED_DATA_START = PEB_$WIRED_DATA_END = LPR_$DATA_START = CT's
 * block, `D 7809FCEC CT'; the map's LPR_$DATA_END is the byte before
 * it), then CT's, AUDIT's (`D 780A0A50 AUDIT') and NETLOG's (`D 780A0BFC
 * NETLOG'), back to back. */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "LPR_$DATA_START" && "LPR_$DATA_END" == "LPR_$DATA_START" - 1 && "LPR_$DATA_START" == "CT_$DATA_START" && "CT_$DATA_START" < "CT_$DATA_END" && "CT_$DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the PEB, LPR, CT, AUDIT and NETLOG wired data ranges in map order")

/* The VM tables below the low region, which lies below IODEFS 0x7F5FB800
 * (arch/m68k/sau6/iodefs.s). */
ASSERT(VM_TABLES_END <= OS_LOW && OS_LOW_END <= IODEFS && IODEFS_GUARD == OS_LOW_END, "the VM tables, then the low region, then the I/O space")
