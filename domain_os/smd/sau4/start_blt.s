/*
 * smd/sau4/start_blt.s - SMD_$START_BLT, the trampoline to the BLT body.
 *
 * Image addresses:
 *   sau4  0x0F8297DA  SMD_$START_BLT
 *
 * It puts SMD_WIRED's data base (SMD_$DISP2_INT) in A0 and jumps to the
 * body in the module's code segment (smd/sau4/wired_proc.s), as the
 * SAU5's.  The body does not read A0.
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

        .globl  SMD_$START_BLT

        .section ".text.SMD_$START_BLT","ax",@progbits
SMD_$START_BLT:
        lea %pc@(SMD_$DISP2_INT),%a0             | f8297da  41fa fbe0
        jmp smd_$start_blt_body                  | f8297de  4ef9 0f81 66f8
