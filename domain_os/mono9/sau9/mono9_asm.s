|
| mono9/sau9/mono9_asm.s - MONO9_ASM: the DN2500 monochrome display's
| hand-written routines: the display's form, the video on and off, the
| color table's one bit, and the cursor's exclusive-or into display
| memory
|
| SAU9 map: "D 3C43348C MONO9_ASM size = 100" (WIRED_DATA, after the
| MONO9 module's 4-byte block), four symbols:
|
|   +0x00  (no symbol)             VTGA's address, the video controller's
|                                  registers (an IODEFS symbol)
|   +0x04  (no symbol)             the display memory's address,
|                                  0x3FFA0000
|   +0x08  DISP_QUERY              the display's form from bits 5..4 of
|                                  VTGA+0x404: 0 (both clear), 2 (both
|                                  set) or 1, a word in D0
|   +0x30  MONO9_$VIDEO_CTL        0x9C to VTGA+0, then bit 3 of VTGA+4
|                                  set when the boolean at 8(SP) is true,
|                                  cleared when false
|   +0x50  MONO9_$SET_COLOR_TABLE  VTGA+0x400 with bit 4 set while the
|                                  byte at 0xC(SP)'s address is nonzero,
|                                  masked with 0x70; the status at
|                                  0x10(SP)'s address cleared
|   +0x7A  MONO9_$XOR_CURSOR       the cursor pattern of SMD_$CURSOR_TABLE
|                                  (40-byte entries: four words, the
|                                  pattern) for the cursor number at
|                                  0x20(SP), exclusive-or'ed with
|                                  bit-field instructions into display
|                                  memory at the position (line, column)
|                                  at 0x22(SP), 2048 bits a line, clipped
|                                  at the memory's end and at column 0;
|                                  D0 0xFF
|   +0xFE  two zero bytes to the segment's end
|
| Hand-written (the `_ASM' segment, code in a data section, no frame;
| the routines read their arguments off the stack, the first longword,
| the descriptor's address, unread).  The callers: MONO9_$IOINIT
| (DISP_QUERY, twice), MONO9_$BLINK_CURSOR (MONO9_$XOR_CURSOR), and the
| display driver through MONO9_$WIRED_DATA's vector (mono9/mono9.ins.pas
| has the headings).  68030 code (`bfextu', `bfins').
|
| Only the SAU9's map has the segment.  Every byte was checked against
| the image by assembling with m68k-elf-as -m68030 and linking at the
| segment's address with the map's VTGA and SMD_$CURSOR_TABLE (the SAU9
| build is not linked yet).  The Apollo assembler's word branches where
| a short one reaches and its CMP/AND/OR <ea>=#imm encodings are .word
| or explicit .w.
|
        .section ".text.DISP_QUERY","ax",@progbits
        .even

        .globl  DISP_QUERY
        .globl  MONO9_$VIDEO_CTL
        .globl  MONO9_$SET_COLOR_TABLE
        .globl  MONO9_$XOR_CURSOR

vtga_addr:                              | 0x3C43348C
        .long   VTGA
memory_addr:                            | 0x3C433490
        .long   0x3FFA0000

DISP_QUERY:                             | 0x3C433494
        movea.l (vtga_addr,%pc),%a0     | 3c433494  207a fff6
        move.b  0x404(%a0),%d0          | 3c433498  1028 0404
        .word   0xc03c,0x0030           | 3c43349c  and.b #0x30,%d0
        beq.w   3f                      | 3c4334a0  6700 0016
        .word   0xb03c,0x0030           | 3c4334a4  cmp.b #0x30,%d0
        bne.w   2f                      | 3c4334a8  6600 000a
        move.b  #2,%d0                  | 3c4334ac  103c 0002
        bra.w   3f                      | 3c4334b0  6000 0006
2:      move.b  #1,%d0                  | 3c4334b4  103c 0001
3:      ext.w   %d0                     | 3c4334b8  4880
        rts                             | 3c4334ba  4e75

MONO9_$VIDEO_CTL:                       | 0x3C4334BC
        movea.l (vtga_addr,%pc),%a1     | 3c4334bc  227a ffce
        move.b  #0x9c,(%a1)             | 3c4334c0  12bc 009c
        tst.b   8(%sp)                  | 3c4334c4  4a2f 0008
        beq.w   1f                      | 3c4334c8  6700 000a
        bset    #3,4(%a1)               | 3c4334cc  08e9 0003 0004
        rts                             | 3c4334d2  4e75
1:      bclr    #3,4(%a1)               | 3c4334d4  08a9 0003 0004
        rts                             | 3c4334da  4e75

MONO9_$SET_COLOR_TABLE:                 | 0x3C4334DC
        movea.l 12(%sp),%a1             | 3c4334dc  226f 000c
        movea.l (vtga_addr,%pc),%a0     | 3c4334e0  207a ffaa
        move.b  0x400(%a0),%d0          | 3c4334e4  1028 0400
        .word   0x803c,0x0010           | 3c4334e8  or.b #0x10,%d0
        tst.b   (%a1)                   | 3c4334ec  4a11
        bne.w   1f                      | 3c4334ee  6600 0006
        .word   0xc03c,0x00ef           | 3c4334f2  and.b #0xef,%d0
1:      .word   0xc03c,0x0070           | 3c4334f6  and.b #0x70,%d0
        move.b  %d0,0x400(%a0)          | 3c4334fa  1140 0400
        movea.l 16(%sp),%a0             | 3c4334fe  206f 0010
        clr.l   (%a0)                   | 3c433502  4290
        rts                             | 3c433504  4e75

MONO9_$XOR_CURSOR:                      | 0x3C433506
        movem.l %d2-%d7,-(%sp)          | 3c433506  48e7 3f00
        clr.l   %d4                     | 3c43350a  4284
        clr.l   %d5                     | 3c43350c  4285
        move.w  36(%sp),%d4             | 3c43350e  382f 0024  column
        move.w  34(%sp),%d5             | 3c433512  3a2f 0022  line
        move.w  32(%sp),%d0             | 3c433516  302f 0020  cursor number
        mulu.w  #40,%d0                 | 3c43351a  c0fc 0028
        lea     SMD_$CURSOR_TABLE,%a0   | 3c43351e  41f9 3c42 a720
        adda.l  %d0,%a0                 | 3c433524  d1c0
        movem.w (%a0)+,%d0-%d3          | 3c433526  4c98 000f
        subq.w  #1,%d1                  | 3c43352a  5341
        adda.l  %d1,%a0                 | 3c43352c  d1c1
        adda.l  %d1,%a0                 | 3c43352e  d1c1
        add.w   %d3,%d5                 | 3c433530  da43
        sub.w   %d2,%d4                 | 3c433532  9842
        bge.w   1f                      | 3c433534  6c00 0004
        clr.l   %d4                     | 3c433538  4284
1:      movea.l (memory_addr,%pc),%a1   | 3c43353a  227a ff54
        move.w  #11,%d6                 | 3c43353e  3c3c 000b
        lsl.l   %d6,%d5                 | 3c433542  edad
        add.l   %d5,%d4                 | 3c433544  d885
        move.l  #2048,%d6               | 3c433546  2c3c 0000 0800
        move.w  #2,%d3                  | 3c43354c  363c 0002
        clr.l   %d5                     | 3c433550  4285
2:      .word   0xb8bc,0x0020,0x0000    | 3c433552  cmp.l #0x200000,%d4
        bcs.w   3f                      | 3c433558  6500 000e
        suba.w  %d3,%a0                 | 3c43355c  90c3
        sub.l   %d6,%d4                 | 3c43355e  9886
        dbf     %d1,2b                  | 3c433560  51c9 fff0
        bra.w   4f                      | 3c433564  6000 001c
3:      bfextu  (%a0){%d5:%d0},%d2      | 3c433568  e9d0 2960
        suba.w  %d3,%a0                 | 3c43356c  90c3
        bfextu  (%a1){%d4:%d0},%d7      | 3c43356e  e9d1 7920
        eor.l   %d2,%d7                 | 3c433572  b587
        bfins   %d7,(%a1){%d4:%d0}      | 3c433574  efd1 7920
        sub.l   %d6,%d4                 | 3c433578  9886
        bmi.w   4f                      | 3c43357a  6b00 0006
        dbf     %d1,3b                  | 3c43357e  51c9 ffe8
4:      st      %d0                     | 3c433582  50c0
        movem.l (%sp)+,%d2-%d7          | 3c433584  4cdf 00fc
        rts                             | 3c433588  4e75
        .word   0                       | 3c43358a  to the segment's end
