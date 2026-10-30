/*
 * sau9.ld - the SAU9 kernel's link (`make TARGET_SAU=sau9', `-T sau9.ld'):
 * the SAU9's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU9's map lays out its
 * own way.  The values are the SAU9 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau9/domain_os.map) and the
 * SAU9 image's RFC header (load address
 * 0x4002400, start 0x4002418, a 12-byte info block 0x2000, 0x3C489800,
 * 0x3C401C00; no split, no fixup table).
 */

/* The RFC load address: file byte 0 lands at physical 0x4002400 (header
 * word 0); COLD's VMA, and COLD_PROC's (identity mapped). */
RFC_LOAD = 0x04002400;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D24 3C401400 DUMP loaded at 4003C00', `I 5 3C401C00 WIRED_PROC loaded
 * at 4004400'). */
RFC_LOW_DELTA = 0x383FD800;

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD 0x1800 bytes
 * (`D23 4002400 COLD size = C68' with COLD_PROC to 0x40035D0, then zeros
 * up to DUMP's file offset), the DUMP page 0x800 at OS_BEGIN + 0x1400
 * (file 0x1800), the kernel from OS_BEGIN + 0x1C00 (file 0x2000, info
 * block +0). */
RFC_COLD_SIZE = 0x1800;
RFC_DUMP_OFFSET = 0x1400;
RFC_DUMP_SIZE = 0x800;
RFC_KERNEL_OFFSET = 0x1C00;

OS_BEGIN = 0x3C400000;              /* D98 3C400000 OS_BEGIN */

/* The low region below the kernel (map `D95 3C000000 OS_LOW' .. `D96
 * 3C0E8000 OS_LOW_END_'), fixed VAs not in the file: UNWIRED_STACKS,
 * DISK_BUFFERS, BUFFER_PAGES (the drivers' DMA pages), the Ethernet's and
 * the 802.5 ring's buffers, PBU_TABLES (the page owners' tables),
 * NETPOOL and AREA_PAGES, back to back.  No object of the tree defines
 * them; ETHERNET_$BUFFER and RING8025_$AUX_DA are the drivers' overlay
 * sections (tools/gen_layout_ld.py LOW_OVERLAYS). */
OS_LOW = 0x3C000000;                /* 3C000000 OS_LOW */
OS_LOW_END = 0x3C0E8000;            /* 3C0E8000 OS_LOW_END */
GLOBAL_B = 0x3C000000;              /* 3C000000 (D97 GLOBAL_B_, size 0) */
OS_STACK = 0x3C000000;              /* 3C000000 UNWIRED_STACKS */
OS_STACK_END = 0x3C050000;          /* 3C050000 */
DBUF_BLKS = 0x3C050000;             /* 3C050000 DISK_BUFFERS */
RAW_BUF = 0x3C060000;               /* 3C060000 */
SM_ECC_BUF = 0x3C060400;            /* 3C060400 */
WIN_ECC_BUF = 0x3C060800;           /* 3C060800 */
DISK_BLK_POOL = 0x3C060C00;         /* 3C060C00 */
WIN_PAGE = 0x3C064C00;              /* 3C064C00 BUFFER_PAGES */
SCSI_PAGE = 0x3C065000;             /* 3C065000 */
SCSI_CDB_PAGE = 0x3C06D400;         /* 3C06D400 */
RING_RCV_PAGE = 0x3C06DC00;         /* 3C06DC00 */
RING2_RCV_PAGE = 0x3C06E000;        /* 3C06E000 */
WIN_IOMAP_PAGES = 0x3C06E400;       /* 3C06E400 */
"ETHERNET_$BUFFER" = 0x3C06F800;    /* D53 3C06F800 ETHERNET_$BUFFER, size 1000 */
"RING8025_$AUX_DA" = 0x3C070800;    /* D64 3C070800 RING8025_$AUX_DA, size 8000 */
"PBU_$PPN_OWNERS" = 0x3C078800;     /* 3C078800 PBU_TABLES */
"SCSI_$PPN_OWNERS" = 0x3C088800;    /* 3C088800 */
"NETWORK_$BUFPOOL" = 0x3C098800;    /* 3C098800 NETPOOL */
OS_BUFFERS_END = 0x3C098800;        /* 3C098800 (D00 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x3C0C8800;           /* 3C0C8800 AREA_PAGES */
AREAS = 0x3C0C8800;                 /* 3C0C8800 */

INCLUDE kernel.ld

/* `D 3C433600 MONO9_DESC': DCTE_$NULL is MONO9_$UNIT, the first DCTE of
 * the SAU9's dynamic DCTE area (DCTE_START), not ROUTE_$PORT. */
"DCTE_$NULL" = "MONO9_$UNIT";

/* The header's kernel offset (cold/sau9/cold_start.s: the literal 0x2000)
 * and COLD's physical constants: the kernel's first page at file 0x2000,
 * the DUMP page at OS_BEGIN + 0x1400 (COLD copies it to physical
 * 0x4001400, the kernel's VA - 0x38400000). */
ASSERT(OS_PROC - RFC_LOW_DELTA == RFC_LOAD + 0x2000, "the kernel starts at file 0x2000 (the header's word)")
ASSERT(ADDR(.dump) == 0x3C401400 && ADDR(.text) == 0x3C401C00, "DUMP and the kernel at the VAs COLD and OS_COLD map")

/* The dynamic DCTE area holds MONO9_$UNIT, 0x40 bytes. */
ASSERT(DCTE_END - DCTE_START == 0x40 && "MONO9_$UNIT" == DCTE_START, "the dynamic DCTE area is MONO9_DESC's DCTE")

/* The wired data ranges (kernel.ld's AUDIT and NETLOG checks): on the
 * SAU9 PEB has no wired data, then CT's (`D 3C49D0BC CT'), AUDIT's and
 * NETLOG's, each end the next one's start. */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "CT_$DATA_START" && "CT_$DATA_START" < "CT_$DATA_END" && "CT_$DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the CT, AUDIT and NETLOG wired data ranges, back to back in map order")

/* What COLD maps (OS_$COLD_START, os/cold.pas): the kernel up to
 * OS_PAGE_END, which is SMAPS + 0x3B800 in the OS_PMAPS window (the
 * global segments' descriptors); the rest of OS_PMAPS (SMAPS_END = RARS,
 * the ASIDs' root tables, RARS_END), AUDIT_LIST, AST_AOT and VM_TABLES
 * are the run-time windows (layout_vm.ld), at the map's offsets. */
ASSERT(OS_PAGE_END == SMAPS + 0x3B800, "OS_PAGE_END ends the global SMAPS, as in the map")
ASSERT(SMAPS_END == OS_PAGE_END + 0xD3F800 && RARS == SMAPS_END && RARS_END == RARS + 0xE800, "SMAPS and RARS at the map's offsets")
ASSERT(AST == RARS_END + 0xC00 && AST_PMAPS == AST + 0x63800 && AREA_$RPMAP_CACHE == AST_PMAPS + 0xB4000 && AST_PMAPS_END == AREA_$RPMAP_CACHE, "AUDIT_LIST, AST_AOT and AST_PMAPS at the map's offsets")
ASSERT(BST == AREA_$RPMAP_CACHE + 0xC00 && MST == BST + 0x6BD800 && PIT_PAGES == MST + 0xD800 && MSTE_PAGES == PIT_PAGES + 0x10000 && VM_TABLES_END == MSTE_PAGES + 0x999800, "the VM tables at the map's offsets")

/* The VM tables' end below IODEFS (the I/O pages, arch/m68k/sau9/
 * iodefs.s), which OS_$INIT compares IODEFS_GUARD with. */
ASSERT(VM_TABLES_END <= IODEFS, "the VM tables must end below IODEFS")
