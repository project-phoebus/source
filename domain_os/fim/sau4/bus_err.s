/*
 * fim/sau4/bus_err.s - FIM_$BUS_ERR and the DNx60 MMU's faults:
 * FIM_$REG_FAULT, FIM_$PAGE_FAULT (= FIM_$SEG_FAULT) and FIM_$ACC_VIOL
 * (SAU4)
 *
 * Transcribed from the SAU4 image, 0x0F822EBA..0x0F822FC7 (the word ahead
 * of FIM_$BUS_ERR, then FIM_$BUS_ERR to FIM_$FP_TRAP, 270 bytes), in the
 * FIM_WIRED segment after FP_$EXCLUSION (fp/m68k/savep.s).  One section,
 * keyed by FIM_$BUS_ERR: the four handlers branch into one another's
 * tails.  CPU_B_PBU_SWITCH, JMP_TO_BUS_ERR and BUS_ERROR_SWITCH ahead of
 * it are fim/m68k/bus_err.s's, as on the SAU3.
 *
 * The DNx60 translates through its region registers (`region_mmu',
 * base/config.ins.pas; Domain Engineering Handbook ch. 9, 9-2, 9-8,
 * 9-13): a missing translation is not a bus error but one of the
 * MMU's own exceptions, vectors 128..131 (REGF_VEC, SEGF_VEC,
 * PAGF_VEC, ACC_VIOL_VEC), whose long fault frame has the faulting
 * address at +0x0A.  OS_$INIT puts
 * FIM_$BUS_ERR on vector 2, FIM_$REG_FAULT on 128 and FIM_$PAGE_FAULT on
 * 129 and 130; the vector table installs FIM_$ACC_VIOL on 131
 * (`mmu_fault_vectors').
 *
 *   FIM_$BUS_ERR    at IPL 7, read and clear the MMU's status word (MMU +
 *                   2), back to IPL 0.  In a PBU's user interrupt
 *                   routine (CPU_B_PBU_SWITCH set), or with status bit 7
 *                   set and no BUS_ERROR_SWITCH armed: SIGBUS (10),
 *                   "bus time-out" 0x0012000C.  Bit 7 set and
 *                   BUS_ERROR_SWITCH armed: through JMP_TO_BUS_ERR.  Bit
 *                   7 clear: back through FIM_$EXIT.
 *   FIM_$REG_FAULT  a region not valid: SIGSEGV (11), "reference to
 *                   illegal address" 0x00040004, in a PBU's routine or
 *                   not.
 *   FIM_$PAGE_FAULT a segment or page not valid: in a PBU's routine,
 *                   signal 19 with "illegal page fault in user gpio
 *                   interrupt routine" 0x00120031; otherwise MST_$TOUCH
 *                   (the frame's faulting address, the status cell in
 *                   the descriptor scratch, 0).  Status 0: back through
 *                   FIM_$EXIT to retry.  A guard fault (0x0004000A):
 *                   FIM_$DELIVER_TRACE_FAULT for the address space, its
 *                   FIM_$TRACE_STS entry the guard fault, and back
 *                   through FIM_$EXIT.  Any other status: SIGSEGV.
 *   FIM_$ACC_VIOL   SIGSEGV, "access violation" 0x00120011.
 *
 * A signal is delivered as the SAU2's are: the status, the signal and the
 * class 0x3000 in the 8 bytes reserved under the saved registers, then
 * FIM_$COM with (&frame, &descriptor).
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): identical to the
 * image modulo relocations (the absolute operands, the PC-relative
 * FIM_$EXIT, FIM_$TRACE_STS and FIM_$DELIVER_TRACE_FAULT as R_68K_PC16,
 * the `bra.s' to JMP_TO_BUS_ERR as R_68K_PC8).
 */

        .extern CPU_B_PBU_SWITCH        /* fim/m68k/bus_err.s, map 0xF822E9A */
        .extern BUS_ERROR_SWITCH        /* fim/m68k/bus_err.s, map 0xF822E9E */
        .extern JMP_TO_BUS_ERR          /* fim/m68k/bus_err.s, image 0xF822E9C */
        .extern MMU                     /* arch/m68k/sau4/iodefs.s, 0xFFFB400 */
        .extern MST_$TOUCH              /* mst/, map 0xF80E384 */
        .extern PROC1_$AS_ID            /* proc1/m68k/proc1_data.s, map 0xF821C1A */
        .extern FIM_$DELIVER_TRACE_FAULT /* fim/m68k/deliver_trace_fault.s, map 0xF824AA4 */
        .extern FIM_$TRACE_STS          /* fim/m68k/wired_data.s, map 0xF824620 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xF824AEE */
        .extern FIM_$COM                /* fim/m68k/com.s, map 0xF8229B4 */

        .equ    MMU_STATUS, MMU + 2     /* the MMU's fault status word */
        .equ    SIGBUS, 10
        .equ    SIGSEGV, 11
        .equ    PBU_PAGE_FAULT_SIGNAL, 19

        .section ".text.FIM_$BUS_ERR","ax",@progbits
        .even

        .global fim_bus_err_align
        .global FIM_$BUS_ERR
        .global FIM_$REG_FAULT
        .global FIM_$PAGE_FAULT
        .global FIM_$SEG_FAULT
        .global FIM_$ACC_VIOL

fim_bus_err_align:
        .short  0                               /* sau4 f822eba  FIM_$BUS_ERR's longword alignment */

FIM_$BUS_ERR:
        ori.w   #0x0700,%sr                     /* sau4 f822ebc  007c 0700 */
        subq.w  #8,%sp                          /* sau4 f822ec0  514f  the descriptor scratch */
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f822ec2  48e7 c0c0 */
        move.w  (MMU_STATUS).l,%d0              /* sau4 f822ec6  3039 0fff b402 */
        clr.w   (MMU_STATUS).l                  /* sau4 f822ecc  4279 0fff b402 */
        andi.w  #0xf8ff,%sr                     /* sau4 f822ed2  027c f8ff  IPL 0 */
        tst.b   (CPU_B_PBU_SWITCH).l            /* sau4 f822ed6  4a39 0f82 2e9a */
        bne.s   .Lbe_timeout                    /* sau4 f822edc  6614 */
        btst    #7,%d0                          /* sau4 f822ede  0800 0007 */
        beq.s   .Lbe_return                     /* sau4 f822ee2  671c */
        tst.l   (BUS_ERROR_SWITCH).l            /* sau4 f822ee4  4ab9 0f82 2e9e */
        beq.s   .Lbe_timeout                    /* sau4 f822eea  6706 */
        movem.l (%sp)+,%d0-%d1/%a0-%a1          /* sau4 f822eec  4cdf 0303 */
        bra.s   JMP_TO_BUS_ERR                  /* sau4 f822ef0  60aa */
.Lbe_timeout:
        move.w  #SIGBUS,%d1                     /* sau4 f822ef2  323c 000a */
        move.l  #0x0012000C,%d0                 /* sau4 f822ef6  203c 0012 000c  "bus time-out" */
        bra.w   .Lfault_deliver                 /* sau4 f822efc  6000 00ac */
.Lbe_return:
        bra.w   .Lfault_return                  /* sau4 f822f00  6000 0060 */

FIM_$REG_FAULT:
        subq.w  #8,%sp                          /* sau4 f822f04  514f */
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f822f06  48e7 c0c0 */
        tst.b   (CPU_B_PBU_SWITCH).l            /* sau4 f822f0a  4a39 0f82 2e9a */
        beq.s   .Lrf_illegal                    /* sau4 f822f10  6718 */
        move.l  #0x00040004,%d0                 /* sau4 f822f12  203c 0004 0004  "reference to illegal address" */
        bra.w   .Lfault_segv                    /* sau4 f822f18  6000 008c */
.Lpbu_page_fault:
        move.w  #PBU_PAGE_FAULT_SIGNAL,%d1      /* sau4 f822f1c  323c 0013 */
        move.l  #0x00120031,%d0                 /* sau4 f822f20  203c 0012 0031  "illegal page fault in user gpio interrupt routine" */
        bra.w   .Lfault_deliver                 /* sau4 f822f26  6000 0082 */
.Lrf_illegal:
        move.l  #0x00040004,%d0                 /* sau4 f822f2a  203c 0004 0004  "reference to illegal address" */
        bra.w   .Lfault_segv                    /* sau4 f822f30  6000 0074 */

FIM_$PAGE_FAULT:
FIM_$SEG_FAULT:
        subq.w  #8,%sp                          /* sau4 f822f34  514f */
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f822f36  48e7 c0c0 */
        tst.b   (CPU_B_PBU_SWITCH).l            /* sau4 f822f3a  4a39 0f82 2e9a */
        bne.s   .Lpbu_page_fault                /* sau4 f822f40  66da */
        move.l  #0,-(%sp)                       /* sau4 f822f42  2f3c 0000 0000 */
        pea     (0x14,%sp)                      /* sau4 f822f48  486f 0014  &status (the scratch) */
        move.l  (0x2a,%sp),-(%sp)               /* sau4 f822f4c  2f2f 002a  the frame's faulting address (+0x0A) */
        jsr     (MST_$TOUCH).l                  /* sau4 f822f50  4eb9 0f80 e384 */
        adda.l  #12,%sp                         /* sau4 f822f56  dffc 0000 000c */
        move.l  (0x10,%sp),%d0                  /* sau4 f822f5c  202f 0010 */
        bne.s   .Lpf_failed                     /* sau4 f822f60  660a */
.Lfault_return:
        movem.l (%sp)+,%d0-%d1/%a0-%a1          /* sau4 f822f62  4cdf 0303 */
        addq.w  #8,%sp                          /* sau4 f822f66  504f */
        jmp     (FIM_$EXIT:w,%pc)               /* sau4 f822f68  4efa 1b84 */
.Lpf_failed:
        move.w  #SIGSEGV,%d1                    /* sau4 f822f6c  323c 000b */
        .short  0xb0bc; .long 0x0004000A        /* sau4 f822f70  b0bc 0004 000a  cmp.l #0x4000a,%d0 ("guard fault"), the <ea>=#imm form */
        bne.s   .Lfault_deliver                 /* sau4 f822f76  6632 */
        move.w  (PROC1_$AS_ID).l,-(%sp)         /* sau4 f822f78  3f39 0f82 1c1a */
        bsr.w   FIM_$DELIVER_TRACE_FAULT        /* sau4 f822f7e  6100 1b24 */
        addq.l  #2,%sp                          /* sau4 f822f82  548f */
        move.w  (PROC1_$AS_ID).l,%d0            /* sau4 f822f84  3039 0f82 1c1a */
        lsl.w   #2,%d0                          /* sau4 f822f8a  e548 */
        lea     (FIM_$TRACE_STS:w,%pc),%a0      /* sau4 f822f8c  41fa 1692 */
        move.l  #0x0004000A,(0,%a0,%d0.w)       /* sau4 f822f90  21bc 0004 000a 0000 */
        bra.s   .Lfault_return                  /* sau4 f822f98  60c8 */

FIM_$ACC_VIOL:
        subq.w  #8,%sp                          /* sau4 f822f9a  514f */
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f822f9c  48e7 c0c0 */
        move.l  #0x00120011,%d0                 /* sau4 f822fa0  203c 0012 0011  "access violation" */
.Lfault_segv:
        move.w  #SIGSEGV,%d1                    /* sau4 f822fa6  323c 000b */
.Lfault_deliver:
        move.l  %d0,(0x10,%sp)                  /* sau4 f822faa  2f40 0010  status */
        move.w  %d1,(0x14,%sp)                  /* sau4 f822fae  3f41 0014  signal */
        move.w  #0x3000,(0x16,%sp)              /* sau4 f822fb2  3f7c 3000 0016  class */
        movem.l (%sp)+,%d0-%d1/%a0-%a1          /* sau4 f822fb8  4cdf 0303 */
        pea     (%sp)                           /* sau4 f822fbc  4857  &descriptor */
        pea     (0xc,%sp)                       /* sau4 f822fbe  486f 000c  &frame */
        jmp     (FIM_$COM).l                    /* sau4 f822fc2  4ef9 0f82 29b4 */
