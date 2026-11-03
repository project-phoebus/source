/*
 * arch/m68k/sau4/iodefs.s - the SAU4 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU4's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the binder's fixup table lists the cells that
 * reference them, so the hand assembly and the Pascal name them and each
 * cell is an R_68K_32 relocation).  It has no bytes.  Every value is the
 * SAU4 map's (sr10.2-install/.../sau4/domain_os.map), in map order:
 *
 *   D40       0  TRAP_PAGE          loaded at 0, size = 400   (the vectors)
 *   D01       0  PROT               loaded at 0, size = 0
 *       F7C0000  PROT
 *   D55 FEFC400  IODEFS_GUARD       loaded at FEFC400, size = 0
 *       FFA0000  DISP2_MEM / IODEFS  ...  FFFB400  MMU    FFFF800  IOMAP
 *
 * IODEFS_GUARD and VM_TABLES_END are not defined here (layout positions,
 * as on the SAU2).  Against the SAU2's: the DNx60's own vectors - its
 * MMU's faults at 0x200..0x20C (REGF_VEC, SEGF_VEC, PAGF_VEC,
 * ACC_VIOL_VEC) and the FP ASID exception (FP_VEC 0x210), the devices'
 * vectored interrupts from 0x240 (the ring and the Winchester share one),
 * the PBU's eight at 0x2C0, the memory's ECC vectors (ECCC_VEC 0x3C0,
 * ECCU_VEC 0x3FC), the timer's at 0x3EC - and the five floating-point
 * exceptions' at 0xC4..0xD4; there is no PTT (the region registers map
 * the pages); the I/O space is the 28-bit space's top, the display
 * memories from 0xFFA0000 (IODEFS), the PBU's windows from 0xFFE0000 and
 * the I/O pages from 0xFFF6000: the color board, MEM's ECC controllers,
 * the displays, the rings and the Winchester, the floppy, the timer and
 * calendar page, SIO, the MMU registers and the I/O map.  Names sharing
 * an address are the map's aliases.
 */

/* The trap page (`D40 0 TRAP_PAGE size = 400'). */
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
        .globl  TRAP_VEC
        .globl  FP_INEXACT_VEC
        .globl  FP_DIV_ZERO_VEC
        .globl  FP_UNDFLO_VEC
        .globl  FP_OP_ERR_VEC
        .globl  FP_OVRFLO_VEC
        .globl  PROM_$MACHINE_ID
        .globl  REGF_VEC
        .globl  SEGF_VEC
        .globl  PAGF_VEC
        .globl  ACC_VIOL_VEC
        .globl  FP_VEC
        .globl  RING_VEC
        .globl  WIN_VEC
        .globl  PBU_VEC0
        .globl  PBU_VEC1
        .globl  PBU_VEC2
        .globl  PBU_VEC3
        .globl  PBU_VEC4
        .globl  PBU_VEC5
        .globl  PBU_VEC6
        .globl  PBU_VEC7
        .globl  OLD_WIN_VEC
        .globl  COLOR_VEC
        .globl  ECCC_VEC
        .globl  DISP2_VEC
        .globl  FLP_VEC
        .globl  DISP1_VEC
        .globl  SIO_VEC
        .globl  TIMER_VEC
        .globl  ECCU_VEC

        .equ    TRAP_PAGE,           0x00000000  /* the exception vector page */
        .equ    BUS_ERROR_VEC,       0x00000008  /* vector 2 */
        .equ    ADDRESS_ERROR_VEC,   0x0000000C  /* vector 3 */
        .equ    ILLEGAL_INST_VEC,    0x00000010  /* vector 4 */
        .equ    ZERO_DIVIDE_VEC,     0x00000014  /* vector 5 */
        .equ    CHK_INST_VEC,        0x00000018  /* vector 6 */
        .equ    TRAPV_INST_VEC,      0x0000001C  /* vector 7 */
        .equ    PRIV_VIOL_VEC,       0x00000020  /* vector 8 */
        .equ    TRACE_VEC,           0x00000024  /* vector 9 */
        .equ    UNIMP_VEC,           0x00000028  /* vector 10, line 1010 */
        .equ    INV_STACK_VEC,       0x00000038  /* vector 14 (format error) */
        .equ    SPURIOUS_INT_VEC,    0x00000060  /* vector 24 */
        .equ    TRAP_VEC,            0x00000080  /* vector 32, TRAP #0 */
        .equ    FP_INEXACT_VEC,      0x000000C4  /* vector 49 */
        .equ    FP_DIV_ZERO_VEC,     0x000000C8  /* vector 50 */
        .equ    FP_UNDFLO_VEC,       0x000000CC  /* vector 51 */
        .equ    FP_OP_ERR_VEC,       0x000000D0  /* vector 52 */
        .equ    FP_OVRFLO_VEC,       0x000000D4  /* vector 53 */
        .equ    PROM_$MACHINE_ID,    0x00000100  /* the PROM's machine id cell (prom/prom.ins.pas) */
        .equ    REGF_VEC,            0x00000200  /* vector 128, region fault */
        .equ    SEGF_VEC,            0x00000204  /* vector 129, segment fault */
        .equ    PAGF_VEC,            0x00000208  /* vector 130, page fault */
        .equ    ACC_VIOL_VEC,        0x0000020C  /* vector 131, access violation */
        .equ    FP_VEC,              0x00000210  /* vector 132, FP ASID exception */
        .equ    RING_VEC,            0x00000240  /* vector 144 */
        .equ    WIN_VEC,             0x00000240
        .equ    PBU_VEC0,            0x000002C0  /* vectors 176..183 */
        .equ    PBU_VEC1,            0x000002C4
        .equ    PBU_VEC2,            0x000002C8
        .equ    PBU_VEC3,            0x000002CC
        .equ    PBU_VEC4,            0x000002D0
        .equ    PBU_VEC5,            0x000002D4
        .equ    PBU_VEC6,            0x000002D8
        .equ    PBU_VEC7,            0x000002DC
        .equ    OLD_WIN_VEC,         0x00000310  /* vector 196 */
        .equ    COLOR_VEC,           0x00000338  /* vector 206 */
        .equ    ECCC_VEC,            0x000003C0  /* vector 240, corrected memory error */
        .equ    DISP2_VEC,           0x000003C8  /* vector 242 */
        .equ    FLP_VEC,             0x000003CC  /* vector 243 */
        .equ    DISP1_VEC,           0x000003D0  /* vector 244 */
        .equ    SIO_VEC,             0x000003E4  /* vector 249 */
        .equ    TIMER_VEC,           0x000003EC  /* vector 251 */
        .equ    ECCU_VEC,            0x000003FC  /* vector 255, uncorrectable memory error */

/* PROT (`F7C0000 PROT'): the first VA past the user's space. */
        .globl  PROT

        .equ    PROT,                0x0F7C0000

/* IODEFS (the symbols from FFA0000). */
        .globl  DISP2_MEM
        .globl  IODEFS
        .globl  DISP1_MEM
        .globl  PBU_MEM
        .globl  PBU
        .globl  PBU_IO
        .globl  PBU_SM_C_PAGE
        .globl  PBU_SM_PAGE
        .globl  PBU_FP_PAGE
        .globl  PBU_MT_PAGE
        .globl  PBU_CTL
        .globl  COLOR_SUP
        .globl  COLOR
        .globl  COLOR_CSTORE
        .globl  CHK_BUFF
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  MEM
        .globl  DISP2
        .globl  DISP1
        .globl  RING2
        .globl  WIN
        .globl  RING1
        .globl  FLOP
        .globl  CALENDAR
        .globl  TIMR
        .globl  SIO
        .globl  MMU
        .globl  IOMAP

        .equ    DISP2_MEM,           0x0FFA0000  /* the second display's memory */
        .equ    IODEFS,              0x0FFA0000  /* the start of the I/O space */
        .equ    DISP1_MEM,           0x0FFC0000  /* the first display's memory */
        .equ    PBU_MEM,             0x0FFE0000  /* the PBU's memory window */
        .equ    PBU,                 0x0FFE0000
        .equ    PBU_IO,              0x0FFE8000  /* the PBU's device pages */
        .equ    PBU_SM_C_PAGE,       0x0FFEE800
        .equ    PBU_SM_PAGE,         0x0FFEEC00
        .equ    PBU_FP_PAGE,         0x0FFEF400
        .equ    PBU_MT_PAGE,         0x0FFEF800
        .equ    PBU_CTL,             0x0FFEFC00  /* the PBU controller */
        .equ    COLOR_SUP,           0x0FFF6000  /* the color board */
        .equ    COLOR,               0x0FFF6400
        .equ    COLOR_CSTORE,        0x0FFF6800
        .equ    CHK_BUFF,            0x0FFF8400
        .equ    AST_$COPY_BUFF,      0x0FFF8800  /* AST's copy window (ast/ast.ins.pas) */
        .equ    AST_$ZERO_BUFF,      0x0FFF8C00  /* AST's zeroing window (ast/ast.ins.pas) */
        .equ    MEM,                 0x0FFF9000  /* the memory boards' ECC controllers */
        .equ    DISP2,               0x0FFF9400  /* the second display's registers */
        .equ    DISP1,               0x0FFF9800  /* the first display's registers */
        .equ    RING2,               0x0FFF9C00  /* the ring controller */
        .equ    WIN,                 0x0FFF9C00  /* the Winchester controller (the same page) */
        .equ    RING1,               0x0FFFA000
        .equ    FLOP,                0x0FFFA800  /* the floppy controller */
        .equ    CALENDAR,            0x0FFFAC00  /* the calendar (the timer's page) */
        .equ    TIMR,                0x0FFFAC00  /* the timer */
        .equ    SIO,                 0x0FFFB000  /* serial I/O */
        .equ    MMU,                 0x0FFFB400  /* the MMU's registers */
        .equ    IOMAP,               0x0FFFF800  /* the I/O map */
