/*
 * uid/m68k/hash.s - UID_$HASH (m68k / SAU2, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image.
 *
 * SAU2 map: "I E17360 UID_$HASH size = 1C", one symbol, UID_$HASH
 * 0xE17360; 0x1C bytes, 0x00E17360..0x00E1737B, and UID_LIST follows at
 * 0xE1737C with no filler.
 *
 * Hand assembly (uid/README.md): no `link', both arguments read
 * off SP, `movem.l (A0),D0-D1', the result left in D0 by a `divu.w' and
 * `swap'.
 *
 * The heading Pascal callers use is uid/uid.ins.pas's (the default
 * convention, both arguments by address): (0x4,SP) the UID's address,
 * (0x8,SP) the address of the word modulus.  The result is the low word
 * of D0: the remainder of ((high xor low)'s high word xor its low word)
 * divided by the modulus, the `swap' leaving the quotient in D0's high
 * word.
 */

        .section ".text.UID_$HASH","ax",@progbits
        .even

        .globl  UID_$HASH
UID_$HASH:
        movea.l (0x4,%sp),%a0                   /* e17360  206f 0004  &uid     */
        movea.l (0x8,%sp),%a1                   /* e17364  226f 0008  &modulus */
        movem.l (%a0),%d0-%d1                   /* e17368  4cd0 0003  high, low */
        eor.l   %d1,%d0                         /* e1736c  b380             */
        move.w  %d0,%d1                         /* e1736e  3200             */
        clr.w   %d0                             /* e17370  4240             */
        swap    %d0                             /* e17372  4840             */
        eor.w   %d1,%d0                         /* e17374  b340             */
        divu.w  (%a1),%d0                       /* e17376  80d1             */
        swap    %d0                             /* e17378  4840  remainder  */
        rts                                     /* e1737a  4e75             */
