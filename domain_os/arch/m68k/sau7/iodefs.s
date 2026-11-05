/*
 * arch/m68k/sau7/iodefs.s - the SAU7 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU7's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the hand assembly and the Pascal name them, so
 * each cell that references one is a relocation to the value below).  It
 * has no bytes.  Every value is the SAU7 map's
 * (sr10.2-install/.../sau7/domain_os.map), in map order:
 *
 *   D52 3C400800  TRAP_PAGE          loaded at 3C400800, size = 400
 *       3BFC0000  PROT
 *   D67 3DFEF400  IODEFS_GUARD       loaded at 2BF1C00, size = 0
 *       3FF5E000  CACHE_TAGS / IODEFS  ...  3FFFB400  MMU
 *
 * Against the SAU8's (arch/m68k/sau8/iodefs.s): the trap page, and with
 * it the PROM's entry cells from +0x100 (PROM_$MACHINE_ID), is the
 * kernel's page at OS_BEGIN + 0x800 (`trap_page_high',
 * base/config.ins.pas): COLD maps it, the link leaves it to them
 * (kernel.ld's .trap_page, NOBITS), and its symbols are the map's fixed
 * VAs here.  Its vectors are the SAU8's: the 68881's at 0xC0..0xD8, the
 * level 7 interrupt's (NMI_VEC) at 0x7C, the AT-bus interrupt
 * controllers' levels from 0x280 (TIMER_VEC = PBU_VEC0 .. WIN_VEC2).
 * There is no PTT; the I/O space is the 32-bit space's top: the physical
 * cache's tags (CACHE_TAGS, IODEFS), the display memories from
 * 0x3FF60000, the PROM at 0x3FFA0000, the system control page (SC_PAGE)
 * and the I/O pages from 0x3FFF0800: the displays, the tape and SCSI,
 * DMA, the second Winchester, the 802.5 and Apollo rings, the Ethernet,
 * the AT-bus interrupt controllers (PIC1, PIC2, at the PBU controller's
 * address), the floppy, Winchester, timer, calendar, SIO and MMU
 * registers.  Names sharing an address are the map's aliases.
 * IODEFS_GUARD and VM_TABLES_END are not defined here (layout positions,
 * as on the SAU2).
 */

/* The trap page (`D 3C400800 TRAP_PAGE size = 400'). */
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
        .globl  FLINE_TRAP_VEC
        .globl  COPROC_VEC
        .globl  INV_STACK_VEC
        .globl  SPURIOUS_INT_VEC
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
        .globl  TIMER_VEC
        .globl  PBU_VEC0
        .globl  SIO_VEC
        .globl  RING_VEC1
        .globl  RING_VEC
        .globl  TAPE_VEC
        .globl  FLP_VEC
        .globl  SIO_VEC2
        .globl  PBU_VEC1
        .globl  CAL_VEC
        .globl  ETHERNET_VEC2
        .globl  ETHERNET_VEC1
        .globl  RING_8025_VEC2
        .globl  RING_8025_VEC1
        .globl  WIN_VEC
        .globl  WIN_VEC2

        .equ    TRAP_PAGE,           0x3C400800  /* the exception vector page */
        .equ    BUS_ERROR_VEC,       0x3C400808  /* vector 2 */
        .equ    ADDRESS_ERROR_VEC,   0x3C40080C  /* vector 3 */
        .equ    ILLEGAL_INST_VEC,    0x3C400810  /* vector 4 */
        .equ    ZERO_DIVIDE_VEC,     0x3C400814  /* vector 5 */
        .equ    CHK_INST_VEC,        0x3C400818  /* vector 6 */
        .equ    TRAPV_INST_VEC,      0x3C40081C  /* vector 7 */
        .equ    PRIV_VIOL_VEC,       0x3C400820  /* vector 8 */
        .equ    TRACE_VEC,           0x3C400824  /* vector 9 */
        .equ    UNIMP_VEC,           0x3C400828  /* vector 10, line 1010 */
        .equ    FLINE_TRAP_VEC,      0x3C40082C  /* vector 11 */
        .equ    COPROC_VEC,          0x3C400834  /* vector 13, coprocessor protocol violation */
        .equ    INV_STACK_VEC,       0x3C400838  /* vector 14, format error */
        .equ    SPURIOUS_INT_VEC,    0x3C400860  /* vector 24 */
        .equ    NMI_VEC,             0x3C40087C  /* vector 31, level 7 */
        .equ    TRAP_VEC,            0x3C400880  /* vector 32, TRAP #0 */
        .equ    FP_BSUN_VEC,         0x3C4008C0  /* vector 48 */
        .equ    FP_INEXACT_VEC,      0x3C4008C4  /* vector 49 */
        .equ    FP_DIV_ZERO_VEC,     0x3C4008C8  /* vector 50 */
        .equ    FP_UNDFLO_VEC,       0x3C4008CC  /* vector 51 */
        .equ    FP_OP_ERR_VEC,       0x3C4008D0  /* vector 52 */
        .equ    FP_OVRFLO_VEC,       0x3C4008D4  /* vector 53 */
        .equ    FP_SIG_NAN_VEC,      0x3C4008D8  /* vector 54 */
        .equ    PROM_$MACHINE_ID,    0x3C400900  /* the PROM's machine id cell (prom/prom.ins.pas) */
        .equ    TIMER_VEC,           0x3C400A80  /* vector 160 */
        .equ    PBU_VEC0,            0x3C400A80  /* vector 160 */
        .equ    SIO_VEC,             0x3C400A84  /* vector 161 */
        .equ    RING_VEC1,           0x3C400A8C  /* vector 163 */
        .equ    RING_VEC,            0x3C400A8C  /* vector 163 */
        .equ    TAPE_VEC,            0x3C400A94  /* vector 165 */
        .equ    FLP_VEC,             0x3C400A98  /* vector 166 */
        .equ    SIO_VEC2,            0x3C400AA0  /* vector 168 */
        .equ    PBU_VEC1,            0x3C400AA0  /* vector 168 */
        .equ    CAL_VEC,             0x3C400AA0  /* vector 168 */
        .equ    ETHERNET_VEC2,       0x3C400AA4  /* vector 169 */
        .equ    ETHERNET_VEC1,       0x3C400AA8  /* vector 170 */
        .equ    RING_8025_VEC2,      0x3C400AAC  /* vector 171 */
        .equ    RING_8025_VEC1,      0x3C400AB0  /* vector 172 */
        .equ    WIN_VEC,             0x3C400AB8  /* vector 174 */
        .equ    WIN_VEC2,            0x3C400ABC  /* vector 175 */

/* PROT (`3BFC0000 PROT'): the first VA past the user's space. */
        .globl  PROT

        .equ    PROT,                0x3BFC0000

/* IODEFS (the symbols from 3FF5E000). */
        .globl  CACHE_TAGS
        .globl  IODEFS
        .globl  CACHE
        .globl  DISP2_MEM
        .globl  DISP1_MEM
        .globl  DISP_ALT_MEM
        .globl  PROM
        .globl  SC_PAGE
        .globl  DISP_ALT2
        .globl  DISP_ALT1
        .globl  TAPE
        .globl  SCSI
        .globl  DMA
        .globl  WIN2
        .globl  RING_8025_2
        .globl  RING_8025_1
        .globl  CHK_BUFF
        .globl  MAST_ENBL_REG
        .globl  IOMAP
        .globl  RING1
        .globl  RING1A
        .globl  ETHERNET1
        .globl  ETHERNET2
        .globl  PAR_BUFF
        .globl  RING2
        .globl  RING2A
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  PBU_CTL
        .globl  PIC1
        .globl  PIC2
        .globl  MMU_$PARITY_PPN
        .globl  COLOR_SUP
        .globl  COLOR
        .globl  DISP2
        .globl  DISP1
        .globl  DISP_MATROX_FIFO
        .globl  DISP_MATROX_CTL1
        .globl  DISP_MATROX_CTL2
        .globl  FLOP
        .globl  WIN
        .globl  TIMR
        .globl  CALENDAR
        .globl  SIO
        .globl  MMU

        .equ    CACHE_TAGS,          0x3FF5E000
        .equ    IODEFS,              0x3FF5E000
        .equ    CACHE,               0x3FF5E000
        .equ    DISP2_MEM,           0x3FF60000
        .equ    DISP1_MEM,           0x3FF60000
        .equ    DISP_ALT_MEM,        0x3FF80000
        .equ    PROM,                0x3FFA0000
        .equ    SC_PAGE,             0x3FFB0000
        .equ    DISP_ALT2,           0x3FFF0800
        .equ    DISP_ALT1,           0x3FFF0C00
        .equ    TAPE,                0x3FFF1000
        .equ    SCSI,                0x3FFF1000
        .equ    DMA,                 0x3FFF1400
        .equ    WIN2,                0x3FFF1800
        .equ    RING_8025_2,         0x3FFF1C00
        .equ    RING_8025_1,         0x3FFF2400
        .equ    CHK_BUFF,            0x3FFF2C00
        .equ    MAST_ENBL_REG,       0x3FFF3000
        .equ    IOMAP,               0x3FFF3400
        .equ    RING1,               0x3FFF3C00
        .equ    RING1A,              0x3FFF4C00
        .equ    ETHERNET1,           0x3FFF5C00
        .equ    ETHERNET2,           0x3FFF6000
        .equ    PAR_BUFF,            0x3FFF6400
        .equ    RING2,               0x3FFF6800
        .equ    RING2A,              0x3FFF7800
        .equ    AST_$COPY_BUFF,      0x3FFF8800
        .equ    AST_$ZERO_BUFF,      0x3FFF8C00
        .equ    PBU_CTL,             0x3FFF9000
        .equ    PIC1,                0x3FFF9000
        .equ    PIC2,                0x3FFF9100
        .equ    MMU_$PARITY_PPN,     0x3FFF9300
        .equ    COLOR_SUP,           0x3FFF9400
        .equ    COLOR,               0x3FFF9400
        .equ    DISP2,               0x3FFF9400
        .equ    DISP1,               0x3FFF9400
        .equ    DISP_MATROX_FIFO,    0x3FFF9800
        .equ    DISP_MATROX_CTL1,    0x3FFF9C00
        .equ    DISP_MATROX_CTL2,    0x3FFFA000
        .equ    FLOP,                0x3FFFA400
        .equ    WIN,                 0x3FFFA800
        .equ    TIMR,                0x3FFFAC00
        .equ    CALENDAR,            0x3FFFAD00
        .equ    SIO,                 0x3FFFB000
        .equ    MMU,                 0x3FFFB400

/* The node id PROM: PIC1's page + 0x200, which RING_$GET_ID probes
 * (ring/ring_driver.ins.pas node_id_prom).  No map symbol names it; the
 * image's RING_$GET_ID has it as an immediate (0x3C437F48), so it is an
 * absolute symbol here. */
        .globl  NODE_ID_PROM

        .equ    NODE_ID_PROM,        0x3FFF9200
