/*
 * sau4.ld - the SAU4 kernel's link (`make TARGET_SAU=sau4', `-T sau4.ld'):
 * the SAU4's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU4's map lays out its
 * own way.  The values are the SAU4 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau4/domain_os.map) and the
 * SAU4 image's RFC header (load address 0x201800, start 0x201824, machine
 * type 4; info block 0xC00, 0xF885C00, 0xF800C00, 0xFEED2B03, 0x95F,
 * 0xA00; no fixup table: the image ends at RELOC).
 */

/* The RFC load address: file byte 0 lands at physical 0x201800 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x00201800;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D23 F800800 DUMP loaded at 202000', `I 4 F800C00 WIRED_PROC loaded at
 * 202400'). */
RFC_LOW_DELTA = 0x0F5FE800;

/* The physical split (info block +16 / +20 = 0x95F, 0xA00, and
 * cold/sau4/cold_start.s's KERNEL_LO_BYTES). */
RFC_SPLIT_LOW = 0x00257C00;
RFC_KERNEL_LO_BYTES = 0x00055800;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x0F800000;              /* D94 F800000 OS_BEGIN */
GLOBAL_B = 0x0F800000;              /* F800000 (D93 GLOBAL_B_, size 0) */

/* The low region (map `D91 FE44000 OS_LOW' .. `D92 FEFC400 OS_LOW_END_'),
 * fixed VAs not in the file, which on the SAU4 lie above the kernel's VM
 * tables (VM_TABLES_END 0xFDED400) and below the I/O space: the segments
 * of `D95 FE44000 UNWIRED_STACKS' (size 50000), `D49 FE94000
 * DISK_BUFFERS' (14C00), `D72 FEA8C00 PBU_TABLES' (3E00), `D00 FEACC00
 * NETPOOL' (30000) and `D98 FEDCC00 AREA_PAGES' (`D FEDCC00 VM_TABLES',
 * 1F800), up to OS_LOW_END.  No object of the tree defines them. */
OS_LOW = 0x0FE44000;                /* FE44000 OS_LOW */
OS_LOW_END = 0x0FEFC400;            /* FEFC400 OS_LOW_END */
OS_STACK = 0x0FE44000;              /* FE44000 UNWIRED_STACKS */
OS_STACK_END = 0x0FE94000;          /* FE94000 */
DBUF_BLKS = 0x0FE94000;             /* FE94000 DISK_BUFFERS */
RAW_BUF = 0x0FEA4000;               /* FEA4000 */
SM_ECC_BUF = 0x0FEA4400;            /* FEA4400 */
WIN_ECC_BUF = 0x0FEA4800;           /* FEA4800 */
DISK_BLK_POOL = 0x0FEA4C00;         /* FEA4C00 */
"PBU_$PPN_OWNERS" = 0x0FEA8C00;     /* FEA8C00 PBU_TABLES */
"NETWORK_$BUFPOOL" = 0x0FEACC00;    /* FEACC00 NETPOOL */
OS_BUFFERS_END = 0x0FEACC00;        /* FEACC00 (D96 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x0FEDCC00;           /* FEDCC00 AREA_PAGES */
AREAS = 0x0FEDCC00;                 /* FEDCC00 */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD_START 0x800
 * bytes at file 0 (`D22 201800 COLD size = 7FC' and four zero bytes), the
 * DUMP page 0x400 at OS_BEGIN + 0x800 (file 0x800), the kernel from
 * OS_BEGIN + 0xC00 (file 0xC00). */
RFC_COLD_SIZE = 0x800;
RFC_DUMP_OFFSET = 0x800;
RFC_DUMP_SIZE = 0x400;
RFC_KERNEL_OFFSET = 0xC00;

/* `D55 FEFC400 IODEFS_GUARD' is the low region's end on the SAU4 (the
 * map's OS_LOW_END), not VM_TABLES_END: the low region lies above the
 * kernel's tables.  OS_$INIT's ceiling check reads it. */
IODEFS_GUARD_AT = OS_LOW_END;

INCLUDE kernel.ld

/* `D28 F8312C4 NET_PORT_TABLE': DCTE_$NULL, the map's third name of
 * ROUTE_$PORT (kernel.ld has NETWORK_$ME), as on the SAU3. */
"DCTE_$NULL" = "ROUTE_$PORT";

/* The physical split, and MMAP, the OS page maps, SMAPS and P1_STACK_BASE
 * in the high piece, which COLD reaches them through.  No fixup table. */
ASSERT(MMAP >= OS_PROC + RFC_KERNEL_LO_BYTES && MMAP < OS_PAGE_END, "MMAP must be in the high piece")
ASSERT(OS_PMAPS >= OS_PROC + RFC_KERNEL_LO_BYTES && SMAPS < OS_PAGE_END, "OS_PMAPS and SMAPS must be in the high piece")
ASSERT(P1_STACK_BASE >= OS_PROC + RFC_KERNEL_LO_BYTES && P1_STACK_BASE < OS_PAGE_END, "P1_STACK_BASE must be in the high piece")
ASSERT(DCTE_START == DCTE_END, "the dynamic DCTE area is empty")

/* What COLD maps: the kernel up to OS_PAGE_END, SMAPS + 0x7800 in the
 * OS_PMAPS window (the global segments' map entries); the rest of
 * OS_PMAPS (SMAPS_END = RARS, the ASIDs' region register sets,
 * RARS_END), AUDIT_LIST, AST_AOT and VM_TABLES are the run-time windows
 * (layout_vm.ld), at the map's offsets. */
ASSERT(OS_PAGE_END == SMAPS + 0x7800, "OS_PAGE_END ends the global SMAPS, as in the map")
ASSERT(SMAPS_END == OS_PAGE_END + 0x1AB800 && RARS == SMAPS_END && RARS_END == RARS + 0x2000, "SMAPS and RARS at the map's offsets")
ASSERT(AST == RARS_END + 0xC00 && AOT == AST + 0x10A00 && AST_PMAPS == AST + 0x4CC00 && VM_TABLES == AST_PMAPS, "AUDIT_LIST, AST_AOT and AST_PMAPS at the map's offsets")
ASSERT(AREA_$RPMAP_CACHE == AST_PMAPS + 0x4C000 && AST_PMAPS_END == AREA_$RPMAP_CACHE && BST == AREA_$RPMAP_CACHE + 0xC00 && MST == BST + 0x1B3000 && PIT_PAGES == MST + 0x3800 && MSTE_PAGES == PIT_PAGES + 0x10000 && VM_TABLES_END == MSTE_PAGES + 0xCCC00, "the VM tables at the map's offsets")

/* The wired data ranges of PEB, LPR, AUDIT and NETLOG (kernel.ld's AUDIT
 * and NETLOG checks), as on the SAU3: no PEB wired data
 * (PEB_$WIRED_DATA_START = PEB_$WIRED_DATA_END = LPR_$DATA_START, `D
 * F893808 LPR_'); LPR's range takes in LPR_'s block, LPR_ASM and CBUF's
 * block, whose last byte is LPR_$DATA_END (`D F893B1C CBUF size = 4',
 * F893B1F); then AUDIT's (`D F893B20 AUDIT') and NETLOG's (`D F893CCC
 * NETLOG'). */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "LPR_$DATA_START" && "LPR_$DATA_START" < "LPR_$DATA_END" && "LPR_$DATA_END" < "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the PEB, LPR, AUDIT and NETLOG wired data ranges in map order")

/* The VM tables below the low region, which lies below IODEFS 0xFFA0000
 * (arch/m68k/sau4/iodefs.s). */
ASSERT(VM_TABLES_END <= OS_LOW && OS_LOW_END <= IODEFS && IODEFS_GUARD == OS_LOW_END, "the VM tables, then the low region, then the I/O space")

