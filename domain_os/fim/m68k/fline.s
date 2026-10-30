/*
 * fim/m68k/fline.s - FIM_$FLINE, the line-F (coprocessor) trap handler
 * (m68k/SAU2, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21ACC..0x00E21B0F (68 bytes), in its
 * own section.  The map gives FIM_$FLINE 0xB4 bytes because the FP
 * context helpers that follow it, 0x00E21B10..0x00E21B7F
 * (fp_$switch_owner .. fp_$save_state), carry no map symbol; they are
 * fp/m68k/fp_context.s's anchored section .text.fp_$switch_owner.
 *
 * Lazy FPU context switch: an FPU instruction from an address space that
 * does not own the 68881 traps here.  With an FPU configured (FP_$SAVEP
 * non-zero), a live address space and a different owner, the handler takes
 * FP_$EXCLUSION, switches the owner (fp_$switch_owner_d2 saves the old
 * owner's state and restores the new one's) and returns through FIM_$EXIT
 * to retry the instruction; otherwise it is an unimplemented instruction
 * and goes to FIM_$UII.  FIM_$BUS_ERR enters at fim_fline_switch (past the
 * FP_$SAVEP test) for an FPU access fault.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.  The PC-relative operands keep their form across sections
 * (R_68K_PC16), and so does `bsr.s fp_$switch_owner_d2' (R_68K_PC8: the
 * helper section follows this one in the link, as in the image).
 *
 * On the SAU9 (`parity_err_regs', base/config.ins.pas: its MMU's error
 * registers) FIM_$FLINE first clears a pending memory error (MMU_CCR
 * bit 4) and the current process's fault status word, and the section
 * starts 8 bytes earlier with FIM_$BUS_ERR's entry for an FPU access
 * fault (fim/sau9/bus_err.s), which saves the registers and joins
 * fim_fline_switch; those lines carry the SAU9 image's addresses.
 */

        .include "base/config.inc"

        .section ".text.FIM_$FLINE","ax",@progbits
        .even

        .extern PROC1_$AS_ID            /* uint16_t, map 0xE2060A */
        .extern FP_$SAVEP               /* fp/m68k/savep.s, map 0xE218D0 */
        .extern FP_$OWNER               /* fp/m68k/savep.s, map 0xE218D4 */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */
        .extern fp_$switch_owner_d2     /* fp/m68k/fp_context.s, image 0xE21B16 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */
        .extern FIM_$UII                /* fim/m68k/uii.s, map 0xE2146C */

        .if parity_err_regs
        /* sau9 3c424714: FIM_$BUS_ERR's entry for an FPU access fault,
           ahead of FIM_$FLINE in its section (no map name) */
        .global fim_fline_fault_entry
fim_fline_fault_entry:
        movem.l %d0-%d3/%a0-%a1,-(%sp)          /* sau9 3c424714  48e7 f0c0 */
        bra.b   fim_fline_switch                /* sau9 3c424718  6026 */
        .short  0                               /* sau9 3c42471a  pad */
        .endif

        .global FIM_$FLINE
FIM_$FLINE:
        movem.l %d0-%d3/%a0-%a1,-(%sp)          /* e21acc */
        .if parity_err_regs
        /* sau9: a pending memory error cleared (MMU_CCR bit 4) and the
           current process's fault status word with it */
        bset    #4,(MMU_CCR).l                  /* sau9 3c424720  08f9 0004 3ff9 f2d0 */
        bclr    #4,(MMU_CCR).l                  /* sau9 3c424728  08b9 0004 3ff9 f2d0 */
        movea.l (PROC1_$CURRENT_PCB).l,%a1      /* sau9 3c424730  2279 3c42 16c4 */
        clr.w   (0x5c,%a1)                      /* sau9 3c424736  4269 005c */
        .endif
        move.l  (FP_$SAVEP:w,%pc),%d0           /* e21ad0  203a fdfe */
        beq.b   .Lfline_uii                     /* e21ad4  no FPU */
        .global fim_fline_switch
fim_fline_switch:
        move.w  (PROC1_$AS_ID).l,%d2            /* e21ad6 */
        beq.b   .Lfline_uii                     /* e21adc  address space 0 */
        cmp.w   (FP_$OWNER:w,%pc),%d2           /* e21ade  b47a fdf4 */
        beq.b   .Lfline_uii                     /* e21ae2  already the owner */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21ae4  487a fdf0 */
        jsr     (ML_$EXCLUSION_START).l         /* e21ae8 */
        addq.l  #4,%sp                          /* e21aee */
        bsr.s   fp_$switch_owner_d2             /* e21af0  6124 (R_68K_PC8) */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21af2  487a fde2 */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21af6 */
        addq.l  #4,%sp                          /* e21afc */
        movem.l (%sp)+,%d0-%d3/%a0-%a1          /* e21afe */
        jmp     (FIM_$EXIT:w,%pc)               /* e21b02  4efa 0db8: retry */
.Lfline_uii:
        movem.l (%sp)+,%d0-%d3/%a0-%a1          /* e21b06 */
        jmp     (FIM_$UII).l                    /* e21b0a  4ef9 00e2 146c */
