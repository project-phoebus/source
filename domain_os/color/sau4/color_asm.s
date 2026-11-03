|
| color/sau4/color_asm.s - COLOR_ASM: the color board's interrupt
| set-up, its interrupt routine and its instruction queue's eventcount
|
| SAU4 map: "D F829B7C COLOR_ASM size = 34" (WIRED_DATA), two symbols:
|
|   +0x00  COLOR_$VECTOR_INIT  stores the interrupt routine's address in
|                              the board's vector, COLOR_VEC (16#CE,
|                              the map's 0x338), itself (COLOR_$COLD_INIT
|                              calls it)
|   +0x0C  (no symbol)         the interrupt routine: saves D0-D1/A0-A1,
|                              switches to the interrupt stack
|                              (IO_$USE_INT_STACK), writes 0x8000 to
|                              COLOR_SUP+0xA0 (the instruction queue's
|                              interrupt off) and leaves through
|                              PROC1_$INT_ADVANCE with COLOR_$IQ_DONE_EC
|                              in A0 (advance it and return from the
|                              interrupt)
|   +0x28  COLOR_$IQ_DONE_EC   an eventcount, 12 bytes, zero (COLOR_$COLD_INIT
|                              initializes it with EC_$INIT)
|
| Hand-written (the `_ASM' segment, code in a data section, no frame;
| the interrupt routine is entered by the vector and left by
| PROC1_$INT_ADVANCE's return from the exception).  The board has one
| interrupt, the instruction queue done, so the routine decodes nothing
| (the SAU5's COLOR_$INT_DECODE), and its pages go through the I/O map,
| so there is no COLOR_$LOAD_MAP (`color_board_iomap',
| base/config.ins.pas).
|
| The SAU4's: the SAU5's COLOR_ASM is 0x9C bytes of other code
| (color/sau5/color_asm.s), and no other SR10.2 map has the segment.
| The Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU4 build takes
| this file.  Every byte was checked against the image by assembling
| and linking the file at the segment's address with the map's
| addresses for the other symbols.
|
        .section ".text.COLOR_$VECTOR_INIT","ax",@progbits
        .even

        .globl  COLOR_$VECTOR_INIT
        .globl  COLOR_$IQ_DONE_EC

COLOR_$VECTOR_INIT:                     | 0xF829B7C
        lea     (1f,%pc),%a0            | f829b7c  41fa 000a
        move.l  %a0,COLOR_VEC           | f829b80  23c8 0000 0338
        rts                             | f829b86  4e75

1:      movem.l %d0-%d1/%a0-%a1,-(%sp)  | f829b88  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | f829b8c  4eb9 0f83 1c26
        move.w  #0x8000,COLOR_SUP+0xA0  | f829b92  33fc 8000 0fff 60a0
        lea     (COLOR_$IQ_DONE_EC,%pc),%a0  | f829b9a  41fa 0008
        jmp     PROC1_$INT_ADVANCE      | f829b9e  4ef9 0f82 1f06

COLOR_$IQ_DONE_EC:                      | 0xF829BA4
        .long   0, 0, 0
