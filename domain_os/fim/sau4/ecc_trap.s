/*
 * fim/sau4/ecc_trap.s - FIM_$ECCC_TRAP and FIM_$ECCU_TRAP, the memory
 * error interrupts (SAU4)
 *
 * Transcribed from the SAU4 image, 0x0F824248..0x0F824277 (map
 * FIM_$ECCC_TRAP and FIM_$ECCU_TRAP to MISS_STATUS, 48 bytes), in the
 * FIM_WIRED segment after FIM_$SPURIOUS_INT's cells, one section per map
 * symbol.  The DNx60's memory boards correct their single-bit errors
 * (`ecc_memory', base/config.ins.pas); OS's vector table installs these
 * two for vectors 240 (ECCC_VEC) and 255 (ECCU_VEC) where the other SAUs
 * have FIM_$PARITY_TRAP.
 *
 *   FIM_$ECCC_TRAP  a corrected error: MEM_$ECCC_LOG (mem/) logs and
 *                   counts it by board and page, then the interrupt
 *                   leaves through PROC1_$INT_EXIT.
 *   FIM_$ECCU_TRAP  an uncorrectable error: CRASH_SYSTEM with
 *                   status 0x0012000F "uncorrectable memory error
 *                   detected", then (if it returns) FIM_$EXIT.
 *
 * The two status longwords follow FIM_$ECCU_TRAP: 0x0012000E
 * "correctable memory error detected", which nothing here reads, and
 * 0x0012000F, the one pushed.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): identical to the
 * image modulo relocations (the absolute calls, the PC-relative status
 * and FIM_$EXIT as R_68K_PC16).
 */

        .extern MEM_$ECCC_LOG           /* mem/, map 0xF80B6B4 */
        .extern PROC1_$INT_EXIT         /* proc1/m68k/int_handler.s, map 0xF821F0E */
        .extern CRASH_SYSTEM            /* misc/m68k/crash_system.s, map 0xF81FAF8 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xF824AEE */

        .section ".text.FIM_$ECCC_TRAP","ax",@progbits
        .even
        .global FIM_$ECCC_TRAP
FIM_$ECCC_TRAP:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f824248  48e7 c0c0 */
        jsr     (MEM_$ECCC_LOG).l               /* sau4 f82424c  4eb9 0f80 b6b4 */
        jmp     (PROC1_$INT_EXIT).l             /* sau4 f824252  4ef9 0f82 1f0e */

        .section ".text.FIM_$ECCU_TRAP","ax",@progbits
        .even
        .global FIM_$ECCU_TRAP
FIM_$ECCU_TRAP:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* sau4 f824258  48e7 c0c0 */
        pea     (.Leccu_status,%pc)             /* sau4 f82425c  487a 0016 */
        jsr     (CRASH_SYSTEM).l                /* sau4 f824260  4eb9 0f81 faf8 */
        addq.w  #4,%sp                          /* sau4 f824266  584f */
        movem.l (%sp)+,%d0-%d1/%a0-%a1          /* sau4 f824268  4cdf 0303 */
        jmp     (FIM_$EXIT:w,%pc)               /* sau4 f82426c  4efa 0880 */
        .long   0x0012000E                      /* sau4 f824270  "correctable memory error detected" */
.Leccu_status:
        .long   0x0012000F                      /* sau4 f824274  "uncorrectable memory error detected" */
