|
| time/sau9/time_asm.s - the hand-written TIME_ASM data segment of the
| SAU9: the calendar read, the timer and clock entries, the clock cells,
| TIME_$SET_VECTOR, the two deferred-interrupt elements and the three
| timer interrupts
|
| SAU9 map: "D 3C42E508 TIME_ASM size = 560" (.DATA, WIRED_DATA),
| 0x3C42E508..0x3C42EA67, one section here.  The segment's code half,
| "I 3C419328 TIME_ASM size = 2C", is ADD48/SUB48 (time/m68k/add48.s).
|
| The SAU2's segment (time/m68k/time_asm.s, time/m68k/timer_handler.s)
| with the SAU9's two chips (`timer_dcte', `calendar_indexed_rtc',
| base/config.ins.pas):
|   - the calendar is a clock of numbered registers (cal/sau9/
|     write_calendar.s): the body waits for the update flag (register
|     10 bit 7), sets SET (register 11 bit 7), reads registers 9, 8, 7, 6
|     (year, month, day, weekday) and 4, 2, 0 (hours, minutes, seconds),
|     clears SET, and turns the date into the clock (4-microsecond ticks
|     since 1980, as the SAU2's: days * 86400 * 250000) and the seconds;
|   - the timers are the TIMER block's three counters (+0, +4, +8: the
|     tick, the virtual timer, the real-time timer; control at +0xC, the
|     pending tick count at +0x18), each with its own vector
|     (TIMER0_VEC, TIMER1_VEC, TIMER2_VEC, which TIME_$SET_VECTOR fills):
|     TIME_$TIMER_HANDLER takes the tick (counting the ticks that found
|     one more, TIME_$MISSED1_COUNT, or several, TIME_$MISSEDN_COUNT,
|     pending; none pending is a spurious interrupt), and the virtual-
|     and real-time-timer interrupts queue their deferred interrupts
|     (TIME_$VT_INT, TIME_$RTE_INT) as the SAU2's handler's arms do;
|   - TIME_$CLOCK, TIME_$ABS_CLOCK and TIME_$GET_TIME_OF_DAY latch and read
|     counter 0 (0x1047 counts a tick).
|
| Hand-written: no frames, arguments read off SP, register arguments,
| A0 = TIME_$READ_CAL handed to the body (moved to A5, then unused).  The
| Apollo assembler's <ea>=#imm forms (cmp/add/sub #imm,Dn), which gas
| spells cmpi/addi/subi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU9 image's.
|

        .section ".text.TIME_$READ_CAL","ax",@progbits
        .even

        .globl  time_$read_cal_body
        .globl  TIME_$READ_CAL
        .globl  IN_VT_INT
        .globl  IN_RT_INT
        .globl  TIME_$VT_TIMER
        .globl  TIME_$WRT_VT_TIMER
        .globl  TIME_$WRT_TIMER
        .globl  TIME_$CLOCK
        .globl  TIME_$ABS_CLOCK
        .globl  TIME_$GET_TIME_OF_DAY
        .globl  TIME_$FAST_CLOCK_EC
        .globl  TIME_$CLOCKH_EC
        .globl  TIME_$CLOCKH
        .globl  TIME_$CLOCKL
        .globl  TIME_$CURRENT_CLOCKH
        .globl  TIME_$CURRENT_CLOCKL
        .globl  TIME_$BOOT_TIME
        .globl  TIME_$CURRENT_TIME
        .globl  TIME_$CURRENT_TICK
        .globl  TIME_$CURRENT_SKEW
        .globl  TIME_$CURRENT_DELTA
        .globl  TIME_$MISSED1_COUNT
        .globl  TIME_$MISSEDN_COUNT
        .globl  TIME_$SET_VECTOR
        .globl  TIME_$DI_VT
        .globl  TIME_$DI_RTE
        .globl  TIME_$TIMER_HANDLER

        .extern CAL                     | arch/m68k/sau9/iodefs.s
        .extern TIMER

| The calendar read: the register's address cell, then the body.
time_$read_cal_cal:
        .long   CAL                             | 3c42e508  3ff9f280
time_$read_cal_body:
        movem.l %d2/%d6-%d7/%a5,-(%sp)          | 3c42e50c  48e7 2304
        movea.l %a0,%a5                         | 3c42e510  2a48
        movea.l (time_$read_cal_cal,%pc),%a0    | 3c42e512  207a fff4
        move.w  #0x3e8,%d1                      | 3c42e516  323c 03e8
.L3c42e51a:
        move.b  #0xa,(CAL).l                    | 3c42e51a  13fc 000a 3ff9 f280
        move.b  (CAL+0x4).l,%d0                 | 3c42e522  1039 3ff9 f284
        btst    #7,%d0                          | 3c42e528  0800 0007
        beq.b   .L3c42e532                      | 3c42e52c  6704
        dbf     %d1,.L3c42e51a                  | 3c42e52e  51c9 ffea
.L3c42e532:
        move.b  #0xb,(CAL).l                    | 3c42e532  13fc 000b 3ff9 f280
        move.b  (CAL+0x4).l,%d0                 | 3c42e53a  1039 3ff9 f284
        bset    #7,%d0                          | 3c42e540  08c0 0007
        move.b  #0xb,(CAL).l                    | 3c42e544  13fc 000b 3ff9 f280
        move.b  %d0,(CAL+0x4).l                 | 3c42e54c  13c0 3ff9 f284
        move.w  #3,%d0                          | 3c42e552  303c 0003
        moveq   #9,%d2                          | 3c42e556  7409
        clr.w   %d1                             | 3c42e558  4241
.L3c42e55a:
        move.b  %d2,(CAL).l                     | 3c42e55a  13c2 3ff9 f280
        subq.l  #1,%d2                          | 3c42e560  5382
        move.b  (CAL+0x4).l,%d1                 | 3c42e562  1239 3ff9 f284
        move.w  %d1,-(%sp)                      | 3c42e568  3f01
        dbf     %d0,.L3c42e55a                  | 3c42e56a  51c8 ffee
        move.w  #2,%d0                          | 3c42e56e  303c 0002
.L3c42e572:
        subq.l  #1,%d2                          | 3c42e572  5382
        move.b  %d2,(CAL).l                     | 3c42e574  13c2 3ff9 f280
        subq.l  #1,%d2                          | 3c42e57a  5382
        move.b  (CAL+0x4).l,%d1                 | 3c42e57c  1239 3ff9 f284
        move.w  %d1,-(%sp)                      | 3c42e582  3f01
        dbf     %d0,.L3c42e572                  | 3c42e584  51c8 ffec
        move.b  #0xb,(CAL).l                    | 3c42e588  13fc 000b 3ff9 f280
        move.b  (CAL+0x4).l,%d0                 | 3c42e590  1039 3ff9 f284
        bclr    #7,%d0                          | 3c42e596  0880 0007
        move.b  #0xb,(CAL).l                    | 3c42e59a  13fc 000b 3ff9 f280
        move.b  %d0,(CAL+0x4).l                 | 3c42e5a2  13c0 3ff9 f284
        clr.l   %d0                             | 3c42e5a8  4280
        move.w  (10,%sp),%d0                    | 3c42e5aa  302f 000a
        move.w  #1,%d1                          | 3c42e5ae  323c 0001
        subq.w  #3,%d0                          | 3c42e5b2  5740
        bge.b   .L3c42e5bc                      | 3c42e5b4  6c06
        clr.w   %d1                             | 3c42e5b6  4241
        .short  0xd07c, 0x000c                  | 3c42e5b8  d07c 000c  addw #12,%d0
.L3c42e5bc:
        move.w  (12,%sp),%d2                    | 3c42e5bc  342f 000c
        add.w   %d1,%d2                         | 3c42e5c0  d441
        .short  0x947c, 0x0051                  | 3c42e5c2  947c 0051  subw #81,%d2
        bge.b   .L3c42e5cc                      | 3c42e5c6  6c04
        .short  0xd47c, 0x0064                  | 3c42e5c8  d47c 0064  addw #100,%d2
.L3c42e5cc:
        move.b  #0xb,(CAL).l                    | 3c42e5cc  13fc 000b 3ff9 f280
        move.b  (CAL+0x4).l,%d1                 | 3c42e5d4  1239 3ff9 f284
        bclr    #7,%d1                          | 3c42e5da  0881 0007
        move.b  %d1,(CAL+0x4).l                 | 3c42e5de  13c1 3ff9 f284
        move.w  %d2,%d1                         | 3c42e5e4  3202
        mulu.w  #0x16d,%d1                      | 3c42e5e6  c2fc 016d
        lsr.w   #2,%d2                          | 3c42e5ea  e44a
        add.w   %d1,%d2                         | 3c42e5ec  d441
        move.w  %d0,%d1                         | 3c42e5ee  3200
        mulu.w  #0x1e,%d1                       | 3c42e5f0  c2fc 001e
        add.w   %d1,%d2                         | 3c42e5f4  d441
        divu.w  #5,%d0                          | 3c42e5f6  80fc 0005
        move.w  %d0,%d1                         | 3c42e5fa  3200
        mulu.w  #3,%d1                          | 3c42e5fc  c2fc 0003
        add.w   %d1,%d2                         | 3c42e600  d441
        swap    %d0                             | 3c42e602  4840
        addq.w  #1,%d0                          | 3c42e604  5240
        lsr.w   #1,%d0                          | 3c42e606  e248
        add.w   %d0,%d2                         | 3c42e608  d440
        move.w  (8,%sp),%d1                     | 3c42e60a  322f 0008
        add.w   %d1,%d2                         | 3c42e60e  d441
        .short  0xd47c, 0x003b                  | 3c42e610  d47c 003b  addw #59,%d2
        move.w  (4,%sp),%d0                     | 3c42e614  302f 0004
        mulu.w  #0x3c,%d0                       | 3c42e618  c0fc 003c
        add.w   (2,%sp),%d0                     | 3c42e61c  d06f 0002
        mulu.w  #0x3c,%d0                       | 3c42e620  c0fc 003c
        .short  0x322f, 0x0000                  | 3c42e624  322f 0000  move.w (0,%sp),%d1: (d16,SP), which gas shortens
        ext.l   %d1                             | 3c42e628  48c1
        add.l   %d1,%d0                         | 3c42e62a  d081
        asl.w   #1,%d2                          | 3c42e62c  e342
        mulu.w  #-0x5740,%d2                    | 3c42e62e  c4fc a8c0
        add.l   %d2,%d0                         | 3c42e632  d082
        movea.l (38,%sp),%a0                    | 3c42e634  206f 0026
        move.l  %d0,(%a0)                       | 3c42e638  2080
        movea.l (34,%sp),%a0                    | 3c42e63a  206f 0022
        move.w  %d0,%d2                         | 3c42e63e  3400
        mulu.w  #-0x2f70,%d2                    | 3c42e640  c4fc d090
        move.w  %d2,(4,%a0)                     | 3c42e644  3142 0004
        clr.w   %d2                             | 3c42e648  4242
        swap    %d2                             | 3c42e64a  4842
        move.w  %d0,%d1                         | 3c42e64c  3200
        mulu.w  #3,%d1                          | 3c42e64e  c2fc 0003
        add.l   %d1,%d2                         | 3c42e652  d481
        swap    %d0                             | 3c42e654  4840
        move.w  %d0,%d1                         | 3c42e656  3200
        mulu.w  #-0x2f70,%d1                    | 3c42e658  c2fc d090
        add.l   %d1,%d2                         | 3c42e65c  d481
        move.l  %d2,(%a0)                       | 3c42e65e  2082
        mulu.w  #3,%d0                          | 3c42e660  c0fc 0003
        add.w   (%a0),%d0                       | 3c42e664  d050
        move.w  %d0,(%a0)                       | 3c42e666  3080
        lea     (14,%sp),%sp                    | 3c42e668  4fef 000e
        movem.l (%sp)+,%d2/%d6-%d7/%a5          | 3c42e66c  4cdf 20c4
        rts                                     | 3c42e670  4e75
        move.w  #0x14,%d1                       | 3c42e672  323c 0014
.L3c42e676:
        subq.w  #1,%d1                          | 3c42e676  5341
        bne.b   .L3c42e676                      | 3c42e678  66fc
        rts                                     | 3c42e67a  4e75
TIME_$READ_CAL:
        lea     (TIME_$READ_CAL,%pc),%a0        | 3c42e67c  41fa fffe
        jmp     (time_$read_cal_body,%pc)       | 3c42e680  4efa fe8a
IN_VT_INT:                                      | 3c42e684  a VT deferred interrupt is queued
        .byte   0
IN_RT_INT:                                      | 3c42e685  an RT deferred interrupt is queued
        .byte   0
TIME_$VT_TIMER:
        lea     (TIMER).l,%a0                   | 3c42e686  41f9 3ff9 f2a0
        move.b  #0xc4,(12,%a0)                  | 3c42e68c  117c 00c4 000c  latch counter 1
        move.b  (4,%a0),%d1                     | 3c42e692  1228 0004
        move.b  (4,%a0),-(%sp)                  | 3c42e696  1f28 0004
        move.b  (4,%a0),%d0                     | 3c42e69a  1028 0004
        lsl.w   #8,%d0                          | 3c42e69e  e148
        move.b  (%sp)+,%d0                      | 3c42e6a0  101f
        btst    #7,%d1                          | 3c42e6a2  0801 0007
        bne.b   .L3c42e6b0                      | 3c42e6a6  6608
        tst.b   (IN_VT_INT).l                   | 3c42e6a8  4a39 3c42 e684
        beq.b   .L3c42e6b2                      | 3c42e6ae  6702
.L3c42e6b0:
        clr.w   %d0                             | 3c42e6b0  4240
.L3c42e6b2:
        rts                                     | 3c42e6b2  4e75
TIME_$WRT_VT_TIMER:
        lea     (TIMER).l,%a2                   | 3c42e6b4  45f9 3ff9 f2a0
        move.b  %d0,(4,%a2)                     | 3c42e6ba  1540 0004
        lsr.w   #8,%d0                          | 3c42e6be  e048
        move.b  %d0,(4,%a2)                     | 3c42e6c0  1540 0004
        sf      (IN_VT_INT).l                   | 3c42e6c4  51f9 3c42 e684
        rts                                     | 3c42e6ca  4e75
TIME_$WRT_TIMER:
        movea.l (4,%sp),%a0                     | 3c42e6cc  206f 0004
        clr.l   %d0                             | 3c42e6d0  4280
        move.w  (%a0),%d0                       | 3c42e6d2  3010
        movea.l (8,%sp),%a0                     | 3c42e6d4  206f 0008
        move.w  (%a0),%d1                       | 3c42e6d8  3210
        lea     (TIMER).l,%a0                   | 3c42e6da  41f9 3ff9 f2a0
        .short  0xb07c, 0x0001                  | 3c42e6e0  b07c 0001  cmpw #1,%d0
        beq.b   .L3c42e718                      | 3c42e6e4  6732
        tst.w   %d1                             | 3c42e6e6  4a41
        bne.b   .L3c42e718                      | 3c42e6e8  662e
        .short  0xb07c, 0x0002                  | 3c42e6ea  b07c 0002  cmpw #2,%d0
        bne.b   .L3c42e704                      | 3c42e6ee  6614
        move.b  #0x70,(12,%a0)                  | 3c42e6f0  117c 0070 000c
        move.b  #0x72,(12,%a0)                  | 3c42e6f6  117c 0072 000c
        move.b  #0x70,(12,%a0)                  | 3c42e6fc  117c 0070 000c
        bra.b   .L3c42e732                      | 3c42e702  602e
.L3c42e704:
        move.b  #0xb0,(12,%a0)                  | 3c42e704  117c 00b0 000c
        move.b  #0xb2,(12,%a0)                  | 3c42e70a  117c 00b2 000c
        move.b  #0xb0,(12,%a0)                  | 3c42e710  117c 00b0 000c
        bra.b   .L3c42e72a                      | 3c42e716  6012
.L3c42e718:
        move.b  %d1,(-4,%a0,%d0.w*4)            | 3c42e718  1181 04fc  the counter TIMER + 4 * (timer - 1)
        lsr.w   #8,%d1                          | 3c42e71c  e049
        move.b  %d1,(-4,%a0,%d0.w*4)            | 3c42e71e  1181 04fc
        .short  0xb07c, 0x0002                  | 3c42e722  b07c 0002  cmpw #2,%d0
        beq.b   .L3c42e732                      | 3c42e726  670a
        blt.b   .L3c42e738                      | 3c42e728  6d0e
.L3c42e72a:
        sf      (IN_RT_INT).l                   | 3c42e72a  51f9 3c42 e685
        bra.b   .L3c42e738                      | 3c42e730  6006
.L3c42e732:
        sf      (IN_VT_INT).l                   | 3c42e732  51f9 3c42 e684
.L3c42e738:
        rts                                     | 3c42e738  4e75
TIME_$CLOCK:
        lea     (TIMER).l,%a0                   | 3c42e73a  41f9 3ff9 f2a0
        move.w  %sr,%d1                         | 3c42e740  40c1
        ori.w   #0x700,%sr                      | 3c42e742  007c 0700
        movea.l (TIME_$CURRENT_CLOCKH,%pc),%a1  | 3c42e746  227a 0118
        clr.l   %d0                             | 3c42e74a  4280
        move.b  #0,(12,%a0)                     | 3c42e74c  117c 0000 000c
        move.b  (%a0),-(%sp)                    | 3c42e752  1f10
        move.b  (%a0),%d0                       | 3c42e754  1010
        lsl.w   #8,%d0                          | 3c42e756  e148
        move.b  (%sp)+,%d0                      | 3c42e758  101f
        neg.w   %d0                             | 3c42e75a  4440
        .short  0xd07c, 0x1047                  | 3c42e75c  d07c 1047  addw #4167,%d0
        .short  0xb07c, 0x0fe3                  | 3c42e760  b07c 0fe3  cmpw #4067,%d0
        bgt.b   .L3c42e774                      | 3c42e764  6e0e
        tst.b   (24,%a0)                        | 3c42e766  4a28 0018
        beq.b   .L3c42e774                      | 3c42e76a  6708
        add.w   (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e76c  d07a 0106
        bcc.b   .L3c42e774                      | 3c42e770  6402
        addq.l  #1,%a1                          | 3c42e772  5289
.L3c42e774:
        cmp.w   (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e774  b07a 00fe
        ble.b   .L3c42e77e                      | 3c42e778  6f04
        move.w  (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e77a  303a 00f8
.L3c42e77e:
        add.w   (TIME_$CURRENT_CLOCKL,%pc),%d0  | 3c42e77e  d07a 00e4
        bcc.b   .L3c42e786                      | 3c42e782  6402
        addq.l  #1,%a1                          | 3c42e784  5289
.L3c42e786:
        move.w  %d1,%sr                         | 3c42e786  46c1
        movea.l (4,%sp),%a0                     | 3c42e788  206f 0004
        move.l  %a1,(%a0)+                      | 3c42e78c  20c9
        move.w  %d0,(%a0)                       | 3c42e78e  3080
        rts                                     | 3c42e790  4e75
TIME_$ABS_CLOCK:
        lea     (TIMER).l,%a0                   | 3c42e792  41f9 3ff9 f2a0
        move.w  %sr,%d1                         | 3c42e798  40c1
        ori.w   #0x700,%sr                      | 3c42e79a  007c 0700
        movea.l (TIME_$CLOCKH,%pc),%a1          | 3c42e79e  227a 00b0
        move.b  #0,(12,%a0)                     | 3c42e7a2  117c 0000 000c
        move.b  (%a0),-(%sp)                    | 3c42e7a8  1f10
        move.b  (%a0),%d0                       | 3c42e7aa  1010
        lsl.w   #8,%d0                          | 3c42e7ac  e148
        move.b  (%sp)+,%d0                      | 3c42e7ae  101f
        neg.w   %d0                             | 3c42e7b0  4440
        .short  0xd07c, 0x1047                  | 3c42e7b2  d07c 1047  addw #4167,%d0
        .short  0xb07c, 0x0fe3                  | 3c42e7b6  b07c 0fe3  cmpw #4067,%d0
        bgt.b   .L3c42e774                      | 3c42e7ba  6eb8
        tst.b   (24,%a0)                        | 3c42e7bc  4a28 0018
        beq.b   .L3c42e7ca                      | 3c42e7c0  6708
        .short  0xd07c, 0x1047                  | 3c42e7c2  d07c 1047  addw #4167,%d0
        bcc.b   .L3c42e7ca                      | 3c42e7c6  6402
        addq.l  #1,%a1                          | 3c42e7c8  5289
.L3c42e7ca:
        add.w   (TIME_$CLOCKL,%pc),%d0          | 3c42e7ca  d07a 0090
        bcc.b   .L3c42e7d2                      | 3c42e7ce  6402
        addq.l  #1,%a1                          | 3c42e7d0  5289
.L3c42e7d2:
        move.w  %d1,%sr                         | 3c42e7d2  46c1
        movea.l (4,%sp),%a0                     | 3c42e7d4  206f 0004
        move.l  %a1,(%a0)+                      | 3c42e7d8  20c9
        move.w  %d0,(%a0)                       | 3c42e7da  3080
        rts                                     | 3c42e7dc  4e75
TIME_$GET_TIME_OF_DAY:
        lea     (TIMER).l,%a0                   | 3c42e7de  41f9 3ff9 f2a0
        move.w  %sr,%d1                         | 3c42e7e4  40c1
        ori.w   #0x700,%sr                      | 3c42e7e6  007c 0700
        movea.l (TIME_$CURRENT_TIME,%pc),%a1    | 3c42e7ea  227a 0080
        clr.l   %d0                             | 3c42e7ee  4280
        move.b  #0,(12,%a0)                     | 3c42e7f0  117c 0000 000c
        move.b  (%a0),-(%sp)                    | 3c42e7f6  1f10
        move.b  (%a0),%d0                       | 3c42e7f8  1010
        lsl.w   #8,%d0                          | 3c42e7fa  e148
        move.b  (%sp)+,%d0                      | 3c42e7fc  101f
        neg.w   %d0                             | 3c42e7fe  4440
        .short  0xd07c, 0x1047                  | 3c42e800  d07c 1047  addw #4167,%d0
        .short  0xb07c, 0x0fe3                  | 3c42e804  b07c 0fe3  cmpw #4067,%d0
        bgt.b   .L3c42e818                      | 3c42e808  6e0e
        tst.b   (24,%a0)                        | 3c42e80a  4a28 0018
        beq.b   .L3c42e818                      | 3c42e80e  6708
        add.w   (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e810  d07a 0062
        bcc.b   .L3c42e818                      | 3c42e814  6402
        addq.l  #1,%a1                          | 3c42e816  5289
.L3c42e818:
        cmp.w   (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e818  b07a 005a
        ble.b   .L3c42e822                      | 3c42e81c  6f04
        move.w  (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e81e  303a 0054
.L3c42e822:
        lsl.l   #2,%d0                          | 3c42e822  e588
        add.l   (TIME_$CURRENT_USEC,%pc),%d0    | 3c42e824  d0ba 004a
        .short  0xb0bc, 0x000f, 0x4240          | 3c42e828  b0bc 000f 4240  cmpl #1000000,%d0
        bmi.b   .L3c42e838                      | 3c42e82e  6b08
        addq.l  #1,%a1                          | 3c42e830  5289
        .short  0x90bc, 0x000f, 0x4240          | 3c42e832  90bc 000f 4240  subl #1000000,%d0
.L3c42e838:
        move.w  %d1,%sr                         | 3c42e838  46c1
        movea.l (4,%sp),%a0                     | 3c42e83a  206f 0004
        move.l  %a1,(%a0)+                      | 3c42e83e  20c9
        move.l  %d0,(%a0)                       | 3c42e840  2080
        rts                                     | 3c42e842  4e75
TIME_$FAST_CLOCK_EC:                            | 3c42e844  an eventcount, empty
        .long   0, TIME_$FAST_CLOCK_EC, TIME_$FAST_CLOCK_EC
TIME_$CLOCKH_EC:                                | 3c42e850  an eventcount, empty; its
TIME_$CLOCKH:                                   |   value is the clock's high longword
        .long   0, TIME_$CLOCKH_EC, TIME_$CLOCKH_EC
TIME_$CLOCKL:                                   | 3c42e85c  the clock's low word
        .word   0, 0
TIME_$CURRENT_CLOCKH:                           | 3c42e860
        .long   0
TIME_$CURRENT_CLOCKL:                           | 3c42e864
        .word   0, 0
TIME_$BOOT_TIME:                                | 3c42e868
        .long   0
TIME_$CURRENT_TIME:                             | 3c42e86c  seconds
        .long   0
TIME_$CURRENT_USEC:                             | 3c42e870  microseconds
        .long   0
TIME_$CURRENT_TICK:                             | 3c42e874
        .word   0
TIME_$CURRENT_SKEW:                             | 3c42e876
        .word   0
TIME_$CURRENT_DELTA:                            | 3c42e878
        .long   0
TIME_$MISSED1_COUNT:                            | 3c42e87c  ticks that found one more pending
        .long   0
TIME_$MISSEDN_COUNT:                            | 3c42e880  ticks that found more pending
        .long   0
time_$mcr_countdown:                            | 3c42e884  MMU_$MCR_CHANGE every 2nd second
        .word   2
TIME_$SET_VECTOR:
        lea     (TIME_$TIMER_HANDLER,%pc),%a0   | 3c42e886  41fa 0040
        move.l  %a0,(TIMER0_VEC).l              | 3c42e88a  23c8 3c40 12a4
        lea     (time_$vt_timer_handler,%pc),%a0| 3c42e890  41fa 0136
        move.l  %a0,(TIMER1_VEC).l              | 3c42e894  23c8 3c40 12a8
        lea     (time_$rt_timer_handler,%pc),%a0| 3c42e89a  41fa 0174
        move.l  %a0,(TIMER2_VEC).l              | 3c42e89e  23c8 3c40 12ac
        rts                                     | 3c42e8a4  4e75
| The two deferred-interrupt elements (di/di.ins.pas di_$q_elem_t, 16
| bytes), zero.
TIME_$DI_VT:                                    | 3c42e8a6
        .space  16
TIME_$DI_RTE:                                   | 3c42e8b6
        .space  16
        .word   0                               | 3c42e8c6  before TIME_$TIMER_HANDLER
TIME_$TIMER_HANDLER:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c42e8c8  48e7 c0c0
        jsr     (IO_$USE_INT_STACK).l           | 3c42e8cc  4eb9 3c43 4426
        lea     (TIMER).l,%a0                   | 3c42e8d2  41f9 3ff9 f2a0
        clr.l   %d1                             | 3c42e8d8  4281
        move.b  (24,%a0),%d1                    | 3c42e8da  1228 0018
        clr.b   (24,%a0)                        | 3c42e8de  4228 0018
        subq.l  #1,%d1                          | 3c42e8e2  5381
        beq.w   .L3c42e904                      | 3c42e8e4  6700 001e
        bcs.w   .Ltick_none                     | 3c42e8e8  6500 016c
        .short  0xb23c, 0x0001                  | 3c42e8ec  b23c 0001  cmpb #1,%d1
        bne.w   .L3c42e8fe                      | 3c42e8f0  6600 000c
        addq.l  #1,(TIME_$MISSED1_COUNT).l      | 3c42e8f4  52b9 3c42 e87c
        bra.w   .L3c42e904                      | 3c42e8fa  6000 0008
.L3c42e8fe:
        addq.l  #1,(TIME_$MISSEDN_COUNT).l      | 3c42e8fe  52b9 3c42 e880
.L3c42e904:
        movea.l (PROC1_$CURRENT_PCB).l,%a0      | 3c42e904  2079 3c42 16c4
        btst    #5,(16,%sp)                     | 3c42e90a  082f 0005 0010
        beq.b   .L3c42e918                      | 3c42e910  6706
        addq.l  #1,(96,%a0)                     | 3c42e912  52a8 0060
        bra.b   .L3c42e91c                      | 3c42e916  6004
.L3c42e918:
        addq.l  #1,(100,%a0)                    | 3c42e918  52a8 0064
.L3c42e91c:
        clr.l   %d0                             | 3c42e91c  4280
        move.w  (TIME_$CURRENT_TICK,%pc),%d0    | 3c42e91e  303a ff54
        add.w   %d0,(TIME_$CURRENT_CLOCKL).l    | 3c42e922  d179 3c42 e864
        bcc.b   .L3c42e930                      | 3c42e928  6406
        addq.l  #1,(TIME_$CURRENT_CLOCKH).l     | 3c42e92a  52b9 3c42 e860
.L3c42e930:
        lsl.l   #2,%d0                          | 3c42e930  e588
        add.l   (TIME_$CURRENT_USEC,%pc),%d0    | 3c42e932  d0ba ff3c
        .short  0xb0bc, 0x000f, 0x4240          | 3c42e936  b0bc 000f 4240  cmpl #1000000,%d0
        bmi.b   .L3c42e94a                      | 3c42e93c  6b0c
        addq.l  #1,(TIME_$CURRENT_TIME).l       | 3c42e93e  52b9 3c42 e86c
        .short  0x90bc, 0x000f, 0x4240          | 3c42e944  90bc 000f 4240  subl #1000000,%d0
.L3c42e94a:
        move.l  %d0,TIME_$CURRENT_USEC          | 3c42e94a  23c0 3c42 e870
        tst.l   (TIME_$CURRENT_DELTA).l         | 3c42e950  4ab9 3c42 e878
        beq.b   .L3c42e976                      | 3c42e956  671e
        move.w  (TIME_$CURRENT_SKEW,%pc),%d0    | 3c42e958  303a ff1c
        ext.l   %d0                             | 3c42e95c  48c0
        sub.l   %d0,(TIME_$CURRENT_DELTA).l     | 3c42e95e  91b9 3c42 e878
        bne.w   .L3c42e976                      | 3c42e964  6600 0010
        clr.w   (TIME_$CURRENT_SKEW).l          | 3c42e968  4279 3c42 e876
        move.w  #0x1047,(TIME_$CURRENT_TICK).l  | 3c42e96e  33fc 1047 3c42 e874
.L3c42e976:
        pea     (TIME_$FAST_CLOCK_EC,%pc)       | 3c42e976  487a fecc
        jsr     (EC_$ADVANCE_WITHOUT_DISPATCH).l| 3c42e97a  4eb9 3c42 3314
        addq.l  #4,%sp                          | 3c42e980  588f
        addi.w  #0x1047,(TIME_$CLOCKL).l        | 3c42e982  0679 1047 3c42 e85c
        bcs.b   .L3c42e996                      | 3c42e98a  650a
        dbf     %d1,.L3c42e904                  | 3c42e98c  51c9 ff76
        jmp     (PROC1_$INT_EXIT).l             | 3c42e990  4ef9 3c42 34fa
.L3c42e996:
        move.l  %d1,-(%sp)                      | 3c42e996  2f01
        lea     (time_$mcr_countdown,%pc),%a0   | 3c42e998  41fa feea
        subq.w  #1,(%a0)                        | 3c42e99c  5350
        bne.b   .L3c42e9b0                      | 3c42e99e  6610
        move.w  #2,(%a0)                        | 3c42e9a0  30bc 0002
        move.w  #1,-(%sp)                       | 3c42e9a4  3f3c 0001
        jsr     (MMU_$MCR_CHANGE).l             | 3c42e9a8  4eb9 3c42 7234
        addq.l  #2,%sp                          | 3c42e9ae  548f
.L3c42e9b0:
        pea     (TIME_$CLOCKH,%pc)              | 3c42e9b0  487a fe9e
        jsr     (EC_$ADVANCE_WITHOUT_DISPATCH).l| 3c42e9b4  4eb9 3c42 3314
        addq.l  #4,%sp                          | 3c42e9ba  588f
        move.l  (%sp)+,%d1                      | 3c42e9bc  221f
        dbf     %d1,.L3c42e904                  | 3c42e9be  51c9 ff44
        jmp     (PROC1_$INT_EXIT).l             | 3c42e9c2  4ef9 3c42 34fa
time_$vt_timer_handler:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c42e9c8  48e7 c0c0
        jsr     (IO_$USE_INT_STACK).l           | 3c42e9cc  4eb9 3c43 4426
        lea     (TIMER).l,%a0                   | 3c42e9d2  41f9 3ff9 f2a0
        moveq   #-1,%d1                         | 3c42e9d8  72ff
        move.b  %d1,(4,%a0)                     | 3c42e9da  1141 0004
        move.b  %d1,(4,%a0)                     | 3c42e9de  1141 0004
        tst.b   (IN_VT_INT).l                   | 3c42e9e2  4a39 3c42 e684
        bne.b   .L3c42ea08                      | 3c42e9e8  661e
        st      (IN_VT_INT).l                   | 3c42e9ea  50f9 3c42 e684
        pea     (TIME_$DI_VT,%pc)               | 3c42e9f0  487a feb4
        clr.l   -(%sp)                          | 3c42e9f4  42a7
        pea     (TIME_$VT_INT).l                | 3c42e9f6  4879 3c41 8472
        jsr     (DI_$ENQ).l                     | 3c42e9fc  4eb9 3c42 35a4
        adda.l  #0xc,%sp                        | 3c42ea02  dffc 0000 000c
.L3c42ea08:
        jmp     (PROC1_$INT_EXIT).l             | 3c42ea08  4ef9 3c42 34fa
        .word   0                               | 3c42ea0e  pad
time_$rt_timer_handler:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c42ea10  48e7 c0c0
        jsr     (IO_$USE_INT_STACK).l           | 3c42ea14  4eb9 3c43 4426
        lea     (TIMER).l,%a0                   | 3c42ea1a  41f9 3ff9 f2a0
        moveq   #-1,%d1                         | 3c42ea20  72ff
        move.b  %d1,(8,%a0)                     | 3c42ea22  1141 0008
        move.b  %d1,(8,%a0)                     | 3c42ea26  1141 0008
        tst.b   (IN_RT_INT).l                   | 3c42ea2a  4a39 3c42 e685
        bne.b   .L3c42ea50                      | 3c42ea30  661e
        st      (IN_RT_INT).l                   | 3c42ea32  50f9 3c42 e685
        pea     (TIME_$DI_RTE,%pc)              | 3c42ea38  487a fe7c
        clr.l   -(%sp)                          | 3c42ea3c  42a7
        pea     (TIME_$RTE_INT).l               | 3c42ea3e  4879 3c41 8434
        jsr     (DI_$ENQ).l                     | 3c42ea44  4eb9 3c42 35a4
        adda.l  #0xc,%sp                        | 3c42ea4a  dffc 0000 000c
.L3c42ea50:
        jmp     (PROC1_$INT_EXIT).l             | 3c42ea50  4ef9 3c42 34fa
.Ltick_none:
        jsr     (IO_$COND_SWITCH_BACK).l        | 3c42ea56  4eb9 3c43 4446
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c42ea5c  4cdf 0303
        jmp     (FIM_$SPURIOUS_INT).l           | 3c42ea60  4ef9 3c42 4b8c
        .word   0                               | 3c42ea66  to the segment's end
