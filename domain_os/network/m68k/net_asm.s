/*
 * network/m68k/net_asm.s - the NET_ASM data segment
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the
 * bytes are the image's.
 *
 * SAU2 map: "D E2459C NET_ASM size = C" (WIRED_DATA), 0x00E2459C..
 * 0x00E245A7, NETBUF_ following at 0xE245A8.  A hand-written block (the
 * `_ASM' segment name).  Its four symbols, the map's, all zero in the
 * image (`gsk read 0xe2459c 0xc'):
 *
 *   0xE2459C  HINT_$HINTFILE_PTR   a longword: the hint file's mapped
 *                                  address (hint/hint.ins.pas)
 *   0xE245A0  REM_FILE_$2LONG1     a word
 *   0xE245A2  NETWORK_$2LONG1      a word
 *   0xE245A4  NODE_$ME             a longword, this node's ID (MARKED;
 *                                  node/node.ins.pas)
 */

        .section ".text.HINT_$HINTFILE_PTR","ax",@progbits

        .globl  HINT_$HINTFILE_PTR
        .globl  REM_FILE_$2LONG1
        .globl  NETWORK_$2LONG1
        .globl  NODE_$ME

HINT_$HINTFILE_PTR:                             /* e2459c */
        .long   0
REM_FILE_$2LONG1:                               /* e245a0 */
        .word   0
NETWORK_$2LONG1:                                /* e245a2 */
        .word   0
NODE_$ME:                                       /* e245a4 */
        .long   0
