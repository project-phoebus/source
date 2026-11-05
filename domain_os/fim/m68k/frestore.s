/*
 * fim/m68k/frestore.s - FIM_$FRESTORE, reload an FPU context saved by
 * FIM_$FSAVE (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21CD4..0x00E21D47 (map
 * FIM_$FRESTORE to FP_$GET_FP, 116 bytes), in its own section.  Also
 * SVC trap 3 entry 0x35 (svc/m68k/svc_tables.s).
 *
 *   void FIM_$FRESTORE(void **statep)     0x24(SP) after the 8-register save
 *
 * *statep points at a record written by fim_$copy_fp_frame (length, word
 * sum, then the flag word and fsave frame).  The words are copied onto the
 * stack, last first, while being summed.  If the sum does not match, the
 * registers are restored, the return address and argument dropped, and
 * the fault "coprocessor protocol violation" (0x0012002D, signal 0x13) is
 * raised by entering FIM_$COM with a descriptor, as FIM_$PARITY_TRAP does.
 * Otherwise, if the flag word is 1, the frame is `frestore'd under
 * FP_$EXCLUSION after making the current address space the FPU owner.
 *
 * The descriptor's class word is pushed from the word at absolute
 * address 0x2000.
 *
 * With `fpa_board' (the SAU7: FIM_$FRESTORE 0x3C426D06) a state topped by
 * the flag word 2 is the accelerator's (FIM_$FSAVE's): under its lock,
 * after making the current address space its owner (fpa_$switch_owner,
 * fim/sau7/fpa.s), its 30 bytes are written back, each status byte to
 * its write address, the control and status register last; bit 1 of
 * the status byte at 16#FFFF8093, bits 2..1 of the one at 16#FFFF8083 and
 * bits 25..14 of the register keep their live values.  FPA_$DEBUG8
 * counts it; the FPU's flag word and frame below it then go as above.
 * Those lines carry the SAU7 image's addresses.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.  The absolute jmp to FIM_$COM (fim/m68k/com.s) is
 * relocated.
 *
 * Not on the SAUs whose floating-point registers are the CPU's own
 * (`fp_state_in_cpu', base/config.ins.pas): the SAU4's routine is
 * in fim/sau4/fp.s.
 */

        .include "base/config.inc"
        .if !fp_state_in_cpu && !fpu_enable_mmu_9   /* the SAU6's: fim/sau6/fp.s */
        .section ".text.FIM_$FRESTORE","ax",@progbits
        .even

        .extern FP_$EXCLUSION           /* fp/m68k/savep.s, image 0xE218D6 */
        .extern ML_$EXCLUSION_START     /* map 0xE20DF8 */
        .extern ML_$EXCLUSION_STOP      /* map 0xE20E7E */
        .extern fp_$switch_owner        /* fp/m68k/fp_context.s, image 0xE21B10 */

        .extern FIM_COM                 /* fim/m68k/com.s: FIM_$COM, map 0xE213A4 */
        .if fpa_board
        .extern fpa_$exclusion          /* fp/m68k/savep.s */
        .extern fpa_$switch_owner       /* fim/sau7/fpa.s */
        .extern FPA_$DEBUG8             /* fim/sau7/fpa.s */
        /* The accelerator's control and status register and its
         * exception register (fim/sau7/fpa_regs.s). */
        .equ    FPA_CSR, 0xFFF90000
        .equ    FPA_EIR, 0xFFF80000
        .endif

        .global FIM_$FRESTORE
FIM_$FRESTORE:
        movem.l %d0-%d3/%a0-%a3,-(%sp)          /* e21cd4 */
        movea.l %sp,%a3                         /* e21cd8 */
        movea.l (0x24,%sp),%a0                  /* e21cda */
        movea.l (%a0),%a0                       /* e21cde  A0 = *statep */
        move.l  (%a0)+,%d1                      /* e21ce0  length */
        move.l  (%a0)+,%d0                      /* e21ce2  word sum */
        adda.l  %d1,%a0                         /* e21ce4 */
        lsr.l   #1,%d1                          /* e21ce6 */
        subq.l  #1,%d1                          /* e21ce8 */
        clr.l   %d3                             /* e21cea */
        clr.l   %d2                             /* e21cec */
.Lfr_copy:
        move.w  -(%a0),%d2                      /* e21cee */
        add.l   %d2,%d3                         /* e21cf0 */
        move.w  %d2,-(%sp)                      /* e21cf2 */
        dbf     %d1,.Lfr_copy                   /* e21cf4  51c9 fff8 */
        cmp.l   %d3,%d0                         /* e21cf8 */
        beq.b   .Lfr_restore                    /* e21cfa */
        movea.l %a3,%sp                         /* e21cfc */
        movem.l (%sp)+,%d0-%d3/%a0-%a3          /* e21cfe */
        addq.w  #8,%sp                          /* e21d02  return address, argument */
        move.w  (0x2000).w,-(%sp)               /* e21d04  3f38 2000: see the header */
        move.w  #0x13,-(%sp)                    /* e21d08  signal number */
        move.l  #0x0012002D,-(%sp)              /* e21d0c  "coprocessor protocol violation" */
        pea     (%sp)                           /* e21d12  &descriptor */
        pea     (0xc,%sp)                       /* e21d14  &exception frame */
        jmp     (FIM_COM).l                     /* e21d18  4ef9 00e2 13a4 */
.Lfr_restore:
        .if fpa_board
        cmpi.w  #2,(%sp)                        /* sau7 3c426d50  0c57 0002  the accelerator's state? */
        bne.w   .Lfr_fpu                        /* sau7 3c426d54  6600 00c4 */
        addq.w  #1,(FPA_$DEBUG8).l              /* sau7 3c426d58  5279 3c42 6650 */
        pea     (fpa_$exclusion:w,%pc)          /* sau7 3c426d5e  487a f634 */
        jsr     (ML_$EXCLUSION_START).l         /* sau7 3c426d62  4eb9 3c42 529a */
        addq.l  #4,%sp                          /* sau7 3c426d68  588f */
        bsr.w   fpa_$switch_owner               /* sau7 3c426d6a  6100 f968 */
        addq.l  #2,%sp                          /* sau7 3c426d6e  548f  the flag word */
        movea.l %sp,%a0                         /* sau7 3c426d70  204f  A0 = the 30 bytes */
        move.l  (FPA_CSR).l,%d0                 /* sau7 3c426d72  2039 fff9 0000 */
        move.l  %d0,%d3                         /* sau7 3c426d78  2600 */
        .short  0xc6bc, 0x03ff, 0xc000          /* sau7 3c426d7a  c6bc 03ff c000  and.l #0x03ffc000,%d3: the bits kept */
        bclr    #31,%d0                         /* sau7 3c426d80  0880 001f */
        move.l  %d0,(FPA_CSR).l                 /* sau7 3c426d84  23c0 fff9 0000 */
        move.b  (0xffff8093).w,%d1              /* sau7 3c426d8a  1238 8093 */
        .short  0xc23c, 0x0002                  /* sau7 3c426d8e  c23c 0002  and.b #2,%d1: its bit kept */
        move.b  (0xffff8083).w,%d2              /* sau7 3c426d92  1438 8083 */
        .short  0xc43c, 0x0006                  /* sau7 3c426d96  c43c 0006  and.b #6,%d2: its bits kept */
        move.b  (%a0)+,(0xffff804f).w           /* sau7 3c426d9a  11d8 804f */
        move.b  (%a0)+,(0xffff8047).w           /* sau7 3c426d9e  11d8 8047 */
        move.b  (%a0)+,(0xffff805b).w           /* sau7 3c426da2  11d8 805b */
        move.b  (%a0)+,(0xffff8053).w           /* sau7 3c426da6  11d8 8053 */
        move.b  (%a0)+,(0xffff804b).w           /* sau7 3c426daa  11d8 804b */
        move.b  (%a0)+,(0xffff8043).w           /* sau7 3c426dae  11d8 8043 */
        move.b  (%a0)+,(0xffff80fb).w           /* sau7 3c426db2  11d8 80fb  the WTK status bytes */
        move.b  (%a0)+,(0xffff80f3).w           /* sau7 3c426db6  11d8 80f3 */
        move.b  (%a0)+,(0xffff80eb).w           /* sau7 3c426dba  11d8 80eb */
        move.b  (%a0)+,(0xffff80e3).w           /* sau7 3c426dbe  11d8 80e3 */
        move.b  (%a0)+,(0xffff80df).w           /* sau7 3c426dc2  11d8 80df */
        move.b  (%a0)+,(0xffff80d7).w           /* sau7 3c426dc6  11d8 80d7 */
        move.b  (%a0)+,(0xffff80cf).w           /* sau7 3c426dca  11d8 80cf */
        move.b  (%a0)+,(0xffff80c7).w           /* sau7 3c426dce  11d8 80c7 */
        move.b  (%a0)+,(0xffff80db).w           /* sau7 3c426dd2  11d8 80db */
        move.b  (%a0)+,%d0                      /* sau7 3c426dd6  1018 */
        .short  0xc03c, 0x00fd                  /* sau7 3c426dd8  c03c 00fd  and.b #0xfd,%d0 */
        or.b    %d1,%d0                         /* sau7 3c426ddc  8001 */
        move.b  %d0,(0xffff80d3).w              /* sau7 3c426dde  11c0 80d3 */
        move.b  (%a0)+,(0xffff80cb).w           /* sau7 3c426de2  11d8 80cb */
        move.b  (%a0)+,%d0                      /* sau7 3c426de6  1018 */
        .short  0xc03c, 0x00f9                  /* sau7 3c426de8  c03c 00f9  and.b #0xf9,%d0 */
        or.b    %d2,%d0                         /* sau7 3c426dec  8002 */
        move.b  %d0,(0xffff80c3).w              /* sau7 3c426dee  11c0 80c3 */
        move.l  (%a0)+,(0xffffbc18).w           /* sau7 3c426df2  21d8 bc18 */
        move.l  (%a0)+,(FPA_EIR).l              /* sau7 3c426df6  23d8 fff8 0000 */
        move.l  (%a0)+,%d0                      /* sau7 3c426dfc  2018 */
        .short  0xc0bc, 0xfc00, 0x3fff          /* sau7 3c426dfe  c0bc fc00 3fff  and.l #0xfc003fff,%d0 */
        or.l    %d3,%d0                         /* sau7 3c426e04  8083 */
        move.l  %d0,(FPA_CSR).l                 /* sau7 3c426e06  23c0 fff9 0000 */
        movea.l %a0,%sp                         /* sau7 3c426e0c  2e48 */
        pea     (fpa_$exclusion:w,%pc)          /* sau7 3c426e0e  487a f584 */
        jsr     (ML_$EXCLUSION_STOP).l          /* sau7 3c426e12  4eb9 3c42 5320 */
        addq.l  #4,%sp                          /* sau7 3c426e18  588f */
.Lfr_fpu:
        .endif
        cmpi.w  #1,(%sp)+                       /* e21d1e  flag word */
        bne.b   .Lfr_done                       /* e21d22 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21d24 */
        jsr     (ML_$EXCLUSION_START).l         /* e21d28 */
        addq.l  #4,%sp                          /* e21d2e */
        bsr.w   fp_$switch_owner                /* e21d30  6100 fdde */
        frestore (%sp)+                         /* e21d34 */
        pea     (FP_$EXCLUSION:w,%pc)           /* e21d36 */
        jsr     (ML_$EXCLUSION_STOP).l          /* e21d3a */
        addq.l  #4,%sp                          /* e21d40 */
.Lfr_done:
        movem.l (%sp)+,%d0-%d3/%a0-%a3          /* e21d42 */
        rts                                     /* e21d46 */
        .endif
