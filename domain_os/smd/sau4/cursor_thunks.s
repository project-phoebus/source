/*
 * smd/sau4/cursor_thunks.s - SMD_$XOR_CURSOR and SMD_$OR_CURSOR, the
 * trampolines to the cursor body, and the lock routines' cells.
 *
 * Image addresses:
 *   sau4  0x0F829682  SMD_$XOR_CURSOR
 *   sau4  0x0F82968C  SMD_$OR_CURSOR
 *
 * Each trampoline puts SMD_WIRED's data base (SMD_$DISP2_INT,
 * smd/sau4/disp1_int.s) in A0 and jumps to its entry of the body in the
 * module's code segment (smd/sau4/wired_proc.s).  The two cells after
 * them hold the addresses of PROC1_$SET_LOCK and PROC1_$CLR_LOCK; the
 * body calls through them at +0x2DA and +0x2DE from the base.
 * MATROX_$BOARD_INSTALLED (smd/m68k/wired_data.s) follows.  The SAU5's
 * code (smd/sau5/cursor_thunks.s) at the SAU4's addresses.
 *
 * Checked by assembly: `m68k-elf-as -m68010', linked with the SMD_WIRED
 * files at their map addresses and the SAU4 map's addresses for the
 * other symbols; every byte is the SAU4 image's.  The address and byte
 * columns are the SAU4 image's.  The CMP, AND, OR and ADD with an
 * immediate source and a data register destination in the Apollo
 * assembler's <ea>=#imm form (gas emits CMPI, ANDI, ORI and ADDI, the same
 * length), the MOVE.L of a small immediate (gas emits MOVEQ) and the
 * ADD.L #imm to a data register (gas emits ADDQ or ADDI) are `.short'
 * words, the instruction in the comment.
 */

        .globl  SMD_$XOR_CURSOR
        .globl  SMD_$OR_CURSOR

        .section ".text.SMD_$XOR_CURSOR","ax",@progbits
SMD_$XOR_CURSOR:
        lea %pc@(SMD_$DISP2_INT),%a0             | f829682  41fa fd38
        jmp smd_$xor_cursor_body                 | f829686  4ef9 0f81 6404
        .section ".text.SMD_$OR_CURSOR","ax",@progbits
SMD_$OR_CURSOR:
        lea %pc@(SMD_$DISP2_INT),%a0             | f82968c  41fa fd2e
        jmp smd_$or_cursor_body                  | f829690  4ef9 0f81 640e

/* The lock routines, for the body (lock 8). */
        .long   PROC1_$SET_LOCK          | f829696
        .long   PROC1_$CLR_LOCK          | f82969a
