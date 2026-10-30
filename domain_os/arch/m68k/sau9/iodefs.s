/*
 * arch/m68k/sau9/iodefs.s - the SAU9 map's absolute symbols, as link-time
 * symbols
 *
 * The SAU9's counterpart of arch/m68k/sau2/iodefs.s (which says why these
 * are absolute globals: the hand assembly and the Pascal name them, so
 * each cell that references one is a relocation to the value below).  It
 * has no bytes.  Every value is the SAU9 map's
 * (sr10.2-install/.../sau9/domain_os.map), in map order:
 *
 *   D44 3C401000  TRAP_PAGE          loaded at 3C401000, size = 400
 *       3BFC0000  PROT
 *   D58 3E52C000  IODEFS_GUARD       loaded at 612E800, size = 0
 *       3FF97C00  RING_8025_2 / IODEFS  ...  3FFE0000  PROM
 *
 * Against the SAU2's: the trap page, and with it the PROM's entry cells
 * from +0x100 (PROM_$MACHINE_ID), is the kernel's page at OS_BEGIN +
 * 0x1000 (`trap_page_high', base/config.ins.pas): COLD maps it, the link
 * leaves it to them (kernel.ld's .trap_page, NOBITS), and its symbols are
 * the map's fixed VAs here.  The vectors are the 68030's and the SAU9's
 * own: NMI_VEC at 0x7C, the FPU's at 0xC0..0xD8, the utility interrupt
 * controller's from 0x280 (INT0_VEC = PBU_VEC .. SIO3_VEC).  There is no
 * PTT; the I/O space starts at 0x3FF97C00 (IODEFS = RING_8025_2) with
 * the ring, Ethernet, display, CPU and utility (serial, calendar, timer,
 * PIO, MMU registers, interrupt controller), SCSI and video pages, the
 * display memory from 0x3FFA0000 and the PROM at 0x3FFE0000.  Names
 * sharing an address are the map's aliases.  IODEFS_GUARD is not defined
 * here (a layout position, VM_TABLES_END, as on the SAU2).
 */

/* The trap page (`D 3C401000 TRAP_PAGE size = 400'). */
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
        .globl  INT0_VEC
        .globl  PBU_VEC
        .globl  ATBUS1_VEC
        .globl  ATBUS2_VEC
        .globl  ATBUS3_VEC
        .globl  SCSI_DMA_VEC
        .globl  SCSI_VEC
        .globl  HORIZ_VEC
        .globl  IOCHK_VEC
        .globl  CAL_VEC
        .globl  TIMER0_VEC
        .globl  TIMER1_VEC
        .globl  TIMER2_VEC
        .globl  SIO0_VEC
        .globl  SIO1_VEC
        .globl  SIO2_VEC
        .globl  SIO3_VEC

        .equ    TRAP_PAGE,         0x3C401000
        .equ    BUS_ERROR_VEC,     0x3C401008
        .equ    ADDRESS_ERROR_VEC, 0x3C40100C
        .equ    ILLEGAL_INST_VEC,  0x3C401010
        .equ    ZERO_DIVIDE_VEC,   0x3C401014
        .equ    CHK_INST_VEC,      0x3C401018
        .equ    TRAPV_INST_VEC,    0x3C40101C
        .equ    PRIV_VIOL_VEC,     0x3C401020
        .equ    TRACE_VEC,         0x3C401024
        .equ    UNIMP_VEC,         0x3C401028
        .equ    FLINE_TRAP_VEC,    0x3C40102C
        .equ    COPROC_VEC,        0x3C401034
        .equ    INV_STACK_VEC,     0x3C401038
        .equ    SPURIOUS_INT_VEC,  0x3C401060
        .equ    NMI_VEC,           0x3C40107C
        .equ    TRAP_VEC,          0x3C401080
        .equ    FP_BSUN_VEC,       0x3C4010C0
        .equ    FP_INEXACT_VEC,    0x3C4010C4
        .equ    FP_DIV_ZERO_VEC,   0x3C4010C8
        .equ    FP_UNDFLO_VEC,     0x3C4010CC
        .equ    FP_OP_ERR_VEC,     0x3C4010D0
        .equ    FP_OVRFLO_VEC,     0x3C4010D4
        .equ    FP_SIG_NAN_VEC,    0x3C4010D8
        .equ    PROM_$MACHINE_ID,  0x3C401100
        .equ    INT0_VEC,          0x3C401280
        .equ    PBU_VEC,           0x3C401280
        .equ    ATBUS1_VEC,        0x3C401284
        .equ    ATBUS2_VEC,        0x3C401288
        .equ    ATBUS3_VEC,        0x3C40128C
        .equ    SCSI_DMA_VEC,      0x3C401290
        .equ    SCSI_VEC,          0x3C401294
        .equ    HORIZ_VEC,         0x3C401298
        .equ    IOCHK_VEC,         0x3C40129C
        .equ    CAL_VEC,           0x3C4012A0
        .equ    TIMER0_VEC,        0x3C4012A4
        .equ    TIMER1_VEC,        0x3C4012A8
        .equ    TIMER2_VEC,        0x3C4012AC
        .equ    SIO0_VEC,          0x3C4012B0
        .equ    SIO1_VEC,          0x3C4012B4
        .equ    SIO2_VEC,          0x3C4012B8
        .equ    SIO3_VEC,          0x3C4012BC

/* PROT (`3BFC0000 PROT'): the first VA past the user's space. */
        .globl  PROT

        .equ    PROT,       0x3BFC0000

/* IODEFS (the symbols from 3FF97C00). */
        .globl  RING_8025_2
        .globl  IODEFS
        .globl  RING_8025_1
        .globl  CHK_BUFF
        .globl  ETHERNET1
        .globl  ETHERNET2
        .globl  PAR_BUFF
        .globl  RING2
        .globl  RING2A
        .globl  RING1
        .globl  RING1A
        .globl  DISP_ALT2
        .globl  DISP_ALT1
        .globl  DISP2
        .globl  DISP1
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  NODE_ID
        .globl  CPU
        .globl  UTILITY
        .globl  SIO0
        .globl  SIO1
        .globl  SIO2
        .globl  SIO3
        .globl  CAL
        .globl  TIMER
        .globl  UTIL_PIO
        .globl  MMU_ISR
        .globl  MMU_CCR
        .globl  UTIL_PIC
        .globl  SCSI
        .globl  VTGA
        .globl  MMU_LEDR
        .globl  MMU_BESR
        .globl  MMU_VIDCR
        .globl  MMU_VIDSR
        .globl  MMU_PEARH
        .globl  MMU_IMR
        .globl  MMU_PEARL
        .globl  DISP2_MEM
        .globl  DISP1_MEM
        .globl  DISP_ALT_MEM
        .globl  PROM

        .equ    RING_8025_2,    0x3FF97C00
        .equ    IODEFS,         0x3FF97C00
        .equ    RING_8025_1,    0x3FF98400
        .equ    CHK_BUFF,       0x3FF98C00
        .equ    ETHERNET1,      0x3FF99000
        .equ    ETHERNET2,      0x3FF99400
        .equ    PAR_BUFF,       0x3FF99800
        .equ    RING2,          0x3FF99C00
        .equ    RING2A,         0x3FF9AC00
        .equ    RING1,          0x3FF9BC00
        .equ    RING1A,         0x3FF9CC00
        .equ    DISP_ALT2,      0x3FF9DC00
        .equ    DISP_ALT1,      0x3FF9E000
        .equ    DISP2,          0x3FF9E400
        .equ    DISP1,          0x3FF9E400
        .equ    AST_$COPY_BUFF, 0x3FF9E800
        .equ    AST_$ZERO_BUFF, 0x3FF9EC00
        .equ    NODE_ID,        0x3FF9F000
        .equ    CPU,            0x3FF9F000
        .equ    UTILITY,        0x3FF9F200
        .equ    SIO0,           0x3FF9F200
        .equ    SIO1,           0x3FF9F220
        .equ    SIO2,           0x3FF9F240
        .equ    SIO3,           0x3FF9F260
        .equ    CAL,            0x3FF9F280
        .equ    TIMER,          0x3FF9F2A0
        .equ    UTIL_PIO,       0x3FF9F2C0
        .equ    MMU_ISR,        0x3FF9F2C0
        .equ    MMU_CCR,        0x3FF9F2D0
        .equ    UTIL_PIC,       0x3FF9F2E0
        .equ    SCSI,           0x3FF9F400
        .equ    VTGA,           0x3FF9F600
        .equ    MMU_LEDR,       0x3FF9F800
        .equ    MMU_BESR,       0x3FF9F804
        .equ    MMU_VIDCR,      0x3FF9FA00
        .equ    MMU_VIDSR,      0x3FF9FA04
        .equ    MMU_PEARH,      0x3FF9FC00
        .equ    MMU_IMR,        0x3FF9FC00
        .equ    MMU_PEARL,      0x3FF9FE00
        .equ    DISP2_MEM,      0x3FFA0000
        .equ    DISP1_MEM,      0x3FFA0000
        .equ    DISP_ALT_MEM,   0x3FFC0000
        .equ    PROM,           0x3FFE0000
