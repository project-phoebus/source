/*
 * fim/m68k/pop_signal.s - FIM_$POP_SIGNAL (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21672..0x00E2167D (map
 * FIM_$POP_SIGNAL to FIM_$SIGNAL_FIRST, 12 bytes), in its own section.
 *
 *   void FIM_$POP_SIGNAL(fim_cleanup_entry_t *rec)      rec at 0x4(SP)
 *
 * Returns to its caller with SP = rec->sp + 4: the stack pointer
 * FIM_$CLEANUP saw, less its return address, i.e. the caller's stack as it
 * was when FIM_$CLEANUP returned; whatever was pushed since is dropped.
 *
 * Byte gate (tools/asm_compare.py): identical to the image.
 */

        .section ".text.FIM_$POP_SIGNAL","ax",@progbits
        .even

        .global FIM_$POP_SIGNAL
FIM_$POP_SIGNAL:
        movea.l (%sp)+,%a0                      /* e21672  A0 = return address */
        movea.l (%sp),%a1                       /* e21674  A1 = rec */
        movea.l (0x10,%a1),%sp                  /* e21676  SP = rec->sp */
        addq.w  #4,%sp                          /* e2167a */
        jmp     (%a0)                           /* e2167c */
