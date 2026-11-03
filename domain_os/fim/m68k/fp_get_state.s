/*
 * fim/m68k/fp_get_state.s - FIM_$FP_GET_STATE (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21DC2..0x00E21E85 (map
 * FIM_$FP_GET_STATE to FIM_$FP_PUT_STATE, 196 bytes), in its own
 * section.
 *
 *   void FIM_$FP_GET_STATE(void *regs, void *frame)
 *        0x14(SP), 0x18(SP) after the 4-register save
 *
 * Copies the current address space's saved 68881 state into two
 * caller buffers, each starting with a longword that receives the number
 * of bytes used, that longword included.  If the current address space owns the FPU,
 * its live state is first saved (fp_$save_state) and ownership dropped,
 * under FP_$EXCLUSION.  Then, if its save slot holds a non-null frame with
 * registers: regs gets the word 0x1234 and 27 longwords (FPCR/FPSR/FPIAR
 * and FP0-FP7), frame gets the word 0x1234 and the (size byte + 4) / 2
 * words of the fsave frame (D1 = size + 4 is computed and not used).  Otherwise each
 * buffer gets a single zero word.
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
 *
 * Not on the SAUs whose floating-point registers are the CPU's own
 * (`fp_state_in_cpu', base/config.ins.pas): the SAU4's routine is
 * in fim/sau4/fp.s.
 */

        .include "base/config.inc"
        .if !fp_state_in_cpu

        .section ".text.FIM_$FP_GET_STATE","ax",@progbits
        .even

        .extern PROC1_$AS_ID            /* uint16_t, map 0xE2060A */
        .extern FP_$SAVEP               /* fp/m68k/savep.s, map 0xE218D0 */
        .extern FP_$OWNER               /* fp/m68k/savep.s, map 0xE218D4 */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */
        .extern fp_$save_state          /* fp/m68k/fp_context.s, image 0xE21B5C */

        /* The FPU owner register (SAU2 MMU page). */
        .equ    FP_HW_OWNER, 0x00FFB402

        .global FIM_$FP_GET_STATE
FIM_$FP_GET_STATE:
        movem.l %d2/%a2-%a4,-(%sp)              /* e21dc2 */
        movea.l (0x14,%sp),%a3                  /* e21dc6  A3 = regs */
        movea.l (0x18,%sp),%a4                  /* e21dca  A4 = frame */
        addq.l  #4,%a3                          /* e21dce  past the count longword */
        addq.l  #4,%a4                          /* e21dd0 */
        move.l  (FP_$SAVEP:w,%pc),%d0           /* e21dd2  203a fafc */
        beq.w   .Lgs_none                       /* e21dd6  6700 0090: no FPU */
        move.w  (PROC1_$AS_ID).l,%d0            /* e21dda */
        cmp.w   (FP_$OWNER:w,%pc),%d0           /* e21de0 */
        bne.b   .Lgs_read                       /* e21de4 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21de6 */
        jsr     (ML_$EXCLUSION_START).l         /* e21dea */
        addq.l  #4,%sp                          /* e21df0 */
        move.w  (PROC1_$AS_ID).l,%d0            /* e21df2 */
        cmp.w   (FP_$OWNER:w,%pc),%d0           /* e21df8  still the owner? */
        bne.b   .Lgs_unlock                     /* e21dfc */
        movea.l (FP_$SAVEP:w,%pc),%a1           /* e21dfe */
        bsr.w   fp_$save_state                  /* e21e02  6100 fd58 (D0 = asid) */
        clr.w   (FP_$OWNER).l                   /* e21e06  4279 00e2 18d4 */
        .if fpu_enable_ccr
        bclr    #7,(MMU_CCR).l                  /* sau9 3c424a7a  08b9 0007 3ff9 f2d0 */
        .elseif fpu_enable_cpu_control
        move.w  %sr,%d2                         /* sau8 3c236e2  40c2 */
        ori.w   #0x700,%sr                      /* sau8 3c236e4  007c 0700 */
        move.w  (MMU_$PID_PRIV).l,%d1           /* sau8 3c236e8  3239 03c2 56a4  the CPU control copy */
        bset    #2,%d1                          /* sau8 3c236ee  08c1 0002 */
        move.w  %d1,(MMU_$PID_PRIV).l           /* sau8 3c236f2  33c1 03c2 56a4 */
        move.b  %d1,(MMU+0x101).l               /* sau8 3c236f8  13c1 03ff b501  the CPU control register */
        move.w  %d2,%sr                         /* sau8 3c236fe  46c2 */
        .else
        move.b  #0,(FP_HW_OWNER).l              /* e21e0c  13fc 0000 00ff b402 */
        .endif
.Lgs_unlock:
        pea     (FP_$EXCLUSION:w,%pc)           /* e21e14 */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21e18 */
        addq.l  #4,%sp                          /* e21e1e */
.Lgs_read:
        movea.l (FP_$SAVEP:w,%pc),%a0           /* e21e20 */
        move.w  (PROC1_$AS_ID).l,%d0            /* e21e24 */
        mulu.w  #0x14a,%d0                      /* e21e2a  FP_SAVE_AREA_SIZE */
        move.l  (-4,%a0,%d0.l),%d0              /* e21e2e  2030 08fc: slot's frame */
        beq.b   .Lgs_none                       /* e21e32 */
        movea.l %d0,%a0                         /* e21e34 */
        tst.b   (1,%a0)                         /* e21e36  registers present? */
        beq.b   .Lgs_none                       /* e21e3a */
        addq.l  #2,%a0                          /* e21e3c  past the 0xFFFF marker */
        move.w  #0x1234,(%a3)+                  /* e21e3e */
        move.w  #26,%d0                         /* e21e42  27 longwords */
.Lgs_regs:
        move.l  (%a0)+,(%a3)+                   /* e21e46 */
        dbf     %d0,.Lgs_regs                   /* e21e48 */
        moveq   #0,%d0                          /* e21e4c */
        move.b  (1,%a0),%d0                     /* e21e4e  fsave frame size */
        move.l  %d0,%d1                         /* e21e52 */
        addq.l  #4,%d1                          /* e21e54 */
        addq.l  #4,%d0                          /* e21e56 */
        lsr.l   #1,%d0                          /* e21e58 */
        subq.l  #1,%d0                          /* e21e5a */
        move.w  #0x1234,(%a4)+                  /* e21e5c */
.Lgs_frame:
        move.w  (%a0)+,(%a4)+                   /* e21e60 */
        dbf     %d0,.Lgs_frame                  /* e21e62 */
        bra.b   .Lgs_counts                     /* e21e66 */
.Lgs_none:
        move.w  #0,(%a3)+                       /* e21e68  36fc 0000 */
        move.w  #0,(%a4)+                       /* e21e6c  38fc 0000 */
.Lgs_counts:
        movea.l (0x14,%sp),%a0                  /* e21e70 */
        suba.l  %a0,%a3                         /* e21e74 */
        move.l  %a3,(%a0)                       /* e21e76  regs count (includes itself) */
        movea.l (0x18,%sp),%a0                  /* e21e78 */
        suba.l  %a0,%a4                         /* e21e7c */
        move.l  %a4,(%a0)                       /* e21e7e */
        movem.l (%sp)+,%d2/%a2-%a4              /* e21e80 */
        rts                                     /* e21e84 */
        .endif
