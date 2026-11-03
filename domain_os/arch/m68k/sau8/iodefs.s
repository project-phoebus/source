/*
 * arch/m68k/sau8/iodefs.s - the SAU8 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU8's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the binder's fixup table lists the cells that
 * reference them, so the hand assembly and the Pascal name them and each
 * cell is an R_68K_32 relocation).  It has no bytes.  Every value is the
 * SAU8 map's (sr10.2-install/.../sau8/domain_os.map), in map order:
 *
 *   D       0  TRAP_PAGE          size = 400   (the vectors, MMB)
 *   D07       0  PROT               loaded at 0, size = 0
 *       39C0000  PROT
 *   D62 3F2E000  IODEFS_GUARD       loaded at 43EA0E, size = 0
 *       3FA0000  DISP1_MEM / IODEFS  ...  3FFB400  MMU
 *
 * IODEFS_GUARD and VM_TABLES_END are not defined here (layout positions,
 * as on the SAU2).  Against the SAU2's: the trap page is at 0 as there,
 * with the DN3000's vectors from 0x280 (the AT-bus interrupt controllers'
 * levels: TIMER_VEC = PBU_VEC0, SIO_VEC, RING_VEC1, TAPE_VEC, FLP_VEC,
 * PBU_VEC1 = CAL_VEC, the Ethernet's, the 802.5 ring's, WIN_VEC) and the
 * 68881's at 0xC0..0xD8; there is no PTT (the MC68851 maps the pages);
 * the I/O space is the 26-bit space's top, the display memory from
 * 0x3FA0000 (IODEFS) and the I/O pages from 0x3FF2000: the displays, the
 * rings, the Ethernet, the AT-bus interrupt controllers (PIC1, PIC2,
 * at the PBU controller's address), the tape, DMA, floppy, Winchester,
 * timer, calendar, SIO and MMU registers.  Names sharing an address are
 * the map's aliases.
 */

/* The trap page (`D 0 TRAP_PAGE size = 400'), and MMB, the map's last
 * symbol of that segment's listing (0x10000). */
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
        .globl  PARITY_VEC
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
        .globl  PBU_VEC1
        .globl  CAL_VEC
        .globl  ETHERNET_VEC2
        .globl  ETHERNET_VEC1
        .globl  RING_8025_VEC2
        .globl  RING_8025_VEC1
        .globl  WIN_VEC
        .globl  MMB

        .equ    TRAP_PAGE,           0x00000000
        .equ    BUS_ERROR_VEC,       0x00000008
        .equ    ADDRESS_ERROR_VEC,   0x0000000C
        .equ    ILLEGAL_INST_VEC,    0x00000010
        .equ    ZERO_DIVIDE_VEC,     0x00000014
        .equ    CHK_INST_VEC,        0x00000018
        .equ    TRAPV_INST_VEC,      0x0000001C
        .equ    PRIV_VIOL_VEC,       0x00000020
        .equ    TRACE_VEC,           0x00000024
        .equ    UNIMP_VEC,           0x00000028
        .equ    FLINE_TRAP_VEC,      0x0000002C
        .equ    COPROC_VEC,          0x00000034
        .equ    INV_STACK_VEC,       0x00000038
        .equ    SPURIOUS_INT_VEC,    0x00000060
        .equ    PARITY_VEC,          0x0000007C
        .equ    TRAP_VEC,            0x00000080
        .equ    FP_BSUN_VEC,         0x000000C0
        .equ    FP_INEXACT_VEC,      0x000000C4
        .equ    FP_DIV_ZERO_VEC,     0x000000C8
        .equ    FP_UNDFLO_VEC,       0x000000CC
        .equ    FP_OP_ERR_VEC,       0x000000D0
        .equ    FP_OVRFLO_VEC,       0x000000D4
        .equ    FP_SIG_NAN_VEC,      0x000000D8
        .equ    PROM_$MACHINE_ID,    0x00000100
        .equ    TIMER_VEC,           0x00000280
        .equ    PBU_VEC0,            0x00000280
        .equ    SIO_VEC,             0x00000284
        .equ    RING_VEC1,           0x0000028C
        .equ    RING_VEC,            0x0000028C
        .equ    TAPE_VEC,            0x00000294
        .equ    FLP_VEC,             0x00000298
        .equ    PBU_VEC1,            0x000002A0
        .equ    CAL_VEC,             0x000002A0
        .equ    ETHERNET_VEC2,       0x000002A4
        .equ    ETHERNET_VEC1,       0x000002A8
        .equ    RING_8025_VEC2,      0x000002AC
        .equ    RING_8025_VEC1,      0x000002B0
        .equ    WIN_VEC,             0x000002B8
        .equ    MMB,                 0x00010000

/* PROT (`39C0000 PROT'): the first VA past the user's space. */
        .globl  PROT

        .equ    PROT,               0x039C0000

/* IODEFS (the symbols from 3FA0000). */
        .globl  DISP1_MEM
        .globl  DISP2_MEM
        .globl  IODEFS
        .globl  DISP_ALT_MEM
        .globl  DISP_ALT2
        .globl  DISP_ALT1
        .globl  RING_8025_2
        .globl  RING_8025_1
        .globl  CHK_BUFF
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
        .globl  COLOR_SUP
        .globl  COLOR
        .globl  DISP1
        .globl  DISP2
        .globl  TAPE
        .globl  DMA
        .globl  MMU_$PARITY_PPN
        .globl  FLOP
        .globl  WIN
        .globl  TIMR
        .globl  CALENDAR
        .globl  SIO
        .globl  MMU

        .equ    DISP1_MEM,           0x03FA0000
        .equ    DISP2_MEM,           0x03FA0000
        .equ    IODEFS,              0x03FA0000
        .equ    DISP_ALT_MEM,        0x03FC0000
        .equ    DISP_ALT2,           0x03FF2000
        .equ    DISP_ALT1,           0x03FF2400
        .equ    RING_8025_2,         0x03FF2800
        .equ    RING_8025_1,         0x03FF3000
        .equ    CHK_BUFF,            0x03FF3800
        .equ    RING1,               0x03FF3C00
        .equ    RING1A,              0x03FF4C00
        .equ    ETHERNET1,           0x03FF5C00
        .equ    ETHERNET2,           0x03FF6000
        .equ    PAR_BUFF,            0x03FF6400
        .equ    RING2,               0x03FF6800
        .equ    RING2A,              0x03FF7800
        .equ    AST_$COPY_BUFF,      0x03FF8800
        .equ    AST_$ZERO_BUFF,      0x03FF8C00
        .equ    PBU_CTL,             0x03FF9000
        .equ    PIC1,                0x03FF9000
        .equ    PIC2,                0x03FF9100
        .equ    COLOR_SUP,           0x03FF9400
        .equ    COLOR,               0x03FF9400
        .equ    DISP1,               0x03FF9400
        .equ    DISP2,               0x03FF9400
        .equ    TAPE,                0x03FF9C00
        .equ    DMA,                 0x03FFA000
        .equ    MMU_$PARITY_PPN,     0x03FFA300
        .equ    FLOP,                0x03FFA400
        .equ    WIN,                 0x03FFA800
        .equ    TIMR,                0x03FFAC00
        .equ    CALENDAR,            0x03FFAD00
        .equ    SIO,                 0x03FFB000
        .equ    MMU,                 0x03FFB400

/* The node id PROM: PIC1's page + 0x200, which RING_$GET_ID probes
 * (ring/ring_driver.ins.pas node_id_prom).  No map symbol names it; its
 * two cells in RING_$GET_ID (0x3C32718, 0x3C32778) are fixup-table cells,
 * so it is an absolute symbol here. */
        .globl  NODE_ID_PROM

        .equ    NODE_ID_PROM,       0x03FF9200
