/*
 * vfmt/m68k/descriptors.s - the VFMT procedure-variable descriptors
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image; the thunk and routine cells are relocations
 * resolved against the image's longwords.
 *
 * Two 16-byte descriptors in .DATA, each its own map segment named after
 * the thunk it jumps to:
 *
 *   D E825E4 VFMT_$FORMATN size = 10   VFMT_$FORMAT10, VFMT_$ENCODE10,
 *                                      VFMT_$FORMAT5, VFMT_$ENCODE5,
 *                                      VFMT_$ENCODE2, VFMT_$FORMAT2
 *   D E825F4 VFMT_$WRITEN  size = 10   VFMT_$WRITE10, VFMT_$WRITE2,
 *                                      VFMT_$WRITE5
 *
 * All the names of a family label one descriptor (the map gives them one
 * address); the thunk passes the caller's argument list on by address and
 * VFMT_$MAIN / VFMT_$WRITE walks it as the format directs, so the names
 * differ only for the callers.  The order of the names is the map's.
 *
 *   +0x00  41fa fffe       lea (-0x2,PC),A0     A0 = the descriptor
 *   +0x04  4ef9 xxxx xxxx  jmp <thunk>.l        VFMT_$FORMATN / VFMT_$WRITEN
 *   +0x0A  xxxx xxxx       the installed routine: VFMT_$MAIN 0xE6AB2A /
 *                          VFMT_$WRITE 0xE6AFE2 (vfmt/vfmt.pas)
 *   +0x0E  0000
 *
 *   00e825e4  41fa fffe 4ef9 00e6 b074 00e6 ab2a 0000
 *   00e825f4  41fa fffe 4ef9 00e6 b0a4 00e6 afe2 0000
 *
 * Code in a data segment, with its own address taken PC-relatively and a
 * routine cell after it, reached by `jsr' from its callers: hand-written
 *.
 */

        .section ".text.VFMT_$FORMAT10","ax",@progbits
        .even

        .globl  VFMT_$FORMAT10
        .globl  VFMT_$ENCODE10
        .globl  VFMT_$FORMAT5
        .globl  VFMT_$ENCODE5
        .globl  VFMT_$ENCODE2
        .globl  VFMT_$FORMAT2
VFMT_$FORMAT10:
VFMT_$ENCODE10:
VFMT_$FORMAT5:
VFMT_$ENCODE5:
VFMT_$ENCODE2:
VFMT_$FORMAT2:
        lea     (VFMT_$FORMAT10:w,%pc),%a0      /* e825e4  41fa fffe       */
        jmp     (VFMT_$FORMATN).l               /* e825e8  4ef9 00e6 b074  */
        .long   VFMT_$MAIN                      /* e825ee  00e6 ab2a       */
        .word   0                               /* e825f2                  */

        .section ".text.VFMT_$WRITE10","ax",@progbits
        .even

        .globl  VFMT_$WRITE10
        .globl  VFMT_$WRITE2
        .globl  VFMT_$WRITE5
VFMT_$WRITE10:
VFMT_$WRITE2:
VFMT_$WRITE5:
        lea     (VFMT_$WRITE10:w,%pc),%a0       /* e825f4  41fa fffe       */
        jmp     (VFMT_$WRITEN).l                /* e825f8  4ef9 00e6 b0a4  */
        .long   VFMT_$WRITE                     /* e825fe  00e6 afe2       */
        .word   0                               /* e82602                  */
