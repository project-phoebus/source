|
| color2/sau5/color2_asm.s - COLOR2_ASM: the COLOR2 board's interrupt
| decoder and its eventcount
|
| SAU5 map: "D E2F390 COLOR2_ASM size = 24" (WIRED_DATA), two symbols:
|
|   +0x00  COLOR2_$INT_DECODE  entered by a jump from a decoder that saved
|                              D0-D1/A0-A1, the vector in D0's low byte:
|                              for 0xA4 the board's eventcount is advanced
|                              (PROC1_$INT_ADVANCE with it in A0); any other
|                              vector goes on to VME_$SPURIOUS_INT
|                              (vme/sau5/vme_asm.s), which restores the
|                              registers
|   +0x16  COLOR2_$INT_EC      an eventcount, 12 bytes, zero (COLOR2_$COLD_INIT
|                              initializes it with EC_$INIT; GPU_$CMND waits
|                              on it, COLOR2_$GET_EC registers it)
|
| Then a zero pad word.  Hand-written (the `_ASM' segment, code in a data
| section, no frame, left by jumps).
|
| The SAU5's: the SAU6's COLOR2_ASM is 0x24 bytes of other code (the
| catalog: COLOR2_$INT_DECODE differs), and no other SR10.2 map has the
| segment.  The Makefile assembles
| */$(TARGET_SAU)/*.s, so only a SAU5 build takes this file.  Every byte
| was checked against the image by assembling and linking the file at
| the segment's address with the map's addresses for the other symbols
| (the SAU5 build is not linked yet).  The Apollo assembler's CMP
| <ea>=#imm encoding is .word.
|
        .section ".text.COLOR2_$INT_DECODE","ax",@progbits
        .even

        .globl  COLOR2_$INT_DECODE
        .globl  COLOR2_$INT_EC

COLOR2_$INT_DECODE:                     | 0xE2F390
        .word   0xb03c,0x00a4           | e2f390  cmp.b #0xa4,%d0
        beq.s   1f                      | e2f394  6706
        jmp     VME_$SPURIOUS_INT       | e2f396  4ef9 00e2 3620
1:      lea     (COLOR2_$INT_EC,%pc),%a0  | e2f39c  41fa 0008
        jmp     PROC1_$INT_ADVANCE      | e2f3a0  4ef9 00e2 15be

COLOR2_$INT_EC:                         | 0xE2F3A6
        .long   0, 0, 0
        .word   0                       | e2f3b2
