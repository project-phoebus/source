/*
 * fim/m68k/fp_init.s - FIM_$FP_INIT and the FSAVE-frame copier
 * (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21BB0..0x00E21C33 (map
 * FIM_$FP_INIT to FIM_$FSAVE, 132 bytes: 84 of FIM_$FP_INIT and the
 * 48-byte helper fim_$copy_fp_frame at 0x00E21C04, which the map counts into
 * it), in its own section.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.
 *
 * With `fpu_enable_ccr' (base/config.ins.pas: the SAU9) the FPU is
 * enabled and disabled with bit 7 of MMU_CCR where the SAU2 writes the
 * FPU owner register (0xFFB402); those lines carry the SAU9 image's
 * addresses.
 * With `fpu_enable_cpu_control' (the SAU8) they set and clear bit 2 of
 * the CPU control register (MMU + 0x101) and of its copy, MMU_$PID_PRIV's
 * low byte, at IPL 7; those lines carry the SAU8 image's addresses.
 */

        .include "base/config.inc"

        .section ".text.FIM_$FP_INIT","ax",@progbits
        .even

        .extern FP_$SAVEP               /* fp/m68k/savep.s, map 0xE218D0 */
        .extern FP_$OWNER               /* fp/m68k/savep.s, map 0xE218D4 */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */

        /* The FPU owner register (SAU2 MMU page):
         * the low byte of the owning address space. */
        .equ    FP_HW_OWNER, 0x00FFB402

/* ====================================================================
 * FIM_$FP_INIT - 0x00E21BB0
 *
 *   void FIM_$FP_INIT(int16_t asid)             asid at 0x4(SP)
 *
 * Gives asid a fresh FP context.  With an FPU configured: if asid owns the
 * FPU, then under FP_$EXCLUSION (and re-checked there) ownership is
 * dropped - FP_$OWNER = 0 and the hardware owner register cleared - so
 * nothing is saved for it; in all cases the slot's saved-frame pointer,
 * the last longword of its 0x14A-byte save area, is cleared.
 * ==================================================================== */
        .global FIM_$FP_INIT
FIM_$FP_INIT:
        tst.l   (FP_$SAVEP).l                   /* e21bb0  4ab9 00e2 18d0 */
        beq.b   .Lfpi_done                      /* e21bb6  no FPU */
        move.w  (0x4,%sp),%d1                   /* e21bb8  D1 = asid */
        cmp.w   (FP_$OWNER:w,%pc),%d1           /* e21bbc  b27a fd16 */
        bne.b   .Lfpi_clear                     /* e21bc0 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21bc2 */
        jsr     (ML_$EXCLUSION_START).l         /* e21bc6 */
        addq.l  #4,%sp                          /* e21bcc */
        move.w  (0x4,%sp),%d1                   /* e21bce */
        cmp.w   (FP_$OWNER:w,%pc),%d1           /* e21bd2  still the owner? */
        bne.b   .Lfpi_unlock                    /* e21bd6 */
        clr.w   (FP_$OWNER).l                   /* e21bd8  4279 00e2 18d4 */
        .if fpu_enable_ccr
        bset    #7,(MMU_CCR).l                  /* sau9 3c42484a  08f9 0007 3ff9 f2d0 */
        .elseif fpu_enable_cpu_control
        move.w  %sr,%d0                         /* sau8 3c23486  40c0 */
        ori.w   #0x700,%sr                      /* sau8 3c23488  007c 0700 */
        move.w  (MMU_$PID_PRIV).l,%d1           /* sau8 3c2348c  3239 03c2 56a4  the CPU control copy */
        bset    #2,%d1                          /* sau8 3c23492  08c1 0002 */
        move.w  %d1,(MMU_$PID_PRIV).l           /* sau8 3c23496  33c1 03c2 56a4 */
        move.b  %d1,(MMU+0x101).l               /* sau8 3c2349c  13c1 03ff b501  the CPU control register */
        move.w  %d0,%sr                         /* sau8 3c234a2  46c0 */
        .else
        move.b  #0,(FP_HW_OWNER).l              /* e21bde  13fc 0000 00ff b402 */
        .endif
.Lfpi_unlock:
        pea     (FP_$EXCLUSION:w,%pc)           /* e21be6 */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21bea */
        addq.l  #4,%sp                          /* e21bf0 */
        move.w  (0x4,%sp),%d1                   /* e21bf2 */
.Lfpi_clear:
        movea.l (FP_$SAVEP:w,%pc),%a0           /* e21bf6  207a fcd8 */
        mulu.w  #0x14a,%d1                      /* e21bfa  FP_SAVE_AREA_SIZE */
        clr.l   (-4,%a0,%d1.w)                  /* e21bfe  42b0 10fc: slot's frame pointer */
.Lfpi_done:
        rts                                     /* e21c02 */

/* ====================================================================
 * fim_$copy_fp_frame - 0x00E21C04 (module-local; no map or Ghidra name)
 *
 * Register convention, called by FIM_$FSAVE (`jsr (-0xb8,PC)' at
 * 0x00E21CBA): A0 = the flag word (0 or 1) that FIM_$FSAVE pushed on top
 * of an `fsave' frame, A1 = end of the caller's buffer, written downward.
 * If the flag is 1 the frame's size byte (second byte of the frame) plus
 * the 4-byte header is added, so D0 = 2 (+ 4 + size) bytes are copied,
 * last word first, to -(A1); then their 32-bit word sum and D0 are pushed
 * on -(A1) the same way.  FIM_$FRESTORE checks that sum.  Returns A1 at the
 * length longword.  Clobbers D0-D3, A0.
 * ==================================================================== */
        .global fim_$copy_fp_frame
fim_$copy_fp_frame:
        clr.l   %d1                             /* e21c04 */
        clr.l   %d3                             /* e21c06 */
        cmpi.w  #1,(%a0)+                       /* e21c08  frame present? */
        bne.b   .Lcff_count                     /* e21c0c */
        move.b  (1,%a0),%d3                     /* e21c0e  frame size byte */
        addq.l  #4,%d3                          /* e21c12  + format word + header */
        adda.l  %d3,%a0                         /* e21c14  A0 = end of the frame */
        add.l   %d3,%d1                         /* e21c16 */
.Lcff_count:
        addq.l  #2,%d1                          /* e21c18  + the flag word */
        move.l  %d1,%d0                         /* e21c1a  D0 = bytes copied */
        lsr.l   #1,%d1                          /* e21c1c */
        subq.l  #1,%d1                          /* e21c1e  words - 1 */
        clr.l   %d3                             /* e21c20  sum */
        clr.l   %d2                             /* e21c22 */
.Lcff_loop:
        move.w  -(%a0),%d2                      /* e21c24 */
        add.l   %d2,%d3                         /* e21c26 */
        move.w  %d2,-(%a1)                      /* e21c28 */
        dbf     %d1,.Lcff_loop                  /* e21c2a  51c9 fff8 */
        move.l  %d3,-(%a1)                      /* e21c2e  sum */
        move.l  %d0,-(%a1)                      /* e21c30  length */
        rts                                     /* e21c32 */
