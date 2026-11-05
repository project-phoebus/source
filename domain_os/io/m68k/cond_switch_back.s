/*
 * io/m68k/cond_switch_back.s - IO_$COND_SWITCH_BACK (SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check'): encodings identical to
 * the image; address operands resolve to our objects.
 *
 * Original address: 0x00E2E846, 22 bytes (IO_$TBLS, between
 * IO_$USE_INT_STACK and io_$flih_dispatch):
 *   22 5f                 movea.l (SP)+,A1
 *   bf fc 00 eb 2b e8     cmpa.l #0xeb2be8,SP       ; the interrupt stack top
 *   66 0a                 bne.b 0x00e2e85a
 *   2e 7a ff d0           movea.l (-0x30,PC),SP     ; IO_$SAVED_OS_SP
 *   42 b9 00 e2 e8 22     clr.l (0x00e2e822).l
 *   4e d1                 jmp (A1)
 *
 * The undo of IO_$USE_INT_STACK (io/m68k/use_int_stack.s): an interrupt
 * routine about to leave calls it, and if SP is exactly the interrupt
 * stack top that IO_$USE_INT_STACK switched to (no nested frames left), SP
 * goes back to the saved OS stack and the save cell is cleared.  It pops
 * its own return address and leaves with `jmp (A1)', since SP may change.
 * Caller: TIME_$TIMER_HANDLER's spurious-interrupt arm (0x00E2B270).
 *
 * The save cell is reached PC-relative, as in the image: the layout keeps
 * it within a 16-bit displacement, and the routine's size matters, since
 * io_$flih_dispatch after it is an exception handler and must stay
 * longword-aligned.
 */

        .section ".text.IO_$COND_SWITCH_BACK","ax",@progbits
        .even

        .extern IO_$SAVED_OS_SP
        .extern INT_STACK_BASE          /* 0xEB2C00, the STACK window (layout) */

/* The interrupt stack top IO_$USE_INT_STACK loads (0xEB2BE8). */
        .set    IO_INT_STACK_TOP, INT_STACK_BASE - 0x18

        .globl  IO_$COND_SWITCH_BACK
IO_$COND_SWITCH_BACK:
        movea.l (%sp)+,%a1                      /* 00e2e846 */
        cmpa.l  #IO_INT_STACK_TOP,%sp           /* 00e2e848 */
        bne.b   1f                              /* 00e2e84e */
        movea.l (IO_$SAVED_OS_SP:w,%pc),%sp     /* 00e2e850 */
        clr.l   (IO_$SAVED_OS_SP).l             /* 00e2e854 */
1:      jmp     (%a1)                           /* 00e2e85a */
