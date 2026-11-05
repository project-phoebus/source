/*
 * smd/sau6/interrupt_init.s - SMD_$INTERRUPT_INIT, install the display
 * interrupt handlers.
 *
 * Image addresses:
 *   sau6  0x7802A72A  SMD_$INTERRUPT_INIT
 *
 * Hand-written code in SMD_WIRED's data segment.  SMD_$INIT calls it
 * with nothing pushed; no argument, no result (smd/smd_internal.ins.pas).
 *
 * The handlers go straight into the TRAP_PAGE's vector cells, as the
 * SAU2's autovector case: SMD_$DISP1_INT (smd/sau6/disp1_int.s) in
 * DISP1_VEC (the SAU6 map's 0x3D0, vector 244) and SMD_$DISP2_INT in
 * DISP2_VEC (0x3C8, vector 242).  No PEB test and no VME_$DEFINE_INT,
 * where the SAU5's form defines VME level 3.
 */

        .section ".text.SMD_$INTERRUPT_INIT","ax",@progbits
        .globl  SMD_$INTERRUPT_INIT

SMD_$INTERRUPT_INIT:
        lea     (SMD_$DISP1_INT:w,%pc),%a0
        move.l  %a0,(DISP1_VEC).l
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        move.l  %a0,(DISP2_VEC).l
        rts
