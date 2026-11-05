|
| time/m68k/time_asm.s - the hand-written TIME_ASM data segment up to the
| timer interrupt: the calendar read, the timer and clock entries, the
| clock cells, TIME_$SET_VECTOR and the two deferred-interrupt elements
| (m68k/SAU2, SAU3, SAU5)
|
| The SAU2 and SAU5 images have the same code here except in the calendar
| read's body, where the SAU5 reaches the MSM5832 through a word port at
| +0x200 of the calendar page (base/config.ins.pas's part
| `calendar_word_port'): control at +0x200, the digit read at +0x201
| without the SAU2's inversion, and the leap-year flag written as a word
| (data in the low byte, the control bits 0x8100 / 0x8300 in the high)
| where the SAU2 writes the inverted digit at +0x22 and the control byte
| at +0x20.  The body keeps its length, so the SAU5's TIME_ASM (`D E2BF38
| TIME_ASM size = 484') is the SAU2's 0x113C higher throughout.  The
| address and byte columns are the SAU2 image's, except on the lines of
| the `.if calendar_word_port' arms, which carry the SAU5 image's.
|
| The SAU3's calendar has a page of its own (CALENDAR 0xFFA400) with the
| registers at its start (`calendar_own_page'): control at +0, reached as
| (A0), the write data at +2 and the read data at +4, inverted as on the
| SAU2.  Each of the body's seven (0x20,A0) operands is (A0) there, two
| bytes shorter, and the word ahead of TIME_$TIMER_HANDLER, which keeps
| the handler on a longword in the SAU2's and SAU5's segment, is not
| there: the SAU3's TIME_ASM (`D E29768 TIME_ASM size = 474') is 0x10
| bytes shorter, the handler at TIME_$DI_RTE + 0x10 (0xE29A8C).
|
| The SAU4's calendar registers are bytes of the timer's page (CALENDAR
| = TIMR 0xFFFAC00, `calendar_timer_page'): control at +0x81, write data
| at +0x83, read data at +0x85, inverted; the operands keep the SAU2's
| length, and its TIME_ASM (`D F82D4B0 TIME_ASM size = 484') is the
| SAU2's laid out the same.
|
| TIME_$WRT_VT_TIMER is here too, with its timer block a TIMR relocation
| (a fixup-table cell, 0xE2AF8E), not a literal.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings and bytes, every address operand a relocation resolved
| against the image's.
|
| SAU2 map: "D E2ADFC TIME_ASM size = 484" (.DATA, WIRED_DATA), 0xE2ADFC..
| 0xE2B280; this section is 0xE2ADFC..0xE2B130, and TIME_$TIMER_HANDLER
| (0xE2B130.., no map symbol) is time/m68k/timer_handler.s.  The
| segment's code half, "I E172D0 TIME_ASM size = 2C", is ADD48/SUB48
| (time/m68k/add48.s).
|
|   0xE2ADFC  (no symbol)           time_$read_cal_body: TIME_$READ_CAL's
|                                   body, entered by its `jmp' with A0 =
|                                   TIME_$READ_CAL (moved to A5, then never
|                                   used): reads the 13 BCD digits of the
|                                   MSM5832 calendar (the page at
|                                   .Lcalendar: +0x20 control, +0x22 write
|                                   data, +0x24 read data, inverted) under
|                                   HOLD, fixes the leap-year flag, and
|                                   returns the clock (6 bytes, 4 us ticks)
|                                   and the seconds through its two
|                                   by-address arguments
|   0xE2AF54  (no symbol)           time_$read_cal_delay_20: D1 = 20, then
|   0xE2AF58  (no symbol)           time_$read_cal_delay: count D1 down
|   0xE2AF5E  TIME_$READ_CAL        (clock: out, secs: out) `lea' of
|                                   itself, `jmp' to the body
|   0xE2AF66  (no symbol)           the calendar page's address, 0xFFA800
|                                   (CALENDAR, a fixup-table cell)
|   0xE2AF6A  IN_VT_INT, 0xE2AF6B IN_RT_INT   bytes: a VT / RT deferred
|                                   interrupt is queued (the handler sets
|                                   them, the writes of the timers clear
|                                   them)
|   0xE2AF6C  TIME_$VT_TIMER        D0.w = the virtual timer's count, 0 when
|                                   it has run out (status bit 1) or its
|                                   DI is queued
|   0xE2AF8A  TIME_$WRT_VT_TIMER    D0.w = the count to load; A0 preserved
|                                   through A2; clears IN_VT_INT
|   0xE2AFA0  TIME_$WRT_TIMER       (timer, value: words by address) load
|                                   timer 0..2 (the RT timer clears
|                                   IN_RT_INT, the VT timer IN_VT_INT)
|   0xE2AFD6  TIME_$CLOCK           (clock: out) the current clock under
|                                   IPL 7: CURRENT_CLOCK + the ticks since
|                                   the last interrupt (the timer's count
|                                   complemented + 0x1047, the tick's
|                                   pending interrupt counted, clamped to
|                                   CURRENT_TICK)
|   0xE2B026  TIME_$ABS_CLOCK       (clock: out) the same from CLOCKH/CLOCKL
|   0xE2B06A  TIME_$GET_TIME_OF_DAY (tv: out) seconds and microseconds
|   0xE2B0C8  TIME_$FAST_CLOCK_EC .. TIME_$CURRENT_DELTA  the clock cells
|                                   (below); the two words the map does
|                                   not name are TIME_$CURRENT_TIME+4 (the
|                                   microseconds, TIME_$CURRENT_USEC) and
|                                   TIME_$CURRENT_DELTA+4 (the MCR
|                                   countdown, 2, time_$mcr_countdown)
|   0xE2B102  TIME_$SET_VECTOR      store TIME_$TIMER_HANDLER's address in
|                                   the level-6 autovector TIMER_VEC (0x78,
|                                   a fixup-table cell, 0xE2B108)
|   0xE2B10E  TIME_$DI_VT, 0xE2B11E TIME_$DI_RTE  the DI elements
|
| The names without a map symbol are local names (tools/asm_compare.py
| LOCAL_SYMBOLS has their image addresses).  The Apollo assembler's
| <ea>=#imm forms of CMP/ADD/SUB/AND, which gas spells CMPI/ADDI/SUBI/ANDI,
| are `.short' opcode words followed by their immediates.
|
| The SAU8's calendar is a clock chip with its registers in the calendar
| page's bytes (`calendar_mapped_rtc'): the body reads its binary time
| under the chip's update bit (`D 3C2CDAC TIME_ASM size = 468'), and the
| word after the MCR countdown is the timer handler's flag
| (`timer_int_pic'); those lines carry the SAU8 image's addresses.
|
| The SAU6's calendar is the SAU8's clock chip: its TIME_ASM (`D 7802E34C
| TIME_ASM size = 430') is the SAU8's code without the timer handler's
| flag word (no `timer_int_pic'), so TIME_$TIMER_HANDLER is on a
| longword without the word ahead of it.
|
| Not on the SAUs with the timers of the TIMER block and the indexed
| clock chip (`timer_dcte', `calendar_indexed_rtc', base/config.ins.pas):
| their TIME_ASM is another segment (the SAU9's time/sau9/time_asm.s).
|
        .include "base/config.inc"
        .if     !timer_dcte

| The calendar's registers, as offsets in its page (.Lcalendar)
        .if calendar_word_port
        .set    CAL_CTL, 0x200                  | sau5: control (word port)
        .set    CAL_RDATA, 0x201                | sau5: read data, true
        .elseif calendar_own_page
        .set    CAL_CTL, 0                      | sau3: control, (A0)
        .set    CAL_WDATA, 2                    | sau3: write data
        .set    CAL_RDATA, 4                    | sau3: read data, inverted
        .elseif calendar_timer_page
        .set    CAL_CTL, 0x81                   | sau4: control, in the timer's page
        .set    CAL_WDATA, 0x83                 | sau4: write data
        .set    CAL_RDATA, 0x85                 | sau4: read data, inverted
        .else
        .set    CAL_CTL, 0x20                   | control
        .set    CAL_WDATA, 0x22                 | write data
        .set    CAL_RDATA, 0x24                 | read data, inverted
        .endif

        .section ".text.TIME_$READ_CAL","ax",@progbits
        .balign 2

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
        .globl  TIME_$SET_VECTOR
        .globl  TIME_$DI_VT
        .globl  TIME_$DI_RTE

        .extern CALENDAR                        | arch/m68k/sau2/iodefs.s, 0xFFA800
        .extern TIMR                            | arch/m68k/sau2/iodefs.s, 0xFFAC00
        .extern TIMER_VEC                       | arch/m68k/sau2/iodefs.s, 0x78
        .extern TIME_$TIMER_HANDLER             | time/m68k/timer_handler.s

time_$read_cal_body:
        movem.l %d2/%d6-%d7/%a5,-(%sp)          | e2adfc  48e7 2304
        movea.l %a0,%a5                         | e2ae00  2a48
        .if calendar_mapped_rtc
| The SAU8's clock chip (`calendar_mapped_rtc'): its registers are the
| bytes of the calendar page.  Wait (up to 1001 turns) for the update bit
| (register 10 bit 7) to clear, hold the clock (register 11 bit 7, SET),
| push the binary time - registers 9..6 (year, month, day, weekday), then
| 4, 2, 0 (hour, minute, second) - as words, release SET, and convert as
| the other form does: days since 1980 from the year and month (March
| based), then the clock (4 us ticks) and the seconds.
        movea.l (.Lcalendar:w,%pc),%a0          | sau8 3c2cdb2  207a 0110
        move.w  #1000,%d1                       | sau8 3c2cdb6  323c 03e8
.Lrtc_uip:
        move.b  (10,%a0),%d0                    | sau8 3c2cdba  1028 000a
        btst    #7,%d0                          | sau8 3c2cdbe  0800 0007  updating?
        beq.s   .Lrtc_hold                      | sau8 3c2cdc2  6704
        dbf     %d1,.Lrtc_uip                   | sau8 3c2cdc4  51c9 fff4
.Lrtc_hold:
        move.b  (11,%a0),%d0                    | sau8 3c2cdc8  1028 000b
        bset    #7,%d0                          | sau8 3c2cdcc  08c0 0007  SET
        move.b  %d0,(11,%a0)                    | sau8 3c2cdd0  1140 000b
        move.w  #3,%d0                          | sau8 3c2cdd4  303c 0003
        lea     (10,%a0),%a1                    | sau8 3c2cdd8  43e8 000a
        clr.w   %d1                             | sau8 3c2cddc  4241
.Lrtc_date:
        move.b  -(%a1),%d1                      | sau8 3c2cdde  1221  registers 9..6
        move.w  %d1,-(%sp)                      | sau8 3c2cde0  3f01
        dbf     %d0,.Lrtc_date                  | sau8 3c2cde2  51c8 fffa
        move.w  #2,%d0                          | sau8 3c2cde6  303c 0002
.Lrtc_time:
        subq.l  #1,%a1                          | sau8 3c2cdea  5389
        move.b  -(%a1),%d1                      | sau8 3c2cdec  1221  registers 4, 2, 0
        move.w  %d1,-(%sp)                      | sau8 3c2cdee  3f01
        dbf     %d0,.Lrtc_time                  | sau8 3c2cdf0  51c8 fff8
        clr.l   %d0                             | sau8 3c2cdf4  4280
        move.w  (0xa,%sp),%d0                   | sau8 3c2cdf6  302f 000a  the month
        move.w  #1,%d1                          | sau8 3c2cdfa  323c 0001
        subq.w  #3,%d0                          | sau8 3c2cdfe  5740
        bge.s   .Lrtc_march                     | sau8 3c2ce00  6c06
        clr.w   %d1                             | sau8 3c2ce02  4241
        .short  0xd07c; .short 0x000c           | sau8 3c2ce04  d07c 000c  add.w   #0xc,%d0, the <ea>=#imm form
.Lrtc_march:
        move.w  (0xc,%sp),%d2                   | sau8 3c2ce08  342f 000c  the year
        add.w   %d1,%d2                         | sau8 3c2ce0c  d441
        .short  0x947c; .short 0x0051           | sau8 3c2ce0e  947c 0051  sub.w   #0x51,%d2, the <ea>=#imm form
        bge.s   .Lrtc_century                   | sau8 3c2ce12  6c04
        .short  0xd47c; .short 0x0064           | sau8 3c2ce14  d47c 0064  add.w   #0x64,%d2, the <ea>=#imm form
.Lrtc_century:
        move.b  (11,%a0),%d1                    | sau8 3c2ce18  1228 000b
        bclr    #7,%d1                          | sau8 3c2ce1c  0881 0007  release SET
        move.b  %d1,(11,%a0)                    | sau8 3c2ce20  1141 000b
        move.w  %d2,%d1                         | sau8 3c2ce24  3202
        mulu.w  #0x16d,%d1                      | sau8 3c2ce26  c2fc 016d
        lsr.w   #2,%d2                          | sau8 3c2ce2a  e44a
        add.w   %d1,%d2                         | sau8 3c2ce2c  d441
        move.w  %d0,%d1                         | sau8 3c2ce2e  3200
        mulu.w  #0x1e,%d1                       | sau8 3c2ce30  c2fc 001e
        add.w   %d1,%d2                         | sau8 3c2ce34  d441
        divu.w  #5,%d0                          | sau8 3c2ce36  80fc 0005
        move.w  %d0,%d1                         | sau8 3c2ce3a  3200
        mulu.w  #3,%d1                          | sau8 3c2ce3c  c2fc 0003
        add.w   %d1,%d2                         | sau8 3c2ce40  d441
        swap    %d0                             | sau8 3c2ce42  4840
        addq.w  #1,%d0                          | sau8 3c2ce44  5240
        lsr.w   #1,%d0                          | sau8 3c2ce46  e248
        add.w   %d0,%d2                         | sau8 3c2ce48  d440
        move.w  (0x8,%sp),%d1                   | sau8 3c2ce4a  322f 0008  the day
        add.w   %d1,%d2                         | sau8 3c2ce4e  d441
        .short  0xd47c; .short 0x003b           | sau8 3c2ce50  d47c 003b  add.w   #0x3b,%d2, the <ea>=#imm form
        move.w  (0x4,%sp),%d0                   | sau8 3c2ce54  302f 0004  the hour
        mulu.w  #0x3c,%d0                       | sau8 3c2ce58  c0fc 003c
        add.w   (0x2,%sp),%d0                   | sau8 3c2ce5c  d06f 0002  the minute
        mulu.w  #0x3c,%d0                       | sau8 3c2ce60  c0fc 003c
        .short  0x322f; .short 0x0000           | sau8 3c2ce64  322f 0000  move.w  (0x0,%sp),%d1, kept with its zero displacement (gas would drop it)
        ext.l   %d1                             | sau8 3c2ce68  48c1  the second
        add.l   %d1,%d0                         | sau8 3c2ce6a  d081
        asl.w   #1,%d2                          | sau8 3c2ce6c  e342
        mulu.w  #0xA8C0,%d2                     | sau8 3c2ce6e  c4fc a8c0
        add.l   %d2,%d0                         | sau8 3c2ce72  d082
        movea.l (0x26,%sp),%a0                  | sau8 3c2ce74  206f 0026
        move.l  %d0,(%a0)                       | sau8 3c2ce78  2080
        movea.l (0x22,%sp),%a0                  | sau8 3c2ce7a  206f 0022
        move.w  %d0,%d2                         | sau8 3c2ce7e  3400
        mulu.w  #0xD090,%d2                     | sau8 3c2ce80  c4fc d090
        move.w  %d2,(0x4,%a0)                   | sau8 3c2ce84  3142 0004
        clr.w   %d2                             | sau8 3c2ce88  4242
        swap    %d2                             | sau8 3c2ce8a  4842
        move.w  %d0,%d1                         | sau8 3c2ce8c  3200
        mulu.w  #3,%d1                          | sau8 3c2ce8e  c2fc 0003
        add.l   %d1,%d2                         | sau8 3c2ce92  d481
        swap    %d0                             | sau8 3c2ce94  4840
        move.w  %d0,%d1                         | sau8 3c2ce96  3200
        mulu.w  #0xD090,%d1                     | sau8 3c2ce98  c2fc d090
        add.l   %d1,%d2                         | sau8 3c2ce9c  d481
        move.l  %d2,(%a0)                       | sau8 3c2ce9e  2082
        mulu.w  #3,%d0                          | sau8 3c2cea0  c0fc 0003
        add.w   (%a0),%d0                       | sau8 3c2cea4  d050
        move.w  %d0,(%a0)                       | sau8 3c2cea6  3080
        lea     (0xe,%sp),%sp                   | sau8 3c2cea8  4fef 000e
        movem.l (%sp)+,%d2/%d6-%d7/%a5          | sau8 3c2ceac  4cdf 20c4
        rts                                     | sau8 3c2ceb0  4e75
        .else
        movea.l (.Lcalendar:w,%pc),%a0          | e2ae02  207a 0162
        move.b  #1,(CAL_CTL,%a0)                | e2ae06  117c 0001 0020
        move.w  #0xc5,%d0                       | e2ae0c  303c 00c5
        move.w  #0xc8,%d1                       | e2ae10  323c 00c8
        bsr.w   time_$read_cal_delay            | e2ae14  6100 0142
.Le2ae18:
        move.b  %d0,(CAL_CTL,%a0)               | e2ae18  1140 0020
        bsr.w   time_$read_cal_delay_20         | e2ae1c  6100 0136
        move.b  (CAL_RDATA,%a0),%d1             | e2ae20  1228 0024
        .if !calendar_word_port
        not.w   %d1                             | e2ae24  4641
        .endif
        .short  0xc27c; .short 0x000f           | e2ae26  c27c 000f  and.w   #0xf,%d1, the <ea>=#imm form
        move.w  %d1,-(%sp)                      | e2ae2a  3f01
        .short  0x907c; .short 0x0010           | e2ae2c  907c 0010  sub.w   #0x10,%d0, the <ea>=#imm form
        bge.s   .Le2ae18                        | e2ae30  6ce6
        move.b  #1,(CAL_CTL,%a0)                | e2ae32  117c 0001 0020
        move.w  #0xa,%d0                        | e2ae38  303c 000a
        mulu.w  (0x14,%sp),%d0                  | e2ae3c  c0ef 0014
        add.w   (0x12,%sp),%d0                  | e2ae40  d06f 0012
        move.w  #1,%d1                          | e2ae44  323c 0001
        subq.w  #3,%d0                          | e2ae48  5740
        bge.s   .Le2ae52                        | e2ae4a  6c06
        clr.w   %d1                             | e2ae4c  4241
        .short  0xd07c; .short 0x000c           | e2ae4e  d07c 000c  add.w   #0xc,%d0, the <ea>=#imm form
.Le2ae52:
        move.w  #0xa,%d2                        | e2ae52  343c 000a
        mulu.w  (0x18,%sp),%d2                  | e2ae56  c4ef 0018
        add.w   (0x16,%sp),%d2                  | e2ae5a  d46f 0016
        add.w   %d1,%d2                         | e2ae5e  d441
        .short  0x947c; .short 0x0051           | e2ae60  947c 0051  sub.w   #0x51,%d2, the <ea>=#imm form
        bge.s   .Le2ae6a                        | e2ae64  6c04
        .short  0xd47c; .short 0x0064           | e2ae66  d47c 0064  add.w   #0x64,%d2, the <ea>=#imm form
.Le2ae6a:
        move.l  %d2,%d1                         | e2ae6a  2202
        addq.w  #1,%d1                          | e2ae6c  5241
        .short  0xc27c; .short 0x0003           | e2ae6e  c27c 0003  and.w   #3,%d1, the <ea>=#imm form
        bne.s   .Le2ae98                        | e2ae72  6624
        move.w  (0x10,%sp),%d1                  | e2ae74  322f 0010
        bset    #2,%d1                          | e2ae78  08c1 0002
        .if calendar_word_port
        clr.w   %d6                             | sau5 e2bfb6  4246
        move.b  %d1,%d6                         | sau5 e2bfb8  1c01
        .short  0x8c7c; .short 0x8100           | sau5 e2bfba  8c7c 8100  or.w #0x8100,%d6, the <ea>=#imm form
        move.w  %d6,(CAL_CTL,%a0)               | sau5 e2bfbe  3146 0200
        move.w  %d6,%d7                         | sau5 e2bfc2  3e06
        .short  0x8e7c; .short 0x0200           | sau5 e2bfc4  8e7c 0200  or.w #0x200,%d7, the <ea>=#imm form
        move.w  %d7,(CAL_CTL,%a0)               | sau5 e2bfc8  3147 0200
        bsr.w   time_$read_cal_delay_20         | sau5 e2bfcc  6100 00c2
        move.w  %d6,(CAL_CTL,%a0)               | sau5 e2bfd0  3146 0200
        .else
        not.w   %d1                             | e2ae7c  4641
        move.b  %d1,(CAL_WDATA,%a0)             | e2ae7e  1141 0022
        move.b  #0x81,(CAL_CTL,%a0)             | e2ae82  117c 0081 0020
        move.b  #0x83,(CAL_CTL,%a0)             | e2ae88  117c 0083 0020
        bsr.w   time_$read_cal_delay_20         | e2ae8e  6100 00c4
        move.b  #0x81,(CAL_CTL,%a0)             | e2ae92  117c 0081 0020
        .endif
.Le2ae98:
        move.b  #0,(CAL_CTL,%a0)                | e2ae98  117c 0000 0020
        move.w  %d2,%d1                         | e2ae9e  3202
        mulu.w  #0x16d,%d1                      | e2aea0  c2fc 016d
        lsr.w   #2,%d2                          | e2aea4  e44a
        add.w   %d1,%d2                         | e2aea6  d441
        move.w  %d0,%d1                         | e2aea8  3200
        mulu.w  #0x1e,%d1                       | e2aeaa  c2fc 001e
        add.w   %d1,%d2                         | e2aeae  d441
        divu.w  #5,%d0                          | e2aeb0  80fc 0005
        move.w  %d0,%d1                         | e2aeb4  3200
        mulu.w  #3,%d1                          | e2aeb6  c2fc 0003
        add.w   %d1,%d2                         | e2aeba  d441
        swap    %d0                             | e2aebc  4840
        addq.w  #1,%d0                          | e2aebe  5240
        lsr.w   #1,%d0                          | e2aec0  e248
        add.w   %d0,%d2                         | e2aec2  d440
        move.w  (0x10,%sp),%d1                  | e2aec4  322f 0010
        .short  0xc27c; .short 0x0003           | e2aec8  c27c 0003  and.w   #3,%d1, the <ea>=#imm form
        mulu.w  #0xa,%d1                        | e2aecc  c2fc 000a
        add.w   (0xe,%sp),%d1                   | e2aed0  d26f 000e
        add.w   %d1,%d2                         | e2aed4  d441
        .short  0xd47c; .short 0x003b           | e2aed6  d47c 003b  add.w   #0x3b,%d2, the <ea>=#imm form
        move.w  (0xa,%sp),%d0                   | e2aeda  302f 000a
        .short  0xc07c; .short 0x0003           | e2aede  c07c 0003  and.w   #3,%d0, the <ea>=#imm form
        mulu.w  #0xa,%d0                        | e2aee2  c0fc 000a
        add.w   (0x8,%sp),%d0                   | e2aee6  d06f 0008
        mulu.w  #0x3c,%d0                       | e2aeea  c0fc 003c
        move.w  #0xa,%d1                        | e2aeee  323c 000a
        mulu.w  (0x6,%sp),%d1                   | e2aef2  c2ef 0006
        add.w   (0x4,%sp),%d1                   | e2aef6  d26f 0004
        add.w   %d1,%d0                         | e2aefa  d041
        mulu.w  #0x3c,%d0                       | e2aefc  c0fc 003c
        move.w  #0xa,%d1                        | e2af00  323c 000a
        mulu.w  (0x2,%sp),%d1                   | e2af04  c2ef 0002
        .short  0xd26f; .short 0x0000           | e2af08  d26f 0000  add.w   (0x0,%sp),%d1, kept with its zero displacement (gas would drop it)
        add.l   %d1,%d0                         | e2af0c  d081
        asl.w   #1,%d2                          | e2af0e  e342
        mulu.w  #0xA8C0,%d2                     | e2af10  c4fc a8c0
        add.l   %d2,%d0                         | e2af14  d082
        movea.l (0x32,%sp),%a0                  | e2af16  206f 0032
        move.l  %d0,(%a0)                       | e2af1a  2080
        movea.l (0x2e,%sp),%a0                  | e2af1c  206f 002e
        move.w  %d0,%d2                         | e2af20  3400
        mulu.w  #0xD090,%d2                     | e2af22  c4fc d090
        move.w  %d2,(0x4,%a0)                   | e2af26  3142 0004
        clr.w   %d2                             | e2af2a  4242
        swap    %d2                             | e2af2c  4842
        move.w  %d0,%d1                         | e2af2e  3200
        mulu.w  #3,%d1                          | e2af30  c2fc 0003
        add.l   %d1,%d2                         | e2af34  d481
        swap    %d0                             | e2af36  4840
        move.w  %d0,%d1                         | e2af38  3200
        mulu.w  #0xD090,%d1                     | e2af3a  c2fc d090
        add.l   %d1,%d2                         | e2af3e  d481
        move.l  %d2,(%a0)                       | e2af40  2082
        mulu.w  #3,%d0                          | e2af42  c0fc 0003
        add.w   (%a0),%d0                       | e2af46  d050
        move.w  %d0,(%a0)                       | e2af48  3080
        lea     (0x1a,%sp),%sp                  | e2af4a  4fef 001a
        movem.l (%sp)+,%d2/%d6-%d7/%a5          | e2af4e  4cdf 20c4
        rts                                     | e2af52  4e75
        .endif
time_$read_cal_delay_20:
        move.w  #0x14,%d1                       | e2af54  323c 0014
time_$read_cal_delay:
        subq.w  #1,%d1                          | e2af58  5341
        bne.s   time_$read_cal_delay            | e2af5a  66fc
        rts                                     | e2af5c  4e75
TIME_$READ_CAL:
        lea     (TIME_$READ_CAL:w,%pc),%a0      | e2af5e  41fa fffe
        jmp     (time_$read_cal_body:w,%pc)     | e2af62  4efa fe98
.Lcalendar:                             | 0xE2AF66: the calendar page, read by the body
        .long   CALENDAR                | 00ffa800, a fixup-table cell
IN_VT_INT:                              | 0xE2AF6A: a virtual-timer DI is queued
        .byte   0
IN_RT_INT:                              | 0xE2AF6B: a real-time-timer DI is queued
        .byte   0
TIME_$VT_TIMER:
        lea     (TIMR).l,%a0                    | e2af6c  41f9 00ff ac00
        movep.w (0x9,%a0),%d0                   | e2af72  0108 0009
        btst    #1,(0x3,%a0)                    | e2af76  0828 0001 0003
        bne.s   .Le2af86                        | e2af7c  6608
        tst.b   (IN_VT_INT).l                   | e2af7e  4a39 00e2 af6a
        beq.s   .Le2af88                        | e2af84  6702
.Le2af86:
        clr.w   %d0                             | e2af86  4240
.Le2af88:
        rts                                     | e2af88  4e75
TIME_$WRT_VT_TIMER:
        movea.l %a0,%a2                         | e2af8a  2448
        lea     (TIMR).l,%a0                    | e2af8c  41f9 00ff ac00
        movep.w %d0,(0x9,%a0)                   | e2af92  0188 0009
        movea.l %a2,%a0                         | e2af96  204a
        sf      (IN_VT_INT).l                   | e2af98  51f9 00e2 af6a
        rts                                     | e2af9e  4e75
TIME_$WRT_TIMER:
        movea.l (0x4,%sp),%a0                   | e2afa0  206f 0004
        clr.l   %d0                             | e2afa4  4280
        move.w  (%a0),%d0                       | e2afa6  3010
        movea.l (0x8,%sp),%a0                   | e2afa8  206f 0008
        move.w  (%a0),%d1                       | e2afac  3210
        lea     (TIMR).l,%a0                    | e2afae  41f9 00ff ac00
        asl.w   #2,%d0                          | e2afb4  e540
        lea     (0x0,%a0,%d0.w),%a0             | e2afb6  41f0 0000
        movep.w %d1,(0x1,%a0)                   | e2afba  0388 0001
        .short  0xb07c; .short 0x0008           | e2afbe  b07c 0008  cmp.w   #8,%d0, the <ea>=#imm form
        beq.s   .Le2afce                        | e2afc2  670a
        blt.s   .Le2afd4                        | e2afc4  6d0e
        sf      (IN_RT_INT).l                   | e2afc6  51f9 00e2 af6b
        bra.s   .Le2afd4                        | e2afcc  6006
.Le2afce:
        sf      (IN_VT_INT).l                   | e2afce  51f9 00e2 af6a
.Le2afd4:
        rts                                     | e2afd4  4e75
TIME_$CLOCK:
        lea     (TIMR).l,%a0                    | e2afd6  41f9 00ff ac00
        move.w  %sr,%d1                         | e2afdc  40c1
        ori.w   #0x700,%sr                      | e2afde  007c 0700
        movea.l (TIME_$CURRENT_CLOCKH:w,%pc),%a1| e2afe2  227a 0100
        clr.l   %d0                             | e2afe6  4280
        movep.w (0x5,%a0),%d0                   | e2afe8  0108 0005
        not.w   %d0                             | e2afec  4640
        .short  0xd07c; .short 0x1047           | e2afee  d07c 1047  add.w   #0x1047,%d0, the <ea>=#imm form
        .short  0xb07c; .short 0x0fe3           | e2aff2  b07c 0fe3  cmp.w   #0xfe3,%d0, the <ea>=#imm form
        bgt.s   .Le2b008                        | e2aff6  6e10
        btst    #0,(0x3,%a0)                    | e2aff8  0828 0000 0003
        beq.s   .Le2b008                        | e2affe  6708
        add.w   (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b000  d07a 00f6
        bcc.s   .Le2b008                        | e2b004  6402
        addq.l  #1,%a1                          | e2b006  5289
.Le2b008:
        cmp.w   (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b008  b07a 00ee
        ble.s   .Le2b012                        | e2b00c  6f04
        move.w  (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b00e  303a 00e8
.Le2b012:
        add.w   (TIME_$CURRENT_CLOCKL:w,%pc),%d0| e2b012  d07a 00d4
        bcc.s   .Le2b01a                        | e2b016  6402
        addq.l  #1,%a1                          | e2b018  5289
.Le2b01a:
        move.w  %d1,%sr                         | e2b01a  46c1
        movea.l (0x4,%sp),%a0                   | e2b01c  206f 0004
        move.l  %a1,(%a0)+                      | e2b020  20c9
        move.w  %d0,(%a0)                       | e2b022  3080
        rts                                     | e2b024  4e75
TIME_$ABS_CLOCK:
        lea     (TIMR).l,%a0                    | e2b026  41f9 00ff ac00
        move.w  %sr,%d1                         | e2b02c  40c1
        ori.w   #0x700,%sr                      | e2b02e  007c 0700
        movea.l (TIME_$CLOCKH:w,%pc),%a1        | e2b032  227a 00a0
        movep.w (0x5,%a0),%d0                   | e2b036  0108 0005
        not.w   %d0                             | e2b03a  4640
        .short  0xd07c; .short 0x1047           | e2b03c  d07c 1047  add.w   #0x1047,%d0, the <ea>=#imm form
        .short  0xb07c; .short 0x0fe3           | e2b040  b07c 0fe3  cmp.w   #0xfe3,%d0, the <ea>=#imm form
        bgt.s   .Le2b008                        | e2b044  6ec2
        btst    #0,(0x3,%a0)                    | e2b046  0828 0000 0003
        beq.s   .Le2b056                        | e2b04c  6708
        .short  0xd07c; .short 0x1047           | e2b04e  d07c 1047  add.w   #0x1047,%d0, the <ea>=#imm form
        bcc.s   .Le2b056                        | e2b052  6402
        addq.l  #1,%a1                          | e2b054  5289
.Le2b056:
        add.w   (TIME_$CLOCKL:w,%pc),%d0        | e2b056  d07a 0088
        bcc.s   .Le2b05e                        | e2b05a  6402
        addq.l  #1,%a1                          | e2b05c  5289
.Le2b05e:
        move.w  %d1,%sr                         | e2b05e  46c1
        movea.l (0x4,%sp),%a0                   | e2b060  206f 0004
        move.l  %a1,(%a0)+                      | e2b064  20c9
        move.w  %d0,(%a0)                       | e2b066  3080
        rts                                     | e2b068  4e75
TIME_$GET_TIME_OF_DAY:
        lea     (TIMR).l,%a0                    | e2b06a  41f9 00ff ac00
        move.w  %sr,%d1                         | e2b070  40c1
        ori.w   #0x700,%sr                      | e2b072  007c 0700
        movea.l (TIME_$CURRENT_TIME:w,%pc),%a1  | e2b076  227a 0078
        clr.l   %d0                             | e2b07a  4280
        movep.w (0x5,%a0),%d0                   | e2b07c  0108 0005
        not.w   %d0                             | e2b080  4640
        .short  0xd07c; .short 0x1047           | e2b082  d07c 1047  add.w   #0x1047,%d0, the <ea>=#imm form
        .short  0xb07c; .short 0x0fe3           | e2b086  b07c 0fe3  cmp.w   #0xfe3,%d0, the <ea>=#imm form
        bgt.s   .Le2b09c                        | e2b08a  6e10
        btst    #0,(0x3,%a0)                    | e2b08c  0828 0000 0003
        beq.s   .Le2b09c                        | e2b092  6708
        add.w   (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b094  d07a 0062
        bcc.s   .Le2b09c                        | e2b098  6402
        addq.l  #1,%a1                          | e2b09a  5289
.Le2b09c:
        cmp.w   (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b09c  b07a 005a
        ble.s   .Le2b0a6                        | e2b0a0  6f04
        move.w  (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b0a2  303a 0054
.Le2b0a6:
        lsl.l   #2,%d0                          | e2b0a6  e588
        add.l   (TIME_$CURRENT_TIME+4:w,%pc),%d0| e2b0a8  d0ba 004a
        .short  0xb0bc; .long 0x000f4240        | e2b0ac  b0bc 000f 4240  cmp.l   #0xf4240,%d0, the <ea>=#imm form
        bmi.s   .Le2b0bc                        | e2b0b2  6b08
        addq.l  #1,%a1                          | e2b0b4  5289
        .short  0x90bc; .long 0x000f4240        | e2b0b6  90bc 000f 4240  sub.l   #0xf4240,%d0, the <ea>=#imm form
.Le2b0bc:
        move.w  %d1,%sr                         | e2b0bc  46c1
        movea.l (0x4,%sp),%a0                   | e2b0be  206f 0004
        move.l  %a1,(%a0)+                      | e2b0c2  20c9
        move.l  %d0,(%a0)                       | e2b0c4  2080
        rts                                     | e2b0c6  4e75

| The clock cells, 0xE2B0C8..0xE2B102.
TIME_$FAST_CLOCK_EC:                    | 0xE2B0C8: eventcount, empty
        .long   0, TIME_$FAST_CLOCK_EC, TIME_$FAST_CLOCK_EC
TIME_$CLOCKH_EC:                        | 0xE2B0D4: eventcount, empty; its
TIME_$CLOCKH:                           |   value is the clock's high longword
        .long   0, TIME_$CLOCKH_EC, TIME_$CLOCKH_EC
TIME_$CLOCKL:                           | 0xE2B0E0: the clock's low word
        .word   0, 0
TIME_$CURRENT_CLOCKH:                   | 0xE2B0E4
        .long   0
TIME_$CURRENT_CLOCKL:                   | 0xE2B0E8
        .word   0, 0
TIME_$BOOT_TIME:                        | 0xE2B0EC
        .long   0
TIME_$CURRENT_TIME:                     | 0xE2B0F0: seconds
        .long   0
        .long   0                       | 0xE2B0F4: microseconds (TIME_$CURRENT_TIME+4)
TIME_$CURRENT_TICK:                     | 0xE2B0F8
        .word   0
TIME_$CURRENT_SKEW:                     | 0xE2B0FA
        .word   0
TIME_$CURRENT_DELTA:                    | 0xE2B0FC
        .long   0
        .word   2                       | 0xE2B100: MCR countdown (TIME_$CURRENT_DELTA+4)
        .if timer_int_pic
        .word   0                       | sau8 0x3C2D060: the timer handler served a timer (TIME_$CURRENT_DELTA+6)
        .endif
TIME_$SET_VECTOR:
        lea     (TIME_$TIMER_HANDLER:w,%pc),%a0 | e2b102  41fa 002c
        move.l  %a0,(TIMER_VEC).l               | e2b106  23c8 0000 0078
        rts                                     | e2b10c  4e75

| The two deferred-interrupt elements (di/di.ins.pas di_$q_elem_t, 16
| bytes), zero; TIME_$INIT clears them with DI_$INIT_Q_ELEM.
TIME_$DI_VT:                            | 0xE2B10E
        .space  16
TIME_$DI_RTE:                           | 0xE2B11E
        .space  16
| The word that keeps TIME_$TIMER_HANDLER on a longword: not on the SAU3
| (its body 0x10 bytes shorter) nor on the SAU6 (the clock chip's body
| without the SAU8's timer flag word).
        .if !calendar_own_page
        .if timer_int_pic
        .word   0                       | sau8 0x3C2D08E, before TIME_$TIMER_HANDLER
        .elseif !calendar_mapped_rtc
        .word   0                       | 0xE2B12E, before TIME_$TIMER_HANDLER
        .endif
        .endif

        .endif
