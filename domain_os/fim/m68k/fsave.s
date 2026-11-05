/*
 * fim/m68k/fsave.s - FIM_$FSAVE, save the FPU context for a fault frame
 * (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21C34..0x00E21CD3 (map
 * FIM_$FSAVE to FIM_$FRESTORE, 160 bytes), in its own section.
 *
 *   void FIM_$FSAVE(int16_t *saved, uint32_t *bufp, <word> mode)
 *        after the 8-register save: 0x24(SP), 0x28(SP), and the word at
 *        0x2C(SP), compared with 1
 *
 * Under FP_$EXCLUSION, after making the current address space the FPU owner
 * when an FPU is configured, *saved = 0, then:
 *   - mode 1: `fsave'.  If M68881_EXISTS (tested as a word) is zero, that
 *     frame is kept.  Otherwise bit 3 of the byte at 0x38(SP) in it is set,
 *     the control registers are pushed, bit 0 of the byte at 4(SP) (the
 *     high byte of the pushed FPSR) is cleared, a null frame is restored
 *     (resetting the FPU) and the control registers are reloaded; go on as
 *     for any mode.
 *   - with M68881_EXISTS non-zero, `fsave' again and keep that frame if its
 *     first word is 0x3FD4 (a 68882 busy frame); otherwise drop everything
 *     saved and push the flag word 0.
 * A kept frame is topped by the flag word 1, copied below *bufp by
 * fim_$copy_fp_frame (length, word sum, words), *bufp moves down to it and
 * *saved = 1.
 *
 * With `fpa_board' (the SAU7: FIM_$FSAVE 0x3C426B96) the accelerator's
 * state goes on top of the FPU's when FPA_$SAVEP is set: under the
 * accelerator's lock the current address space is made its owner
 * (fpa_$switch_owner, fim/sau7/fpa.s) and, in mode 2 or when bit 4 of
 * its control and status register is set, 30 bytes are pushed (the
 * register, its exception register, the longword at 16#FFFFBC14 and 18
 * status bytes, the register's bit 31 cleared while they are read, then
 * set and bit 4 cleared), topped by the flag word 2; FPA_$DEBUG6 and
 * FPA_$DEBUG7 count them.  Those lines carry the SAU7 image's addresses.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations (the call into fim/m68k/fp_init.s's helper keeps its
 * `jsr (d16,PC)' form as R_68K_PC16).
 *
 * Not on the SAUs whose floating-point registers are the CPU's own
 * (`fp_state_in_cpu', base/config.ins.pas): the SAU4's map has no
 * FIM_$FSAVE.
 */

        .include "base/config.inc"
        .if !fp_state_in_cpu && !fpu_enable_mmu_9   /* the SAU6's: fim/sau6/fp.s */

        .section ".text.FIM_$FSAVE","ax",@progbits
        .even

        .extern FP_$SAVEP               /* fp/m68k/savep.s, map 0xE218D0 */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */
        .extern fp_$switch_owner        /* fp/m68k/fp_context.s, image 0xE21B10 */
        .extern fim_$copy_fp_frame      /* fim/m68k/fp_init.s, image 0xE21C04 */
        /* M68881_EXISTS: peb/peb.ins.pas, map 0xE8180C (the 4-byte
         * PEB_UNWIRED segment; a longword whose first byte is the flag).
         * Tested as a WORD here, its first word. */
        .extern M68881_EXISTS
        .if fpa_board
        .extern FPA_$SAVEP              /* fp/m68k/savep.s */
        .extern fpa_$exclusion          /* fp/m68k/savep.s */
        .extern fpa_$switch_owner       /* fim/sau7/fpa.s */
        .extern FPA_$DEBUG6             /* fim/sau7/fpa.s */
        .extern FPA_$DEBUG7             /* fim/sau7/fpa.s */
        /* The accelerator's control and status register and its
         * exception register (FIM_$FP_GET_FPCSR's, FIM_$FP_GET_EIR's,
         * fim/sau7/fpa_regs.s). */
        .equ    FPA_CSR, 0xFFF90000
        .equ    FPA_EIR, 0xFFF80000
        .endif

        .global FIM_$FSAVE
FIM_$FSAVE:
        movem.l %d0-%d3/%a0-%a3,-(%sp)          /* e21c34 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21c38 */
        jsr     (ML_$EXCLUSION_START).l         /* e21c3c */
        addq.l  #4,%sp                          /* e21c42 */
        tst.l   (FP_$SAVEP).l                   /* e21c44 */
        beq.b   .Lfs_owned                      /* e21c4a */
        bsr.w   fp_$switch_owner                /* e21c4c  6100 fec2 */
.Lfs_owned:
        movea.l (0x24,%sp),%a3                  /* e21c50 */
        clr.w   (%a3)                           /* e21c54  *saved = 0 */
        movea.l %sp,%a3                         /* e21c56  A3 = frame base */
        cmpi.w  #1,(0x2c,%a3)                   /* e21c58  mode 1? */
        bne.b   .Lfs_save                       /* e21c5e */
        fsave   -(%sp)                          /* e21c60 */
        tst.w   (M68881_EXISTS).l               /* e21c62  4a79 00e8 180c */
        beq.w   .Lfs_keep                       /* e21c68  6700 0030 */
        bset.b  #3,(0x38,%sp)                   /* e21c6c  08ef 0003 0038 */
        fmovem.l %fpcr/%fpsr/%fpiar,-(%sp)      /* e21c72  f227 bc00 */
        bclr.b  #0,(4,%sp)                      /* e21c76  08af 0000 0004 */
        clr.l   -(%sp)                          /* e21c7c  a null frame ... */
        frestore (%sp)+                         /* e21c7e  ... resets the FPU */
        fmovem.l (%sp)+,%fpcr/%fpsr/%fpiar      /* e21c80  f21f 9c00 */
.Lfs_save:
        tst.w   (M68881_EXISTS).l               /* e21c84 */
        beq.b   .Lfs_discard                    /* e21c8a */
        fsave   -(%sp)                          /* e21c8c */
        cmpi.w  #0x3fd4,(%sp)                   /* e21c8e */
        beq.b   .Lfs_keep                       /* e21c92 */
.Lfs_discard:
        movea.l %a3,%sp                         /* e21c94 */
        clr.w   -(%sp)                          /* e21c96  flag 0: nothing kept */
        bra.b   .Lfs_unlock                     /* e21c98 */
.Lfs_keep:
        move.w  #1,-(%sp)                       /* e21c9a  flag 1: frame kept */
.Lfs_unlock:
        pea     (FP_$EXCLUSION:w,%pc)           /* e21c9e */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21ca2 */
        addq.l  #4,%sp                          /* e21ca8 */
        .if fpa_board
        move.l  (FPA_$SAVEP:w,%pc),%d0          /* sau7 3c426c0c  203a f780 */
        beq.w   .Lfs_no_fpa                     /* sau7 3c426c10  6700 00ca  no accelerator */
        pea     (fpa_$exclusion:w,%pc)          /* sau7 3c426c14  487a f77e */
        jsr     (ML_$EXCLUSION_START).l         /* sau7 3c426c18  4eb9 3c42 529a */
        addq.l  #4,%sp                          /* sau7 3c426c1e  588f */
        bsr.w   fpa_$switch_owner               /* sau7 3c426c20  6100 fab2 */
        cmpi.w  #2,(0x2c,%a3)                   /* sau7 3c426c24  0c6b 0002 002c  mode 2? */
        beq.s   .Lfs_fpa_save                   /* sau7 3c426c2a  6714 */
        move.l  (FPA_CSR).l,%d0                 /* sau7 3c426c2c  2039 fff9 0000 */
        btst    #4,%d0                          /* sau7 3c426c32  0800 0004 */
        beq.w   .Lfs_fpa_unlock                 /* sau7 3c426c36  6700 0098  nothing to keep */
        addq.w  #1,(FPA_$DEBUG6).l              /* sau7 3c426c3a  5279 3c42 664c */
.Lfs_fpa_save:
        addq.w  #1,(FPA_$DEBUG7).l              /* sau7 3c426c40  5279 3c42 664e */
        movea.l %sp,%a0                         /* sau7 3c426c46  204f */
        suba.l  #30,%sp                         /* sau7 3c426c48  9ffc 0000 001e  the state, 30 bytes */
        move.l  (FPA_CSR).l,%d0                 /* sau7 3c426c4e  2039 fff9 0000 */
        move.l  %d0,-(%a0)                      /* sau7 3c426c54  2100 */
        move.l  (FPA_EIR).l,-(%a0)              /* sau7 3c426c56  2139 fff8 0000 */
        bclr    #31,%d0                         /* sau7 3c426c5c  0880 001f */
        move.l  %d0,(FPA_CSR).l                 /* sau7 3c426c60  23c0 fff9 0000 */
        move.l  (0xffffbc14).w,-(%a0)           /* sau7 3c426c66  2138 bc14 */
        move.b  (0xffff8083).w,-(%a0)           /* sau7 3c426c6a  1138 8083  the WTK status bytes */
        move.b  (0xffff808b).w,-(%a0)           /* sau7 3c426c6e  1138 808b */
        move.b  (0xffff8093).w,-(%a0)           /* sau7 3c426c72  1138 8093 */
        move.b  (0xffff809b).w,-(%a0)           /* sau7 3c426c76  1138 809b */
        move.b  (0xffff8087).w,-(%a0)           /* sau7 3c426c7a  1138 8087 */
        move.b  (0xffff808f).w,-(%a0)           /* sau7 3c426c7e  1138 808f */
        move.b  (0xffff8097).w,-(%a0)           /* sau7 3c426c82  1138 8097 */
        move.b  (0xffff809f).w,-(%a0)           /* sau7 3c426c86  1138 809f */
        move.b  (0xffff80a3).w,-(%a0)           /* sau7 3c426c8a  1138 80a3 */
        move.b  (0xffff80ab).w,-(%a0)           /* sau7 3c426c8e  1138 80ab */
        move.b  (0xffff80b3).w,-(%a0)           /* sau7 3c426c92  1138 80b3 */
        move.b  (0xffff80bb).w,-(%a0)           /* sau7 3c426c96  1138 80bb */
        move.b  (0xffff8083).w,-(%a0)           /* sau7 3c426c9a  1138 8083 */
        move.b  (0xffff808b).w,-(%a0)           /* sau7 3c426c9e  1138 808b */
        move.b  (0xffff8093).w,-(%a0)           /* sau7 3c426ca2  1138 8093 */
        move.b  (0xffff809b).w,-(%a0)           /* sau7 3c426ca6  1138 809b */
        move.b  (0xffff8087).w,-(%a0)           /* sau7 3c426caa  1138 8087 */
        move.b  (0xffff808f).w,-(%a0)           /* sau7 3c426cae  1138 808f */
        move.b  #0,(0xffff80fb).w               /* sau7 3c426cb2  11fc 0000 80fb */
        move.b  #0,(0xffff80db).w               /* sau7 3c426cb8  11fc 0000 80db */
        bset    #31,%d0                         /* sau7 3c426cbe  08c0 001f */
        bclr    #4,%d0                          /* sau7 3c426cc2  0880 0004 */
        move.l  %d0,(FPA_CSR).l                 /* sau7 3c426cc6  23c0 fff9 0000 */
        move.w  #2,-(%sp)                       /* sau7 3c426ccc  3f3c 0002  flag 2: the accelerator's state */
.Lfs_fpa_unlock:
        pea     (fpa_$exclusion:w,%pc)          /* sau7 3c426cd0  487a f6c2 */
        jsr     (ML_$EXCLUSION_STOP).l          /* sau7 3c426cd4  4eb9 3c42 5320 */
        addq.l  #4,%sp                          /* sau7 3c426cda  588f */
.Lfs_no_fpa:
        .endif
        tst.w   (%sp)                           /* e21caa */
        bne.b   .Lfs_copy                       /* e21cac */
        addq.l  #2,%sp                          /* e21cae */
        bra.b   .Lfs_done                       /* e21cb0 */
.Lfs_copy:
        movea.l %sp,%a0                         /* e21cb2  A0 = flag word */
        movea.l (0x28,%a3),%a1                  /* e21cb4 */
        movea.l (%a1),%a1                       /* e21cb8  A1 = *bufp */
        jsr     (fim_$copy_fp_frame:w,%pc)      /* e21cba  4eba ff48 */
        movea.l %a3,%sp                         /* e21cbe */
        movea.l (0x28,%sp),%a3                  /* e21cc0 */
        move.l  %a1,(%a3)                       /* e21cc4  *bufp = A1 */
        movea.l (0x24,%sp),%a3                  /* e21cc6 */
        move.w  #1,(%a3)                        /* e21cca  *saved = 1 */
.Lfs_done:
        movem.l (%sp)+,%d0-%d3/%a0-%a3          /* e21cce */
        rts                                     /* e21cd2 */
        .endif
