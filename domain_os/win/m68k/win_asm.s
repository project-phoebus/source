|
| win/m68k/win_asm.s - WIN_ASM, WIN_$FILL_CTL_BUF and WIN_$EMPTY_CTL_BUF:
| move a sector's header and data between memory and the Winchester
| controller's data port by program (m68k; the SAU7, SAU8)
|
| The map's WIN_ASM (0x4C bytes, WIRED_PROC) is in the maps of the SAUs
| with the AT bus Winchester controller only (`win_atbus_ctlr',
| base/config.ins.pas); the other SAUs' maps have no WIN_ASM, so the file
| assembles to nothing there.  The SAU7's segment is byte for byte the
| SAU8's.  The address and byte columns are the SAU8 image's.
|
| SAU8 map: "I 3C1AF50 WIN_ASM size = 4C" (WIRED_PROC), WIN_$FILL_CTL_BUF
| at its start, WIN_$EMPTY_CTL_BUF at +0x26.
|
| Hand-written (the `_ASM' segment, no frame, the arguments read off
| SP): WIN8_$DO_IO calls them with three arguments by address, each the
| address of a pointer:
|
|   WIN_$FILL_CTL_BUF   (4,SP) the header (16 words), (8,SP) the data
|                       (512 words), (12,SP) the controller's data port
|   WIN_$EMPTY_CTL_BUF  (4,SP) the data port, (8,SP) the header,
|                       (12,SP) the data
|
| FILL writes the 16 header words, then the 512 data words, to the port
| (a word register, not stepped); EMPTY reads them from it.
|
        .include "base/config.inc"

        .if win_atbus_ctlr

        .section ".text.WIN_$FILL_CTL_BUF","ax",@progbits
        .even

        .globl  WIN_$FILL_CTL_BUF
        .globl  WIN_$EMPTY_CTL_BUF

WIN_$FILL_CTL_BUF:                      | 0x03C1AF50
        moveq   #15,%d0                 | 3c1af50  700f
        movea.l (4,%sp),%a0             | 3c1af52  206f 0004
        movea.l (%a0),%a0               | 3c1af56  2050
        movea.l (12,%sp),%a1            | 3c1af58  226f 000c
        movea.l (%a1),%a1               | 3c1af5c  2251
1:      move.w  (%a0)+,(%a1)            | 3c1af5e  3298
        dbf     %d0,1b                  | 3c1af60  51c8 fffc
        move.w  #511,%d0                | 3c1af64  303c 01ff
        movea.l (8,%sp),%a0             | 3c1af68  206f 0008
        movea.l (%a0),%a0               | 3c1af6c  2050
2:      move.w  (%a0)+,(%a1)            | 3c1af6e  3298
        dbf     %d0,2b                  | 3c1af70  51c8 fffc
        rts                             | 3c1af74  4e75

WIN_$EMPTY_CTL_BUF:                     | 0x03C1AF76
        moveq   #15,%d0                 | 3c1af76  700f
        movea.l (8,%sp),%a0             | 3c1af78  206f 0008
        movea.l (%a0),%a0               | 3c1af7c  2050
        movea.l (4,%sp),%a1             | 3c1af7e  226f 0004
        movea.l (%a1),%a1               | 3c1af82  2251
3:      move.w  (%a1),(%a0)+            | 3c1af84  30d1
        dbf     %d0,3b                  | 3c1af86  51c8 fffc
        move.w  #511,%d0                | 3c1af8a  303c 01ff
        movea.l (12,%sp),%a0            | 3c1af8e  206f 000c
        movea.l (%a0),%a0               | 3c1af92  2050
4:      move.w  (%a1),(%a0)+            | 3c1af94  30d1
        dbf     %d0,4b                  | 3c1af96  51c8 fffc
        rts                             | 3c1af9a  4e75

        .endif
