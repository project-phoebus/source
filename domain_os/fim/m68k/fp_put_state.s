/*
 * fim/m68k/fp_put_state.s - FIM_$FP_PUT_STATE (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21E86..0x00E21F1F (map
 * FIM_$FP_PUT_STATE to FIM_$SPURIOUS_INT, 154 bytes: 152 of code and a
 * 2-byte longword pad), in its own section.
 *
 *   void FIM_$FP_PUT_STATE(void *regs, void *frame)
 *        0x18(SP), 0x1C(SP) after the 5-register save
 *
 * The inverse of FIM_$FP_GET_STATE, with an FPU configured.  Into the
 * current address space's save slot: if frame's first word is not 0x1234
 * the slot's frame pointer is cleared; otherwise the fsave frame is copied
 * from the words that follow (size byte + 4 bytes, as the image counts
 * them) to the end of the slot, and if regs is tagged 0x1234 too, its 27
 * longwords and the 0xFFFF "registers present" marker go below it and the
 * slot's frame pointer is set.  With no frame but tagged registers, the
 * registers are loaded straight into the FPU after making the current
 * address space the owner under FP_$EXCLUSION.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.
 *
 * The pad word at the end keeps FIM_$SPURIOUS_INT longword aligned in
 * the SAU2's FIM_WIRED; the SAU9's (`fpu_enable_ccr': its FP routines
 * are 2 bytes longer, so FIM_$SPURIOUS_INT is aligned at 0x3C424B8C) has
 * none, nor has the SAU7's (FIM_$SPURIOUS_INT at 0x3C427174).
 *
 * With `fpa_board' (the SAU7: FIM_$FP_PUT_STATE 0x3C427084) the
 * accelerator's part of the two buffers comes first when FPA_$SAVEP is
 * set: frame's tag word is stepped over, and if regs is tagged 0x1234
 * the current address space's accelerator slot gets the flag word 1, the
 * 32 register longwords, the exception and the control and status
 * registers from regs and the 18 status bytes from frame; with no
 * accelerator both buffers' zero words are stepped over.  The FPU's
 * part follows.  Those lines carry the SAU7 image's addresses.
 *
 * Not on the SAUs whose floating-point registers are the CPU's own
 * (`fp_state_in_cpu', base/config.ins.pas): the SAU4's routine is
 * in fim/sau4/fp.s.
 */

        .include "base/config.inc"
        .if !fp_state_in_cpu && !fpu_enable_mmu_9   /* the SAU6's: fim/sau6/fp.s */

        .section ".text.FIM_$FP_PUT_STATE","ax",@progbits
        .even

        .extern PROC1_$AS_ID            /* uint16_t, map 0xE2060A */
        .extern FP_$SAVEP               /* fp/m68k/savep.s, map 0xE218D0 */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */
        .extern fp_$switch_owner        /* fp/m68k/fp_context.s, image 0xE21B10 */
        .if fpa_board
        .extern FPA_$SAVEP              /* fp/m68k/savep.s */
        /* Bytes per address space in the accelerator's save-area table
         * (fim/sau7/fpa.s). */
        .equ    FPA_SAVE_AREA_SIZE, 156
        .endif

        .global FIM_$FP_PUT_STATE
FIM_$FP_PUT_STATE:
        movem.l %d2-%d3/%a2-%a4,-(%sp)          /* e21e86 */
        movea.l (0x18,%sp),%a3                  /* e21e8a  A3 = regs */
        movea.l (0x1c,%sp),%a4                  /* e21e8e  A4 = frame */
        addq.l  #4,%a3                          /* e21e92  past the count longword */
        addq.l  #4,%a4                          /* e21e94 */
        .if fpa_board
        move.l  (FPA_$SAVEP:w,%pc),%d0          /* sau7 3c427094  203a f2f8 */
        beq.w   .Lps_fpa_none                   /* sau7 3c427098  6700 004e  no accelerator */
        addq.l  #2,%a4                          /* sau7 3c42709c  548c  frame's tag word */
        cmpi.w  #0x1234,(%a3)+                  /* sau7 3c42709e  0c5b 1234  registers tagged? */
        bne.w   .Lps_fpu                        /* sau7 3c4270a2  6600 0048 */
        movea.l %d0,%a0                         /* sau7 3c4270a6  2040 */
        move.w  (PROC1_$AS_ID).l,%d0            /* sau7 3c4270a8  3039 3c42 4aa2 */
        subq.w  #1,%d0                          /* sau7 3c4270ae  5340 */
        blt.w   .Lps_fpu                        /* sau7 3c4270b0  6d00 003a */
        mulu.w  #FPA_SAVE_AREA_SIZE,%d0         /* sau7 3c4270b4  c0fc 009c */
        lea     (0,%a0,%d0.l),%a0               /* sau7 3c4270b8  41f0 0800  the slot */
        move.w  #1,(%a0)+                       /* sau7 3c4270bc  30fc 0001  a state saved */
        move.w  #31,%d0                         /* sau7 3c4270c0  303c 001f  32 longwords */
.Lps_fpa_regs:
        move.l  (%a3)+,(%a0)+                   /* sau7 3c4270c4  20db */
        dbf     %d0,.Lps_fpa_regs               /* sau7 3c4270c6  51c8 fffc */
        adda.l  #18,%a0                         /* sau7 3c4270ca  d1fc 0000 0012  past the status bytes */
        move.l  (%a3)+,(%a0)+                   /* sau7 3c4270d0  20db  the exception register */
        move.l  (%a3)+,(%a0)                    /* sau7 3c4270d2  209b  the control and status register */
        suba.l  #22,%a0                         /* sau7 3c4270d4  91fc 0000 0016  back to the status bytes */
        moveq   #18,%d0                         /* sau7 3c4270da  7012 */
        lsr.l   #1,%d0                          /* sau7 3c4270dc  e288 */
        subq.l  #1,%d0                          /* sau7 3c4270de  5380  9 words */
.Lps_fpa_status:
        move.w  (%a4)+,(%a0)+                   /* sau7 3c4270e0  30dc */
        dbf     %d0,.Lps_fpa_status             /* sau7 3c4270e2  51c8 fffc */
        bra.s   .Lps_fpu                        /* sau7 3c4270e6  6004 */
.Lps_fpa_none:
        addq.l  #2,%a3                          /* sau7 3c4270e8  548b  the zero words */
        addq.l  #2,%a4                          /* sau7 3c4270ea  548c */
.Lps_fpu:
        .endif
        move.l  (FP_$SAVEP:w,%pc),%d0           /* e21e96 */
        beq.w   .Lps_done                       /* e21e9a  6700 007c: no FPU */
        movea.l (FP_$SAVEP:w,%pc),%a0           /* e21e9e */
        move.w  (PROC1_$AS_ID).l,%d0            /* e21ea2 */
        mulu.w  #0x14a,%d0                      /* e21ea8  FP_SAVE_AREA_SIZE */
        adda.l  %d0,%a0                         /* e21eac */
        subq.l  #4,%a0                          /* e21eae  A0 = &slot frame pointer */
        movea.l %a0,%a2                         /* e21eb0 */
        cmpi.w  #0x1234,(%a4)+                  /* e21eb2  frame tagged? */
        beq.b   .Lps_frame                      /* e21eb6 */
        clr.l   (%a0)                           /* e21eb8  no saved frame */
        bra.b   .Lps_live                       /* e21eba */
.Lps_frame:
        clr.w   %d0                             /* e21ebc */
        move.b  (1,%a4),%d0                     /* e21ebe  fsave frame size */
        addq.w  #4,%d0                          /* e21ec2 */
        adda.l  %d0,%a4                         /* e21ec4  d9c0 */
        lsr.w   #1,%d0                          /* e21ec6 */
        subq.l  #1,%d0                          /* e21ec8 */
.Lps_copy_frame:
        move.w  -(%a4),-(%a0)                   /* e21eca */
        dbf     %d0,.Lps_copy_frame             /* e21ecc */
        cmpi.w  #0x1234,(%a3)+                  /* e21ed0  registers tagged? */
        bne.b   .Lps_done                       /* e21ed4 */
        adda.l  #108,%a3                        /* e21ed6  d7fc 0000 006c: 27 longwords */
        move.w  #26,%d0                         /* e21edc */
.Lps_copy_regs:
        move.l  -(%a3),-(%a0)                   /* e21ee0 */
        dbf     %d0,.Lps_copy_regs              /* e21ee2 */
        move.w  #-1,-(%a0)                      /* e21ee6  0xFFFF: registers present */
        move.l  %a0,(%a2)                       /* e21eea  slot's frame pointer */
        bra.b   .Lps_done                       /* e21eec */
.Lps_live:
        cmpi.w  #0x1234,(%a3)+                  /* e21eee */
        bne.b   .Lps_done                       /* e21ef2 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21ef4 */
        jsr     (ML_$EXCLUSION_START).l         /* e21ef8 */
        addq.l  #4,%sp                          /* e21efe */
        bsr.w   fp_$switch_owner                /* e21f00  6100 fc0e */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21f04 */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21f08 */
        addq.l  #4,%sp                          /* e21f0e */
        fmovem.l (%a3)+,%fpcr/%fpsr/%fpiar      /* e21f10  f21b 9c00 */
        fmovem.x (%a3)+,%fp0-%fp7               /* e21f14  f21b d0ff */
.Lps_done:
        movem.l (%sp)+,%d2-%d3/%a2-%a4          /* e21f18 */
        rts                                     /* e21f1c */
        .if !fpu_enable_ccr && !fpa_board
        .short  0x0000                          /* e21f1e  pad; FIM_$SPURIOUS_INT is at 0xE21F20 */
        .endif
        .endif
