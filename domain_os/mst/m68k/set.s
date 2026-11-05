|
| mst/m68k/set.s - MST_$SET and MST_$SET_CLEAR, set and clear a bit of a
| bit map
|
| The SAU2, SAU3, SAU5, SAU7, SAU8 and SAU9 images have the same code here;
| the address and byte columns below are the SAU2 image's (the SAU7's
| MST_ASM is at 0x3C41DCBC, the SAU8's at 0x3C1B2D8, the SAU9's at
| 0x3C41CCA4).
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings; the Apollo assembler's `or.w #imm,Dn' <ea>=#imm form
| (827c), which gas spells ORI, is a `.short' opcode word and its
| immediate.
|
| SAU2 map: "I E1A0FC MST_ASM size = 38" (between UID_ and PCHIST):
|   0xE1A0FC  MST_$SET        (map: by address; size: word, bit: word, by
|                             value) bset bit `bit' of the bit map
|   0xE1A118  MST_$SET_CLEAR  (the same) bclr
| No frame; the arguments are read off SP: the map's address at (4,SP),
| the map's size in bits at (8,SP), the bit number at (0xA,SP).  The byte
| index is ((size - 1) | 15) - bit, shifted right by 3: bit 0 is the
| least significant bit of the map's last byte of its last word, the
| Pascal set layout, so the bit numbers are a
| Pascal set's members.  0xE1A134 is PCHIST_$COUNT.
|
        .section ".text.MST_$SET","ax",@progbits
        .balign 2

        .globl  MST_$SET
        .globl  MST_$SET_CLEAR

MST_$SET:
        move.w  (0xa,%sp),%d0                   | e1a0fc  302f 000a
        move.w  (0x8,%sp),%d1                   | e1a100  322f 0008
        subq.w  #1,%d1                          | e1a104  5341
        .short  0x827c; .short 0x000f           | e1a106  827c 000f  or.w    #0xf,%d1, the <ea>=#imm form
        sub.w   %d0,%d1                         | e1a10a  9240
        lsr.w   #3,%d1                          | e1a10c  e649
        movea.l (0x4,%sp),%a0                   | e1a10e  206f 0004
        bset    %d0,(0x0,%a0,%d1.w)             | e1a112  01f0 1000
        rts                                     | e1a116  4e75
MST_$SET_CLEAR:
        move.w  (0xa,%sp),%d0                   | e1a118  302f 000a
        move.w  (0x8,%sp),%d1                   | e1a11c  322f 0008
        subq.w  #1,%d1                          | e1a120  5341
        .short  0x827c; .short 0x000f           | e1a122  827c 000f  or.w    #0xf,%d1, the <ea>=#imm form
        sub.w   %d0,%d1                         | e1a126  9240
        lsr.w   #3,%d1                          | e1a128  e649
        movea.l (0x4,%sp),%a0                   | e1a12a  206f 0004
        bclr    %d0,(0x0,%a0,%d1.w)             | e1a12e  01b0 1000
        rts                                     | e1a132  4e75
