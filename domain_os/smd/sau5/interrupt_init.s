/*
 * smd/sau5/interrupt_init.s - SMD_$INTERRUPT_INIT, install the display
 * interrupt handlers.
 *
 * Image addresses:
 *   sau5  0x00E28216  SMD_$INTERRUPT_INIT
 *
 * Hand-written code in SMD_WIRED's data segment.  SMD_$INIT calls it
 * with nothing pushed; no argument, no result (smd/smd_internal.ins.pas).
 *
 * Unit 1's handler, SMD_$DISP1_INT (smd/sau5/disp1_int.s), goes in
 * PEB_$DISP_INT_ADDR when PEB_$INFO's installed byte (+0x1A) is nonzero
 * (the test is zero against nonzero, as on the SAU2), else it is defined
 * as VME level 3's handler with VME_$DEFINE_INT; then unit 2's,
 * SMD_$DISP2_INT, is defined as VME level 3's handler.  Each call pushes
 * the handler's argument (nil), the handler, and the interrupt id
 * (io_$int_id_t, its two words 3 and 3), calls through A0, and pops the
 * arguments; D0-D1/A0-A1 are saved around it.
 *
 * Without a PEB both calls define level 3, so the second replaces
 * SMD_$DISP1_INT with SMD_$DISP2_INT; A0 is loaded with SMD_$DISP2_INT
 * before the second call's register save.
 */

        .section ".text.SMD_$INTERRUPT_INIT","ax",@progbits
        .globl  SMD_$INTERRUPT_INIT

SMD_$INTERRUPT_INIT:
        lea     (SMD_$DISP1_INT:w,%pc),%a0
        lea     (PEB_$INFO).l,%a1
        tst.b   (0x1a,%a1)              /* installed */
        beq.w   .Lvme
        move.l  %a0,(PEB_$DISP_INT_ADDR).l
        bra.w   .Lunit2
.Lvme:
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        move.l  #0,-(%sp)               /* handler_arg: nil */
        pea     (SMD_$DISP1_INT:w,%pc)
        move.w  #0x3,-(%sp)             /* the id: level 3 */
        move.w  #0x3,-(%sp)
        lea     (VME_$DEFINE_INT).l,%a0
        jsr     (%a0)
        adda.l  #0xc,%sp
        movem.l (%sp)+,%d0-%d1/%a0-%a1
.Lunit2:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        move.l  #0,-(%sp)
        pea     (SMD_$DISP2_INT:w,%pc)
        move.w  #0x3,-(%sp)
        move.w  #0x3,-(%sp)
        lea     (VME_$DEFINE_INT).l,%a0
        jsr     (%a0)
        adda.l  #0xc,%sp
        movem.l (%sp)+,%d0-%d1/%a0-%a1
        rts
