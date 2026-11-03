|
| ring_8025/sau8/ring_8025_asm.s - RING_8025_ASM, RING_8025_$$MOVB2B:
| copy bytes downward, from the ends of the two buffers
|
| SAU8 map: "I 3C8D720 RING_8025_ASM size = 38" (RING8025_PROC, after
| the RING_8025 code segment), RING_8025_$$MOVB2B its only symbol.  The
| SAU7's segment has the same bytes (0x3C49A1A8); the SAU9's driver has
| no such segment.  Nothing in the image calls it: no instruction or
| cell holds its address.
|
| Hand-written (an `_ASM' segment, no frame, the arguments read off SP),
| three arguments by value:
|
|   (4,SP)   the end of the destination
|   (8,SP)   the end of the source
|   (12,SP)  the byte count, a word
|
| When both ends are even the longwords are moved first (count div 4,
| from the ends downward), then the remaining count mod 4 bytes; when
| either is odd every byte is moved singly.  A count of 0 moves nothing.
|
| The Apollo assembler's `and.w #imm,Dn' (<ea>=#imm, 0xC07C), which gas
| encodes as andi, is written as `.short'.
|
| Byte check: assembled with `m68k-elf-as -m68020 -m68881' and compared
| with the image's 0x38 bytes; the build has no SAU8 target yet.  The
| address and byte columns are the SAU8 image's.
|
        .section ".text.RING_8025_ASM.RING8025_PROC","ax",@progbits
        .even

        .globl  RING_8025_$$MOVB2B

RING_8025_$$MOVB2B:                     | 0x3C8D720
        movem.l (4,%sp),%a0-%a1         | 3c8d720  4cef 0300 0004
        move.w  (12,%sp),%d0            | 3c8d726  302f 000c
        move.l  %a0,%d1                 | 3c8d72a  2208
        btst    #0,%d1                  | 3c8d72c  0801 0000
        bne.s   2f                      | 3c8d730  661a
        move.l  %a1,%d1                 | 3c8d732  2209
        btst    #0,%d1                  | 3c8d734  0801 0000
        bne.s   2f                      | 3c8d738  6612
        move.w  %d0,%d1                 | 3c8d73a  3200
        .short  0xc07c, 0x0003          | 3c8d73c  c07c 0003  and.w #3,%d0
        lsr.w   #2,%d1                  | 3c8d740  e449
        subq.w  #1,%d1                  | 3c8d742  5341
        blt.s   2f                      | 3c8d744  6d06
1:      move.l  -(%a1),-(%a0)           | 3c8d746  2121
        dbf     %d1,1b                  | 3c8d748  51c9 fffc
2:      subq.w  #1,%d0                  | 3c8d74c  5340
        blt.s   4f                      | 3c8d74e  6d06
3:      move.b  -(%a1),-(%a0)           | 3c8d750  1121
        dbf     %d0,3b                  | 3c8d752  51c8 fffc
4:      rts                             | 3c8d756  4e75
