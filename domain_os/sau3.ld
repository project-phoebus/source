/*
 * sau3.ld - the SAU3 kernel's link (`make TARGET_SAU=sau3', `-T sau3.ld'):
 * the SAU3's constants, then kernel.ld (the output sections and the checks
 * every SAU shares), then the checks on what the SAU3's map lays out its
 * own way.  The values are the SAU3 map's
 * (sr10.2-install/install/ri.apollo.os.v.10.2/sau3/domain_os.map) and the
 * SAU3 image's RFC header, which has the SAU2's load address, kernel
 * offset, kernel VA and split (header words 0x101400, 0x101424, machine
 * type 3, info block 0xC00, 0xE79C00, 0xE00800, 0xFEED2B03, 0x55F,
 * 0x600).
 */

/* The RFC load address: file byte 0 lands at physical 0x101400 (header
 * word 0); COLD's VMA. */
RFC_LOAD = 0x00101400;

/* VA - low address for DUMP and the kernel: the map's `loaded at' rule
 * (`D23 E00400 DUMP loaded at 101C00', `I 4 E00800 WIRED_PROC loaded at
 * 102000'). */
RFC_LOW_DELTA = 0x00CFE800;

/* The physical split (info block +16 / +20 = 0x55F, 0x600, and
 * cold/sau3/cold_start.s's SPLIT_LOW and KERNEL_LO_BYTES). */
RFC_SPLIT_LOW = 0x00157C00;
RFC_KERNEL_LO_BYTES = 0x00055C00;   /* RFC_SPLIT_LOW - (OS_PROC - RFC_LOW_DELTA) */

OS_BEGIN = 0x00E00000;              /* D96 E00000 OS_BEGIN */

/* The low region below the kernel (map `D93 D00000 OS_LOW' .. `D94 DA7800
 * OS_LOW_END_'), fixed VAs not in the file, as on the SAU2, with two more
 * segments between DISK_BUFFERS and NETPOOL: `D74 D64C00 PBU_TABLES'
 * (0xE00 bytes, then a page's gap) and `D89 D65C00 IIC_$CONTROL_PAG', the
 * internet interface controller's lines' control pages (0x2000 bytes). */
OS_LOW = 0x00D00000;                /* D00000 OS_LOW */
OS_LOW_END = 0x00DA7800;            /* DA7800 OS_LOW_END */

/* The map's symbols in that region, each the map's VA: the segments of
 * `D97 D00000 UNWIRED_STACKS' (size 50000), `D50 D50000 DISK_BUFFERS'
 * (14C00), `D74 D64C00 PBU_TABLES' (E00), `D89 D65C00 IIC_$CONTROL_PAG'
 * (2000), `D02 D67C00 NETPOOL' (30000) and `D00 D97C00 AREA_PAGES' (`D
 * D97C00 VM_TABLES', FC00), up to OS_LOW_END.  No object of the tree
 * defines them: pbu/pbu.ins.pas names PBU_$PPN_OWNERS, IIC_$CONTROL_PAG
 * is iic/iic.pas's overlay section (a COMMON symbol, tools/gen_layout_ld.py
 * LOW_OVERLAYS), and the others are the SAU2's (sau2.ld). */
GLOBAL_B = 0x00D00000;              /* D00000 (D95 GLOBAL_B_, size 0) */
OS_STACK = 0x00D00000;              /* D00000 UNWIRED_STACKS */
OS_STACK_END = 0x00D50000;          /* D50000 */
DBUF_BLKS = 0x00D50000;             /* D50000 DISK_BUFFERS */
RAW_BUF = 0x00D60000;               /* D60000 */
SM_ECC_BUF = 0x00D60400;            /* D60400 */
WIN_ECC_BUF = 0x00D60800;           /* D60800 */
DISK_BLK_POOL = 0x00D60C00;         /* D60C00 */
"PBU_$PPN_OWNERS" = 0x00D64C00;     /* D64C00 PBU_TABLES */
"IIC_$CONTROL_PAG" = 0x00D65C00;    /* D89 D65C00 IIC_$CONTROL_PAG, size 2000 */
"NETWORK_$BUFPOOL" = 0x00D67C00;    /* D67C00 NETPOOL */
OS_BUFFERS_END = 0x00D67C00;        /* D67C00 (D98 OS_BUFFERS_END, size 0) */
NETPOOL_END = 0x00D97C00;           /* D97C00 AREA_PAGES */
AREAS = 0x00D97C00;                 /* D97C00 */

/* COLD, DUMP and the kernel in the file (kernel.ld): COLD_START 0x800
 * bytes at file 0, the DUMP page 0x400 at OS_BEGIN + 0x400 (file 0x800),
 * the kernel from OS_BEGIN + 0x800 (file 0xC00). */
RFC_COLD_SIZE = 0x800;
RFC_DUMP_OFFSET = 0x400;
RFC_DUMP_SIZE = 0x400;
RFC_KERNEL_OFFSET = 0x800;

INCLUDE kernel.ld

/* `D28 E2CCF4 NET_PORT_TABLE': DCTE_$NULL, the map's third name of
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

/* The VM tables' run-time windows, as on the SAU2 (the SAU3's map has the
 * SAU2's addresses from OS_PAGE up): right after the COLD-mapped kernel,
 * in the map's order and at its offsets, page aligned, and below the I/O
 * space. */
ASSERT(AREA_$RPMAP_CACHE == OS_PAGE_END && OS_PAGE_END % 0x400 == 0, "the VM-table windows start at OS_PAGE_END, on a page")
ASSERT(AST_PMAPS + 0xFC00 == AREA_$RPMAP_CACHE && AST_PMAPS_END == AREA_$RPMAP_CACHE, "AST_PMAPS_END (AST_PMAPS + 0xFC00) must be AREA_$RPMAP_CACHE, the last COLD-mapped block")
ASSERT(AREA_$RPMAP_CACHE < MST && MST < PIT_PAGES && PIT_PAGES < MSTE_PAGES && MSTE_PAGES < VM_TABLES_END, "the VM-table windows in map order")
ASSERT(MST % 0x400 == 0 && PIT_PAGES % 0x400 == 0 && MSTE_PAGES % 0x400 == 0 && VM_TABLES_END % 0x400 == 0, "the VM-table windows start pages")
ASSERT(MST - AREA_$RPMAP_CACHE == 0xC00 && PIT_PAGES - MST == 0xC00 && MSTE_PAGES - PIT_PAGES == 0x10000, "the VM-table windows keep the map's sizes")
ASSERT(VM_TABLES_END == MSTE_PAGES + 0x166 * 0x400 && IODEFS_GUARD == VM_TABLES_END, "VM_TABLES_END = IODEFS_GUARD = MSTE_PAGES + MST_MSTE_PAGES_MAX pages")

/* The wired data ranges of PEB, LPR, AUDIT and NETLOG (kernel.ld's AUDIT
 * and NETLOG checks): the SAU3 has no PEB wired data (PEB_$WIRED_DATA_START
 * = PEB_$WIRED_DATA_END = LPR_$DATA_START, `D E8417C LPR_'); LPR's range
 * takes in LPR_'s block, LPR_ASM and CBUF's block, whose last byte is
 * LPR_$DATA_END (`D E844D4 CBUF size = 4', E844D7); IIC's block
 * (`D E844D8 IIC') lies between it and AUDIT's (`D E84584 AUDIT'), then
 * NETLOG's (`D E84730 NETLOG'). */
ASSERT("PEB_$WIRED_DATA_START" == "PEB_$WIRED_DATA_END" && "PEB_$WIRED_DATA_END" == "LPR_$DATA_START" && "LPR_$DATA_START" < "LPR_$MOVE_DATA" && "LPR_$MOVE_DATA" < "LPR_$DATA_END" && "LPR_$DATA_END" < "AUDIT_$DATA_START" && "AUDIT_$DATA_START" < "AUDIT_$DATA_END" && "AUDIT_$DATA_END" == "NETLOG_$DATA_START" && "NETLOG_$DATA_START" < "NETLOG_$DATA_END" && "NETLOG_$DATA_END" <= RING_DATA_START, "the PEB, LPR, AUDIT and NETLOG wired data ranges in map order")

/* The IIC driver's wired range (iic/iic.ins.pas): its code from a page
 * (`I18 E85400 IIC_AQWRD_PROC'), then the two data sections up to
 * IIC_$DATA_END, below the ring's data. */
ASSERT("IIC_$PROC_START" % 0x400 == 0 && "IIC_$PROC_START" < "IIC_$PROC_END" && "IIC_$PROC_END" <= "IIC_$DATA_START" && "IIC_$DATA_START" < "IIC_$DATA_END" && "IIC_$DATA_END" <= RING_DATA_START, "the IIC wired range: code from a page, then its data")

/* The VM tables' end (kernel.ld's VM-table checks) below 0xFA0000, where
 * COLD's 68020 fixup pass starts treating a cell as an I/O address
 * (cold/sau3/cold_start.s IO_WINDOW), and below IODEFS 0xFC0000
 * (arch/m68k/sau3/iodefs.s). */
ASSERT(VM_TABLES_END < 0x00FA0000 && VM_TABLES_END <= IODEFS, "the VM tables must end below the 68020 I/O fixup window and IODEFS")
