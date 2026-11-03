/*
 * smd/sau4/unwire_mm.s - SMD_$UNWIRE_MM, the trampoline to the body that
 * unwires the BLT's main-memory pages, and WP_$UNWIRE's cell.
 *
 * Image addresses:
 *   sau4  0x0F8297CC  SMD_$UNWIRE_MM
 *
 * It puts SMD_WIRED's data base (SMD_$DISP2_INT) in A0 and jumps to the
 * body in the module's code segment (smd/sau4/wired_proc.s), which
 * calls WP_$UNWIRE through the cell that follows (+0x41A from the base).
 * SMD_$WIRE_MM, SMD_$BLT and SMD_$ACQ_DISPLAY call it with the display
 * record's address and the unit's controller (`blt_main_memory',
 * smd/smd_internal.ins.pas).
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

        .globl  SMD_$UNWIRE_MM

        .section ".text.SMD_$UNWIRE_MM","ax",@progbits
SMD_$UNWIRE_MM:
        lea %pc@(SMD_$DISP2_INT),%a0             | f8297cc  41fa fbee
        jmp smd_$unwire_mm_body                  | f8297d0  4ef9 0f81 6670
        .long   WP_$UNWIRE               | f8297d6
