/*
 * smd/sau6/cursor_thunks.s - SMD_$XOR_CURSOR and SMD_$OR_CURSOR, the
 * trampolines to the cursor body, and the lock routines' cells.
 *
 * Image addresses:
 *   sau6  0x7802A59A  SMD_$XOR_CURSOR
 *   sau6  0x7802A5A4  SMD_$OR_CURSOR
 *
 * Each trampoline puts SMD_WIRED's data base (SMD_$DISP2_INT,
 * smd/sau6/disp1_int.s) in A0 and jumps to its entry of the body in the
 * module's code segment (smd/sau6/wired_proc.s, which gives the
 * arguments and the result).  The two cells after them hold the
 * addresses of PROC1_$SET_LOCK and PROC1_$CLR_LOCK; the body calls
 * through them at +0x2D2 and +0x2D6 from the base.  They are unnamed in
 * the map.  MATROX_$BOARD_INSTALLED (smd/m68k/wired_data.s) follows.
 *
 * SHOW_CURSOR, smd_$cursor_op and the blink routines
 * (smd/sau6/blink_cursor_1.s) call SMD_$XOR_CURSOR; nothing in the image
 * calls SMD_$OR_CURSOR.  The `:w' keeps the brief PC-relative form of the
 * `lea' (gas would pick the 68020 full extension word).
 */

        .section ".text.SMD_$XOR_CURSOR","ax",@progbits
        .globl  SMD_$XOR_CURSOR

SMD_$XOR_CURSOR:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        jmp     (smd_$xor_cursor_body).l

        .section ".text.SMD_$OR_CURSOR","ax",@progbits
        .globl  SMD_$OR_CURSOR

SMD_$OR_CURSOR:
        lea     (SMD_$DISP2_INT:w,%pc),%a0
        jmp     (smd_$or_cursor_body).l

/* The lock routines, for the body (lock 8). */
        .long   PROC1_$SET_LOCK
        .long   PROC1_$CLR_LOCK
