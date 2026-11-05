/*
 * smd/sau6/scroll.s - SMD_$START_SCROLL and SMD_$CONTINUE_SCROLL, the
 * trampolines to the scroll bodies.
 *
 * Image addresses:
 *   sau6  0x7802A740  SMD_$START_SCROLL
 *   sau6  0x7802A74A  SMD_$CONTINUE_SCROLL
 *
 * Each puts SMD_WIRED's data base (SMD_$DISP2_INT) in A0 and jumps to
 * its body in the module's code segment (smd/sau6/wired_proc.s, which
 * gives the arguments), as the SAU2's.  The bodies call the BLT setup
 * through the base (smd_$setup_scroll_blt, smd/sau6/disp1_int.s).
 */

        .section ".text.SMD_$START_SCROLL","ax",@progbits
        .globl  SMD_$START_SCROLL

SMD_$START_SCROLL:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        jmp     (smd_$start_scroll_body).l

        .section ".text.SMD_$CONTINUE_SCROLL","ax",@progbits
        .globl  SMD_$CONTINUE_SCROLL

SMD_$CONTINUE_SCROLL:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        jmp     (smd_$continue_scroll_body).l
