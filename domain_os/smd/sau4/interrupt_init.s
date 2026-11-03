/*
 * smd/sau4/interrupt_init.s - SMD_$INTERRUPT_INIT, install the display
 * interrupt handlers.
 *
 * Image addresses:
 *   sau4  0x0F8297A2  SMD_$INTERRUPT_INIT
 *
 * Hand-written code in SMD_WIRED's data segment.  SMD_$INIT calls it
 * with nothing pushed; no argument, no result (smd/smd_internal.ins.pas).
 * SMD_$DISP1_INT goes in its vector, DISP1_VEC, and SMD_$DISP2_INT in
 * DISP2_VEC (the map's absolute symbols), by their absolute addresses.
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

        .globl  SMD_$INTERRUPT_INIT

        .section ".text.SMD_$INTERRUPT_INIT","ax",@progbits
SMD_$INTERRUPT_INIT:
        lea %pc@(SMD_$DISP1_INT),%a0             | f8297a2  41fa fc32
        movel %a0,DISP1_VEC                      | f8297a6  23c8 0000 03d0
        lea %pc@(SMD_$DISP2_INT),%a0             | f8297ac  41fa fc0e
        movel %a0,DISP2_VEC                      | f8297b0  23c8 0000 03c8
        rts                                      | f8297b6  4e75
