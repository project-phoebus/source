/*
 * arch/m68k/sau6/iodefs.s - the SAU6 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU6's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the binder's fixup table lists the cells that
 * reference them, so the hand assembly and the Pascal name them and each
 * cell is an R_68K_32 relocation; the SAU6's image has no fixup table, but
 * the names keep the references traceable).  It has no bytes.  Every
 * value is the SAU6 map's (sr10.2-install/.../sau6/domain_os.map), in map
 * order:
 *
 *   D         0  TRAP_PAGE          size = 400   (the vectors)
 *   D03       0  PROT               loaded at 0, size = 0
 *      77FC0000  PROT
 *   D577F5EC400  IODEFS_GUARD       loaded at 7F5EC400, size = 0
 *      7F5FB800  ETHERNET1 / IODEFS  ...  7FFFB400  MMU
 *
 * IODEFS_GUARD, OS_LOW_END and VM_TABLES_END are not defined here (layout
 * positions, as on the SAU2).  Against the SAU5's (arch/m68k/sau5/iodefs.s):
 * the vectors of the 68881 (FP_BSUN_VEC .. FP_SIG_NAN_VEC, 0xC0..0xD8)
 * and the coprocessor's (COPROC_VEC), the FPA's (FPA_VEC), the devices'
 * vectored interrupts from 0x220 (the ring, the tape and Winchester, the
 * second Winchester board, the graphics processor, the COLOR2 board, the
 * eight of the multibus at 0x2C0) and the VME bus's at 0x3E0..0x3FC;
 * there is no PTT or PFT (the MMU's tables are in memory); the I/O space
 * is the 31-bit space's top: the Ethernet controllers' pages (IODEFS),
 * the NGC boards, the data cache, the second Winchester board's window
 * (TAPE6, WIN6), the graphics processor's control block (KOLOR_CTL), the
 * display memories, the PBU's windows and the I/O pages from 0x7FFF5000.
 * Names sharing an address are the map's aliases.
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
        .globl  COPROC_VEC
        .globl  INV_STACK_VEC
        .globl  SPURIOUS_INT_VEC
        .globl  SIO_VEC
        .globl  FPA_VEC
        .globl  CAL_VEC
        .globl  TIMER_VEC
        .globl  NMI_VEC
        .globl  TRAP_VEC
        .globl  FP_BSUN_VEC
        .globl  FP_INEXACT_VEC
        .globl  FP_DIV_ZERO_VEC
        .globl  FP_UNDFLO_VEC
        .globl  FP_OP_ERR_VEC
        .globl  FP_OVRFLO_VEC
        .globl  FP_SIG_NAN_VEC
        .globl  PROM_$MACHINE_ID
        .globl  RING_VEC
        .globl  TAPE_VEC
        .globl  WIN_VEC
        .globl  WIN6_VEC
        .globl  GPU_DONE_VEC
        .globl  GPU_PAGE_VEC
        .globl  COLOR2_DONE_VEC
        .globl  MULTB_VEC0
        .globl  MULTB_VEC1
        .globl  MULTB_VEC2
        .globl  MULTB_VEC3
        .globl  MULTB_VEC4
        .globl  MULTB_VEC5
        .globl  MULTB_VEC6
        .globl  MULTB_VEC7
        .globl  DISP2_VEC
        .globl  DISP1_VEC
        .globl  ETHERNET_VEC1
        .globl  ETHERNET_VEC2
        .globl  VME_VEC8
        .globl  VME_VEC9
        .globl  VME_VECA
        .globl  VME_VECB
        .globl  VME_VECC
        .globl  VME_VECD
        .globl  VME_VECE
        .globl  VME_VECF

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
        .equ    COPROC_VEC,          0x00000034  /* vector 13, coprocessor protocol violation */
        .equ    INV_STACK_VEC,       0x00000038  /* vector 14, format error */
        .equ    SPURIOUS_INT_VEC,    0x00000060  /* vector 24 */
        .equ    SIO_VEC,             0x00000064  /* vector 25 */
        .equ    FPA_VEC,             0x00000070  /* vector 28 */
        .equ    CAL_VEC,             0x00000074  /* vector 29 */
        .equ    TIMER_VEC,           0x00000078  /* vector 30 */
        .equ    NMI_VEC,             0x0000007C  /* vector 31 */
        .equ    TRAP_VEC,            0x00000080  /* vector 32, TRAP #0 */
        .equ    FP_BSUN_VEC,         0x000000C0  /* vector 48 */
        .equ    FP_INEXACT_VEC,      0x000000C4  /* vector 49 */
        .equ    FP_DIV_ZERO_VEC,     0x000000C8  /* vector 50 */
        .equ    FP_UNDFLO_VEC,       0x000000CC  /* vector 51 */
        .equ    FP_OP_ERR_VEC,       0x000000D0  /* vector 52 */
        .equ    FP_OVRFLO_VEC,       0x000000D4  /* vector 53 */
        .equ    FP_SIG_NAN_VEC,      0x000000D8  /* vector 54 */
        .equ    PROM_$MACHINE_ID,    0x00000100  /* the PROM's machine id cell (prom/prom.ins.pas) */
        .equ    RING_VEC,            0x00000220  /* vector 136 */
        .equ    TAPE_VEC,            0x00000230  /* vector 140 */
        .equ    WIN_VEC,             0x00000230  /* vector 140 */
        .equ    WIN6_VEC,            0x00000240  /* vector 144 */
        .equ    GPU_DONE_VEC,        0x00000280  /* vector 160 */
        .equ    GPU_PAGE_VEC,        0x00000284  /* vector 161 */
        .equ    COLOR2_DONE_VEC,     0x00000290  /* vector 164 */
        .equ    MULTB_VEC0,          0x000002C0  /* vector 176 */
        .equ    MULTB_VEC1,          0x000002C4  /* vector 177 */
        .equ    MULTB_VEC2,          0x000002C8  /* vector 178 */
        .equ    MULTB_VEC3,          0x000002CC  /* vector 179 */
        .equ    MULTB_VEC4,          0x000002D0  /* vector 180 */
        .equ    MULTB_VEC5,          0x000002D4  /* vector 181 */
        .equ    MULTB_VEC6,          0x000002D8  /* vector 182 */
        .equ    MULTB_VEC7,          0x000002DC  /* vector 183 */
        .equ    DISP2_VEC,           0x000003C8  /* vector 242 */
        .equ    DISP1_VEC,           0x000003D0  /* vector 244 */
        .equ    ETHERNET_VEC1,       0x000003D4  /* vector 245 */
        .equ    ETHERNET_VEC2,       0x000003D8  /* vector 246 */
        .equ    VME_VEC8,            0x000003E0  /* vector 248 */
        .equ    VME_VEC9,            0x000003E4  /* vector 249 */
        .equ    VME_VECA,            0x000003E8  /* vector 250 */
        .equ    VME_VECB,            0x000003EC  /* vector 251 */
        .equ    VME_VECC,            0x000003F0  /* vector 252 */
        .equ    VME_VECD,            0x000003F4  /* vector 253 */
        .equ    VME_VECE,            0x000003F8  /* vector 254 */
        .equ    VME_VECF,            0x000003FC  /* vector 255 */

/* PROT (`77FC0000 PROT'): the first VA past the user's space. */
        .globl  PROT

        .equ    PROT,                0x77FC0000

/* IODEFS (the symbols from 7F5FB800). */
        .globl  ETHERNET1
        .globl  IODEFS
        .globl  ETHERNET2
        .globl  NGC_PIXEL
        .globl  NGC3_CTL
        .globl  NGC3_MEM
        .globl  NGC2_CTL
        .globl  NGC2_MEM
        .globl  NGC1_CTL
        .globl  NGC1_MEM
        .globl  DCACHE
        .globl  TAPE6
        .globl  WIN6
        .globl  KOLOR_CTL
        .globl  DISP_MEM_2KX1K
        .globl  DISP2_MEM
        .globl  DISP1_MEM
        .globl  PBU_IO
        .globl  PBU
        .globl  PBU_SM_C_PAGE
        .globl  PBU_SM_PAGE
        .globl  PBU_FP_PAGE
        .globl  PBU_MT_PAGE
        .globl  GPU
        .globl  IOMAP
        .globl  COLOR_SUP
        .globl  COLOR
        .globl  COLOR_CSTORE
        .globl  PBU_CTL
        .globl  CHK_BUFF
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  VME_CTL
        .globl  MEM
        .globl  RING2
        .globl  DISP2
        .globl  DISP1
        .globl  TAPE
        .globl  WIN
        .globl  TIMR
        .globl  CALENDAR
        .globl  SIO
        .globl  MMU

        .equ    ETHERNET1,           0x7F5FB800  /* the first Ethernet controller's page */
        .equ    IODEFS,              0x7F5FB800  /* the start of the I/O space */
        .equ    ETHERNET2,           0x7F5FBC00  /* the second Ethernet controller's page */
        .equ    NGC_PIXEL,           0x7F5FC000
        .equ    NGC3_CTL,            0x7FDFC000
        .equ    NGC3_MEM,            0x7FE0C000
        .equ    NGC2_CTL,            0x7FE8C000
        .equ    NGC2_MEM,            0x7FE9C000
        .equ    NGC1_CTL,            0x7FF1C000
        .equ    NGC1_MEM,            0x7FF2C000
        .equ    DCACHE,              0x7FF6C000
        .equ    TAPE6,               0x7FF70000  /* the second Winchester and cartridge tape board */
        .equ    WIN6,                0x7FF70000
        .equ    KOLOR_CTL,           0x7FF90000  /* the graphics processor's control block */
        .equ    DISP_MEM_2KX1K,      0x7FFA0000
        .equ    DISP2_MEM,           0x7FFA0000  /* the second display's memory */
        .equ    DISP1_MEM,           0x7FFC0000  /* the first display's memory */
        .equ    PBU_IO,              0x7FFE0000
        .equ    PBU,                 0x7FFE0000  /* the PBU's window */
        .equ    PBU_SM_C_PAGE,       0x7FFE6800
        .equ    PBU_SM_PAGE,         0x7FFE6C00
        .equ    PBU_FP_PAGE,         0x7FFE7400
        .equ    PBU_MT_PAGE,         0x7FFE7800
        .equ    GPU,                 0x7FFE8000  /* the graphics processor */
        .equ    IOMAP,               0x7FFF5000  /* the I/O map */
        .equ    COLOR_SUP,           0x7FFF6000  /* the color board */
        .equ    COLOR,               0x7FFF6400
        .equ    COLOR_CSTORE,        0x7FFF6800
        .equ    PBU_CTL,             0x7FFF7C00  /* the PBU controller */
        .equ    CHK_BUFF,            0x7FFF8000
        .equ    AST_$COPY_BUFF,      0x7FFF8800  /* AST's copy window (ast/ast.ins.pas) */
        .equ    AST_$ZERO_BUFF,      0x7FFF8C00  /* AST's zeroing window (ast/ast.ins.pas) */
        .equ    VME_CTL,             0x7FFF9400  /* the VME bus adapter */
        .equ    MEM,                 0x7FFF9800  /* the memory boards' registers */
        .equ    RING2,               0x7FFF9C00  /* the ring controller */
        .equ    DISP2,               0x7FFFA000  /* the second display's registers */
        .equ    DISP1,               0x7FFFA400  /* the first display's registers */
        .equ    TAPE,                0x7FFFA800
        .equ    WIN,                 0x7FFFA800  /* the Winchester controller (the same page) */
        .equ    TIMR,                0x7FFFAC00  /* the timer */
        .equ    CALENDAR,            0x7FFFAD00  /* the calendar (in the timer's page) */
        .equ    SIO,                 0x7FFFB000  /* serial I/O */
        .equ    MMU,                 0x7FFFB400  /* the MMU's registers */
