|
| color2/sau6/color2_asm.s - COLOR2_ASM: the COLOR2 board's interrupt
| handler and its eventcount
|
| SAU6 map: "D 78032C98 COLOR2_ASM size = 24" (WIRED_DATA), two symbols:
|
|   +0x00  COLOR2_$INT_DECODE  the board's interrupt handler, entered by
|                              its vector, COLOR2_DONE_VEC (0x290;
|                              COLOR2_$INT_INIT puts it there,
|                              `gpu_own_vectors'): it raises the IPL to 7,
|                              saves D0-D1/A0-A1, switches to the
|                              interrupt stack (IO_$USE_INT_STACK) and
|                              advances the board's eventcount
|                              (PROC1_$INT_ADVANCE with it in A0)
|   +0x18  COLOR2_$INT_EC      an eventcount, 12 bytes, zero (COLOR2_$COLD_INIT
|                              initializes it with EC_$INIT; GPU_$CMND waits
|                              on it, COLOR2_$GET_EC registers it)
|
| Hand-written (the `_ASM' segment, code in a data section, no frame,
| left by a jump).  The SAU5's COLOR2_$INT_DECODE (color2/sau5/
| color2_asm.s) is entered by a jump from a decoder that saved the
| registers, and tests the vector.
|
| The Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU6 build takes
| this file.  Every byte was checked against the image by assembling and
| linking the file at the segment's address with the SAU6 map's
| addresses for the other symbols.
|
        .section ".text.COLOR2_$INT_DECODE","ax",@progbits
        .even

        .globl  COLOR2_$INT_DECODE
        .globl  COLOR2_$INT_EC

COLOR2_$INT_DECODE:                     | 0x78032C98
        oriw    #0x700,%sr              | 78032c98  007c 0700  IPL 7
        moveml  %d0-%d1/%a0-%a1,%sp@-   | 78032c9c  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | 78032ca0  4eb9 7803 7026
        lea     (COLOR2_$INT_EC,%pc),%a0  | 78032ca6  41fa 0008
        jmp     PROC1_$INT_ADVANCE      | 78032caa  4ef9 7802 2e96

COLOR2_$INT_EC:                         | 0x78032CB0
        .long   0, 0, 0
