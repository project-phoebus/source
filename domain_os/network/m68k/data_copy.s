/*
 * network/m68k/data_copy.s - OS_$DATA_COPY (m68k / SAU2, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'):
 * encodings identical to the image.
 *
 * The second routine of the hand-written NETWORK_ASM segment (SAU2 map:
 * "I E11EF0 NETWORK_ASM size = B8": NETWORK_$GET_CHKSUM 0xE11EF0,
 * OS_$DATA_COPY 0xE11F04 (MARKED), OS_$DATA_ZERO 0xE11F42).  0x3E bytes,
 * 0x00E11F04..0x00E11F41.
 *
 * Not compiler output: no link/unlk, the arguments are read off SP with a
 * `movem.l', and the source/destination registers are exchanged through
 * D0.
 *
 * The heading Pascal callers use is os/os.ins.pas's
 *   procedure os_$data_copy(in src: univ os_$data_t;
 *                           out dst: univ os_$data_t; len: integer32);
 *                           val_param;
 * (0x4,SP) the source's address, (0x8,SP) the destination's, (0xC,SP) the
 * byte count by value (APP_$RECEIVE 0xE00962..0xE00970 pushes them).
 *
 * What it does: when both addresses are even, copy len div 4 longwords
 * and then the len mod 4 remaining bytes; when either is odd, copy all
 * len bytes one at a time.  The counts are words: `move.w D0w,D1w;
 * and.w #3,D0w; lsr.w #2,D1w; subq.w #1; blt', so only the low 16 bits
 * of the length count, and on the byte path a low word of 0x8001 or more
 * is negative after the `subq.w' and copies nothing (the original's; no
 * caller passes so much).
 *
 * The `and.w #3,D0w' at 0x00E11F26 is the Apollo assembler's <ea>=#imm
 * form (c07c), which gas spells as `andi'; it is written as `.short'.
 */

        .section ".text.OS_$DATA_COPY","ax",@progbits
        .even

        .globl  OS_$DATA_COPY
OS_$DATA_COPY:
        movem.l (0x4,%sp),%a0-%a1               /* e11f04  4cef 0300 0004 */
        move.l  %a0,%d0                         /* e11f0a  2008  D0 = src   */
        movea.l %a1,%a0                         /* e11f0c  2049  A0 = dst   */
        movea.l %d0,%a1                         /* e11f0e  2240  A1 = src   */
        move.l  (0xc,%sp),%d0                   /* e11f10  202f 000c  len   */
        move.l  %a0,%d1                         /* e11f14  2208             */
        btst    #0,%d1                          /* e11f16  0801 0000        */
        bne.b   .Lbytes                         /* e11f1a  661a  dst odd    */
        move.l  %a1,%d1                         /* e11f1c  2209             */
        btst    #0,%d1                          /* e11f1e  0801 0000        */
        bne.b   .Lbytes                         /* e11f22  6612  src odd    */
        move.w  %d0,%d1                         /* e11f24  3200             */
        .short  0xc07c, 0x0003                  /* e11f26  and.w #3,%d0 (<ea>=#imm form; gas: andi) */
        lsr.w   #2,%d1                          /* e11f2a  e449  longwords  */
        subq.w  #1,%d1                          /* e11f2c  5341             */
        blt.b   .Lbytes                         /* e11f2e  6d06  none       */
.Llongs:
        move.l  (%a1)+,(%a0)+                   /* e11f30  20d9             */
        dbf     %d1,.Llongs                     /* e11f32  51c9 fffc        */
.Lbytes:
        subq.w  #1,%d0                          /* e11f36  5340             */
        blt.b   .Ldone                          /* e11f38  6d06             */
.Lbyte:
        move.b  (%a1)+,(%a0)+                   /* e11f3a  10d9             */
        dbf     %d0,.Lbyte                      /* e11f3c  51c8 fffc        */
.Ldone:
        rts                                     /* e11f40  4e75             */
