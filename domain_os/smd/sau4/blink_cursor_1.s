/*
 * smd/sau4/blink_cursor_1.s - SMD_$BLINK_CURSOR_1, SMD_$BLINK_CURSOR_2
 * and SMD_$BLINK_CURSOR, the cursor blink routines.
 *
 * Image addresses:
 *   sau4  0x0F8296D0  SMD_$BLINK_CURSOR_1
 *   sau4  0x0F829702  SMD_$BLINK_CURSOR_2
 *   sau4  0x0F82978C  SMD_$BLINK_CURSOR
 *
 * Called with nothing pushed (smd/smd_internal.ins.pas).  Each blinks its
 * unit's cursor, an XOR through SMD_$XOR_CURSOR, and flips the cursor's
 * painted flag (SMD_TIME_$COM+2): unit 1 at IPL 7 unless DISP1 is busy
 * (its status word negative); unit 2, a color board's display (types 3
 * and 4), only when the board is ready and idle (COLOR_SUP+2's bits 4 and
 * 5, its byte at +0xA1) and the record unlocked, else unless DISP2 is
 * busy.  SMD_$BLINK_CURSOR takes the controller's address off the stack
 * and blinks unit 2's cursor for DISP2, unit 1's for any other.
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

        .globl  SMD_$BLINK_CURSOR_1
        .globl  SMD_$BLINK_CURSOR_2
        .globl  SMD_$BLINK_CURSOR

        .section ".text.SMD_$BLINK_CURSOR_1","ax",@progbits
SMD_$BLINK_CURSOR_1:
        moveml %d2/%a2-%a3/%a5,%sp@-             | f8296d0  48e7 2034
        lea %pc@(SMD_$DISP2_INT),%a5             | f8296d4  4bfa fce6
        movew %sr,%sp@-                          | f8296d8  40e7
        oriw #0x700,%sr                          | f8296da  007c 0700
        lea %pc@(SMD_$DISP2_INT),%a5             | f8296de  4bfa fcdc
        tstw DISP1                               | f8296e2  4a79 0fff 9800
        bmiw .Lf829784                           | f8296e8  6b00 009a
        lea %pc@(SMD_TIME_$COM+2),%a1            | f8296ec  43fa 0368
        lea %pc@(SMD_$DISPLAY_COM),%a0           | f8296f0  41fa 01a2
        movel #DISP1,%sp@-                       | f8296f4  2f3c 0fff 9800
        movel #DISP1_MEM,%sp@-                   | f8296fa  2f3c 0ffc 0000
        bras .Lf829768                           | f829700  6066

/* Unit 2: the color board's display or the second monochrome one. */
SMD_$BLINK_CURSOR_2:
        moveml %d2/%a2-%a3/%a5,%sp@-             | f829702  48e7 2034
        lea %pc@(SMD_$DISP2_INT),%a5             | f829706  4bfa fcb4
        movew %sr,%sp@-                          | f82970a  40e7
        lea %pc@(SMD_$DISPLAY_COM+0xe0),%a0      | f82970c  41fa 0266
        cmpiw #3,%a0@                            | f829710  0c50 0003
        beqs .Lf82971c                           | f829714  6706
        cmpiw #4,%a0@                            | f829716  0c50 0004
        bnes .Lf829750                           | f82971a  6634
.Lf82971c:
        btst #4,COLOR_SUP+0x2                    | f82971c  0839 0004 0fff 6002
        beqw .Lf829784                           | f829724  6700 005e
        btst #5,COLOR_SUP+0x2                    | f829728  0839 0005 0fff 6002
        bnew .Lf829784                           | f829730  6600 0052
        cmpiw #0,%a0@(2)                         | f829734  0c68 0000 0002
        bnew .Lf829784                           | f82973a  6600 0048
        tstb COLOR_SUP+0xa1                      | f82973e  4a39 0fff 60a1
        bnew .Lf829784                           | f829744  6600 003e
        pea COLOR_SUP                            | f829748  4879 0fff 6000
        bras .Lf82975e                           | f82974e  600e
.Lf829750:
        tstw DISP2                               | f829750  4a79 0fff 9400
        bmis .Lf829784                           | f829756  6b2c
        movel #DISP1,%sp@-                       | f829758  2f3c 0fff 9800
.Lf82975e:
        lea %pc@(SMD_TIME_$COM+2),%a1            | f82975e  43fa 02f6
        movel #DISP2_MEM,%sp@-                   | f829762  2f3c 0ffa 0000

/* The XOR: the memory and controller pushed above, then the time
   flag, the record, its limits, the position and the cursor number. */
.Lf829768:
        moveal %a1,%a2                           | f829768  2449
        pea %a1@                                 | f82976a  4851
        pea %a0@                                 | f82976c  4850
        pea %a0@(0xce)                           | f82976e  4868 00ce
        pea %a0@(0x32)                           | f829772  4868 0032
        pea %a0@(0x36)                           | f829776  4868 0036
        jsr %pc@(SMD_$XOR_CURSOR)                | f82977a  4eba ff06
        addaw #0x1c,%sp                          | f82977e  defc 001c
        notb %a2@                                | f829782  4612
.Lf829784:
        movew %sp@+,%sr                          | f829784  46df
        moveml %sp@+,%d2/%a2-%a3/%a5             | f829786  4cdf 2c04
        rts                                      | f82978a  4e75
SMD_$BLINK_CURSOR:
        cmpil #DISP2,%sp@(4)                     | f82978c  0caf 0fff 9400 0004
        beqs .Lf82979c                           | f829794  6706
        bsrw SMD_$BLINK_CURSOR_1                 | f829796  6100 ff38
        rts                                      | f82979a  4e75
.Lf82979c:
        bsrw SMD_$BLINK_CURSOR_2                 | f82979c  6100 ff64
        rts                                      | f8297a0  4e75
