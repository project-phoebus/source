/*
 * fim/m68k/rls_cleanup.s - FIM_$RLS_CLEANUP, release a cleanup handler
 * (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E2165C..0x00E21671 (map
 * FIM_$RLS_CLEANUP to FIM_$POP_SIGNAL, 22 bytes), in its own section.
 *
 *   void FIM_$RLS_CLEANUP(fim_cleanup_entry_t *rec)     rec at 0x4(SP)
 *
 * FIM_$CLEANUP_STACK[PROC1_$CURRENT] = rec->link.  No check that rec is the
 * current head.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations (FIM_$CLEANUP_STACK by R_68K_PC16, as the image's
 * `lea (0x48,PC)').
 */

        .section ".text.FIM_$RLS_CLEANUP","ax",@progbits
        .even

        .extern PROC1_$CURRENT          /* map 0xE20608 */
        .extern FIM_$CLEANUP_STACK      /* fim/m68k/signal.s, image 0xE216B2 */

        .global FIM_$RLS_CLEANUP
FIM_$RLS_CLEANUP:
        move.w  (PROC1_$CURRENT).l,%d0          /* e2165c */
        movea.l (0x4,%sp),%a1                   /* e21662 */
        lsl.w   #2,%d0                          /* e21666 */
        lea     (FIM_$CLEANUP_STACK:w,%pc),%a0  /* e21668  41fa 0048 */
        adda.w  %d0,%a0                         /* e2166c */
        move.l  (%a1),(%a0)                     /* e2166e  head = rec->link */
        rts                                     /* e21670 */
