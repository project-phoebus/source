|
| color/sau5/color_asm.s - COLOR_ASM: the color board's interrupt
| set-up, its interrupt decoder, its instruction queue's eventcount and
| its color map loader
|
| SAU5 map: "D E28540 COLOR_ASM size = 9C" (WIRED_DATA), four symbols:
|
|   +0x00  COLOR_$VECTOR_INIT  defines the board's interrupt: VME_$DEFINE_INT
|                              with the id (3, 3), COLOR_$INT_DECODE and a
|                              nil argument (COLOR_$COLD_INIT calls it)
|   +0x2A  COLOR_$INT_DECODE   the handler VME_ calls with the vector word
|                              in the longword argument's low byte: 0xA8
|                              (the instruction queue done) writes 0x8000
|                              to COLOR_SUP+0xA0 and advances
|                              COLOR_$IQ_DONE_EC, 0xA4 advances nothing
|                              (D0 0), any other vector advances
|                              COLOR2_$INT_EC (color2/sau5/color2_asm.s);
|                              D0 0xFF when it advanced one
|   +0x5E  COLOR_$IQ_DONE_EC   an eventcount, 12 bytes, zero (COLOR_$COLD_INIT
|                              initializes it with EC_$INIT)
|   +0x6A  COLOR_$LOAD_MAP     writes a color map entry: the entry's address
|                              and two words by value off the stack; waits
|                              for COLOR_SUP+2's bit 7 to clear, then at IPL 7
|                              strobes COLOR_SUP+0x98 with 0x400 before each
|                              of the two word stores
|
| Hand-written (the `_ASM' segment, code in a data section, no frame;
| the handler and COLOR_$LOAD_MAP read their arguments off the stack).
| The callers: COLOR_$COLD_INIT (COLOR_$VECTOR_INIT), COLOR_$MAP and
| COLOR_$UNMAP (COLOR_$LOAD_MAP, color/color.ins.pas's heading).
|
| The SAU5's: the SAU4's COLOR_ASM is 0x34 bytes of other code, and no
| other SR10.2 map has the segment.  The Makefile assembles
| */$(TARGET_SAU)/*.s, so only a SAU5 build takes this file.  Every byte
| was checked against the image by assembling and linking the file at
| the segment's address with the map's addresses for the other symbols
| (the SAU5 build is not linked yet).  The Apollo assembler's CMP
| <ea>=#imm encodings and `adda.l #imm' are .word.
|
        .section ".text.COLOR_$VECTOR_INIT","ax",@progbits
        .even

        .globl  COLOR_$VECTOR_INIT
        .globl  COLOR_$INT_DECODE
        .globl  COLOR_$IQ_DONE_EC
        .globl  COLOR_$LOAD_MAP

COLOR_$VECTOR_INIT:                     | 0xE28540
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | e28540  48e7 c0c0
        move.l  #0,-(%sp)               | e28544  2f3c 0000 0000
        pea     (COLOR_$INT_DECODE,%pc) | e2854a  487a 001e
        move.w  #3,-(%sp)               | e2854e  3f3c 0003
        move.w  #3,-(%sp)               | e28552  3f3c 0003
        lea     VME_$DEFINE_INT,%a0     | e28556  41f9 00e0 aa94
        jsr     (%a0)                   | e2855c  4e90
        .word   0xdffc,0x0000,0x000c    | e2855e  adda.l #12,%sp
        movem.l (%sp)+,%d0-%d1/%a0-%a1  | e28564  4cdf 0303
        rts                             | e28568  4e75

COLOR_$INT_DECODE:                      | 0xE2856A
        move.l  4(%sp),%d0              | e2856a  202f 0004
        .word   0xb03c,0x00a8           | e2856e  cmp.b #0xa8,%d0
        beq.s   2f                      | e28572  671c
        .word   0xb03c,0x00a4           | e28574  cmp.b #0xa4,%d0
        bne.s   1f                      | e28578  6604
        clr.b   %d0                     | e2857a  4200
        bra.s   3f                      | e2857c  6010
1:      pea     COLOR2_$INT_EC          | e2857e  4879 00e2 f3a6
4:      jsr     EC_$ADVANCE_WITHOUT_DISPATCH  | e28584  4eb9 00e2 13e0
        addq.l  #4,%sp                  | e2858a  588f
        st      %d0                     | e2858c  50c0
3:      rts                             | e2858e  4e75
2:      move.w  #0x8000,COLOR_SUP+0xA0  | e28590  33fc 8000 00ff 60a0
        pea     (COLOR_$IQ_DONE_EC,%pc) | e28598  487a 0004
        bra.s   4b                      | e2859c  60e6

COLOR_$IQ_DONE_EC:                      | 0xE2859E
        .long   0, 0, 0

COLOR_$LOAD_MAP:                        | 0xE285AA
        move.l  %a2,-(%sp)              | e285aa  2f0a
        lea     8(%sp),%a2              | e285ac  45ef 0008
        movea.l (%a2)+,%a0              | e285b0  205a
        lea     COLOR_SUP,%a1           | e285b2  43f9 00ff 6000
1:      btst    #7,2(%a1)               | e285b8  0829 0007 0002
        bne.s   1b                      | e285be  66f8
        ori.w   #0x700,%sr              | e285c0  007c 0700
        move.w  #0x400,0x98(%a1)        | e285c4  337c 0400 0098
        move.w  (%a2)+,(%a0)+           | e285ca  30da
        move.w  #0x400,0x98(%a1)        | e285cc  337c 0400 0098
        move.w  (%a2),(%a0)             | e285d2  3092
        andi.w  #0xf8ff,%sr             | e285d4  027c f8ff
        movea.l (%sp)+,%a2              | e285d8  245f
        rts                             | e285da  4e75
