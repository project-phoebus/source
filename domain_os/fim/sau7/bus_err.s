/*
 * fim/sau7/bus_err.s - MMU_$BUS_STATUS and FIM_$BUS_ERR, the bus error
 * (vector 2) handler, for the SAU7's CPU status register, its
 * MC68030 or MC68851 PMMU and the floating-point accelerator (SAU7)
 *
 * SAU7 map, in "D 3C426334 FIM_WIRED size = 1804":
 *   0x3C4263A6  MMU_$BUS_STATUS   the last bus error's status word
 *                                (FIM_$BUILD_DF stores it in the fault's
 *                                information word, `pmmu_page_maps',
 *                                base/config.ins.pas)
 *   0x3C4263A8  FIM_$BUS_ERR      to 0x3C4265CB (NMI_$CNT, fim/sau7/
 *                                nmi.s, follows)
 * One section, keyed by MMU_$BUS_STATUS; CPU_B_PBU_SWITCH, JMP_TO_BUS_ERR
 * and BUS_ERROR_SWITCH before it are fim/m68k/bus_err.s's, FP_$SAVEP ..
 * FPA_$OWNER and their locks fp/m68k/savep.s's.
 *
 * The SAU8's handler (fim/sau8/bus_err.s, whose analysis of the frame
 * formats, the bus status and the PMMU's status applies) with:
 *   - the word at the system control page's +2 (SC_PAGE) cleared with
 *     the two status words;
 *   - status bit 12 ("mmu timeout") tested only when the CPU is not an
 *     MC68030 (M68030 clear: the MC68851's);
 *   - a faulting address at 16#FFF80000 and up, with FPA_$SAVEP set, is
 *     the accelerator's: to fpa_$bus_err_entry (fim/sau7/fpa.s) with the
 *     registers and the scratch as they are;
 *   - the bus status bits 16#3F0E (the SAU8's 16#3F06 and bit 3) send a
 *     fault to the time-out path, in the handler and in a PBU's user
 *     interrupt routine;
 *   - no PMMU-less form: the PMMU is always there; the translation is
 *     flushed with `pflush' on an MC68030 and `pflushs' on the MC68851;
 *   - an access violation on the MC68851 first clears the byte at
 *     SC_PAGE + 16#E.
 *
 * Hand-written: no frame, the fault descriptor scratch below the saved
 * registers, the PMMU instructions.  The Apollo assembler's <ea>=#imm
 * forms (cmp #imm) and the PMMU instructions gas does not encode
 * (ptestr with the function code in D0, pflushs) are written as `.short'.
 *
 * Byte gate (the SAU7 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68030 -m68881' and compared with the image at the map's
 * addresses by tools/asm_compare.py's rules, modulo relocations.  The
 * address and byte columns are the SAU7 image's.
 */

        .include "base/config.inc"
        .if fpa_board

        .section ".text.MMU_$BUS_STATUS","ax",@progbits
        .even

        .globl  MMU_$BUS_STATUS
        .globl  FIM_$BUS_ERR

        .extern MMU                     /* the CPU status register */
        .extern SC_PAGE                 /* the system control page */
        .extern M68030                  /* mmu/mmu.ins.pas: the CPU is an MC68030 */
        .extern FPA_$SAVEP              /* fp/m68k/savep.s */
        .extern fpa_$bus_err_entry      /* fim/sau7/fpa.s */
        .extern fim_fline_fault_entry   /* fim/m68k/fline.s */

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

        .equ    FPA_BASE,           0xFFF80000  /* the accelerator's addresses */

MMU_$BUS_STATUS:                                | 3c4263a6
        .short  0

FIM_$BUS_ERR:
        ori.w   #0x700,%sr                      | 3c4263a8  007c 0700  IPL 7
        subq.w  #8,%sp                          | 3c4263ac  514f  the fault descriptor scratch
        movem.l %d0-%d3/%a0-%a2,-(%sp)          | 3c4263ae  48e7 f0e0
        movea.l (PROC1_$CURRENT_PCB).l,%a0      | 3c4263b2  2079 3c42 2f60
        move.w  (MMU).l,%d1                     | 3c4263b8  3239 3fff b400  the CPU status
        or.w    (0x5c,%a0),%d1                  | 3c4263be  8268 005c  the process's fault status
        move.w  %d1,(MMU_$BUS_STATUS).l         | 3c4263c2  33c1 3c42 63a6
        clr.w   (MMU).l                         | 3c4263c8  4279 3fff b400
        clr.w   (0x5c,%a0)                      | 3c4263ce  4268 005c
        clr.w   (SC_PAGE+2).l                   | 3c4263d2  4279 3ffb 0002
        tst.b   (M68030).l                      | 3c4263d8  4a39 3c42 90ea
        bne.s   .Lpbu_check                     | 3c4263de  6608
        btst    #12,%d1                         | 3c4263e0  0801 000c
        bne.w   .Lwalk_error                    | 3c4263e4  6600 0122
.Lpbu_check:
        tst.b   (CPU_B_PBU_SWITCH).l            | 3c4263e8  4a39 3c42 636e  in a PBU's routine?
        bne.w   .Lpbu_fault                     | 3c4263ee  6600 01c6

        /* the faulting address, from the format A or B frame */
        move.w  (0x2e,%sp),%d0                  | 3c4263f2  302f 002e  the SSW
        btst    #8,%d0                          | 3c4263f6  0800 0008  DF: a data cycle?
        beq.s   .Lnot_data                      | 3c4263fa  6706
        move.l  (0x34,%sp),%d2                  | 3c4263fc  242f 0034  the data cycle's address
        bra.s   .Lclassify                      | 3c426400  6024
.Lnot_data:
        cmpi.b  #0xa0,(0x2a,%sp)                | 3c426402  0c2f 00a0 002a  format A?
        bne.s   .Lformat_b                      | 3c426408  6610
        move.l  (0x26,%sp),%d2                  | 3c42640a  242f 0026  the frame's PC
        addq.l  #2,%d2                          | 3c42640e  5482  stage C
        btst    #14,%d0                         | 3c426410  0800 000e  FB: stage B?
        beq.s   .Lclassify                      | 3c426414  6710
        addq.l  #2,%d2                          | 3c426416  5482
        bra.s   .Lclassify                      | 3c426418  600c
.Lformat_b:
        move.l  (0x48,%sp),%d2                  | 3c42641a  242f 0048  stage B's address
        btst    #15,%d0                         | 3c42641e  0800 000f  FC: stage C?
        beq.s   .Lclassify                      | 3c426422  6702
        subq.l  #2,%d2                          | 3c426424  5582

        /* D1 = the bus status, D2 = the faulting address */
.Lclassify:
        .short  0xb4bc                          | 3c426426  b4bc fff8 0000  cmp.l #FPA_BASE,%d2
        .long   FPA_BASE
        bcs.s   .Lnot_fpa                       | 3c42642c  650a
        tst.l   (FPA_$SAVEP).l                  | 3c42642e  4ab9 3c42 638e
        bne.w   fpa_$bus_err_entry              | 3c426434  6600 021e  fim/sau7/fpa.s
.Lnot_fpa:
        move.w  #0x3f0e,%d3                     | 3c426438  363c 3f0e
        and.w   %d1,%d3                         | 3c42643c  c641
        bne.w   .Ltimeout                       | 3c42643e  6600 012a  not an MMU fault
        movea.l %d2,%a0                         | 3c426442  2042
        .short  0xf010, 0x9e08                  | 3c426444  f010 9e08  ptestr %d0,(%a0),#7
        subq.w  #2,%sp                          | 3c426448  554f
        pmove   %psr,(%sp)                      | 3c42644a  f017 6200
        move.w  (%sp)+,%d3                      | 3c42644e  361f  D3 = the PSR
        tst.b   (M68030).l                      | 3c426450  4a39 3c42 90ea
        beq.s   .Lflush_68851                   | 3c426456  6706
        pflush  #0,#0,(%a0)                     | 3c426458  f010 3810
        bra.s   .Lflushed                       | 3c42645c  6004
.Lflush_68851:
        .short  0xf010, 0x3c10                  | 3c42645e  f010 3c10  pflushs #0,#0,(%a0)
.Lflushed:
        btst    #10,%d3                         | 3c426462  0803 000a  I: invalid descriptor?
        beq.w   .Lvalid                         | 3c426466  6700 0074
        move.b  #7,%d1                          | 3c42646a  123c 0007
        and.b   %d3,%d1                         | 3c42646e  c203  the walk's level
        .short  0xb23c, 0x0001                  | 3c426470  b23c 0001  cmp.b #1,%d1
        beq.w   .Lillegal                       | 3c426474  6700 00be
        btst    #15,%d3                         | 3c426478  0803 000f  B: a bus error in the walk?
        bne.w   .Lwalk_error                    | 3c42647c  6600 008a
        andi.w  #0xf8ff,%sr                     | 3c426480  027c f8ff  IPL 0 across the pager

        /* a page fault: MST_$TOUCH(address, &status, 0) */
.Ltouch:
        move.l  #0,-(%sp)                       | 3c426484  2f3c 0000 0000
        pea     (0x20,%sp)                      | 3c42648a  486f 0020  &scratch status
        move.l  %d2,-(%sp)                      | 3c42648e  2f02
        jsr     (MST_$TOUCH).l                  | 3c426490  4eb9 3c40 f848
        adda.l  #12,%sp                         | 3c426496  dffc 0000 000c
        move.l  (0x1c,%sp),%d0                  | 3c42649c  202f 001c
        bne.s   .Ltouch_failed                  | 3c4264a0  660a
.Lreturn:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c4264a2  4cdf 070f
        addq.w  #8,%sp                          | 3c4264a6  504f
        jmp     (FIM_$EXIT:w,%pc)               | 3c4264a8  4efa 1646  retry the instruction
.Ltouch_failed:
        move.w  #SIGSEGV,%d1                    | 3c4264ac  323c 000b
        .short  0xb0bc                          | 3c4264b0  b0bc 0004 000a  cmp.l #STATUS_MST_GUARD_FAULT,%d0
        .long   STATUS_MST_GUARD_FAULT
        bne.w   .Ldeliver                       | 3c4264b6  6600 0090
        /* a guard page: a trace fault for the address space */
        move.w  (PROC1_$AS_ID).l,-(%sp)         | 3c4264ba  3f39 3c42 4aa2
        bsr.w   FIM_$DELIVER_TRACE_FAULT        | 3c4264c0  6100 15d8
        addq.l  #2,%sp                          | 3c4264c4  548f
        move.w  (PROC1_$AS_ID).l,%d0            | 3c4264c6  3039 3c42 4aa2
        lsl.w   #2,%d0                          | 3c4264cc  e548
        lea     (FIM_$TRACE_STS:w,%pc),%a0      | 3c4264ce  41fa 111a
        move.l  #STATUS_MST_GUARD_FAULT,(0,%a0,%d0.w) | 3c4264d2  21bc 0004 000a 0000
        bra.s   .Lreturn                        | 3c4264da  60c6

        /* a valid translation */
.Lvalid:
        btst    #13,%d3                         | 3c4264dc  0803 000d  S: supervisor only?
        bne.s   .Lviolation                     | 3c4264e0  6636
        btst    #14,%d3                         | 3c4264e2  0803 000e  W: write protected?
        bne.s   .Lviolation                     | 3c4264e6  6630
        btst    #7,%d0                          | 3c4264e8  0800 0007  SSW RM: read-modify-write?
        beq.s   .Lnot_rmw                       | 3c4264ec  6706
        ploadw  %d0,(%a0)                       | 3c4264ee  f010 2008
        bra.s   .Lreturn                        | 3c4264f2  60ae
.Lnot_rmw:
        btst    #11,%d3                         | 3c4264f4  0803 000b  M: modified?
        beq.s   .Lretry                         | 3c4264f8  670c
        btst    #8,%d0                          | 3c4264fa  0800 0008  DF
        beq.s   .Lretry                         | 3c4264fe  6706
        btst    #6,%d0                          | 3c426500  0800 0006  RW: a read?
        beq.s   .Lviolation                     | 3c426504  6712
.Lretry:
        bra.s   .Lreturn                        | 3c426506  609a

.Lwalk_error:
        pea     (.Lsts_timeout,%pc)             | 3c426508  487a 0036
        jsr     (CRASH_SYSTEM).l                | 3c42650c  4eb9 3c42 2b00
        addq.w  #4,%sp                          | 3c426512  584f
        bra.w   .Ltouch                         | 3c426514  6000 ff6e

.Lviolation:
        tst.b   (M68030).l                      | 3c426518  4a39 3c42 90ea
        bne.s   .Lviolation_sts                 | 3c42651e  6608
        move.b  #0,(SC_PAGE+0xe).l              | 3c426520  13fc 0000 3ffb 000e
.Lviolation_sts:
        move.l  #STATUS_FAULT_ACCESS_VIOLATION,%d0 | 3c426528  203c 0012 0011
        move.w  #SIGSEGV,%d1                    | 3c42652e  323c 000b
        bra.s   .Ldeliver                       | 3c426532  6014
.Lillegal:
        move.l  #STATUS_ILLEGAL_ADDRESS,%d0     | 3c426534  203c 0004 0004
        move.w  #SIGSEGV,%d1                    | 3c42653a  323c 000b
        bra.s   .Ldeliver                       | 3c42653e  6008
        .globl  fim_$sts_mmu_timeout
fim_$sts_mmu_timeout:                           | also FIM_$NMI's (fim/sau7/nmi.s)
.Lsts_timeout:
        .long   STATUS_MMU_TIMEOUT              | 3c426540  0007 0006
        .long   STATUS_MMU_UNKNOWN              | 3c426544  0007 0007  not referenced

        /* deliver the fault in D0 (status), D1 (signal) through FIM_$COM */
.Ldeliver:
        andi.w  #0xf8ff,%sr                     | 3c426548  027c f8ff
        move.l  %d0,(0x1c,%sp)                  | 3c42654c  2f40 001c  descriptor: status
        move.w  %d1,(0x20,%sp)                  | 3c426550  3f41 0020  signal
        move.w  #FAULT_CLASS_ACCESS,(0x22,%sp)  | 3c426554  3f7c 3000 0022  class
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c42655a  4cdf 070f
        pea     (%sp)                           | 3c42655e  4857  &descriptor
        pea     (0xc,%sp)                       | 3c426560  486f 000c  &frame
        jmp     (FIM_COM).l                     | 3c426564  4ef9 3c42 5844

        /* a bus status bit: a bus time-out */
.Ltimeout:
        tst.l   (BUS_ERROR_SWITCH).l            | 3c42656a  4ab9 3c42 6372
        beq.s   .Lno_switch                     | 3c426570  6708
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c426572  4cdf 070f
        bra.w   JMP_TO_BUS_ERR                  | 3c426576  6000 fdf8
.Lno_switch:
        btst    #2,%d1                          | 3c42657a  0801 0002  an FPU access?
        beq.s   .Lbus_timeout                   | 3c42657e  672a
        tst.l   (FP_$SAVEP).l                   | 3c426580  4ab9 3c42 6376
        bne.s   .Lfp_switch                     | 3c426586  6618
        move.b  (MMU_$PID_PRIV+1).l,%d0         | 3c426588  1039 3c42 8ff5  the CPU control copy
        bclr    #2,%d0                          | 3c42658e  0880 0002  FPU off
        move.b  %d0,(MMU_$PID_PRIV+1).l         | 3c426592  13c0 3c42 8ff5
        move.b  %d0,(MMU+0x101).l               | 3c426598  13c0 3fff b501  the CPU control register
        bra.s   .Lbus_timeout                   | 3c42659e  600a
.Lfp_switch:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c4265a0  4cdf 070f
        addq.w  #8,%sp                          | 3c4265a4  504f
        bra.w   fim_fline_fault_entry           | 3c4265a6  6000 0424  fim/m68k/fline.s
.Lbus_timeout:
        move.l  #STATUS_FAULT_BUS_TIME_OUT,%d0  | 3c4265aa  203c 0012 000c
        move.w  #SIGBUS,%d1                     | 3c4265b0  323c 000a
        bra.s   .Ldeliver                       | 3c4265b4  6092

        /* in a PBU's user interrupt routine */
.Lpbu_fault:
        move.w  #0x3f0e,%d0                     | 3c4265b6  303c 3f0e
        and.w   %d1,%d0                         | 3c4265ba  c041
        bne.s   .Lbus_timeout                   | 3c4265bc  66ec
        move.l  #STATUS_FAULT_ILLEGAL_PAGE_FAULT,%d0 | 3c4265be  203c 0012 0031
        move.w  #PBU_PAGE_FAULT_SIGNAL,%d1      | 3c4265c4  323c 0013
        bra.w   .Ldeliver                       | 3c4265c8  6000 ff7e

        .endif
