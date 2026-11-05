/*
 * fp/m68k/savep.s - the FP cells of the FIM_WIRED segment: FP_$SAVEP,
 * FP_$OWNER, FP_$EXCLUSION (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * 0x00E218D0..0x00E218E7 in the SAU2 image (map FP_$SAVEP, FP_$OWNER; 24
 * bytes to FIM_$BUS_ERR), between the bus-error trampoline cell
 * BUS_ERROR_SWITCH and FIM_$BUS_ERR, in their own section so
 * tools/gen_layout_ld.py links them at their map position.  Declared in
 * fp/fp.ins.pas.
 *
 *   0x00E218D0  FP_$SAVEP      long   the per-address-space FP save-area
 *                                     table (0x14A bytes per AS), allocated
 *                                     by PEB_$LOAD_WCS, cleared by
 *                                     OS_$SHUTDOWN; 0 = no FPU configured,
 *                                     which is what FIM_$FP_ABORT,
 *                                     FIM_$FP_INIT, FIM_$FSAVE and FIM_$FLINE
 *                                     test
 *   0x00E218D4  FP_$OWNER      word   address space that owns the FPU
 *   0x00E218D6  FP_$EXCLUSION  18     ml_$exclusion_t guarding the FPU
 *                                     context (Ghidra name; not in the map)
 *
 * The image bytes (`gsk read 0xE218D0 24'):
 *   00000000 0000 00000000 00e218d6 00e218d6 00000000 ffff
 * i.e. the lock ships in the state ML_$EXCLUSION_INIT leaves it: no
 * holder, both waiter links pointing at the lock itself, count -1.  The
 * self-pointers are relocations here (R_68K_32 FP_$EXCLUSION).
 *
 * With the floating-point accelerator (`fpa_board', base/config.ins.pas:
 * the SAU7) the same three cells follow for it, FPA_$SAVEP, FPA_$OWNER
 * and its lock (no map name), 24 bytes to MMU_$BUS_STATUS; those lines
 * carry the SAU7 image's addresses.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.
 */

        .include "base/config.inc"

        .section ".text.FP_$SAVEP","ax",@progbits
        .even

        .global FP_$SAVEP
FP_$SAVEP:
        .long   0                               /* e218d0 */

        .global FP_$OWNER
FP_$OWNER:
        .short  0                               /* e218d4 */

        .global FP_$EXCLUSION
FP_$EXCLUSION:                                  /* e218d6  ml_$exclusion_t */
        .long   0                               /* +0x00 */
        .long   FP_$EXCLUSION                   /* +0x04  waiter list head (self) */
        .long   FP_$EXCLUSION                   /* +0x08  waiter list tail (self) */
        .long   0                               /* +0x0C */
        .short  -1                              /* +0x10  -1: unlocked */

        .if fpa_board
/* The floating-point accelerator's cells, the FPU's three again (sau7
 * 3c42638e..3c4263a5): its save-area base, its owner, and the lock of its
 * context, whose waiter links point at itself. */
        .global FPA_$SAVEP
FPA_$SAVEP:
        .long   0                               /* sau7 3c42638e */

        .global FPA_$OWNER
FPA_$OWNER:
        .short  0                               /* sau7 3c426392 */

        .global fpa_$exclusion
fpa_$exclusion:                                 /* sau7 3c426394  ml_$exclusion_t */
        .long   0                               /* +0x00 */
        .long   fpa_$exclusion                  /* +0x04  waiter list head (self) */
        .long   fpa_$exclusion                  /* +0x08  waiter list tail (self) */
        .long   0                               /* +0x0C */
        .short  -1                              /* +0x10  -1: unlocked */
        .endif
