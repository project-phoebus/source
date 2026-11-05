/*
 * fim/sau6/fp.s - the SAU6's FPU routines: FIM_$FLINE and its owner
 * switch, FIM_$FP_ABORT, FIM_$FP_INIT, FIM_$FSAVE, FIM_$FRESTORE,
 * FP_$GET_FP, FP_$PUT_FP, FIM_$FP_GET_STATE and FIM_$FP_PUT_STATE (SAU6)
 *
 * SAU6 map, in "D 78023E94 FIM_WIRED size = 131C": 0x780242CE (the bus
 * error handler's FPU entry, fim_fline_fault_entry, no map name, six
 * bytes ahead of FIM_$FLINE) to FIM_$SPURIOUS_INT (0x78024834).  One
 * section, keyed by FIM_$FLINE: the routines share the owner switch and
 * the save and restore helpers by `bsr'.  The SAU2's routines
 * (fim/m68k/fline.s .. fp_put_state.s, fp/m68k/fp_context.s) with the
 * DN5xxT's FPU (`fpu_enable_mmu_9', base/config.ins.pas):
 *   - the FPU is enabled by bit 7 of the byte at MMU + 9: set when no
 *     address space owns it (FIM_$FP_INIT, FIM_$FP_GET_STATE), cleared
 *     by the owner switch, where the SAU2 writes the FPU owner register;
 *   - FIM_$FLINE reads the MMU's word at +0xE first;
 *   - after each `fsave', when M68881_EXISTS is clear, 16#443E is
 *     written to the FPU interface's register 16#FFFFFC0A;
 *   - two helpers after FIM_$FP_INIT read and clear the interface's
 *     longword at 16#FFFFFFF8 with its register 16#FFFFFC82 set to 1
 *     and bit 5 of the byte at MMU + 16#1B cleared around it; the owner
 *     switch's restore calls the second for a saved state with bit 11 of
 *     its first word, and puts the state's control bits back;
 *   - FIM_$FSAVE, with M68881_EXISTS clear, saves the state with bit 4
 *     of MMU + 16#1B cleared and checks the interface's status (bits
 *     16#3E00 of its word) for a frame to keep.
 *
 * Byte gate (the SAU6 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68020 -m68881' and compared with the image at the map's
 * addresses, modulo relocations.  The Apollo assembler's <ea>=#imm forms
 * of CMP/AND (gas's CMPI/ANDI) are `.short' words.  The address and
 * byte columns are the SAU6 image's.
 */

        .include "base/config.inc"
        .if fpu_enable_mmu_9

        .extern FP_$SAVEP               /* fp/m68k/savep.s */
        .extern FP_$OWNER               /* fp/m68k/savep.s */
        .extern FP_$EXCLUSION           /* fp/m68k/savep.s */
        .extern ML_$EXCLUSION_START
        .extern ML_$EXCLUSION_STOP
        .extern PROC1_$AS_ID
        .extern FIM_$EXIT               /* fim/m68k/exit.s */
        .extern FIM_$UII                /* fim/m68k/uii.s */
        .extern M68881_EXISTS
        .extern MMU                     /* I/O definitions */

        .section ".text.FIM_$FLINE","ax",@progbits
        .even

        .global fim_fline_fault_entry
        .global FIM_$FLINE
        .global FIM_$FP_ABORT
        .global FIM_$FP_INIT
        .global FIM_$FSAVE
        .global FIM_$FRESTORE
        .global FP_$GET_FP
        .global FP_$PUT_FP
        .global FIM_$FP_GET_STATE
        .global FIM_$FP_PUT_STATE

fim_fline_fault_entry:
        movem.l %d0-%d3/%a0-%a1,-(%sp)           /* sau6 780242ce  48e7 f0c0 */
        bra.s   .L780242e4                       /* sau6 780242d2  6010 */
FIM_$FLINE:
        movem.l %d0-%d3/%a0-%a1,-(%sp)           /* sau6 780242d4  48e7 f0c0 */
        move.w  (MMU+0xe).l,%d0                  /* sau6 780242d8  3039 7fff b40e */
        move.l  (FP_$SAVEP:w,%pc),%d0              /* sau6 780242de  203a fbfe */
        beq.s   .L78024314                       /* sau6 780242e2  6730 */
.L780242e4:
        move.w  (PROC1_$AS_ID).l,%d2             /* sau6 780242e4  3439 7802 2baa */
        beq.s   .L78024314                       /* sau6 780242ea  6728 */
        cmp.w   (FP_$OWNER:w,%pc),%d2              /* sau6 780242ec  b47a fbf4 */
        beq.s   .L78024314                       /* sau6 780242f0  6722 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780242f2  487a fbf0 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 780242f6  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 780242fc  588f */
        bsr.s   .L78024324                       /* sau6 780242fe  6124 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 78024300  487a fbe2 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 78024304  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 7802430a  588f */
        movem.l (%sp)+,%d0-%d3/%a0-%a1           /* sau6 7802430c  4cdf 030f */
        jmp     (FIM_$EXIT:w,%pc)                  /* sau6 78024310  4efa 0e54 */
.L78024314:
        movem.l (%sp)+,%d0-%d3/%a0-%a1           /* sau6 78024314  4cdf 030f */
        jmp     (FIM_$UII).l                     /* sau6 78024318  4ef9 7802 3a0c */
.L7802431e:
        move.w  (PROC1_$AS_ID).l,%d2             /* sau6 7802431e  3439 7802 2baa */
.L78024324:
        move.w  (FP_$OWNER:w,%pc),%d0              /* sau6 78024324  303a fbbc */
        movea.l (FP_$SAVEP:w,%pc),%a1              /* sau6 78024328  227a fbb4 */
        cmp.w   %d0,%d2                          /* sau6 7802432c  b440 */
        beq.s   .L78024398                       /* sau6 7802432e  6768 */
        move.w  %d2,(FP_$OWNER).l                /* sau6 78024330  33c2 7802 3ee2 */
        bclr    #7,(MMU+0x9).l                   /* sau6 78024336  08b9 0007 7fff b409 */
        bsr.s   .L7802439a                       /* sau6 7802433e  615a */
.L78024340:
        mulu.w  #330,%d2                         /* sau6 78024340  c4fc 014a */
        beq.s   .L78024398                       /* sau6 78024344  6752 */
        move.l  (-4,%a1,%d2.l),%d0               /* sau6 78024346  2031 28fc */
        movea.l %d0,%a0                          /* sau6 7802434a  2040 */
        bne.s   .L78024358                       /* sau6 7802434c  660a */
        fmove.l #62464,%fpcr                     /* sau6 7802434e  f23c 9000 0000 f400 */
        bra.s   .L78024398                       /* sau6 78024356  6040 */
.L78024358:
        tst.b   (1,%a0)                          /* sau6 78024358  4a28 0001 */
        beq.s   .L78024396                       /* sau6 7802435c  6738 */
        addq.w  #2,%a0                           /* sau6 7802435e  5448 */
        fmovem.l (%a0)+,%fpiar/%fpsr/%fpcr       /* sau6 78024360  f218 9c00 */
        fmovem.x (%a0)+,%fp0-%fp7                /* sau6 78024364  f218 d0ff */
        tst.b   (M68881_EXISTS).l                /* sau6 78024368  4a39 7809 bee6 */
        bne.s   .L78024396                       /* sau6 7802436e  6626 */
        move.w  (-16,%a1,%d2.l),(-14,%a1,%d2.l)  /* sau6 78024370  33b1 28f0 28f2 */
        btst    #11,(-6,%a1,%d2.l)               /* sau6 78024376  0831 000b 28fa */
        beq.s   .L78024382                       /* sau6 7802437c  6704 */
        jsr     (.L78024482,%pc)                 /* sau6 7802437e  4eba 0102 */
.L78024382:
        btst    #2,(-5,%a1,%d2.l)                /* sau6 78024382  0831 0002 28fb */
        bne.s   .L78024396                       /* sau6 78024388  660c */
        andi.b  #31,(-14,%a1,%d2.l)              /* sau6 7802438a  0231 001f 28f2 */
        bset    #5,(-14,%a1,%d2.l)               /* sau6 78024390  08f1 0005 28f2 */
.L78024396:
        frestore (%a0)+                          /* sau6 78024396  f358 */
.L78024398:
        rts                                      /* sau6 78024398  4e75 */
.L7802439a:
        mulu.w  #330,%d0                         /* sau6 7802439a  c0fc 014a */
        beq.s   .L780243cc                       /* sau6 7802439e  672c */
        lea     (-4,%a1,%d0.l),%a0               /* sau6 780243a0  41f1 08fc */
        fsave   -(%a0)                           /* sau6 780243a4  f320 */
        tst.w   (M68881_EXISTS).l                /* sau6 780243a6  4a79 7809 bee6 */
        bne.w   .L780243b6                       /* sau6 780243ac  6600 0008 */
        move.w  #17470,(0xfc0a).w                /* sau6 780243b0  31fc 443e fc0a */
.L780243b6:
        tst.b   (1,%a0)                          /* sau6 780243b6  4a28 0001 */
        beq.s   .L780243c8                       /* sau6 780243ba  670c */
        fmovem.x %fp0-%fp7,-(%a0)                /* sau6 780243bc  f220 e0ff */
        fmovem.l %fpiar/%fpsr/%fpcr,-(%a0)       /* sau6 780243c0  f220 bc00 */
        move.w  #-1,-(%a0)                       /* sau6 780243c4  313c ffff */
.L780243c8:
        move.l  %a0,(-4,%a1,%d0.l)               /* sau6 780243c8  2388 08fc */
.L780243cc:
        rts                                      /* sau6 780243cc  4e75 */
FIM_$FP_ABORT:
        move.l  (FP_$SAVEP:w,%pc),%d0              /* sau6 780243ce  203a fb0e */
        beq.s   .L7802440c                       /* sau6 780243d2  6738 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780243d4  487a fb0e */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 780243d8  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 780243de  588f */
        movem.l %d2-%d3,-(%sp)                   /* sau6 780243e0  48e7 3000 */
        bsr.w   .L7802431e                       /* sau6 780243e4  6100 ff38 */
        movem.l (%sp)+,%d2-%d3                   /* sau6 780243e8  4cdf 000c */
        lea     (%sp),%a0                        /* sau6 780243ec  41d7 */
        fsave   -(%a0)                           /* sau6 780243ee  f320 */
        tst.w   (M68881_EXISTS).l                /* sau6 780243f0  4a79 7809 bee6 */
        bne.w   .L78024400                       /* sau6 780243f6  6600 0008 */
        move.w  #17470,(0xfc0a).w                /* sau6 780243fa  31fc 443e fc0a */
.L78024400:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 78024400  487a fae2 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 78024404  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 7802440a  588f */
.L7802440c:
        rts                                      /* sau6 7802440c  4e75 */
FIM_$FP_INIT:
        tst.l   (FP_$SAVEP).l                    /* sau6 7802440e  4ab9 7802 3ede */
        beq.s   .L78024460                       /* sau6 78024414  674a */
        move.w  (4,%sp),%d1                      /* sau6 78024416  322f 0004 */
        cmp.w   (FP_$OWNER:w,%pc),%d1              /* sau6 7802441a  b27a fac6 */
        bne.s   .L78024454                       /* sau6 7802441e  6634 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 78024420  487a fac2 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 78024424  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 7802442a  588f */
        move.w  (4,%sp),%d1                      /* sau6 7802442c  322f 0004 */
        cmp.w   (FP_$OWNER:w,%pc),%d1              /* sau6 78024430  b27a fab0 */
        bne.s   .L78024444                       /* sau6 78024434  660e */
        clr.w   (FP_$OWNER).l                    /* sau6 78024436  4279 7802 3ee2 */
        bset    #7,(MMU+0x9).l                   /* sau6 7802443c  08f9 0007 7fff b409 */
.L78024444:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 78024444  487a fa9e */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 78024448  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 7802444e  588f */
        move.w  (4,%sp),%d1                      /* sau6 78024450  322f 0004 */
.L78024454:
        movea.l (FP_$SAVEP:w,%pc),%a0              /* sau6 78024454  207a fa88 */
        mulu.w  #330,%d1                         /* sau6 78024458  c2fc 014a */
        clr.l   (-4,%a0,%d1.w)                   /* sau6 7802445c  42b0 10fc */
.L78024460:
        rts                                      /* sau6 78024460  4e75 */
.L78024462:
        bclr    #5,(MMU+0x1b).l                  /* sau6 78024462  08b9 0005 7fff b41b */
        move.w  #1,(0xfc82).w                    /* sau6 7802446a  31fc 0001 fc82 */
        move.l  (0xfff8).w,%d0                   /* sau6 78024470  2038 fff8 */
        clr.w   (0xfc82).w                       /* sau6 78024474  4278 fc82 */
        bset    #5,(MMU+0x1b).l                  /* sau6 78024478  08f9 0005 7fff b41b */
        rts                                      /* sau6 78024480  4e75 */
.L78024482:
        bclr    #5,(MMU+0x1b).l                  /* sau6 78024482  08b9 0005 7fff b41b */
        move.w  #1,(0xfc82).w                    /* sau6 7802448a  31fc 0001 fc82 */
        move.l  #0,(0xfff8).w                    /* sau6 78024490  21fc 0000 0000 fff8 */
        clr.w   (0xfc82).w                       /* sau6 78024498  4278 fc82 */
        bset    #5,(MMU+0x1b).l                  /* sau6 7802449c  08f9 0005 7fff b41b */
        rts                                      /* sau6 780244a4  4e75 */
.L780244a6:
        clr.l   %d1                              /* sau6 780244a6  4281 */
        clr.l   %d3                              /* sau6 780244a8  4283 */
        cmpi.w  #1,(%a0)+                        /* sau6 780244aa  0c58 0001 */
        bne.s   .L780244ba                       /* sau6 780244ae  660a */
        move.b  (1,%a0),%d3                      /* sau6 780244b0  1628 0001 */
        addq.l  #4,%d3                           /* sau6 780244b4  5883 */
        adda.l  %d3,%a0                          /* sau6 780244b6  d1c3 */
        add.l   %d3,%d1                          /* sau6 780244b8  d283 */
.L780244ba:
        addq.l  #2,%d1                           /* sau6 780244ba  5481 */
        move.l  %d1,%d0                          /* sau6 780244bc  2001 */
        lsr.l   #1,%d1                           /* sau6 780244be  e289 */
        subq.l  #1,%d1                           /* sau6 780244c0  5381 */
        clr.l   %d3                              /* sau6 780244c2  4283 */
        clr.l   %d2                              /* sau6 780244c4  4282 */
.L780244c6:
        move.w  -(%a0),%d2                       /* sau6 780244c6  3420 */
        add.l   %d2,%d3                          /* sau6 780244c8  d682 */
        move.w  %d2,-(%a1)                       /* sau6 780244ca  3302 */
        dbf     %d1,.L780244c6                   /* sau6 780244cc  51c9 fff8 */
        move.l  %d3,-(%a1)                       /* sau6 780244d0  2303 */
        move.l  %d0,-(%a1)                       /* sau6 780244d2  2300 */
        rts                                      /* sau6 780244d4  4e75 */
FIM_$FSAVE:
        movem.l %d0-%d3/%a0-%a3,-(%sp)           /* sau6 780244d6  48e7 f0f0 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780244da  487a fa08 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 780244de  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 780244e4  588f */
        tst.l   (FP_$SAVEP).l                    /* sau6 780244e6  4ab9 7802 3ede */
        beq.s   .L780244f2                       /* sau6 780244ec  6704 */
        bsr.w   .L7802431e                       /* sau6 780244ee  6100 fe2e */
.L780244f2:
        movea.l (36,%sp),%a3                     /* sau6 780244f2  266f 0024 */
        clr.w   (%a3)                            /* sau6 780244f6  4253 */
        movea.l %sp,%a3                          /* sau6 780244f8  264f */
        cmpi.w  #1,(44,%a3)                      /* sau6 780244fa  0c6b 0001 002c */
        bne.s   .L78024526                       /* sau6 78024500  6624 */
        fsave   -(%sp)                           /* sau6 78024502  f327 */
        tst.w   (M68881_EXISTS).l                /* sau6 78024504  4a79 7809 bee6 */
        beq.w   .L78024594                       /* sau6 7802450a  6700 0088 */
        bset    #3,(56,%sp)                      /* sau6 7802450e  08ef 0003 0038 */
        fmovem.l %fpiar/%fpsr/%fpcr,-(%sp)       /* sau6 78024514  f227 bc00 */
        bclr    #0,(4,%sp)                       /* sau6 78024518  08af 0000 0004 */
        clr.l   -(%sp)                           /* sau6 7802451e  42a7 */
        frestore (%sp)+                          /* sau6 78024520  f35f */
        fmovem.l (%sp)+,%fpiar/%fpsr/%fpcr       /* sau6 78024522  f21f 9c00 */
.L78024526:
        tst.w   (M68881_EXISTS).l                /* sau6 78024526  4a79 7809 bee6 */
        beq.s   .L7802453c                       /* sau6 7802452c  670e */
        fsave   -(%sp)                           /* sau6 7802452e  f327 */
        cmpi.w  #16340,(%sp)                     /* sau6 78024530  0c57 3fd4 */
        beq.s   .L78024594                       /* sau6 78024534  675e */
        movea.l %a3,%sp                          /* sau6 78024536  2e4b */
        clr.w   -(%sp)                           /* sau6 78024538  4267 */
        bra.s   .L780245a6                       /* sau6 7802453a  606a */
.L7802453c:
        bclr    #4,(MMU+0x1b).l                  /* sau6 7802453c  08b9 0004 7fff b41b */
        move.w  (0xfc00).w,%d1                   /* sau6 78024544  3238 fc00 */
        move.w  %d1,%d2                          /* sau6 78024548  3401 */
        .short  0xc27c, 0x3e00  /* andw #15872,%d1 */ /* sau6 7802454a  c27c 3e00 */
        .short  0xb27c, 0x0800  /* cmpw #2048,%d1 */ /* sau6 7802454e  b27c 0800 */
        beq.s   .L7802455a                       /* sau6 78024552  6706 */
        move.w  (0xfc00).w,%d1                   /* sau6 78024554  3238 fc00 */
        move.w  %d1,%d2                          /* sau6 78024558  3401 */
.L7802455a:
        btst    #1,%d2                           /* sau6 7802455a  0802 0001 */
        bne.s   .L7802457a                       /* sau6 7802455e  661a */
        fsave   -(%sp)                           /* sau6 78024560  f327 */
        bsr.w   .L78024462                       /* sau6 78024562  6100 fefe */
        .short  0xb0bc, 0xffff, 0xffff  /* cmpl #-1,%d0 */ /* sau6 78024566  b0bc ffff ffff */
        bne.s   .L7802458e                       /* sau6 7802456c  6620 */
        cmpi.b  #56,(1,%sp)                      /* sau6 7802456e  0c2f 0038 0001 */
        bne.s   .L78024594                       /* sau6 78024574  661e */
        frestore (%sp)+                          /* sau6 78024576  f35f */
        bra.s   .L7802458a                       /* sau6 78024578  6010 */
.L7802457a:
        bsr.w   .L78024462                       /* sau6 7802457a  6100 fee6 */
        .short  0xb0bc, 0xffff, 0xffff  /* cmpl #-1,%d0 */ /* sau6 7802457e  b0bc ffff ffff */
        beq.s   .L7802458a                       /* sau6 78024584  6704 */
        fsave   -(%sp)                           /* sau6 78024586  f327 */
        bra.s   .L7802458e                       /* sau6 78024588  6004 */
.L7802458a:
        clr.w   -(%sp)                           /* sau6 7802458a  4267 */
        bra.s   .L7802459e                       /* sau6 7802458c  6010 */
.L7802458e:
        bset    #11,(-2,%a3)                     /* sau6 7802458e  08eb 000b fffe */
.L78024594:
        move.w  #1,-(%sp)                        /* sau6 78024594  3f3c 0001 */
        move.w  #17470,(0xfc0a).w                /* sau6 78024598  31fc 443e fc0a */
.L7802459e:
        bset    #4,(MMU+0x1b).l                  /* sau6 7802459e  08f9 0004 7fff b41b */
.L780245a6:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780245a6  487a f93c */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 780245aa  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 780245b0  588f */
        tst.w   (%sp)                            /* sau6 780245b2  4a57 */
        bne.s   .L780245ba                       /* sau6 780245b4  6604 */
        addq.l  #2,%sp                           /* sau6 780245b6  548f */
        bra.s   .L780245d6                       /* sau6 780245b8  601c */
.L780245ba:
        movea.l %sp,%a0                          /* sau6 780245ba  204f */
        movea.l (40,%a3),%a1                     /* sau6 780245bc  226b 0028 */
        movea.l (%a1),%a1                        /* sau6 780245c0  2251 */
        jsr     (.L780244a6,%pc)                 /* sau6 780245c2  4eba fee2 */
        movea.l %a3,%sp                          /* sau6 780245c6  2e4b */
        movea.l (40,%sp),%a3                     /* sau6 780245c8  266f 0028 */
        move.l  %a1,(%a3)                        /* sau6 780245cc  2689 */
        movea.l (36,%sp),%a3                     /* sau6 780245ce  266f 0024 */
        move.w  #1,(%a3)                         /* sau6 780245d2  36bc 0001 */
.L780245d6:
        movem.l (%sp)+,%d0-%d3/%a0-%a3           /* sau6 780245d6  4cdf 0f0f */
        rts                                      /* sau6 780245da  4e75 */
FIM_$FRESTORE:
        movem.l %d0-%d3/%a0-%a3,-(%sp)           /* sau6 780245dc  48e7 f0f0 */
        movea.l %sp,%a3                          /* sau6 780245e0  264f */
        movea.l (36,%sp),%a0                     /* sau6 780245e2  206f 0024 */
        movea.l (%a0),%a0                        /* sau6 780245e6  2050 */
        move.l  (%a0)+,%d1                       /* sau6 780245e8  2218 */
        move.l  (%a0)+,%d0                       /* sau6 780245ea  2018 */
        adda.l  %d1,%a0                          /* sau6 780245ec  d1c1 */
        lsr.l   #1,%d1                           /* sau6 780245ee  e289 */
        subq.l  #1,%d1                           /* sau6 780245f0  5381 */
        clr.l   %d3                              /* sau6 780245f2  4283 */
        clr.l   %d2                              /* sau6 780245f4  4282 */
.L780245f6:
        move.w  -(%a0),%d2                       /* sau6 780245f6  3420 */
        add.l   %d2,%d3                          /* sau6 780245f8  d682 */
        move.w  %d2,-(%sp)                       /* sau6 780245fa  3f02 */
        dbf     %d1,.L780245f6                   /* sau6 780245fc  51c9 fff8 */
        cmp.l   %d3,%d0                          /* sau6 78024600  b083 */
        beq.s   .L78024626                       /* sau6 78024602  6722 */
        movea.l %a3,%sp                          /* sau6 78024604  2e4b */
        movem.l (%sp)+,%d0-%d3/%a0-%a3           /* sau6 78024606  4cdf 0f0f */
        addq.w  #8,%sp                           /* sau6 7802460a  504f */
        move.w  (0x2000).w,-(%sp)                  /* sau6 7802460c  3f38 2000 */
        move.w  #19,-(%sp)                       /* sau6 78024610  3f3c 0013 */
        move.l  #0x12002d,-(%sp)                  /* sau6 78024614  2f3c 0012 002d */
        pea     (%sp)                            /* sau6 7802461a  4857 */
        pea     (12,%sp)                         /* sau6 7802461c  486f 000c */
        jmp     (FIM_$COM).l                     /* sau6 78024620  4ef9 7802 3944 */
.L78024626:
        cmpi.w  #1,(%sp)+                        /* sau6 78024626  0c5f 0001 */
        bne.s   .L78024656                       /* sau6 7802462a  662a */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802462c  487a f8b6 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 78024630  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 78024636  588f */
        bsr.w   .L7802431e                       /* sau6 78024638  6100 fce4 */
        btst    #11,(-2,%a3)                     /* sau6 7802463c  082b 000b fffe */
        beq.s   .L78024648                       /* sau6 78024642  6704 */
        jsr     (.L78024482,%pc)                 /* sau6 78024644  4eba fe3c */
.L78024648:
        frestore (%sp)+                          /* sau6 78024648  f35f */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802464a  487a f898 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 7802464e  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 78024654  588f */
.L78024656:
        movem.l (%sp)+,%d0-%d3/%a0-%a3           /* sau6 78024656  4cdf 0f0f */
        rts                                      /* sau6 7802465a  4e75 */
FP_$GET_FP:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802465c  487a f886 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 78024660  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 78024666  588f */
        move.l  %d2,-(%sp)                       /* sau6 78024668  2f02 */
        bsr.s   .L78024684                       /* sau6 7802466a  6118 */
        move.w  (8,%sp),%d2                      /* sau6 7802466c  342f 0008 */
        bsr.w   .L78024340                       /* sau6 78024670  6100 fcce */
        move.l  (%sp)+,%d2                       /* sau6 78024674  241f */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 78024676  487a f86c */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 7802467a  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 78024680  588f */
        rts                                      /* sau6 78024682  4e75 */
.L78024684:
        move.w  (PROC1_$AS_ID).l,%d2             /* sau6 78024684  3439 7802 2baa */
        move.w  (FP_$OWNER:w,%pc),%d0              /* sau6 7802468a  303a f856 */
        movea.l (FP_$SAVEP:w,%pc),%a1              /* sau6 7802468e  227a f84e */
        cmp.w   %d0,%d2                          /* sau6 78024692  b440 */
        beq.s   .L780246a8                       /* sau6 78024694  6712 */
        move.w  %d2,(FP_$OWNER).l                /* sau6 78024696  33c2 7802 3ee2 */
        bclr    #7,(MMU+0x9).l                   /* sau6 7802469c  08b9 0007 7fff b409 */
        bsr.w   .L7802439a                       /* sau6 780246a4  6100 fcf4 */
.L780246a8:
        rts                                      /* sau6 780246a8  4e75 */
FP_$PUT_FP:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780246aa  487a f838 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 780246ae  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 780246b4  588f */
        movem.l %d2-%d3,-(%sp)                   /* sau6 780246b6  48e7 3000 */
        bsr.w   .L7802431e                       /* sau6 780246ba  6100 fc62 */
        move.w  (12,%sp),%d0                     /* sau6 780246be  302f 000c */
        bsr.w   .L7802439a                       /* sau6 780246c2  6100 fcd6 */
        movem.l (%sp)+,%d2-%d3                   /* sau6 780246c6  4cdf 000c */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780246ca  487a f818 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 780246ce  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 780246d4  588f */
        rts                                      /* sau6 780246d6  4e75 */
FIM_$FP_GET_STATE:
        movem.l %d2/%a2-%a4,-(%sp)               /* sau6 780246d8  48e7 2038 */
        movea.l (20,%sp),%a3                     /* sau6 780246dc  266f 0014 */
        movea.l (24,%sp),%a4                     /* sau6 780246e0  286f 0018 */
        addq.l  #4,%a3                           /* sau6 780246e4  588b */
        addq.l  #4,%a4                           /* sau6 780246e6  588c */
        move.l  (FP_$SAVEP:w,%pc),%d0              /* sau6 780246e8  203a f7f4 */
        beq.w   .L7802477e                       /* sau6 780246ec  6700 0090 */
        move.w  (PROC1_$AS_ID).l,%d0             /* sau6 780246f0  3039 7802 2baa */
        cmp.w   (FP_$OWNER:w,%pc),%d0              /* sau6 780246f6  b07a f7ea */
        bne.s   .L78024736                       /* sau6 780246fa  663a */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 780246fc  487a f7e6 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 78024700  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 78024706  588f */
        move.w  (PROC1_$AS_ID).l,%d0             /* sau6 78024708  3039 7802 2baa */
        cmp.w   (FP_$OWNER:w,%pc),%d0              /* sau6 7802470e  b07a f7d2 */
        bne.s   .L7802472a                       /* sau6 78024712  6616 */
        movea.l (FP_$SAVEP:w,%pc),%a1              /* sau6 78024714  227a f7c8 */
        bsr.w   .L7802439a                       /* sau6 78024718  6100 fc80 */
        clr.w   (FP_$OWNER).l                    /* sau6 7802471c  4279 7802 3ee2 */
        bset    #7,(MMU+0x9).l                   /* sau6 78024722  08f9 0007 7fff b409 */
.L7802472a:
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802472a  487a f7b8 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 7802472e  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 78024734  588f */
.L78024736:
        movea.l (FP_$SAVEP:w,%pc),%a0              /* sau6 78024736  207a f7a6 */
        move.w  (PROC1_$AS_ID).l,%d0             /* sau6 7802473a  3039 7802 2baa */
        mulu.w  #330,%d0                         /* sau6 78024740  c0fc 014a */
        move.l  (-4,%a0,%d0.l),%d0               /* sau6 78024744  2030 08fc */
        beq.s   .L7802477e                       /* sau6 78024748  6734 */
        movea.l %d0,%a0                          /* sau6 7802474a  2040 */
        tst.b   (1,%a0)                          /* sau6 7802474c  4a28 0001 */
        beq.s   .L7802477e                       /* sau6 78024750  672c */
        addq.l  #2,%a0                           /* sau6 78024752  5488 */
        move.w  #4660,(%a3)+                     /* sau6 78024754  36fc 1234 */
        move.w  #26,%d0                          /* sau6 78024758  303c 001a */
.L7802475c:
        move.l  (%a0)+,(%a3)+                    /* sau6 7802475c  26d8 */
        dbf     %d0,.L7802475c                   /* sau6 7802475e  51c8 fffc */
        moveq   #0,%d0                           /* sau6 78024762  7000 */
        move.b  (1,%a0),%d0                      /* sau6 78024764  1028 0001 */
        move.l  %d0,%d1                          /* sau6 78024768  2200 */
        addq.l  #4,%d1                           /* sau6 7802476a  5881 */
        addq.l  #4,%d0                           /* sau6 7802476c  5880 */
        lsr.l   #1,%d0                           /* sau6 7802476e  e288 */
        subq.l  #1,%d0                           /* sau6 78024770  5380 */
        move.w  #4660,(%a4)+                     /* sau6 78024772  38fc 1234 */
.L78024776:
        move.w  (%a0)+,(%a4)+                    /* sau6 78024776  38d8 */
        dbf     %d0,.L78024776                   /* sau6 78024778  51c8 fffc */
        bra.s   .L78024786                       /* sau6 7802477c  6008 */
.L7802477e:
        move.w  #0,(%a3)+                        /* sau6 7802477e  36fc 0000 */
        move.w  #0,(%a4)+                        /* sau6 78024782  38fc 0000 */
.L78024786:
        movea.l (20,%sp),%a0                     /* sau6 78024786  206f 0014 */
        suba.l  %a0,%a3                          /* sau6 7802478a  97c8 */
        move.l  %a3,(%a0)                        /* sau6 7802478c  208b */
        movea.l (24,%sp),%a0                     /* sau6 7802478e  206f 0018 */
        suba.l  %a0,%a4                          /* sau6 78024792  99c8 */
        move.l  %a4,(%a0)                        /* sau6 78024794  208c */
        movem.l (%sp)+,%d2/%a2-%a4               /* sau6 78024796  4cdf 1c04 */
        rts                                      /* sau6 7802479a  4e75 */
FIM_$FP_PUT_STATE:
        movem.l %d2-%d3/%a2-%a4,-(%sp)           /* sau6 7802479c  48e7 3038 */
        movea.l (24,%sp),%a3                     /* sau6 780247a0  266f 0018 */
        movea.l (28,%sp),%a4                     /* sau6 780247a4  286f 001c */
        addq.l  #4,%a3                           /* sau6 780247a8  588b */
        addq.l  #4,%a4                           /* sau6 780247aa  588c */
        move.l  (FP_$SAVEP:w,%pc),%d0              /* sau6 780247ac  203a f730 */
        beq.w   .L7802482e                       /* sau6 780247b0  6700 007c */
        movea.l (FP_$SAVEP:w,%pc),%a0              /* sau6 780247b4  207a f728 */
        move.w  (PROC1_$AS_ID).l,%d0             /* sau6 780247b8  3039 7802 2baa */
        mulu.w  #330,%d0                         /* sau6 780247be  c0fc 014a */
        adda.l  %d0,%a0                          /* sau6 780247c2  d1c0 */
        subq.l  #4,%a0                           /* sau6 780247c4  5988 */
        movea.l %a0,%a2                          /* sau6 780247c6  2448 */
        cmpi.w  #4660,(%a4)+                     /* sau6 780247c8  0c5c 1234 */
        beq.s   .L780247d2                       /* sau6 780247cc  6704 */
        clr.l   (%a0)                            /* sau6 780247ce  4290 */
        bra.s   .L78024804                       /* sau6 780247d0  6032 */
.L780247d2:
        clr.w   %d0                              /* sau6 780247d2  4240 */
        move.b  (1,%a4),%d0                      /* sau6 780247d4  102c 0001 */
        addq.w  #4,%d0                           /* sau6 780247d8  5840 */
        adda.l  %d0,%a4                          /* sau6 780247da  d9c0 */
        lsr.w   #1,%d0                           /* sau6 780247dc  e248 */
        subq.l  #1,%d0                           /* sau6 780247de  5380 */
.L780247e0:
        move.w  -(%a4),-(%a0)                    /* sau6 780247e0  3124 */
        dbf     %d0,.L780247e0                   /* sau6 780247e2  51c8 fffc */
        cmpi.w  #4660,(%a3)+                     /* sau6 780247e6  0c5b 1234 */
        bne.s   .L7802482e                       /* sau6 780247ea  6642 */
        adda.l  #108,%a3                         /* sau6 780247ec  d7fc 0000 006c */
        move.w  #26,%d0                          /* sau6 780247f2  303c 001a */
.L780247f6:
        move.l  -(%a3),-(%a0)                    /* sau6 780247f6  2123 */
        dbf     %d0,.L780247f6                   /* sau6 780247f8  51c8 fffc */
        move.w  #-1,-(%a0)                       /* sau6 780247fc  313c ffff */
        move.l  %a0,(%a2)                        /* sau6 78024800  2488 */
        bra.s   .L7802482e                       /* sau6 78024802  602a */
.L78024804:
        cmpi.w  #4660,(%a3)+                     /* sau6 78024804  0c5b 1234 */
        bne.s   .L7802482e                       /* sau6 78024808  6624 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802480a  487a f6d8 */
        jsr     (ML_$EXCLUSION_START).l          /* sau6 7802480e  4eb9 7802 3398 */
        addq.l  #4,%sp                           /* sau6 78024814  588f */
        bsr.w   .L7802431e                       /* sau6 78024816  6100 fb06 */
        pea     (FP_$EXCLUSION:w,%pc)              /* sau6 7802481a  487a f6c8 */
        jsr     (ML_$EXCLUSION_STOP).l           /* sau6 7802481e  4eb9 7802 341e */
        addq.l  #4,%sp                           /* sau6 78024824  588f */
        fmovem.l (%a3)+,%fpiar/%fpsr/%fpcr       /* sau6 78024826  f21b 9c00 */
        fmovem.x (%a3)+,%fp0-%fp7                /* sau6 7802482a  f21b d0ff */
.L7802482e:
        movem.l (%sp)+,%d2-%d3/%a2-%a4           /* sau6 7802482e  4cdf 1c0c */
        rts                                      /* sau6 78024832  4e75 */
        .endif
