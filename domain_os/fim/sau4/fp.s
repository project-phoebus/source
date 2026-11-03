/*
 * fim/sau4/fp.s - the DNx60's floating-point context: FIM_$FP_TRAP,
 * FP_$GET_FP, FP_$PUT_FP, FIM_$FP_GET_STATE, FIM_$FP_PUT_STATE,
 * FIM_$FP_INIT, FIM_$FRESTORE (= FIM_$FP_ABORT) and the save tables
 * (FP_$CNTL) (SAU4)
 *
 * Transcribed from the SAU4 image, 0x0F822FC8..0x0F8241E3 (map
 * FIM_$FP_TRAP to FIM_$SPURIOUS_INT, 4636 bytes), in the FIM_WIRED
 * segment after FIM_$ACC_VIOL (fim/sau4/bus_err.s), one section per map
 * symbol.
 *
 * The floating-point registers are the CPU's own (`fp_state_in_cpu',
 * base/config.ins.pas): there is no coprocessor to save or restore, so
 * FIM_$FRESTORE and FIM_$FP_ABORT are a return, and the registers are
 * switched lazily through the FP ASID: control register 0x11E holds the
 * address space whose state the FP registers hold, and an FP instruction
 * of another one traps through vector 132 (FP_VEC) to FIM_$FP_TRAP
 * (Domain Engineering Handbook ch. 9, 9-2, 9-8).  Each address space
 * (0..57, by PROC1_$AS_ID) has three slots:
 *
 *   fp_$fpsr_table  0x0F823192  58 * 4   FPSR
 *   FP_$CNTL        0x0F82327A  58 * 4   FPCR, 0x3400 in the image (the
 *                                        operand error, overflow and
 *                                        divide by zero traps enabled)
 *   fp_$regs_table  0x0F823362  58 * 64  FP0..FP7, 8 bytes each (double)
 *
 * and a pad word to FIM_$SPURIOUS_INT (0x0F8241E2).  The registers are
 * stored with `fmove.d FPn,(A0)+' (opmode 0x00) and loaded with the word
 * the image has, opmode 0x01 (`fint.d (A0)+,FPn' in the MC68881's
 * encoding).
 *
 *   FIM_$FP_TRAP      at IPL 7 with SR bit 11 set (`ori.w #0xf00'), save
 *                     the FP ASID's FPSR, FPCR and registers, make the
 *                     current address space the FP ASID, load its slots,
 *                     clear SR bit 11, and retry through FIM_$EXIT.
 *   FP_$GET_FP(asid)  load the registers (FP0 twice), FPCR and FPSR from
 *                     the address space's slots (asid as a word at 4(SP)).
 *   FP_$PUT_FP(&asid) store FPSR, FPCR and the registers into them.
 *   FIM_$FP_GET_STATE(buf, &count)  the FP state for a fault frame: 76
 *                     (the length), FPSR, FPCR, FP0..FP7 into buf, and 4
 *                     into *count.
 *   FIM_$FP_PUT_STATE(buf)  load FP0..FP7, FPCR and FPSR from such a
 *                     buffer.
 *   FIM_$FP_INIT      a new address space's FP state: when it is the FP
 *                     ASID, clear control register 0x111 and SR bit 11;
 *                     its FPCR slot = 0x3400.  It has no return of its
 *                     own: it runs on into FIM_$FRESTORE's.
 *
 * The control registers 0x11E (the FP ASID) and 0x111 are written as
 * `movec' words: gas knows no names for the DNx60's control registers.
 * The floating-point instructions are words too, the instruction in the
 * comment: the SAU4 is assembled for the 68010 (Makefile ASFLAGS), for
 * which gas has no floating-point instructions.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): identical to the
 * image modulo relocations (the PC-relative table and FIM_$EXIT operands
 * as R_68K_PC16, PROC1_$AS_ID absolute).
 */

        .extern PROC1_$AS_ID            /* proc1/m68k/proc1_data.s, map 0xF821C1A */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xF824AEE */

        .equ    FP_ASIDS, 58            /* address spaces 0..57 */
        .equ    FP_DEFAULT_FPCR, 0x3400

        .global FIM_$FP_TRAP
        .global FP_$GET_FP
        .global FP_$PUT_FP
        .global FIM_$FP_GET_STATE
        .global FIM_$FP_PUT_STATE
        .global FIM_$FP_INIT
        .global FIM_$FRESTORE
        .global FIM_$FP_ABORT
        .global fp_$fpsr_table
        .global FP_$CNTL
        .global fp_$regs_table

        .section ".text.FIM_$FP_TRAP","ax",@progbits
        .even
FIM_$FP_TRAP:
        ori.w   #0x0f00,%sr                     /* sau4 f822fc8  007c 0f00  IPL 7, SR bit 11 */
        movem.l %d0/%a0-%a2,-(%sp)              /* sau4 f822fcc  48e7 80e0 */
        .short  0x4e7a, 0x011e                  /* sau4 f822fd0  movec 0x11e,%d0  the FP ASID */
        lsl.w   #2,%d0                          /* sau4 f822fd4  e548 */
        lea     (fp_$fpsr_table:w,%pc),%a1      /* sau4 f822fd6  43fa 01ba */
        lea     (FP_$CNTL:w,%pc),%a2            /* sau4 f822fda  45fa 029e */
        .short  0xf231, 0xa800, 0x0000          /* sau4 f822fde  fmove.l %fpsr,(0,%a1,%d0.w) */
        .short  0xf232, 0xb000, 0x0000          /* sau4 f822fe4  fmove.l %fpcr,(0,%a2,%d0.w) */
        lsl.w   #4,%d0                          /* sau4 f822fea  e948 */
        lea     (fp_$regs_table:w,%pc),%a0      /* sau4 f822fec  41fa 0374 */
        adda.w  %d0,%a0                         /* sau4 f822ff0  d0c0 */
        .short  0xf218, 0x7400                  /* sau4 f822ff2  fmove.d %fp0,(%a0)+ */
        .short  0xf218, 0x7480                  /* sau4 f822ff6  fmove.d %fp1,(%a0)+ */
        .short  0xf218, 0x7500                  /* sau4 f822ffa  fmove.d %fp2,(%a0)+ */
        .short  0xf218, 0x7580                  /* sau4 f822ffe  fmove.d %fp3,(%a0)+ */
        .short  0xf218, 0x7600                  /* sau4 f823002  fmove.d %fp4,(%a0)+ */
        .short  0xf218, 0x7680                  /* sau4 f823006  fmove.d %fp5,(%a0)+ */
        .short  0xf218, 0x7700                  /* sau4 f82300a  fmove.d %fp6,(%a0)+ */
        .short  0xf210, 0x7780                  /* sau4 f82300e  fmove.d %fp7,(%a0) */
        clr.l   %d0                             /* sau4 f823012  4280 */
        move.w  (PROC1_$AS_ID).l,%d0            /* sau4 f823014  3039 0f82 1c1a */
        .short  0x4e7b, 0x011e                  /* sau4 f82301a  movec %d0,0x11e */
        lsl.w   #2,%d0                          /* sau4 f82301e  e548 */
        .short  0xf231, 0x8800, 0x0000          /* sau4 f823020  fmove.l (0,%a1,%d0.w),%fpsr */
        .short  0xf232, 0x9000, 0x0000          /* sau4 f823026  fmove.l (0,%a2,%d0.w),%fpcr */
        lsl.w   #4,%d0                          /* sau4 f82302c  e948 */
        lea     (fp_$regs_table:w,%pc),%a0      /* sau4 f82302e  41fa 0332 */
        adda.w  %d0,%a0                         /* sau4 f823032  d0c0 */
        .short  0xf218, 0x5401                  /* sau4 f823034  fint.d (%a0)+,%fp0 */
        .short  0xf218, 0x5481                  /* sau4 f823038  fint.d (%a0)+,%fp1 */
        .short  0xf218, 0x5501                  /* sau4 f82303c  fint.d (%a0)+,%fp2 */
        .short  0xf218, 0x5581                  /* sau4 f823040  fint.d (%a0)+,%fp3 */
        .short  0xf218, 0x5601                  /* sau4 f823044  fint.d (%a0)+,%fp4 */
        .short  0xf218, 0x5681                  /* sau4 f823048  fint.d (%a0)+,%fp5 */
        .short  0xf218, 0x5701                  /* sau4 f82304c  fint.d (%a0)+,%fp6 */
        .short  0xf210, 0x5781                  /* sau4 f823050  fint.d (%a0),%fp7 */
        andi.w  #0xf7ff,%sr                     /* sau4 f823054  027c f7ff  SR bit 11 clear */
        movem.l (%sp)+,%d0/%a0-%a2              /* sau4 f823058  4cdf 0701 */
        jmp     (FIM_$EXIT:w,%pc)               /* sau4 f82305c  4efa 1a90 */

        .section ".text.FP_$GET_FP","ax",@progbits
        .even
FP_$GET_FP:
        clr.l   %d0                             /* sau4 f823060  4280 */
        move.w  (0x4,%sp),%d0                   /* sau4 f823062  302f 0004  asid */
        lsl.w   #6,%d0                          /* sau4 f823066  ed48 */
        lea     (fp_$regs_table:w,%pc),%a0      /* sau4 f823068  41fa 02f8 */
        lea     (0,%a0,%d0.w),%a0               /* sau4 f82306c  41f0 0000 */
        .short  0xf210, 0x5401                  /* sau4 f823070  fint.d (%a0),%fp0 */
        .short  0xf218, 0x5401                  /* sau4 f823074  fint.d (%a0)+,%fp0 */
        .short  0xf218, 0x5481                  /* sau4 f823078  fint.d (%a0)+,%fp1 */
        .short  0xf218, 0x5501                  /* sau4 f82307c  fint.d (%a0)+,%fp2 */
        .short  0xf218, 0x5581                  /* sau4 f823080  fint.d (%a0)+,%fp3 */
        .short  0xf218, 0x5601                  /* sau4 f823084  fint.d (%a0)+,%fp4 */
        .short  0xf218, 0x5681                  /* sau4 f823088  fint.d (%a0)+,%fp5 */
        .short  0xf218, 0x5701                  /* sau4 f82308c  fint.d (%a0)+,%fp6 */
        .short  0xf210, 0x5781                  /* sau4 f823090  fint.d (%a0),%fp7 */
        lsr.w   #4,%d0                          /* sau4 f823094  e848 */
        lea     (FP_$CNTL:w,%pc),%a1            /* sau4 f823096  43fa 01e2 */
        .short  0xf231, 0x9000, 0x0000          /* sau4 f82309a  fmove.l (0,%a1,%d0.w),%fpcr */
        lea     (fp_$fpsr_table:w,%pc),%a1      /* sau4 f8230a0  43fa 00f0 */
        .short  0xf231, 0x8800, 0x0000          /* sau4 f8230a4  fmove.l (0,%a1,%d0.w),%fpsr */
        rts                                     /* sau4 f8230aa  4e75 */

        .section ".text.FP_$PUT_FP","ax",@progbits
        .even
FP_$PUT_FP:
        movea.l (0x4,%sp),%a0                   /* sau4 f8230ac  206f 0004  &asid */
        clr.l   %d0                             /* sau4 f8230b0  4280 */
        move.w  (%a0),%d0                       /* sau4 f8230b2  3010 */
        lsl.w   #2,%d0                          /* sau4 f8230b4  e548 */
        lea     (fp_$fpsr_table:w,%pc),%a1      /* sau4 f8230b6  43fa 00da */
        .short  0xf231, 0xa800, 0x0000          /* sau4 f8230ba  fmove.l %fpsr,(0,%a1,%d0.w) */
        lea     (FP_$CNTL:w,%pc),%a1            /* sau4 f8230c0  43fa 01b8 */
        .short  0xf231, 0xb000, 0x0000          /* sau4 f8230c4  fmove.l %fpcr,(0,%a1,%d0.w) */
        lsl.w   #4,%d0                          /* sau4 f8230ca  e948 */
        lea     (fp_$regs_table:w,%pc),%a0      /* sau4 f8230cc  41fa 0294 */
        lea     (0,%a0,%d0.w),%a0               /* sau4 f8230d0  41f0 0000 */
        .short  0xf218, 0x7400                  /* sau4 f8230d4  fmove.d %fp0,(%a0)+ */
        .short  0xf218, 0x7480                  /* sau4 f8230d8  fmove.d %fp1,(%a0)+ */
        .short  0xf218, 0x7500                  /* sau4 f8230dc  fmove.d %fp2,(%a0)+ */
        .short  0xf218, 0x7580                  /* sau4 f8230e0  fmove.d %fp3,(%a0)+ */
        .short  0xf218, 0x7600                  /* sau4 f8230e4  fmove.d %fp4,(%a0)+ */
        .short  0xf218, 0x7680                  /* sau4 f8230e8  fmove.d %fp5,(%a0)+ */
        .short  0xf218, 0x7700                  /* sau4 f8230ec  fmove.d %fp6,(%a0)+ */
        .short  0xf210, 0x7780                  /* sau4 f8230f0  fmove.d %fp7,(%a0) */
        rts                                     /* sau4 f8230f4  4e75 */

        .section ".text.FIM_$FP_GET_STATE","ax",@progbits
        .even
FIM_$FP_GET_STATE:
        movea.l (0x4,%sp),%a0                   /* sau4 f8230f6  206f 0004  buf */
        move.l  #76,(%a0)+                      /* sau4 f8230fa  20fc 0000 004c  the length */
        .short  0xf218, 0xa800                  /* sau4 f823100  fmove.l %fpsr,(%a0)+ */
        .short  0xf218, 0xb000                  /* sau4 f823104  fmove.l %fpcr,(%a0)+ */
        .short  0xf218, 0x7400                  /* sau4 f823108  fmove.d %fp0,(%a0)+ */
        .short  0xf218, 0x7480                  /* sau4 f82310c  fmove.d %fp1,(%a0)+ */
        .short  0xf218, 0x7500                  /* sau4 f823110  fmove.d %fp2,(%a0)+ */
        .short  0xf218, 0x7580                  /* sau4 f823114  fmove.d %fp3,(%a0)+ */
        .short  0xf218, 0x7600                  /* sau4 f823118  fmove.d %fp4,(%a0)+ */
        .short  0xf218, 0x7680                  /* sau4 f82311c  fmove.d %fp5,(%a0)+ */
        .short  0xf218, 0x7700                  /* sau4 f823120  fmove.d %fp6,(%a0)+ */
        .short  0xf210, 0x7780                  /* sau4 f823124  fmove.d %fp7,(%a0) */
        movea.l (0x8,%sp),%a0                   /* sau4 f823128  206f 0008  &count */
        move.l  #4,(%a0)                        /* sau4 f82312c  20bc 0000 0004 */
        rts                                     /* sau4 f823132  4e75 */

        .section ".text.FIM_$FP_PUT_STATE","ax",@progbits
        .even
FIM_$FP_PUT_STATE:
        movea.l (0x4,%sp),%a0                   /* sau4 f823134  206f 0004  buf */
        addq.l  #4,%a0                          /* sau4 f823138  5888  past the length */
        movea.l %a0,%a1                         /* sau4 f82313a  2248  FPSR, FPCR */
        addq.l  #8,%a0                          /* sau4 f82313c  5088 */
        .short  0xf218, 0x5401                  /* sau4 f82313e  fint.d (%a0)+,%fp0 */
        .short  0xf218, 0x5481                  /* sau4 f823142  fint.d (%a0)+,%fp1 */
        .short  0xf218, 0x5501                  /* sau4 f823146  fint.d (%a0)+,%fp2 */
        .short  0xf218, 0x5581                  /* sau4 f82314a  fint.d (%a0)+,%fp3 */
        .short  0xf218, 0x5601                  /* sau4 f82314e  fint.d (%a0)+,%fp4 */
        .short  0xf218, 0x5681                  /* sau4 f823152  fint.d (%a0)+,%fp5 */
        .short  0xf218, 0x5701                  /* sau4 f823156  fint.d (%a0)+,%fp6 */
        .short  0xf218, 0x5781                  /* sau4 f82315a  fint.d (%a0)+,%fp7 */
        .short  0xf229, 0x9000, 0x0004          /* sau4 f82315e  fmove.l (0x4,%a1),%fpcr */
        .short  0xf211, 0x8800                  /* sau4 f823164  fmove.l (%a1),%fpsr */
        rts                                     /* sau4 f823168  4e75 */

        .section ".text.FIM_$FP_INIT","ax",@progbits
        .even
FIM_$FP_INIT:
        .short  0x4e7a, 0x111e                  /* sau4 f82316a  movec 0x11e,%d1  the FP ASID */
        move.w  (PROC1_$AS_ID).l,%d0            /* sau4 f82316e  3039 0f82 1c1a */
        cmp.w   %d0,%d1                         /* sau4 f823174  b240 */
        bne.s   .Lfpi_slot                      /* sau4 f823176  660a */
        clr.l   %d1                             /* sau4 f823178  4281 */
        .short  0x4e7b, 0x1111                  /* sau4 f82317a  movec %d1,0x111 */
        andi.w  #0xf7ff,%sr                     /* sau4 f82317e  027c f7ff  SR bit 11 clear */
.Lfpi_slot:
        lsl.w   #2,%d0                          /* sau4 f823182  e548 */
        lea     (FP_$CNTL:w,%pc),%a1            /* sau4 f823184  43fa 00f4 */
        move.l  #FP_DEFAULT_FPCR,(0,%a1,%d0.w)  /* sau4 f823188  23bc 0000 3400 0000 */
        /* falls through into FIM_$FRESTORE's rts (the next section) */

        .section ".text.FIM_$FRESTORE","ax",@progbits
        .even
FIM_$FRESTORE:
FIM_$FP_ABORT:
        rts                                     /* sau4 f823190  4e75 */
fp_$fpsr_table:                                 /* sau4 f823192 */
        .space  FP_ASIDS * 4

        .section ".text.FP_$CNTL","ax",@progbits
        .even
FP_$CNTL:                                       /* sau4 f82327a */
        .rept   FP_ASIDS
        .long   FP_DEFAULT_FPCR
        .endr
fp_$regs_table:                                 /* sau4 f823362 */
        .space  FP_ASIDS * 64
        .short  0                               /* sau4 f8241e2  pad */
