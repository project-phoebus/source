/*
 * sau5.ld - the SAU5 kernel's link (`make TARGET_SAU=sau5', `-T sau5.ld'):
 * the SAU5's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU5's map lays out its
 * own way.  The values are the SAU5 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau5/domain_os.map) and the
 * SAU5 image's RFC header, which has the SAU2's load address, kernel
 * offset, kernel VA and split (header words
 * 0x101400, 0x101424, info block 0xC00, 0xE7F800, 0xE00800, 0xFEED2B03,
 * 0x55F, 0x600).
 */

/* The RFC load address: file byte 0 lands at physical 0x101400 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x00101400;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D23 E00400 DUMP loaded at 101C00', `I 4 E00800 WIRED_PROC loaded at
 * 102000'). */
RFC_LOW_DELTA = 0x00CFE800;

/* The physical split (info block +16 / +20 = 0x55F, 0x600, and
 * cold/sau5/cold_start.s's SPLIT_LOW and KERNEL_LO_BYTES). */
RFC_SPLIT_LOW = 0x00157C00;
RFC_KERNEL_LO_BYTES = 0x00055C00;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x00E00000;              /* D95 E00000 OS_BEGIN */

/* The low region below the kernel (map `D92 D00000 OS_LOW' .. `D93 DB5D60
 * OS_LOW_END_'), fixed VAs not in the file, as on the SAU2, with two more
 * segments: `D73 D64C00 PBU_TABLES' between DISK_BUFFERS and NETPOOL, and
 * `D00 DA6400 AST_AOT' after AREA_PAGES (on the SAU2 AST_AOT is a window
 * in the kernel's bss, gen_layout_ld.py BSS_WINDOWS[2]). */
OS_LOW = 0x00D00000;                /* D00000 OS_LOW */
OS_LOW_END = 0x00DB5D60;            /* DB5D60 OS_LOW_END */

/* The map's symbols in that region, each the map's VA: the segments of
 * `D96 D00000 UNWIRED_STACKS' (size 50000), `D49 D50000 DISK_BUFFERS'
 * (14C00), `D73 D64C00 PBU_TABLES' (1C00), `D01 D66800 NETPOOL' (30000),
 * `D99 D96800 AREA_PAGES' (`D D96800 VM_TABLES', FC00) and `D00 DA6400
 * AST_AOT' (`D DA6400 VM_TABLES', F960), back to back up to OS_LOW_END.
 * No object of the tree defines them: pbu/pbu.ins.pas names
 * PBU_$PPN_OWNERS, ast/ast.ins.pas AST and AOT, and the others are the
 * SAU2's (sau2.ld). */
GLOBAL_B = 0x00D00000;              /* D00000 (D94 GLOBAL_B_, size 0) */
OS_STACK = 0x00D00000;              /* D00000 UNWIRED_STACKS */
OS_STACK_END = 0x00D50000;          /* D50000 */
DBUF_BLKS = 0x00D50000;             /* D50000 DISK_BUFFERS */
RAW_BUF = 0x00D60000;               /* D60000 */
SM_ECC_BUF = 0x00D60400;            /* D60400 */
WIN_ECC_BUF = 0x00D60800;           /* D60800 */
DISK_BLK_POOL = 0x00D60C00;         /* D60C00 */
"PBU_$PPN_OWNERS" = 0x00D64C00;     /* D64C00 PBU_TABLES */
"NETWORK_$BUFPOOL" = 0x00D66800;    /* D66800 NETPOOL */
OS_BUFFERS_END = 0x00D66800;        /* D66800 (D97 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x00D96800;           /* D96800 AREA_PAGES */
AREAS = 0x00D96800;                 /* D96800 */
AST = 0x00DA6400;                   /* DA6400 AST_AOT */
AOT = 0x00DA8B60;                   /* DA8B60 */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD_START 0x800
 * bytes at file 0, the DUMP page 0x400 at OS_BEGIN + 0x400 (file 0x800),
 * the kernel from OS_BEGIN + 0x800 (file 0xC00). */
RFC_COLD_SIZE = 0x800;
RFC_DUMP_OFFSET = 0x400;
RFC_DUMP_SIZE = 0x400;
RFC_KERNEL_OFFSET = 0x800;

INCLUDE kernel.ld

/* `D28 E2E0A0 NET_PORT_TABLE': DCTE_$NULL, the map's third name of
 * ROUTE_$PORT (kernel.ld has NETWORK_$ME). */
"DCTE_$NULL" = "ROUTE_$PORT";

/* The physical split: the fixup table past it, and MMAP,
 * MMU_$PTTX and P1_STACK_BASE in the high piece, which COLD reaches them
 * through. */
ASSERT(RELOC - RFC_LOW_DELTA > RFC_SPLIT_LOW, "the fixup table must start past the split (COLD traps otherwise)")
ASSERT(MMAP >= OS_PROC + RFC_KERNEL_LO_BYTES && MMAP < OS_PAGE_END, "MMAP must be in the high piece")
ASSERT(MMU_$PTTX >= OS_PROC + RFC_KERNEL_LO_BYTES && MMU_$PTTX < OS_PAGE_END, "MMU_$PTTX must be in the high piece")
ASSERT(P1_STACK_BASE >= OS_PROC + RFC_KERNEL_LO_BYTES && P1_STACK_BASE < OS_PAGE_END, "P1_STACK_BASE must be in the high piece")
ASSERT(MMU_$PTTX >= OS_PAGE, "PTTX lies past the paging loop")
ASSERT(DCTE_START == DCTE_END, "the dynamic DCTE area is empty")

/* The VM tables' run-time windows: right
 * after the COLD-mapped kernel, in the map's order and at its offsets,
 * page aligned, and below the I/O space.  AST_PMAPS_END (AST_PMAPS's end,
 * 0xFC00 bytes in the map) is AREA_$RPMAP_CACHE as in the map.  The window end must
 * also stay below the address where COLD's 68020 fixup pass starts treating
 * a cell as an I/O address (cold_start.s IO_WINDOW),
 * and below IODEFS (hardware, arch/m68k/<sau>/iodefs.s), which OS_$INIT
 * compares IODEFS_GUARD with (0x00E33982): the SAU's script asserts both. */
ASSERT(AREA_$RPMAP_CACHE == OS_PAGE_END && OS_PAGE_END % 0x400 == 0, "the VM-table windows start at OS_PAGE_END, on a page")
ASSERT(AST_PMAPS + 0xFC00 == AREA_$RPMAP_CACHE && AST_PMAPS_END == AREA_$RPMAP_CACHE, "AST_PMAPS_END (AST_PMAPS + 0xFC00) must be AREA_$RPMAP_CACHE, the last COLD-mapped block")
ASSERT(AREA_$RPMAP_CACHE < MST && MST < PIT_PAGES && PIT_PAGES < MSTE_PAGES && MSTE_PAGES < VM_TABLES_END, "the VM-table windows in map order")
ASSERT(MST % 0x400 == 0 && PIT_PAGES % 0x400 == 0 && MSTE_PAGES % 0x400 == 0 && VM_TABLES_END % 0x400 == 0, "the VM-table windows start pages")
ASSERT(MST - AREA_$RPMAP_CACHE == 0xC00 && PIT_PAGES - MST == 0xC00 && MSTE_PAGES - PIT_PAGES == 0x10000, "the VM-table windows keep the map's sizes")
ASSERT(VM_TABLES_END == MSTE_PAGES + 0x166 * 0x400 && IODEFS_GUARD == VM_TABLES_END, "VM_TABLES_END = IODEFS_GUARD = MSTE_PAGES + MST_MSTE_PAGES_MAX pages")

/* The wired data ranges of PEB, AUDIT and NETLOG (kernel.ld's AUDIT and
 * NETLOG checks): on the SAU5 CT's data segment lies between PEB's and
 * AUDIT's (`D E8C994 PEB_WIRED', `D E8CFEC CT', `D E8DD04 AUDIT', `D
 * E8DEB0 NETLOG'), each end the next one's start. */
ASSERT("PEB_$WIRED_DATA_START" < "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "CT_$DATA_START" && "CT_$DATA_START" < "CT_$DATA_END" && "CT_$DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the PEB, CT, AUDIT and NETLOG wired data ranges, back to back in map order")

/* The VM tables' end (kernel.ld's VM-table checks) below 0xF90000, where
 * COLD's 68020 fixup pass starts treating a cell as an I/O address
 * (cold/sau5/cold_start.s IO_WINDOW), which is IODEFS (= KOLOR_CTL,
 * arch/m68k/sau5/iodefs.s). */
ASSERT(VM_TABLES_END < 0x00F90000 && VM_TABLES_END <= IODEFS, "the VM tables must end below the 68020 I/O fixup window and IODEFS")
