|
| scsi/sau9/scsi_asm.s - SCSI_ASM, SCSI_$HP_WRITE and SCSI_$HP_READ: move
| a transfer's bytes between memory and the 53C90's DMA port by program
|
| SAU9 maps: "I 3C4203E8 SCSI_ASM size = B4" (WIRED_PROC), SCSI_$HP_WRITE
| at its start; "D 3C43358C SCSI_ASM size = 50" (WIRED_DATA), a cell
| holding UTIL_PIO's address, then SCSI_$HP_READ at +4 and a zero pad
| word to the segment's end.
|
| Hand-written (the `_ASM' segments, code in a data section, no frame,
| the arguments read off SP, `jmp' back to the loop head): SCSI_$C90_DMA
| calls them with four arguments by address (scsi/scsi.ins.pas):
|
|   (20,SP)  the address of a pointer to the FIFO flags register
|   (24,SP)  the address of a pointer to the DMA port
|   (28,SP)  the address of a pointer to the buffer
|   (32,SP)  the address of the byte count
|
| (after the four saved registers).  Each runs at IPL 4 (SR 0x2400, the
| old SR restored at the end) and returns in D0 the bytes moved.
|
| SCSI_$HP_WRITE writes at most what the FIFO has room for (16 bytes
| less its count, the flags' bits 4..0, a count above 16 taken as 16),
| at most the byte count, in pieces of 16, 8, 4, 2 and 1 bytes, the
| count's bits deciding; it loops until the byte count or the room is
| used up (both are reread each time round: the room from the flags).
| The buffer pointer itself is not advanced in memory: the caller
| passes a fresh one.
|
| SCSI_$HP_READ does not read its first argument: it tests bit 4 of the
| utility PIO register (UTIL_PIO, the cell before it) and reads one
| byte from the port while that bit is set, up to the byte count.  It
| returns the bytes read (0 when the bit was clear from the start or
| the count was 0).
|
| Byte check: assembled with `m68k-elf-as -m68030' and compared with the
| image (each address operand of an absolute cell left at 0 by the
| assembler, UTIL_PIO's); the build has no SAU9 target yet.  The
| Apollo assembler's <ea>=#imm forms (cmp.l, and.b, sub.l, add.l #imm),
| which gas spells as cmpi/andi/subi/addi, are written as `.short'.
| The address and byte columns are the SAU9 image's.
|
        .section ".text.SCSI_$HP_WRITE","ax",@progbits
        .even

        .globl  SCSI_$HP_WRITE

SCSI_$HP_WRITE:                         | 0x3C4203E8
        movem.l %d2-%d4/%a2,-(%sp)      | 3c4203e8  48e7 3820
        move.w  %sr,%d4                 | 3c4203ec  40c4
        move.w  #0x2400,%sr             | 3c4203ee  46fc 2400
        clr.l   %d0                     | 3c4203f2  4280
        clr.l   %d2                     | 3c4203f4  4282
        clr.l   %d3                     | 3c4203f6  4283
        movea.l (20,%sp),%a0            | 3c4203f8  206f 0014
        movea.l (%a0),%a0               | 3c4203fc  2050
        movea.l (24,%sp),%a1            | 3c4203fe  226f 0018
        movea.l (%a1),%a1               | 3c420402  2251
        movea.l (32,%sp),%a2            | 3c420404  246f 0020
        move.l  (%a2),%d1               | 3c420408  2212
        movea.l (28,%sp),%a2            | 3c42040a  246f 001c
        movea.l (%a2),%a2               | 3c42040e  2452
1:                                      | the loop head
        tst.l   %d1                     | 3c420410  4a81
        beq.w   7f                      | 3c420412  6700 0080
        move.b  (%a0),%d3               | 3c420416  1610
        .short  0xc63c, 0x001f          | 3c420418  and.b #31,%d3
        .short  0xb6bc                  | 3c42041c  cmp.l #16,%d3
        .long   16
        ble.s   2f                      | 3c420422  6f02
        moveq   #16,%d3                 | 3c420424  7610
2:      moveq   #16,%d2                 | 3c420426  7410
        sub.l   %d3,%d2                 | 3c420428  9483
        cmp.l   %d2,%d1                 | 3c42042a  b282
        bge.s   3f                      | 3c42042c  6c02
        move.l  %d1,%d2                 | 3c42042e  2401
3:      tst.l   %d2                     | 3c420430  4a82
        beq.s   7f                      | 3c420432  6760
        btst    #4,%d2                  | 3c420434  0802 0004
        beq.s   4f                      | 3c420438  6718
        move.l  (%a2)+,(%a1)            | 3c42043a  229a
        move.l  (%a2)+,(%a1)            | 3c42043c  229a
        move.l  (%a2)+,(%a1)            | 3c42043e  229a
        move.l  (%a2)+,(%a1)            | 3c420440  229a
        .short  0x92bc                  | 3c420442  sub.l #16,%d1
        .long   16
        .short  0xd0bc                  | 3c420448  add.l #16,%d0
        .long   16
        jmp     (1b,%pc)                | 3c42044e  4efa ffc0
4:      btst    #3,%d2                  | 3c420452  0802 0003
        beq.s   5f                      | 3c420456  670c
        move.l  (%a2)+,(%a1)            | 3c420458  229a
        move.l  (%a2)+,(%a1)            | 3c42045a  229a
        subq.l  #8,%d1                  | 3c42045c  5181
        addq.l  #8,%d0                  | 3c42045e  5080
        jmp     (1b,%pc)                | 3c420460  4efa ffae
5:      btst    #2,%d2                  | 3c420464  0802 0002
        beq.s   6f                      | 3c420468  670a
        move.l  (%a2)+,(%a1)            | 3c42046a  229a
        subq.l  #4,%d1                  | 3c42046c  5981
        addq.l  #4,%d0                  | 3c42046e  5880
        jmp     (1b,%pc)                | 3c420470  4efa ff9e
6:      btst    #1,%d2                  | 3c420474  0802 0001
        beq.s   8f                      | 3c420478  670a
        move.w  (%a2)+,(%a1)            | 3c42047a  329a
        subq.l  #2,%d1                  | 3c42047c  5581
        addq.l  #2,%d0                  | 3c42047e  5480
        jmp     (1b,%pc)                | 3c420480  4efa ff8e
8:      btst    #0,%d2                  | 3c420484  0802 0000
        beq.s   1b                      | 3c420488  6786
        move.b  (%a2)+,(%a1)            | 3c42048a  129a
        subq.l  #1,%d1                  | 3c42048c  5381
        addq.l  #1,%d0                  | 3c42048e  5280
        jmp     (1b,%pc)                | 3c420490  4efa ff7e
7:      move.w  %d4,%sr                 | 3c420494  46c4
        movem.l (%sp)+,%d2-%d4/%a2      | 3c420496  4cdf 041c
        rts                             | 3c42049a  4e75

        .section ".text.SCSI_$HP_READ","ax",@progbits
        .even

        .globl  SCSI_$HP_READ

        | The segment's first longword: UTIL_PIO's address.
scsi_$util_pio:
        .long   UTIL_PIO                | 3c43358c  3ff9 f2c0

SCSI_$HP_READ:                          | 0x3C433590
        movem.l %d2-%d4/%a2,-(%sp)      | 3c433590  48e7 3820
        move.w  %sr,%d4                 | 3c433594  40c4
        move.w  #0x2400,%sr             | 3c433596  46fc 2400
        clr.l   %d0                     | 3c43359a  4280
        movea.l (scsi_$util_pio,%pc),%a0 | 3c43359c  207a ffee
        movea.l (24,%sp),%a1            | 3c4335a0  226f 0018
        movea.l (%a1),%a1               | 3c4335a4  2251
        movea.l (32,%sp),%a2            | 3c4335a6  246f 0020
        move.l  (%a2),%d1               | 3c4335aa  2212
        movea.l (28,%sp),%a2            | 3c4335ac  246f 001c
        movea.l (%a2),%a2               | 3c4335b0  2452
        tst.l   %d1                     | 3c4335b2  4a81
        beq.s   3f                      | 3c4335b4  671c
        move.l  %d1,%d2                 | 3c4335b6  2401
        btst    #4,(%a0)                | 3c4335b8  0810 0004
        beq.s   3f                      | 3c4335bc  6714
        subq.l  #1,%d2                  | 3c4335be  5382
1:      move.b  (%a1),(%a2)+            | 3c4335c0  14d1
        btst    #4,(%a0)                | 3c4335c2  0810 0004
        dbeq    %d2,1b                  | 3c4335c6  57ca fff8
        tst.l   %d2                     | 3c4335ca  4a82
        bmi.s   2f                      | 3c4335cc  6b02
        sub.l   %d2,%d1                 | 3c4335ce  9282
2:      move.l  %d1,%d0                 | 3c4335d0  2001
3:      move.w  %d4,%sr                 | 3c4335d2  46c4
        movem.l (%sp)+,%d2-%d4/%a2      | 3c4335d4  4cdf 041c
        rts                             | 3c4335d8  4e75
        .word   0                       | 3c4335da  0000
