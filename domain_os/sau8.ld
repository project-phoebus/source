/*
 * sau8.ld - the SAU8 kernel's link (`make TARGET_SAU=sau8', `-T sau8.ld'):
 * the SAU8's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU8's map lays out its
 * own way.  The values are the SAU8 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau8/domain_os.map) and the
 * SAU8 image's RFC header (load address 0x101C00, start 0x101C24, machine
 * type 8; info block 0x1400, 0x3C8D800, 0x3C00C00, 0xFEED2B03, 0x55F,
 * 0x600: the SAU2's split, a fixup table at RELOC).
 */

/* The RFC load address: file byte 0 lands at physical 0x101C00 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x00101C00;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D24 3C00400 DUMP loaded at 102800', `I 4 3C00C00 WIRED_PROC loaded at
 * 103000'). */
RFC_LOW_DELTA = 0x03AFDC00;

/* The physical split (info block +16 / +20 = 0x55F, 0x600, and
 * cold/sau8/cold_start.s's SPLIT_LOW and KERNEL_LO_BYTES). */
RFC_SPLIT_LOW = 0x00157C00;
RFC_KERNEL_LO_BYTES = 0x00054C00;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x03C00000;              /* D00 3C00000 OS_BEGIN */

/* The low region below the kernel (map `D97 3A00000 OS_LOW' .. `D98
 * 3AEC000 OS_LOW_END_'), fixed VAs not in the file: UNWIRED_STACKS,
 * DISK_BUFFERS, BUFFER_PAGES (the drivers' DMA pages: the Winchester's,
 * the rings' receive pages, the floppy's), the Ethernet's and the 802.5
 * ring's buffers, PBU_TABLES, NETPOOL, AREA_PAGES and AST_AOT (the AST
 * and the AOT, as on the SAU5), back to back.  No object of the tree
 * defines them; ETHERNET_$BUFFER and RING8025_$AUX_DA are the drivers'
 * overlay sections (tools/gen_layout_ld.py LOW_OVERLAYS). */
OS_LOW = 0x03A00000;                /* 3A00000 OS_LOW */
OS_LOW_END = 0x03AEC000;            /* 3AEC000 OS_LOW_END */
GLOBAL_B = 0x03A00000;              /* 3A00000 (D99 GLOBAL_B_, size 0) */
OS_STACK = 0x03A00000;              /* 3A00000 UNWIRED_STACKS */
OS_STACK_END = 0x03A50000;          /* 3A50000 */
DBUF_BLKS = 0x03A50000;             /* 3A50000 DISK_BUFFERS */
RAW_BUF = 0x03A60000;               /* 3A60000 */
SM_ECC_BUF = 0x03A60400;            /* 3A60400 */
WIN_ECC_BUF = 0x03A60800;           /* 3A60800 */
DISK_BLK_POOL = 0x03A60C00;         /* 3A60C00 */
WIN_PAGE = 0x03A64C00;              /* 3A64C00 BUFFER_PAGES */
RING_RCV_PAGE = 0x03A65000;         /* 3A65000 */
RING2_RCV_PAGE = 0x03A65400;        /* 3A65400 */
WIN_IOMAP_PAGES = 0x03A65800;       /* 3A65800 */
FLP_PAGE = 0x03A66C00;              /* 3A66C00 */
FLP_OVRRUN_PAGE = 0x03A67000;       /* 3A67000 */
"ETHERNET_$BUFFER" = 0x03A67400;    /* D57 3A67400 ETHERNET_$BUFFER, size 1000 */
"RING8025_$AUX_DA" = 0x03A68400;    /* D68 3A68400 RING8025_$AUX_DA, size 7C00 */
"PBU_$PPN_OWNERS" = 0x03A70000;     /* 3A70000 PBU_TABLES */
"NETWORK_$BUFPOOL" = 0x03A74000;    /* 3A74000 NETPOOL */
OS_BUFFERS_END = 0x03A74000;        /* 3A74000 (D02 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x03AA4000;           /* 3AA4000 AREA_PAGES */
AREAS = 0x03AA4000;                 /* 3AA4000 */
AST = 0x03AC3800;                   /* 3AC3800 AST_AOT */
AOT = 0x03ACE000;                   /* 3ACE000 */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD_START 0xC00
 * bytes at file 0 (`D23 101C00 COLD size = BFC' and four zero bytes), the
 * DUMP page 0x800 at OS_BEGIN + 0x400 (file 0xC00), the kernel from
 * OS_BEGIN + 0xC00 (file 0x1400). */
RFC_COLD_SIZE = 0xC00;
RFC_DUMP_OFFSET = 0x400;
RFC_DUMP_SIZE = 0x800;
RFC_KERNEL_OFFSET = 0xC00;

INCLUDE kernel.ld

/* `D31 3C30564 NET_PORT_TABLE': DCTE_$NULL, the map's third name of
 * ROUTE_$PORT (kernel.ld has NETWORK_$ME), as on the SAU3. */
"DCTE_$NULL" = "ROUTE_$PORT";

/* The physical split: the fixup table past it, and MMAP, the root
 * tables' page tables and P1_STACK_BASE in the high piece, which COLD
 * reaches them through. */
ASSERT(RELOC - RFC_LOW_DELTA > RFC_SPLIT_LOW, "the fixup table must start past the split (COLD traps otherwise)")
ASSERT(MMAP >= OS_PROC + RFC_KERNEL_LO_BYTES && MMAP < OS_PAGE_END, "MMAP must be in the high piece")
ASSERT(P1_STACK_BASE >= OS_PROC + RFC_KERNEL_LO_BYTES && P1_STACK_BASE < OS_PAGE_END, "P1_STACK_BASE must be in the high piece")
ASSERT(DCTE_START == DCTE_END, "the dynamic DCTE area is empty")

/* What COLD maps: the kernel up to OS_PAGE_END, SMAPS + 0x3400 in the
 * OS_PMAPS window (the global segments' descriptors); the rest of
 * OS_PMAPS (SMAPS_END = RARS, the ASIDs' root tables, RARS_END),
 * AUDIT_LIST and VM_TABLES are the run-time windows (layout_vm.ld), at
 * the map's offsets. */
ASSERT(OS_PAGE_END == SMAPS + 0x3400, "OS_PAGE_END ends the global SMAPS, as in the map")
ASSERT(SMAPS_END == OS_PAGE_END + 0xB9400 && RARS == SMAPS_END && RARS_END == RARS + 0x7400, "SMAPS and RARS at the map's offsets")
ASSERT(AST_PMAPS == RARS_END + 0xC00 && VM_TABLES == AST_PMAPS && AREA_$RPMAP_CACHE == AST_PMAPS + 0x30000 && AST_PMAPS_END == AREA_$RPMAP_CACHE, "AUDIT_LIST and AST_PMAPS at the map's offsets")
ASSERT(BST == AREA_$RPMAP_CACHE + 0xC00 && MST == BST + 0x65800 && PIT_PAGES == MST + 0x3800 && MSTE_PAGES == PIT_PAGES + 0x10000 && VM_TABLES_END == MSTE_PAGES + 0xCCC00, "the VM tables at the map's offsets")

/* The wired data ranges (kernel.ld's AUDIT and NETLOG checks): on the
 * SAU8 PEB has no wired data, then CT's (`D 3C9D43C CT'), AUDIT's and
 * NETLOG's, each end the next one's start. */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "CT_$DATA_START" && "CT_$DATA_START" < "CT_$DATA_END" && "CT_$DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the CT, AUDIT and NETLOG wired data ranges, back to back in map order")

/* The VM tables' end below 0x3F80000, where COLD's MC68851 fixup pass
 * starts treating a cell as an I/O address (cold/sau8/cold_start.s), and
 * below IODEFS 0x3FA0000 (arch/m68k/sau8/iodefs.s). */
ASSERT(VM_TABLES_END < 0x03F80000 && VM_TABLES_END <= IODEFS, "the VM tables must end below the I/O fixup window and IODEFS")
