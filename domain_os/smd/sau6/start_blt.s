/*
 * smd/sau6/start_blt.s - SMD_$START_BLT, the trampoline to the BLT body.
 *
 * Image addresses:
 *   sau6  0x7802A754  SMD_$START_BLT
 *
 * It puts SMD_WIRED's data base (SMD_$DISP2_INT) in A0 and jumps to the
 * body in the module's code segment (smd/sau6/wired_proc.s, which gives
 * the arguments), as the SAU2's.  The body does not read A0.
 */

        .section ".text.SMD_$START_BLT","ax",@progbits
        .globl  SMD_$START_BLT

SMD_$START_BLT:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        jmp     (smd_$start_blt_body).l
