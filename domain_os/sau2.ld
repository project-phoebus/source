/*
 * sau2.ld - the SAU2 kernel's link (`-T sau2.ld'): the SAU2's constants,
 * then kernel.ld (the output sections and the checks every SAU shares),
 * then the checks on what the SAU2's map lays out its own way.  The
 * values are the SAU2 map's (sau2-maps/domain_os.10.2.map) and the SAU2
 * image's RFC header.
 */

/* The RFC load address: file byte 0 lands at physical 0x101400 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x00101400;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule.
 * OS_PROC - RFC_LOW_DELTA = 0x102000 = RFC_LOAD + 0xC00, info block +0. */
RFC_LOW_DELTA = 0x00CFE800;

/* The physical split (info block +16 / +20, COLD's immediates): file pages
 * whose PPN would be >= 0x55F go to PPN 0x600 up. */
RFC_SPLIT_LOW = 0x00157C00;
RFC_KERNEL_LO_BYTES = 0x00055C00;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x00E00000;

/* The low region below the kernel (map `D92 D00000 OS_LOW' .. `D93 DA4800
 * OS_LOW_END_': UNWIRED_STACKS, DISK_BUFFERS, NETPOOL, AREA_PAGES), fixed
 * VAs not in the file; OS_$INIT maps them (canned map 1, 0x00E33996).
 * Symbols rather than C constants so the cells naming them are fixups, as
 * in the image. */
OS_LOW = 0x00D00000;
OS_LOW_END = 0x00DA4800;

/* The map's symbols in that region, each the map's VA: the
 * segments of `D96 D00000 UNWIRED_STACKS' (size 50000), `D46 D50000
 * DISK_BUFFERS' (14C00), `D01 D64C00 NETPOOL' (30000) and `D99 D94C00
 * AREA_PAGES' (`D D94C00 VM_TABLES', FC00), back to back up to OS_LOW_END.
 * Nothing in the file; the module segments have no code and no object of
 * the tree defines them (the kernel's code reaches them by these names:
 * dbuf/dbuf.ins.pas DBUF_BLKS, disk/disk.ins.pas DISK_BLK_POOL,
 * network/network.ins.pas NETWORK_$BUFPOOL / NETPOOL_END, area/area.ins.pas
 * AREAS).  tools/gen_layout_ld.py --check-elf compares every such fixed-VA
 * map symbol of the link with the map. */
GLOBAL_B = 0x00D00000;              /* D00000 (D94 GLOBAL_B_, size 0) */
OS_STACK = 0x00D00000;              /* D00000 UNWIRED_STACKS */
OS_STACK_END = 0x00D50000;          /* D50000 */
DBUF_BLKS = 0x00D50000;             /* D50000 DISK_BUFFERS */
RAW_BUF = 0x00D60000;               /* D60000 */
SM_ECC_BUF = 0x00D60400;            /* D60400 */
WIN_ECC_BUF = 0x00D60800;           /* D60800 */
DISK_BLK_POOL = 0x00D60C00;         /* D60C00 */
"NETWORK_$BUFPOOL" = 0x00D64C00;    /* D64C00 NETPOOL */
OS_BUFFERS_END = 0x00D64C00;        /* D64C00 (D97 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x00D94C00;           /* D94C00 AREA_PAGES */
AREAS = 0x00D94C00;                 /* D94C00 */

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
 * NETLOG checks): on the SAU2 three adjacent data segments of the map, each
 * end the next one's start (`D E84E80 PEB_WIRED', `D E854D8 AUDIT',
 * `D E85684 NETLOG'). */
ASSERT("PEB_$WIRED_DATA_START" < "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the PEB, AUDIT and NETLOG wired data ranges, back to back in map order")

/* The VM tables' end (kernel.ld's VM-table checks) below 0xFA0000, where
 * COLD's 68020 fixup pass starts treating a cell as an I/O address
 * (cold/sau2/cold_start.s IO_WINDOW), and below DISP1_MEM = IODEFS 0xFC0000
 * (arch/m68k/sau2/iodefs.s). */
ASSERT(VM_TABLES_END < 0x00FA0000 && VM_TABLES_END <= DISP1_MEM, "the VM tables must end below the 68020 I/O fixup window and IODEFS")
