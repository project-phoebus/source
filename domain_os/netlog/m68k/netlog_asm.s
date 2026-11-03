/*
 * netlog/m68k/netlog_asm.s - the NETLOG_ASM data segment
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the bytes are the
 * image's, the eventcount's two self-pointers as relocations resolved
 * against the image's longwords.
 *
 * SAU2 map: "D E248E0 NETLOG_ASM size = 1C" (WIRED_DATA), 0x00E248E0..
 * 0x00E248FB, NETWORK following at 0xE248FC.  A hand-written block (the
 * `_ASM' segment name).  Its symbols, the map's (`gsk read 0xe248e0
 * 0x1c': `0000 0000 0000 0000 0000 0000 00e2 48e8 00e2 48e8 0000 0000
 * 0000 0000'):
 *
 *   0xE248E0  NETLOG_$OK_TO_LOG         a boolean byte and its pad byte
 *   0xE248E2  NETLOG_$OK_TO_LOG_SERVER  the same (MARKED)
 *   0xE248E4  NETLOG_$KINDS             a longword, the kinds logged
 *   0xE248E8  NETLOG_$EC                an eventcount (12 bytes: the
 *                                       value, then the waiter list's head
 *                                       and tail, both the eventcount's
 *                                       own address when empty)
 *   0xE248F4  NETLOG_$NODE              a longword
 *   0xE248F8  NETLOG_$SOCK              a word, then a pad word to the
 *                                       segment's end
 *
 * The types are the Pascal tree's externs (netlog/netlog.ins.pas).
 */

        .section ".text.NETLOG_$OK_TO_LOG","ax",@progbits

        .globl  NETLOG_$OK_TO_LOG
        .globl  NETLOG_$OK_TO_LOG_SERVER
        .globl  NETLOG_$KINDS
        .globl  NETLOG_$EC
        .globl  NETLOG_$NODE
        .globl  NETLOG_$SOCK

NETLOG_$OK_TO_LOG:                              /* e248e0 */
        .byte   0, 0
NETLOG_$OK_TO_LOG_SERVER:                       /* e248e2 */
        .byte   0, 0
NETLOG_$KINDS:                                  /* e248e4 */
        .long   0
NETLOG_$EC:                                     /* e248e8 */
        .long   0                               /* value                 */
        .long   NETLOG_$EC                      /* e248ec  00e248e8 head */
        .long   NETLOG_$EC                      /* e248f0  00e248e8 tail */
NETLOG_$NODE:                                   /* e248f4 */
        .long   0
NETLOG_$SOCK:                                   /* e248f8 */
        .word   0
        .word   0                               /* e248fa: to the segment's end */
