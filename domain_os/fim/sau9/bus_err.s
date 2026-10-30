/*
 * fim/sau9/bus_err.s - MMU_$BUS_STATUS and FIM_$BUS_ERR, the bus error
 * (vector 2) handler, for the MC68030's MMU (SAU9)
 *
 * SAU9 map, in "D 3C4244A0 FIM_WIRED size = 10A4":
 *   0x3C4244F8  MMU_$BUS_STATUS   the last bus error's status word (a
 *                                 longword cell; FIM_$BUILD_DF stores it
 *                                 in the fault's information word,
 *                                 `pmmu_page_maps', base/config.ins.pas)
 *   0x3C4244FC  FIM_$BUS_ERR      to 0x3C4246C1 (NMI_$CNT follows)
 * One section, keyed by MMU_$BUS_STATUS; JMP_TO_BUS_ERR and
 * BUS_ERROR_SWITCH before it are fim/m68k/bus_err.s's.
 *
 * The SAU2's handler (fim/m68k/bus_err.s, whose analysis of the frame
 * formats applies) reads the PFT MMU's status byte; this one:
 *   - takes the bus error status from the memory error register MMU_BESR
 *     (its four lane bits, inverted: a set bit is a failing lane) ORed
 *     with the current process's fault status word (PROC1_$CURRENT_PCB +
 *     0x5C, which the probes and FIM_$FLINE clear), keeps it in
 *     MMU_$BUS_STATUS, clears the pending error with a pulse of MMU_CCR
 *     bit 4 and the process's word;
 *   - finds the faulting address in the 68030's format A or B frame as
 *     the SAU2's 68020 path does;
 *   - with a lane bit set (bit 0 or 1): a bus time-out, to the routine in
 *     BUS_ERROR_SWITCH when one is armed; else an FPU access with a save
 *     area (FP_$SAVEP) goes to FIM_$FLINE's owner switch, without one the
 *     FPU is disabled (MMU_CCR bit 7) and the fault is a time-out
 *     (SIGBUS);
 *   - else asks the PMMU (`ptestr #7', `pmove psr') about the address and
 *     flushes its translation: an invalid descriptor (PSR bit 10) is a
 *     page fault for MST_$TOUCH, at IPL 0 (a guard page becomes a trace
 *     fault, as on the SAU2), unless the walk hit the limit (PSR level 1:
 *     an illegal address, SIGSEGV) or a bus error (PSR bit 15: crash with
 *     "mmu timeout", then touch); a supervisor violation or a
 *     write-protected page (PSR bits 13, 14) is an access violation; a
 *     read-modify-write cycle (SSW RM) is retried after `ploadw'; a write
 *     to a modified page (PSR bit 11) of a data cycle that is not a read
 *     (SSW DF and not RW) is an access violation; anything else retries.
 *
 * Hand-written: no frame, the fault descriptor scratch below the saved
 * registers, the PMMU instructions.  The Apollo assembler's <ea>=#imm
 * forms (cmp/eor #imm) are written as `.short'.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU9 image's.
 */

        .section ".text.MMU_$BUS_STATUS","ax",@progbits
        .even

        .globl  MMU_$BUS_STATUS
        .globl  FIM_$BUS_ERR

        .extern MMU_BESR                /* arch/m68k/sau9/iodefs.s */
        .extern MMU_CCR

        /* status_$t values (the SR10.2 status database) */
        .equ    STATUS_MST_GUARD_FAULT,        0x0004000A /* "guard fault" */
        .equ    STATUS_ILLEGAL_ADDRESS,        0x00040004 /* "reference to illegal address" */
        .equ    STATUS_FAULT_ACCESS_VIOLATION, 0x00120011 /* "access violation" */
        .equ    STATUS_FAULT_BUS_TIME_OUT,     0x0012000C /* "bus time-out" */
        .equ    STATUS_MMU_TIMEOUT,            0x00070006 /* "mmu timeout" */
        .equ    STATUS_MMU_UNKNOWN,            0x00070007 /* "unknown mmu status" */

        .equ    SIGBUS,             10
        .equ    SIGSEGV,            11
        .equ    FAULT_CLASS_ACCESS, 0x3000

MMU_$BUS_STATUS:                                | 3c4244f8
        .long   0

FIM_$BUS_ERR:
        ori.w   #0x700,%sr                      | 3c4244fc  007c 0700  IPL 7
        subq.w  #8,%sp                          | 3c424500  514f  the fault descriptor scratch
        movem.l %d0-%d3/%a0-%a2,-(%sp)          | 3c424502  48e7 f0e0
        movea.l PROC1_$CURRENT_PCB,%a0          | 3c424506  2079 3c42 16c4
        clr.l   %d1                             | 3c42450c  4281
        move.b  MMU_BESR,%d1                    | 3c42450e  1239 3ff9 f804  the lanes
        .short  0x0a01, 0x00ff                  | 3c424514  0a01 00ff  eori.b #0xff,%d1
        or.w    (0x5c,%a0),%d1                  | 3c424518  8268 005c  the process's fault status
        move.w  %d1,MMU_$BUS_STATUS             | 3c42451c  33c1 3c42 44f8
        bset    #4,MMU_CCR                      | 3c424522  08f9 0004 3ff9 f2d0  clear the error
        bclr    #4,MMU_CCR                      | 3c42452a  08b9 0004 3ff9 f2d0
        clr.w   (0x5c,%a0)                      | 3c424532  4268 005c

        /* the faulting address, from the format A or B frame */
        move.w  (0x2e,%sp),%d0                  | 3c424536  302f 002e  the SSW
        btst    #8,%d0                          | 3c42453a  0800 0008  DF: a data cycle?
        beq.b   .Lnot_data                      | 3c42453e  6706
        move.l  (0x34,%sp),%d2                  | 3c424540  242f 0034  the data cycle's address
        bra.b   .Lclassify                      | 3c424544  6024
.Lnot_data:
        .short  0x0c2f, 0x00a0, 0x002a          | 3c424546  0c2f 00a0 002a  cmpi.b #0xa0,(0x2a,%sp): format A?
        bne.b   .Lformat_b                      | 3c42454c  6610
        move.l  (0x26,%sp),%d2                  | 3c42454e  242f 0026  the frame's PC
        addq.l  #2,%d2                          | 3c424552  5482  stage C
        btst    #14,%d0                         | 3c424554  0800 000e  FB: stage B?
        beq.b   .Lclassify                      | 3c424558  6710
        addq.l  #2,%d2                          | 3c42455a  5482
        bra.b   .Lclassify                      | 3c42455c  600c
.Lformat_b:
        move.l  (0x48,%sp),%d2                  | 3c42455e  242f 0048  stage B's address
        btst    #15,%d0                         | 3c424562  0800 000f  FC: stage C?
        beq.b   .Lclassify                      | 3c424566  6702
        subq.l  #2,%d2                          | 3c424568  5582

        /* D1 = the bus status, D2 = the faulting address */
.Lclassify:
        btst    #1,%d1                          | 3c42456a  0801 0001  a lane bit: no MMU fault
        bne.w   .Ltimeout                       | 3c42456e  6600 0114
        btst    #0,%d1                          | 3c424572  0801 0000
        bne.w   .Ltimeout                       | 3c424576  6600 010c
        movea.l %d2,%a0                         | 3c42457a  2042
        .short  0xf010, 0x9e08                  | 3c42457c  f010 9e08  ptestr %d0,(%a0),#7
        subq.w  #2,%sp                          | 3c424580  554f
        pmove   %psr,(%sp)                      | 3c424582  f017 6200
        move.w  (%sp)+,%d3                      | 3c424586  361f  D3 = the PSR
        pflush  #0,#0,(%a0)                     | 3c424588  f010 3810
        btst    #10,%d3                         | 3c42458c  0803 000a  I: invalid descriptor?
        beq.w   .Lvalid                         | 3c424590  6700 0074
        move.b  #7,%d1                          | 3c424594  123c 0007
        and.b   %d3,%d1                         | 3c424598  c203  the walk's level
        .short  0xb23c, 0x0001                  | 3c42459a  b23c 0001  cmp.b #1,%d1
        beq.w   .Lillegal                       | 3c42459e  6700 00ae
        btst    #15,%d3                         | 3c4245a2  0803 000f  B: a bus error in the walk?
        bne.w   .Lwalk_error                    | 3c4245a6  6600 008a
        andi.w  #0xf8ff,%sr                     | 3c4245aa  027c f8ff  IPL 0 across the pager

        /* a page fault: MST_$TOUCH(address, &status, 0) */
.Ltouch:
        move.l  #0,-(%sp)                       | 3c4245ae  2f3c 0000 0000
        pea     (0x20,%sp)                      | 3c4245b4  486f 0020  &scratch status
        move.l  %d2,-(%sp)                      | 3c4245b8  2f02
        jsr     MST_$TOUCH                      | 3c4245ba  4eb9 3c40 fe10
        adda.l  #12,%sp                         | 3c4245c0  dffc 0000 000c
        move.l  (0x1c,%sp),%d0                  | 3c4245c6  202f 001c
        bne.b   .Ltouch_failed                  | 3c4245ca  660a
.Lreturn:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c4245cc  4cdf 070f
        addq.w  #8,%sp                          | 3c4245d0  504f
        jmp     (FIM_$EXIT:w,%pc)               | 3c4245d2  4efa 0f26  retry the instruction
.Ltouch_failed:
        move.w  #SIGSEGV,%d1                    | 3c4245d6  323c 000b
        .short  0xb0bc                          | 3c4245da  b0bc 0004 000a  cmp.l #STATUS_MST_GUARD_FAULT,%d0
        .long   STATUS_MST_GUARD_FAULT
        bne.w   .Ldeliver                       | 3c4245e0  6600 0080
        /* a guard page: a trace fault for the address space */
        move.w  PROC1_$AS_ID,-(%sp)             | 3c4245e4  3f39 3c42 3206
        bsr.w   FIM_$DELIVER_TRACE_FAULT        | 3c4245ea  6100 0eb8
        addq.l  #2,%sp                          | 3c4245ee  548f
        move.w  PROC1_$AS_ID,%d0                | 3c4245f0  3039 3c42 3206
        lsl.w   #2,%d0                          | 3c4245f6  e548
        lea     (FIM_$TRACE_STS:w,%pc),%a0      | 3c4245f8  41fa 09fa
        move.l  #STATUS_MST_GUARD_FAULT,(0,%a0,%d0.w) | 3c4245fc  21bc 0004 000a 0000
        bra.b   .Lreturn                        | 3c424604  60c6

        /* a valid translation */
.Lvalid:
        btst    #13,%d3                         | 3c424606  0803 000d  S: supervisor only?
        bne.b   .Lviolation                     | 3c42460a  6636
        btst    #14,%d3                         | 3c42460c  0803 000e  W: write protected?
        bne.b   .Lviolation                     | 3c424610  6630
        btst    #7,%d0                          | 3c424612  0800 0007  SSW RM: read-modify-write?
        beq.b   .Lnot_rmw                       | 3c424616  6706
        ploadw  %d0,(%a0)                       | 3c424618  f010 2008
        bra.b   .Lreturn                        | 3c42461c  60ae
.Lnot_rmw:
        btst    #11,%d3                         | 3c42461e  0803 000b  M: modified?
        beq.b   .Lretry                         | 3c424622  670c
        btst    #8,%d0                          | 3c424624  0800 0008  DF
        beq.b   .Lretry                         | 3c424628  6706
        btst    #6,%d0                          | 3c42462a  0800 0006  RW: a read?
        beq.b   .Lviolation                     | 3c42462e  6712
.Lretry:
        bra.b   .Lreturn                        | 3c424630  609a

.Lwalk_error:
        pea     (.Lsts_timeout,%pc)             | 3c424632  487a 0026
        jsr     CRASH_SYSTEM                    | 3c424636  4eb9 3c42 1300
        addq.w  #4,%sp                          | 3c42463c  584f
        bra.w   .Ltouch                         | 3c42463e  6000 ff6e
.Lviolation:
        move.l  #STATUS_FAULT_ACCESS_VIOLATION,%d0 | 3c424642  203c 0012 0011
        move.w  #SIGSEGV,%d1                    | 3c424648  323c 000b
        bra.b   .Ldeliver                       | 3c42464c  6014
.Lillegal:
        move.l  #STATUS_ILLEGAL_ADDRESS,%d0     | 3c42464e  203c 0004 0004
        move.w  #SIGSEGV,%d1                    | 3c424654  323c 000b
        bra.b   .Ldeliver                       | 3c424658  6008
.Lsts_timeout:
        .long   STATUS_MMU_TIMEOUT              | 3c42465a  0007 0006
        .long   STATUS_MMU_UNKNOWN              | 3c42465e  0007 0007  not referenced

        /* deliver the fault in D0 (status), D1 (signal) through FIM_$COM */
.Ldeliver:
        andi.w  #0xf8ff,%sr                     | 3c424662  027c f8ff
        move.l  %d0,(0x1c,%sp)                  | 3c424666  2f40 001c  descriptor: status
        move.w  %d1,(0x20,%sp)                  | 3c42466a  3f41 0020  signal
        move.w  #FAULT_CLASS_ACCESS,(0x22,%sp)  | 3c42466e  3f7c 3000 0022  class
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c424674  4cdf 070f
        pea     (%sp)                           | 3c424678  4857  &descriptor
        pea     (12,%sp)                        | 3c42467a  486f 000c  &frame
        jmp     FIM_COM                         | 3c42467e  4ef9 3c42 3fb4

        /* a lane bit set: a bus time-out */
.Ltimeout:
        tst.l   BUS_ERROR_SWITCH                | 3c424684  4ab9 3c42 44dc
        beq.b   .Lno_switch                     | 3c42468a  6708
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c42468c  4cdf 070f
        bra.w   JMP_TO_BUS_ERR                  | 3c424690  6000 fe48
.Lno_switch:
        btst    #0,%d1                          | 3c424694  0801 0000
        beq.b   .Lbus_timeout                   | 3c424698  671c
        tst.l   FP_$SAVEP                       | 3c42469a  4ab9 3c42 44e0  an FPU access?
        bne.b   .Lfp_switch                     | 3c4246a0  660a
        bclr    #7,MMU_CCR                      | 3c4246a2  08b9 0007 3ff9 f2d0  FPU off
        bra.b   .Lbus_timeout                   | 3c4246aa  600a
.Lfp_switch:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c4246ac  4cdf 070f
        addq.w  #8,%sp                          | 3c4246b0  504f
        bra.w   fim_fline_fault_entry           | 3c4246b2  6000 0060  fim/m68k/fline.s
.Lbus_timeout:
        move.l  #STATUS_FAULT_BUS_TIME_OUT,%d0  | 3c4246b6  203c 0012 000c
        move.w  #SIGBUS,%d1                     | 3c4246bc  323c 000a
        bra.b   .Ldeliver                       | 3c4246c0  60a0
