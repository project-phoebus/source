/*
 * arch/m68k/sau5/iodefs.s - the SAU5 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU5's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the binder's fixup table lists the cells that
 * reference them, so the hand assembly and the Pascal name them and each
 * cell is an R_68K_32 relocation).  It has no bytes.  Every value is the
 * SAU5 map's (sr10.2-install/.../sau5/domain_os.map), in map order:
 *
 *   D       0  TRAP_PAGE          size = 400   (the vectors)
 *   D57  700000  PTT                loaded at 700000, size = 0
 *        CC0000  PROT
 *   D55  F48000  IODEFS_GUARD       loaded at 2576C6, size = 0
 *        F90000  KOLOR_CTL / IODEFS  ...  FFB400  MMU    FFB800  PFT
 *
 * IODEFS_GUARD and VM_TABLES_END are not defined here (layout positions,
 * as on the SAU2).  Against the SAU2's: the I/O space starts at 0xF90000
 * (the SAU2's at 0xFC0000), with the color board (KOLOR_CTL, COLOR_*),
 * the second display (DISP2_MEM, DISP2), the PBU pages, the I/O map
 * (IOMAP), the graphics processor (GPU) and the VME controller (VME_CTL);
 * the vectors at 0x6C..0x74 are PEB_VEC, VME_VEC and VME_ERR_VEC; there is
 * no DMA, DISK or FLOP page.  Names sharing an address are the map's
 * aliases.
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
        .globl  KEYBD_VEC
        .globl  PEB_VEC
        .globl  VME_VEC
        .globl  VME_ERR_VEC
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
        .equ    KEYBD_VEC,          0x00000068  /* autovector level 2 */
        .equ    PEB_VEC,            0x0000006C  /* autovector level 3 */
        .equ    VME_VEC,            0x00000070  /* autovector level 4 */
        .equ    VME_ERR_VEC,        0x00000074  /* autovector level 5 */
        .equ    TIMER_VEC,          0x00000078  /* autovector level 6 */
        .equ    PARITY_VEC,         0x0000007C  /* autovector level 7 */
        .equ    TRAP_VEC,           0x00000080  /* vector 32, TRAP #0 */
        .equ    PROM_$MACHINE_ID,   0x00000100  /* the PROM's machine id cell (prom/prom.ins.pas) */

/* The PTT and PROT windows (`D57 700000 PTT size = 0'). */
        .globl  PTT
        .globl  PROT

        .equ    PTT,        0x00700000  /* page translation table window */
        .equ    PROT,       0x00CC0000  /* the PROT window */

/* IODEFS (`D55 F48000 IODEFS_GUARD', the symbols from F90000). */
        .globl  KOLOR_CTL
        .globl  IODEFS
        .globl  DISP_MEM_2KX1K
        .globl  DISP2_MEM
        .globl  DISP1_MEM
        .globl  PBU_IO
        .globl  PBU
        .globl  PBU_SM_C_PAGE
        .globl  PBU_SM_PAGE
        .globl  PBU_FP_PAGE
        .globl  PBU_MT_PAGE
        .globl  IOMAP
        .globl  COLOR_SUP
        .globl  COLOR_USER
        .globl  COLOR
        .globl  COLOR_CSTORE
        .globl  PEB_$M_CTRL_PAGE
        .globl  FPU_CTL
        .globl  PEB_CTL
        .globl  PEB
        .globl  PEB_$M_DCMD_PAGE
        .globl  FPU_CMD
        .globl  PEB_$M_CS_PAGE
        .globl  FPU_CS
        .globl  PBU_CTL
        .globl  GPU
        .globl  CHK_BUFF
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  PAR_BUFF
        .globl  VME_CTL
        .globl  DISP1_SUP
        .globl  DISP1
        .globl  DISP2
        .globl  RING2
        .globl  DISP1_USER
        .globl  DISP1_CSTORE
        .globl  CALENDAR
        .globl  TAPE
        .globl  WIN
        .globl  TIMR
        .globl  SIO
        .globl  MMU
        .globl  PFT

        .equ    KOLOR_CTL,          0x00F90000
        .equ    IODEFS,             0x00F90000
        .equ    DISP_MEM_2KX1K,     0x00FA0000
        .equ    DISP2_MEM,          0x00FA0000
        .equ    DISP1_MEM,          0x00FC0000
        .equ    PBU_IO,             0x00FE0000
        .equ    PBU,                0x00FE0000
        .equ    PBU_SM_C_PAGE,      0x00FE6800
        .equ    PBU_SM_PAGE,        0x00FE6C00
        .equ    PBU_FP_PAGE,        0x00FE7400
        .equ    PBU_MT_PAGE,        0x00FE7800
        .equ    IOMAP,              0x00FF5000
        .equ    COLOR_SUP,          0x00FF6000
        .equ    COLOR_USER,         0x00FF6400
        .equ    COLOR,              0x00FF6400
        .equ    COLOR_CSTORE,       0x00FF6800
        .equ    PEB_$M_CTRL_PAGE,   0x00FF7000
        .equ    FPU_CTL,            0x00FF7000
        .equ    PEB_CTL,            0x00FF7000
        .equ    PEB,                0x00FF7000
        .equ    PEB_$M_DCMD_PAGE,   0x00FF7400
        .equ    FPU_CMD,            0x00FF7400
        .equ    PEB_$M_CS_PAGE,     0x00FF7800
        .equ    FPU_CS,             0x00FF7800
        .equ    PBU_CTL,            0x00FF7C00
        .equ    GPU,                0x00FF8000
        .equ    CHK_BUFF,           0x00FF8400
        .equ    AST_$COPY_BUFF,     0x00FF8800
        .equ    AST_$ZERO_BUFF,     0x00FF8C00
        .equ    PAR_BUFF,           0x00FF9000
        .equ    VME_CTL,            0x00FF9400
        .equ    DISP1_SUP,          0x00FF9800
        .equ    DISP1,              0x00FF9800
        .equ    DISP2,              0x00FF9800
        .equ    RING2,              0x00FF9C00
        .equ    DISP1_USER,         0x00FFA000
        .equ    DISP1_CSTORE,       0x00FFA400
        .equ    CALENDAR,           0x00FFA800
        .equ    TAPE,               0x00FFA800
        .equ    WIN,                0x00FFA800
        .equ    TIMR,               0x00FFAC00
        .equ    SIO,                0x00FFB000
        .equ    MMU,                0x00FFB400
        .equ    PFT,                0x00FFB800
