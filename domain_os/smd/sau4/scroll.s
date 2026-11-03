/*
 * smd/sau4/scroll.s - SMD_$START_SCROLL and SMD_$CONTINUE_SCROLL, the
 * trampolines to the scroll bodies.
 *
 * Image addresses:
 *   sau4  0x0F8297B8  SMD_$START_SCROLL
 *   sau4  0x0F8297C2  SMD_$CONTINUE_SCROLL
 *
 * Each puts SMD_WIRED's data base (SMD_$DISP2_INT) in A0 and jumps to
 * its body in the module's code segment (smd/sau4/wired_proc.s), as the
 * SAU2's and SAU5's.
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

        .globl  SMD_$START_SCROLL
        .globl  SMD_$CONTINUE_SCROLL

        .section ".text.SMD_$START_SCROLL","ax",@progbits
SMD_$START_SCROLL:
        lea %pc@(SMD_$DISP2_INT),%a0             | f8297b8  41fa fc02
        jmp smd_$start_scroll_body               | f8297bc  4ef9 0f81 660a
        .section ".text.SMD_$CONTINUE_SCROLL","ax",@progbits
SMD_$CONTINUE_SCROLL:
        lea %pc@(SMD_$DISP2_INT),%a0             | f8297c2  41fa fbf8
        jmp smd_$continue_scroll_body            | f8297c6  4ef9 0f81 663e
