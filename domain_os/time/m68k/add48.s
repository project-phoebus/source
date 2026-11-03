|
| time/m68k/add48.s - ADD48 and SUB48, 48-bit clock arithmetic
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings.
|
| SAU2 map: "I E172D0 TIME_ASM size = 2C" (the WIRED_PROC code of the
| hand-written TIME_ASM module; its data segment, `D E2ADFC TIME_ASM', is
| time/m68k/time_asm.s), between DXM_WIRED_ and TONE:
|   0xE172D0  ADD48   (a, b: clocks by address) a := a + b; the low word
|                     with `add.w', then the high longword with `addx.l'
|   0xE172E4  SUB48   (a, b: clocks by address) a := a - b, and D0 = a >= 0
|                     (`spl'): a boolean function
| A clock is 6 bytes: a high longword and a low word (time/time.ins.pas
| time_$clock_t).  No frame; the addresses are read off SP.  The word at
| 0xE172FA is the segment's zero pad to its size (TONE follows).
|
        .section ".text.ADD48","ax",@progbits
        .balign 2

        .globl  ADD48
        .globl  SUB48

ADD48:
        movea.l (0x4,%sp),%a0                   | e172d0  206f 0004
        movea.l (0x8,%sp),%a1                   | e172d4  226f 0008
        addq.l  #4,%a0                          | e172d8  5888
        addq.l  #4,%a1                          | e172da  5889
        move.w  (%a1),%d0                       | e172dc  3011
        add.w   %d0,(%a0)                       | e172de  d150
        addx.l  -(%a1),-(%a0)                   | e172e0  d189
        rts                                     | e172e2  4e75
SUB48:
        movea.l (0x4,%sp),%a0                   | e172e4  206f 0004
        movea.l (0x8,%sp),%a1                   | e172e8  226f 0008
        addq.l  #4,%a0                          | e172ec  5888
        addq.l  #4,%a1                          | e172ee  5889
        move.w  (%a1),%d0                       | e172f0  3011
        sub.w   %d0,(%a0)                       | e172f2  9150
        subx.l  -(%a1),-(%a0)                   | e172f4  9189
        spl     %d0                             | e172f6  5ac0
        rts                                     | e172f8  4e75
        .word   0                               | e172fa  0000  pad to the segment size
