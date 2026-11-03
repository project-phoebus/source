/*
 * fim/sau8/bus_err.s - MMU_$BUS_STATUS and FIM_$BUS_ERR, the bus error
 * (vector 2) handler, for the DN3000's CPU status register and its
 * optional MC68851 PMMU (SAU8)
 *
 * SAU8 map, in "D 3C230D0 FIM_WIRED size = 1118":
 *   0x3C2312A  MMU_$BUS_STATUS   the last bus error's status word
 *                                (FIM_$BUILD_DF stores it in the fault's
 *                                information word, `pmmu_page_maps',
 *                                base/config.ins.pas)
 *   0x3C2312C  FIM_$BUS_ERR      to 0x3C23343 (FIM_$FLINE's FPU entry,
 *                                fim/m68k/fline.s, follows)
 * One section, keyed by MMU_$BUS_STATUS; CPU_B_PBU_SWITCH, JMP_TO_BUS_ERR
 * and BUS_ERROR_SWITCH before it are fim/m68k/bus_err.s's.
 *
 * The SAU9's handler (fim/sau9/bus_err.s, whose analysis of the frame
 * formats and of the PMMU's status applies) with the DN3000's registers:
 *   - the bus error status is the CPU status register's word (MMU) ORed
 *     with the current process's fault status word (PROC1_$CURRENT_PCB +
 *     0x5C), kept in MMU_$BUS_STATUS; both are cleared;
 *   - status bit 12 crashes the system with "mmu timeout", then takes the
 *     fault as a page fault;
 *   - while the processor runs a PBU's user interrupt routine
 *     (CPU_B_PBU_SWITCH's low byte set) a fault with none of the status
 *     bits 16#3F06 is "illegal page fault in user gpio interrupt routine"
 *     (signal 19), else a bus time-out;
 *   - after the faulting address is found, any of the status bits 16#3F06
 *     is a bus time-out, to the routine in BUS_ERROR_SWITCH when one is
 *     armed; else bit 2 is an FPU access: with a save area (FP_$SAVEP) to
 *     FIM_$FLINE's owner switch, without one the FPU is disabled (bit 2
 *     of the CPU control register, through its copy, MMU_$PID_PRIV's low
 *     byte) and the fault is a time-out (SIGBUS);
 *   - without a PMMU (MMU_$HAVE_PMMU clear) the MMU's fault code is read
 *     with `moves' from 16#0C000000 (written back): 7 is an illegal
 *     address, 1 an access violation, anything else a page fault;
 *   - with one, `ptestr #7' and `pmove psr' as on the SAU9, the
 *     translation flushed with `pflushs' (the MC68851's shared-globally
 *     form; the SAU9's MC68030 has `pflush').
 *
 * Hand-written: no frame, the fault descriptor scratch below the saved
 * registers, the PMMU instructions.  The Apollo assembler's <ea>=#imm
 * forms (cmp/and #imm) and the PMMU instructions gas does not encode
 * (ptestr with the function code in D0, pflushs) are written as
 * `.short'.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau8 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU8 image's.
 */

        .section ".text.MMU_$BUS_STATUS","ax",@progbits
        .even

        .globl  MMU_$BUS_STATUS
        .globl  FIM_$BUS_ERR

        .extern MMU                     /* arch/m68k/sau8/iodefs.s: the CPU status register */

        /* status_$t values (the SR10.2 status database) */
        .equ    STATUS_MST_GUARD_FAULT,        0x0004000A /* "guard fault" */
        .equ    STATUS_ILLEGAL_ADDRESS,        0x00040004 /* "reference to illegal address" */
        .equ    STATUS_FAULT_ACCESS_VIOLATION, 0x00120011 /* "access violation" */
        .equ    STATUS_FAULT_BUS_TIME_OUT,     0x0012000C /* "bus time-out" */
        .equ    STATUS_FAULT_ILLEGAL_PAGE_FAULT, 0x00120031 /* "illegal page fault in user gpio interrupt routine" */
        .equ    STATUS_MMU_TIMEOUT,            0x00070006 /* "mmu timeout" */
        .equ    STATUS_MMU_UNKNOWN,            0x00070007 /* "unknown mmu status" */

        .equ    SIGBUS,             10
        .equ    SIGSEGV,            11
        .equ    PBU_PAGE_FAULT_SIGNAL, 19
        .equ    FAULT_CLASS_ACCESS, 0x3000

MMU_$BUS_STATUS:                                | 3c2312a
        .short  0

FIM_$BUS_ERR:
        ori.w   #0x700,%sr                      | 3c2312c  007c 0700  IPL 7
        subq.w  #8,%sp                          | 3c23130  514f  the fault descriptor scratch
        movem.l %d0-%d3/%a0-%a2,-(%sp)          | 3c23132  48e7 f0e0
        movea.l (PROC1_$CURRENT_PCB).l,%a0      | 3c23136  2079 03c2 0300
        move.w  (MMU).l,%d1                     | 3c2313c  3239 03ff b400  the CPU status
        or.w    (0x5c,%a0),%d1                  | 3c23142  8268 005c  the process's fault status
        move.w  %d1,(MMU_$BUS_STATUS).l         | 3c23146  33c1 03c2 312a
        clr.w   (MMU).l                         | 3c2314c  4279 03ff b400
        clr.w   (0x5c,%a0)                      | 3c23152  4268 005c
        btst    #12,%d1                         | 3c23156  0801 000c
        bne.w   .Lwalk_error                    | 3c2315a  6600 010c
        tst.b   (CPU_B_PBU_SWITCH).l            | 3c2315e  4a39 03c2 310a  in a PBU's routine?
        bne.w   .Lpbu_fault                     | 3c23164  6600 01c8

        /* the faulting address, from the format A or B frame */
        move.w  (0x2e,%sp),%d0                  | 3c23168  302f 002e  the SSW
        btst    #8,%d0                          | 3c2316c  0800 0008  DF: a data cycle?
        beq.s   .Lnot_data                      | 3c23170  6706
        move.l  (0x34,%sp),%d2                  | 3c23172  242f 0034  the data cycle's address
        bra.s   .Lclassify                      | 3c23176  6024
.Lnot_data:
        .short  0x0c2f, 0x00a0, 0x002a          | 3c23178  0c2f 00a0 002a  cmpi.b #0xa0,(0x2a,%sp): format A?
        bne.s   .Lformat_b                      | 3c2317e  6610
        move.l  (0x26,%sp),%d2                  | 3c23180  242f 0026  the frame's PC
        addq.l  #2,%d2                          | 3c23184  5482  stage C
        btst    #14,%d0                         | 3c23186  0800 000e  FB: stage B?
        beq.s   .Lclassify                      | 3c2318a  6710
        addq.l  #2,%d2                          | 3c2318c  5482
        bra.s   .Lclassify                      | 3c2318e  600c
.Lformat_b:
        move.l  (0x48,%sp),%d2                  | 3c23190  242f 0048  stage B's address
        btst    #15,%d0                         | 3c23194  0800 000f  FC: stage C?
        beq.s   .Lclassify                      | 3c23198  6702
        subq.l  #2,%d2                          | 3c2319a  5582

        /* D1 = the bus status, D2 = the faulting address */
.Lclassify:
        move.w  #0x3f06,%d3                     | 3c2319c  363c 3f06
        and.w   %d1,%d3                         | 3c231a0  c641
        bne.w   .Ltimeout                       | 3c231a2  6600 013e  not an MMU fault
        tst.b   (MMU_$HAVE_PMMU).l              | 3c231a6  4a39 03c2 579a
        beq.w   .Lno_pmmu                       | 3c231ac  6700 00ca
        movea.l %d2,%a0                         | 3c231b0  2042
        .short  0xf010, 0x9e08                  | 3c231b2  f010 9e08  ptestr %d0,(%a0),#7
        subq.w  #2,%sp                          | 3c231b6  554f
        pmove   %psr,(%sp)                      | 3c231b8  f017 6200
        move.w  (%sp)+,%d3                      | 3c231bc  361f  D3 = the PSR
        .short  0xf010, 0x3c10                  | 3c231be  f010 3c10  pflushs #0,#0,(%a0)
        btst    #10,%d3                         | 3c231c2  0803 000a  I: invalid descriptor?
        beq.w   .Lvalid                         | 3c231c6  6700 0074
        move.b  #7,%d1                          | 3c231ca  123c 0007
        and.b   %d3,%d1                         | 3c231ce  c203  the walk's level
        .short  0xb23c, 0x0001                  | 3c231d0  b23c 0001  cmp.b #1,%d1
        beq.w   .Lillegal                       | 3c231d4  6700 00d6
        btst    #15,%d3                         | 3c231d8  0803 000f  B: a bus error in the walk?
        bne.w   .Lwalk_error                    | 3c231dc  6600 008a
        andi.w  #0xf8ff,%sr                     | 3c231e0  027c f8ff  IPL 0 across the pager

        /* a page fault: MST_$TOUCH(address, &status, 0) */
.Ltouch:
        move.l  #0,-(%sp)                       | 3c231e4  2f3c 0000 0000
        pea     (0x20,%sp)                      | 3c231ea  486f 0020  &scratch status
        move.l  %d2,-(%sp)                      | 3c231ee  2f02
        jsr     (MST_$TOUCH).l                  | 3c231f0  4eb9 03c0 ed44
        adda.l  #12,%sp                         | 3c231f6  dffc 0000 000c
        move.l  (0x1c,%sp),%d0                  | 3c231fc  202f 001c
        bne.s   .Ltouch_failed                  | 3c23200  660a
.Lreturn:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c23202  4cdf 070f
        addq.w  #8,%sp                          | 3c23206  504f
        jmp     (FIM_$EXIT:w,%pc)               | 3c23208  4efa 0f96  retry the instruction
.Ltouch_failed:
        move.w  #SIGSEGV,%d1                    | 3c2320c  323c 000b
        .short  0xb0bc                          | 3c23210  b0bc 0004 000a  cmp.l #STATUS_MST_GUARD_FAULT,%d0
        .long   STATUS_MST_GUARD_FAULT
        bne.w   .Ldeliver                       | 3c23216  6600 00a8
        /* a guard page: a trace fault for the address space */
        move.w  (PROC1_$AS_ID).l,-(%sp)         | 3c2321a  3f39 03c2 1e42
        bsr.w   FIM_$DELIVER_TRACE_FAULT        | 3c23220  6100 0f28
        addq.l  #2,%sp                          | 3c23224  548f
        move.w  (PROC1_$AS_ID).l,%d0            | 3c23226  3039 03c2 1e42
        lsl.w   #2,%d0                          | 3c2322c  e548
        lea     (FIM_$TRACE_STS:w,%pc),%a0      | 3c2322e  41fa 0a6a
        move.l  #STATUS_MST_GUARD_FAULT,(0,%a0,%d0.w) | 3c23232  21bc 0004 000a 0000
        bra.s   .Lreturn                        | 3c2323a  60c6

        /* a valid translation */
.Lvalid:
        btst    #13,%d3                         | 3c2323c  0803 000d  S: supervisor only?
        bne.s   .Lviolation                     | 3c23240  665e
        btst    #14,%d3                         | 3c23242  0803 000e  W: write protected?
        bne.s   .Lviolation                     | 3c23246  6658
        btst    #7,%d0                          | 3c23248  0800 0007  SSW RM: read-modify-write?
        beq.s   .Lnot_rmw                       | 3c2324c  6706
        ploadw  %d0,(%a0)                       | 3c2324e  f010 2008
        bra.s   .Lreturn                        | 3c23252  60ae
.Lnot_rmw:
        btst    #11,%d3                         | 3c23254  0803 000b  M: modified?
        beq.s   .Lretry                         | 3c23258  670c
        btst    #8,%d0                          | 3c2325a  0800 0008  DF
        beq.s   .Lretry                         | 3c2325e  6706
        btst    #6,%d0                          | 3c23260  0800 0006  RW: a read?
        beq.s   .Lviolation                     | 3c23264  673a
.Lretry:
        bra.s   .Lreturn                        | 3c23266  609a

.Lwalk_error:
        pea     (.Lsts_timeout,%pc)             | 3c23268  487a 004e
        jsr     (CRASH_SYSTEM).l                | 3c2326c  4eb9 03c1 ff00
        addq.w  #4,%sp                          | 3c23272  584f
        bra.w   .Ltouch                         | 3c23274  6000 ff6e

        /* no PMMU: the MMU's fault code, through the function-code space */
.Lno_pmmu:
        moves.l (0xc000000).l,%d0               | 3c23278  0eb9 0000 0c00 0000
        moves.l %d0,(0xc000000).l               | 3c23280  0eb9 0800 0c00 0000
        andi.w  #0xf8ff,%sr                     | 3c23288  027c f8ff
        .short  0xc0bc, 0x0000, 0x000f          | 3c2328c  c0bc 0000 000f  and.l #15,%d0
        .short  0xb03c, 0x0007                  | 3c23292  b03c 0007  cmp.b #7,%d0
        beq.s   .Lillegal                       | 3c23296  6714
        .short  0xb03c, 0x0001                  | 3c23298  b03c 0001  cmp.b #1,%d0
        bne.w   .Ltouch                         | 3c2329c  6600 ff46
.Lviolation:
        move.l  #STATUS_FAULT_ACCESS_VIOLATION,%d0 | 3c232a0  203c 0012 0011
        move.w  #SIGSEGV,%d1                    | 3c232a6  323c 000b
        bra.s   .Ldeliver                       | 3c232aa  6014
.Lillegal:
        move.l  #STATUS_ILLEGAL_ADDRESS,%d0     | 3c232ac  203c 0004 0004
        move.w  #SIGSEGV,%d1                    | 3c232b2  323c 000b
        bra.s   .Ldeliver                       | 3c232b6  6008
.Lsts_timeout:
        .long   STATUS_MMU_TIMEOUT              | 3c232b8  0007 0006
        .long   STATUS_MMU_UNKNOWN              | 3c232bc  0007 0007  not referenced

        /* deliver the fault in D0 (status), D1 (signal) through FIM_$COM */
.Ldeliver:
        andi.w  #0xf8ff,%sr                     | 3c232c0  027c f8ff
        move.l  %d0,(0x1c,%sp)                  | 3c232c4  2f40 001c  descriptor: status
        move.w  %d1,(0x20,%sp)                  | 3c232c8  3f41 0020  signal
        move.w  #FAULT_CLASS_ACCESS,(0x22,%sp)  | 3c232cc  3f7c 3000 0022  class
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c232d2  4cdf 070f
        pea     (%sp)                           | 3c232d6  4857  &descriptor
        pea     (0xc,%sp)                       | 3c232d8  486f 000c  &frame
        jmp     (FIM_COM).l                     | 3c232dc  4ef9 03c2 2be4

        /* a bus status bit: a bus time-out */
.Ltimeout:
        tst.l   (BUS_ERROR_SWITCH).l            | 3c232e2  4ab9 03c2 310e
        beq.s   .Lno_switch                     | 3c232e8  6708
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c232ea  4cdf 070f
        bra.w   JMP_TO_BUS_ERR                  | 3c232ee  6000 fe1c
.Lno_switch:
        btst    #2,%d1                          | 3c232f2  0801 0002  an FPU access?
        beq.s   .Lbus_timeout                   | 3c232f6  672a
        tst.l   (FP_$SAVEP).l                   | 3c232f8  4ab9 03c2 3112
        bne.s   .Lfp_switch                     | 3c232fe  6618
        move.b  (MMU_$PID_PRIV+1).l,%d0         | 3c23300  1039 03c2 56a5  the CPU control copy
        bclr    #2,%d0                          | 3c23306  0880 0002  FPU off
        move.b  %d0,(MMU_$PID_PRIV+1).l         | 3c2330a  13c0 03c2 56a5
        move.b  %d0,(MMU+0x101).l               | 3c23310  13c0 03ff b501  the CPU control register
        bra.s   .Lbus_timeout                   | 3c23316  600a
.Lfp_switch:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c23318  4cdf 070f
        addq.w  #8,%sp                          | 3c2331c  504f
        bra.w   fim_fline_fault_entry           | 3c2331e  6000 0024  fim/m68k/fline.s
.Lbus_timeout:
        move.l  #STATUS_FAULT_BUS_TIME_OUT,%d0  | 3c23322  203c 0012 000c
        move.w  #SIGBUS,%d1                     | 3c23328  323c 000a
        bra.s   .Ldeliver                       | 3c2332c  6092

        /* in a PBU's user interrupt routine */
.Lpbu_fault:
        move.w  #0x3f06,%d0                     | 3c2332e  303c 3f06
        and.w   %d1,%d0                         | 3c23332  c041
        bne.s   .Lbus_timeout                   | 3c23334  66ec
        move.l  #STATUS_FAULT_ILLEGAL_PAGE_FAULT,%d0 | 3c23336  203c 0012 0031
        move.w  #PBU_PAGE_FAULT_SIGNAL,%d1      | 3c2333c  323c 0013
        bra.w   .Ldeliver                       | 3c23340  6000 ff7e
