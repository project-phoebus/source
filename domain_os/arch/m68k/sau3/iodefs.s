/*
 * arch/m68k/sau3/iodefs.s - the SAU3 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU3's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the binder's fixup table lists the cells that
 * reference them, so the hand assembly and the Pascal name them and each
 * cell is an R_68K_32 relocation).  It has no bytes.  Every value is the
 * SAU3 map's (sr10.2-install/.../sau3/domain_os.map), in map order:
 *
 *   D       0  TRAP_PAGE          size = 400   (the vectors)
 *   D58  700000  PTT                loaded at 700000, size = 0
 *        CC0000  PROT
 *   D56  F4FC00  IODEFS_GUARD       loaded at 25E1C2, size = 0
 *        FC0000  IODEFS  ...  FFB400  MMU    FFB800  PFT
 *
 * IODEFS_GUARD and VM_TABLES_END are not defined here (layout positions,
 * as on the SAU2).  Against the SAU2's: there is no display (no DISP1_MEM,
 * DISP1), no floppy or disk page; the PBU pages (PBU_IO and its device
 * windows, with the internet interface controller's PBU_IIC_PAGE), the
 * I/O map (IOMAP), the PBU controller (PBU_CTL) and the line printer
 * (LPR) are added; the calendar has a page of its own (0xFFA400), apart
 * from the Winchester's; the vectors at 0x6C..0x74 are RING_VEC, PBU_VEC
 * and LPR_VEC, and there is no KEYBD_VEC.  Names sharing an address are
 * the map's aliases.
 */

/* The trap page (`D 0 TRAP_PAGE size = 400'). */
        .globl  TRAP_PAGE
        .globl  BUS_ERROR_VEC
        .globl  ADDRESS_ERROR_VEC
        .globl  ILLEGAL_INST_VEC
        .globl  ZERO_DIVIDE_VEC
        .globl  CHK_INST_VEC
        .globl  TRAPV_INST_VEC
        .globl  PRIV_VIOL_VEC
        .globl  TRACE_VEC
        .globl  UNIMP_VEC
        .globl  INV_STACK_VEC
        .globl  SPURIOUS_INT_VEC
        .globl  SIO_VEC
        .globl  RING_VEC
        .globl  PBU_VEC
        .globl  LPR_VEC
        .globl  TIMER_VEC
        .globl  PARITY_VEC
        .globl  TRAP_VEC
        .globl  PROM_$MACHINE_ID

        .equ    TRAP_PAGE,          0x00000000  /* the exception vector page (VBR) */
        .equ    BUS_ERROR_VEC,      0x00000008  /* vector 2 */
        .equ    ADDRESS_ERROR_VEC,  0x0000000C  /* vector 3 */
        .equ    ILLEGAL_INST_VEC,   0x00000010  /* vector 4 */
        .equ    ZERO_DIVIDE_VEC,    0x00000014  /* vector 5 */
        .equ    CHK_INST_VEC,       0x00000018  /* vector 6 */
        .equ    TRAPV_INST_VEC,     0x0000001C  /* vector 7 */
        .equ    PRIV_VIOL_VEC,      0x00000020  /* vector 8 */
        .equ    TRACE_VEC,          0x00000024  /* vector 9 */
        .equ    UNIMP_VEC,          0x00000028  /* vector 10, line 1010 */
        .equ    INV_STACK_VEC,      0x00000038  /* vector 14 (format error) */
        .equ    SPURIOUS_INT_VEC,   0x00000060  /* vector 24 */
        .equ    SIO_VEC,            0x00000064  /* autovector level 1 */
        .equ    RING_VEC,           0x0000006C  /* autovector level 3 */
        .equ    PBU_VEC,            0x00000070  /* autovector level 4 */
        .equ    LPR_VEC,            0x00000074  /* autovector level 5 */
        .equ    TIMER_VEC,          0x00000078  /* autovector level 6 */
        .equ    PARITY_VEC,         0x0000007C  /* autovector level 7 */
        .equ    TRAP_VEC,           0x00000080  /* vector 32, TRAP #0 */
        .equ    PROM_$MACHINE_ID,   0x00000100  /* the PROM's machine id cell (prom/prom.ins.pas) */

/* The PTT and PROT windows (`D58 700000 PTT size = 0'). */
        .globl  PTT
        .globl  PROT

        .equ    PTT,        0x00700000  /* page translation table window */
        .equ    PROT,       0x00CC0000  /* the PROT window */

/* IODEFS (`D56 F4FC00 IODEFS_GUARD', the symbols from FC0000). */
        .globl  IODEFS
        .globl  PBU_IO
        .globl  PBU
        .globl  PBU_IIC_PAGE
        .globl  PBU_SM_C_PAGE
        .globl  PBU_SM_PAGE
        .globl  PBU_FP_PAGE
        .globl  PBU_MT_PAGE
        .globl  IOMAP
        .globl  PEB_$M_CTRL_PAGE
        .globl  FPU_CTL
        .globl  PEB_CTL
        .globl  PEB
        .globl  PEB_$M_DCMD_PAGE
        .globl  FPU_CMD
        .globl  PEB_$M_CS_PAGE
        .globl  FPU_CS
        .globl  PBU_CTL
        .globl  LPR
        .globl  CHK_BUFF
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  PAR_BUFF
        .globl  RING2
        .globl  DMA
        .globl  CALENDAR
        .globl  TIMR
        .globl  SIO
        .globl  MMU
        .globl  PFT

        .equ    IODEFS,             0x00FC0000  /* the start of the I/O space */
        .equ    PBU_IO,             0x00FE0000  /* the PBU's device pages */
        .equ    PBU,                0x00FE0000
        .equ    PBU_IIC_PAGE,       0x00FE6400  /* the internet interface controller */
        .equ    PBU_SM_C_PAGE,      0x00FE6800
        .equ    PBU_SM_PAGE,        0x00FE6C00
        .equ    PBU_FP_PAGE,        0x00FE7400
        .equ    PBU_MT_PAGE,        0x00FE7800
        .equ    IOMAP,              0x00FF5000  /* the PBU's I/O map */
        .equ    PEB_$M_CTRL_PAGE,   0x00FF7000  /* the PEB (FPU) control page */
        .equ    FPU_CTL,            0x00FF7000
        .equ    PEB_CTL,            0x00FF7000
        .equ    PEB,                0x00FF7000
        .equ    PEB_$M_DCMD_PAGE,   0x00FF7400  /* the PEB command page */
        .equ    FPU_CMD,            0x00FF7400
        .equ    PEB_$M_CS_PAGE,     0x00FF7800  /* the PEB control store page */
        .equ    FPU_CS,             0x00FF7800
        .equ    PBU_CTL,            0x00FF7C00  /* the PBU controller */
        .equ    LPR,                0x00FF8000  /* the line printer */
        .equ    CHK_BUFF,           0x00FF8400
        .equ    AST_$COPY_BUFF,     0x00FF8800  /* AST's copy window (ast/ast.ins.pas) */
        .equ    AST_$ZERO_BUFF,     0x00FF8C00  /* AST's zeroing window (ast/ast.ins.pas) */
        .equ    PAR_BUFF,           0x00FF9000  /* the parity scratch page (parity/parity.ins.pas) */
        .equ    RING2,              0x00FF9C00  /* token ring controller */
        .equ    DMA,                0x00FFA000  /* DMA controller */
        .equ    CALENDAR,           0x00FFA400  /* calendar */
        .equ    TIMR,               0x00FFAC00  /* timer */
        .equ    SIO,                0x00FFB000  /* serial I/O */
        .equ    MMU,                0x00FFB400  /* MMU registers */
        .equ    PFT,                0x00FFB800  /* page frame table */
