|
| time/m68k/timer_handler.s - TIME_$TIMER_HANDLER, the level-6 timer
| interrupt (SAU2, SAU5)
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.  The SAU8's (`timer_int_pic',
| base/config.ins.pas; TIME_$DI_RTE + 0x12, 0x3C2D090) is another form:
| it acknowledges PIC1, serves every pending timer in a loop, flags each
| in the word after the MCR countdown, and advances TIME_$CLOCKH_EC
| itself; its lines carry the SAU8 image's addresses.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's
| encodings, every address operand a relocation resolved against the
| image's.
|
| The TIME_ASM cells are hand assembly in time/m68k/time_asm.s, so the
| (d16,PC) operands the image uses for them are the image's; the timer
| block is TIMR (a fixup-table cell, 0xE2B13C), and the two cells the map
| does not name are reached as map symbol + offset: the microseconds,
| TIME_$CURRENT_TIME+4 (0xE2B0F4), and the MCR countdown word,
| TIME_$CURRENT_DELTA+4 (0xE2B100).
|
| Original address: 0x00E2B130, 336 bytes (0x00E2B130 .. 0x00E2B27F), the
| end of the map's TIME_ASM segment (D E2ADFC size 0x484).  The map names
| no symbol here (TIME_$TIMER_HANDLER is a local name;
| tools/asm_compare.py LOCAL_SYMBOLS, tools/gen_layout_ld.py ANCHORS);
| TIME_$SET_VECTOR (0x00E2B102, time/m68k/time_asm.s) stores the address
| into the level-6 autovector (0x78).  Entered from the exception with the
| frame on the stack: SR at (0,SP) before the movem, (0x10,SP) after it.
|
| The timer block (TIMR, 0xFFAC00): (2,A0) is the interrupt status, bit 0
| the clock tick, bit 1 the virtual timer, bit 2 the real-time timer;
| reading (4,A0) acknowledges the tick; `movep.w' of -1 to (9,A0) /
| (0xd,A0) reloads the VT / RT counters (bytes 0xFFAC09/0B and
| 0xFFAC0D/0F).
|
|   0x00E2B130  save D0-D1/A0-A1, IO_$USE_INT_STACK
|   0x00E2B13A  status bit 0 clear -> 0x00E2B200
|   -- clock tick --
|   0x00E2B14C  acknowledge; charge the tick to PROC1_$CURRENT_PCB:
|               +0x60 if the interrupted SR had S (bit 13 = bit 5 of its
|               high byte, (0x10,SP)), else +0x64
|   0x00E2B168  CURRENT_CLOCK (48 bits) += TIME_$CURRENT_TICK
|   0x00E2B17C  the microseconds += tick * 4; >= 1000000 ->
|               CURRENT_TIME++, microseconds -= 1000000
|   0x00E2B19C  CURRENT_DELTA != 0: DELTA -= SKEW (sign-extended);
|               reaching 0 -> SKEW = 0, TICK = 0x1047
|   0x00E2B1C2  EC_$ADVANCE_WITHOUT_DISPATCH(&TIME_$FAST_CLOCK_EC)
|   0x00E2B1CE  CLOCKL += 0x1047; no carry -> PROC1_$INT_EXIT
|   0x00E2B1DE  carry (a CLOCKH step): every second one, MMU_$MCR_CHANGE(7)
|               (the countdown word, reloaded with 2); then
|               PROC1_$INT_ADVANCE with A0 = TIME_$CLOCKH_EC
|   -- virtual timer (0x00E2B200) --
|               reload; unless IN_VT_INT: set it and
|               DI_$ENQ(TIME_$VT_INT, 0, &TIME_$DI_VT); PROC1_$INT_EXIT
|   -- real-time timer (0x00E2B238) --
|               the same with IN_RT_INT, TIME_$RTE_INT, TIME_$DI_RTE
|   -- none of the three (0x00E2B270) --
|               IO_$COND_SWITCH_BACK, restore, FIM_$SPURIOUS_INT
|
| The SAU4's passes MMU_$MCR_CHANGE 0x10F (`mcr_change_low_bits': its
| MMU_$MCR_CHANGE flips the low four bits of an argument from 0xFF up
| without the shift; mmu/sau4/mmu_asm.s) where the SAU2 passes 7; that
| line carries the SAU4 image's address.  The SAU6's passes 1
| (`mcr_change_bit_0'); its other lines are the SAU2's (the SAU6 image's
| handler, 0x7802E62C, is the SAU2's code with its own addresses).
|
| The image spells `cmp.l' / `sub.l #1000000,D0' as CMP/SUB <ea>=#imm;
| they are `.short' opcode words with their immediates here.
|
| Not on the SAUs with the timers of the TIMER block and the indexed
| clock chip (`timer_dcte', `calendar_indexed_rtc', base/config.ins.pas):
| their TIME_ASM is another segment (the SAU9's time/sau9/time_asm.s).
|
        .include "base/config.inc"
        .if     !timer_dcte

        .section ".text.TIME_$TIMER_HANDLER","ax",@progbits
        .balign 2

        .globl  TIME_$TIMER_HANDLER

        .extern IO_$USE_INT_STACK               | io/m68k/use_int_stack.s
        .extern IO_$COND_SWITCH_BACK            | io/m68k/cond_switch_back.s
        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern PROC1_$INT_EXIT                 | proc1/m68k/int_handler.s
        .extern PROC1_$INT_ADVANCE              | proc1/m68k/int_handler.s
        .extern EC_$ADVANCE_WITHOUT_DISPATCH    | ec/m68k/advance_without_dispatch.s
        .extern MMU_$MCR_CHANGE                 | mmu/m68k/mcr_change.s
        .extern DI_$ENQ                         | di/m68k/enq.s
        .extern TIME_$VT_INT                    | time/vt_int.pas
        .extern TIME_$RTE_INT                   | time/rte_int.pas
        .extern FIM_$SPURIOUS_INT               | fim/m68k/spurious_int.s
        | time/m68k/time_asm.s:
        .extern TIME_$CURRENT_TICK, TIME_$CURRENT_CLOCKL, TIME_$CURRENT_CLOCKH
        .extern TIME_$CURRENT_TIME, TIME_$CURRENT_DELTA, TIME_$CURRENT_SKEW
        .extern TIME_$FAST_CLOCK_EC, TIME_$CLOCKL, TIME_$CLOCKH
        .extern IN_VT_INT, IN_RT_INT, TIME_$DI_VT, TIME_$DI_RTE

TIME_$TIMER_HANDLER:
        .if timer_int_pic
| The SAU8's form (`timer_int_pic'): acknowledge PIC1, then serve the
| timers until none is pending, the word TIME_$CURRENT_DELTA+6 set by each
| one served; none at all is a spurious interrupt.  The clock carry
| advances TIME_$CLOCKH_EC without dispatching (the other form leaves
| through PROC1_$INT_ADVANCE).
        .extern PIC1                            | arch/m68k/sau8/iodefs.s
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | sau8 3c2d090  48e7 c0c0
        jsr     (IO_$USE_INT_STACK).l           | sau8 3c2d094  4eb9 03c3 1426
        clr.w   (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d09a  4279 03c2 d060
        move.b  #0x20,(PIC1).l                  | sau8 3c2d0a0  13fc 0020 03ff 9000
.Lpoll:
        lea     (TIMR).l,%a0                    | sau8 3c2d0a8  41f9 03ff ac00
        move.w  (2,%a0),%d0                     | sau8 3c2d0ae  3028 0002
        btst    #0,%d0                          | sau8 3c2d0b2  0800 0000
        beq.w   .Lnot_tick                      | sau8 3c2d0b6  6700 00c6
        tst.w   (4,%a0)                         | sau8 3c2d0ba  4a68 0004
        movea.l (PROC1_$CURRENT_PCB).l,%a0      | sau8 3c2d0be  2079 03c2 0300
        btst    #5,(0x10,%sp)                   | sau8 3c2d0c4  082f 0005 0010
        beq.s   .Lsystem                        | sau8 3c2d0ca  6706
        addq.l  #1,(0x60,%a0)                   | sau8 3c2d0cc  52a8 0060
        bra.s   .Ltick                          | sau8 3c2d0d0  6004
.Lsystem:
        addq.l  #1,(0x64,%a0)                   | sau8 3c2d0d2  52a8 0064
.Ltick:
        clr.l   %d0                             | sau8 3c2d0d6  4280
        move.w  (TIME_$CURRENT_TICK:w,%pc),%d0  | sau8 3c2d0d8  303a ff7c
        add.w   %d0,(TIME_$CURRENT_CLOCKL).l    | sau8 3c2d0dc  d179 03c2 d046
        bcc.s   .Lusec                          | sau8 3c2d0e2  6406
        addq.l  #1,(TIME_$CURRENT_CLOCKH).l     | sau8 3c2d0e4  52b9 03c2 d042
.Lusec:
        lsl.l   #2,%d0                          | sau8 3c2d0ea  e588
        add.l   (TIME_$CURRENT_TIME+0x4:w,%pc),%d0| sau8 3c2d0ec  d0ba ff64
        .short  0xb0bc; .long 0x000f4240        | sau8 3c2d0f0  b0bc 000f 4240  cmp.l   #0xf4240,%d0, the <ea>=#imm form
        bmi.s   .Lusec_store                    | sau8 3c2d0f6  6b0c
        addq.l  #1,(TIME_$CURRENT_TIME).l       | sau8 3c2d0f8  52b9 03c2 d04e
        .short  0x90bc; .long 0x000f4240        | sau8 3c2d0fe  90bc 000f 4240  sub.l   #0xf4240,%d0, the <ea>=#imm form
.Lusec_store:
        move.l  %d0,(TIME_$CURRENT_TIME+0x4).l  | sau8 3c2d104  23c0 03c2 d052
        tst.l   (TIME_$CURRENT_DELTA).l         | sau8 3c2d10a  4ab9 03c2 d05a
        beq.s   .Lskew_done                     | sau8 3c2d110  671e
        move.w  (TIME_$CURRENT_SKEW:w,%pc),%d0  | sau8 3c2d112  303a ff44
        ext.l   %d0                             | sau8 3c2d116  48c0
        sub.l   %d0,(TIME_$CURRENT_DELTA).l     | sau8 3c2d118  91b9 03c2 d05a
        bne.w   .Lskew_done                     | sau8 3c2d11e  6600 0010
        clr.w   (TIME_$CURRENT_SKEW).l          | sau8 3c2d122  4279 03c2 d058
        move.w  #0x1047,(TIME_$CURRENT_TICK).l  | sau8 3c2d128  33fc 1047 03c2 d056
.Lskew_done:
        pea     (TIME_$FAST_CLOCK_EC:w,%pc)     | sau8 3c2d130  487a fef4
        jsr     (EC_$ADVANCE_WITHOUT_DISPATCH).l| sau8 3c2d134  4eb9 03c2 1f50
        addq.l  #4,%sp                          | sau8 3c2d13a  588f
        addi.w  #0x1047,(TIME_$CLOCKL).l        | sau8 3c2d13c  0679 1047 03c2 d03e
        bcs.s   .Lclock_carry                   | sau8 3c2d144  650a
        st      (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d146  50f9 03c2 d060
        bra.w   .Lpoll                          | sau8 3c2d14c  6000 ff5a
.Lclock_carry:
        lea     (TIME_$CURRENT_DELTA+0x4:w,%pc),%a0| sau8 3c2d150  41fa ff0c
        subq.w  #1,(%a0)                        | sau8 3c2d154  5350
        bne.s   .Lmcr_done                      | sau8 3c2d156  6610
        move.w  #2,(%a0)                        | sau8 3c2d158  30bc 0002
        move.w  #1,-(%sp)                       | sau8 3c2d15c  3f3c 0001
        jsr     (MMU_$MCR_CHANGE).l             | sau8 3c2d160  4eb9 03c2 5e64
        addq.l  #2,%sp                          | sau8 3c2d166  548f
.Lmcr_done:
        st      (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d168  50f9 03c2 d060
        pea     (TIME_$CLOCKH_EC:w,%pc)         | sau8 3c2d16e  487a fec2
        jsr     (EC_$ADVANCE_WITHOUT_DISPATCH).l| sau8 3c2d172  4eb9 03c2 1f50
        addq.l  #4,%sp                          | sau8 3c2d178  588f
        bra.w   .Lpoll                          | sau8 3c2d17a  6000 ff2c
.Lnot_tick:
        btst    #1,%d0                          | sau8 3c2d17e  0800 0001
        beq.s   .Lnot_vt                        | sau8 3c2d182  6736
        moveq   #-1,%d1                         | sau8 3c2d184  72ff
        movep.w %d1,(9,%a0)                     | sau8 3c2d186  0388 0009
        tst.b   (IN_VT_INT).l                   | sau8 3c2d18a  4a39 03c2 cec8
        bne.s   .Lvt_queued                     | sau8 3c2d190  661e
        st      (IN_VT_INT).l                   | sau8 3c2d192  50f9 03c2 cec8
        pea     (TIME_$DI_VT:w,%pc)             | sau8 3c2d198  487a fed4
        clr.l   -(%sp)                          | sau8 3c2d19c  42a7
        pea     (TIME_$VT_INT).l                | sau8 3c2d19e  4879 03c1 7304
        jsr     (DI_$ENQ).l                     | sau8 3c2d1a4  4eb9 03c2 21e0
        adda.l  #0xc,%sp                        | sau8 3c2d1aa  dffc 0000 000c
.Lvt_queued:
        st      (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d1b0  50f9 03c2 d060
        bra.w   .Lpoll                          | sau8 3c2d1b6  6000 fef0
.Lnot_vt:
        btst    #2,%d0                          | sau8 3c2d1ba  0800 0002
        beq.s   .Lnone_left                     | sau8 3c2d1be  6736
        moveq   #-1,%d1                         | sau8 3c2d1c0  72ff
        movep.w %d1,(0xd,%a0)                   | sau8 3c2d1c2  0388 000d
        tst.b   (IN_RT_INT).l                   | sau8 3c2d1c6  4a39 03c2 cec9
        bne.s   .Lrt_queued                     | sau8 3c2d1cc  661e
        st      (IN_RT_INT).l                   | sau8 3c2d1ce  50f9 03c2 cec9
        pea     (TIME_$DI_RTE:w,%pc)            | sau8 3c2d1d4  487a fea8
        clr.l   -(%sp)                          | sau8 3c2d1d8  42a7
        pea     (TIME_$RTE_INT).l               | sau8 3c2d1da  4879 03c1 72c6
        jsr     (DI_$ENQ).l                     | sau8 3c2d1e0  4eb9 03c2 21e0
        adda.l  #0xc,%sp                        | sau8 3c2d1e6  dffc 0000 000c
.Lrt_queued:
        st      (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d1ec  50f9 03c2 d060
        bra.w   .Lpoll                          | sau8 3c2d1f2  6000 feb4
.Lnone_left:
        tst.b   (TIME_$CURRENT_DELTA+0x6).l     | sau8 3c2d1f6  4a39 03c2 d060
        beq.s   .Lspurious                      | sau8 3c2d1fc  6706
        jmp     (PROC1_$INT_EXIT).l             | sau8 3c2d1fe  4ef9 03c2 2136
.Lspurious:
        jsr     (IO_$COND_SWITCH_BACK).l        | sau8 3c2d204  4eb9 03c3 1446
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | sau8 3c2d20a  4cdf 0303
        jmp     (FIM_$SPURIOUS_INT).l           | sau8 3c2d20e  4ef9 03c2 380c
        .else
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | e2b130  48e7 c0c0
        jsr     IO_$USE_INT_STACK               | e2b134  4eb9 00e2 e826
        lea     (TIMR).l,%a0                    | e2b13a  41f9 00ff ac00
        move.w  (0x2,%a0),%d0                   | e2b140  3028 0002
        btst    #0,%d0                          | e2b144  0800 0000
        beq.w   .Le2b200                        | e2b148  6700 00b6
        tst.w   (0x4,%a0)                       | e2b14c  4a68 0004
        movea.l (PROC1_$CURRENT_PCB).l,%a0      | e2b150  2079 00e1 eac8
        btst    #5,(0x10,%sp)                   | e2b156  082f 0005 0010
        beq.s   .Le2b164                        | e2b15c  6706
        addq.l  #1,(0x60,%a0)                   | e2b15e  52a8 0060
        bra.s   .Le2b168                        | e2b162  6004
.Le2b164:
        addq.l  #1,(0x64,%a0)                   | e2b164  52a8 0064
.Le2b168:
        clr.l   %d0                             | e2b168  4280
        move.w  (TIME_$CURRENT_TICK:w,%pc),%d0  | e2b16a  303a ff8c
        add.w   %d0,(TIME_$CURRENT_CLOCKL).l    | e2b16e  d179 00e2 b0e8
        bcc.s   .Le2b17c                        | e2b174  6406
        addq.l  #1,(TIME_$CURRENT_CLOCKH).l     | e2b176  52b9 00e2 b0e4
.Le2b17c:
        lsl.l   #2,%d0                          | e2b17c  e588
        add.l   (TIME_$CURRENT_TIME+4:w,%pc),%d0| e2b17e  d0ba ff74
        .short  0xb0bc; .long 0x000f4240        | e2b182  b0bc 000f 4240  cmp.l   #0xf4240,%d0, the <ea>=#imm form
        bmi.s   .Le2b196                        | e2b188  6b0c
        addq.l  #1,(TIME_$CURRENT_TIME).l       | e2b18a  52b9 00e2 b0f0
        .short  0x90bc; .long 0x000f4240        | e2b190  90bc 000f 4240  sub.l   #0xf4240,%d0, the <ea>=#imm form
.Le2b196:
        move.l  %d0,(TIME_$CURRENT_TIME+4).l    | e2b196  23c0 00e2 b0f4
        tst.l   (TIME_$CURRENT_DELTA).l         | e2b19c  4ab9 00e2 b0fc
        beq.s   .Le2b1c2                        | e2b1a2  671e
        move.w  (TIME_$CURRENT_SKEW:w,%pc),%d0  | e2b1a4  303a ff54
        ext.l   %d0                             | e2b1a8  48c0
        sub.l   %d0,(TIME_$CURRENT_DELTA).l     | e2b1aa  91b9 00e2 b0fc
        bne.w   .Le2b1c2                        | e2b1b0  6600 0010
        clr.w   (TIME_$CURRENT_SKEW).l          | e2b1b4  4279 00e2 b0fa
        move.w  #0x1047,(TIME_$CURRENT_TICK).l  | e2b1ba  33fc 1047 00e2 b0f8
.Le2b1c2:
        pea     (TIME_$FAST_CLOCK_EC:w,%pc)     | e2b1c2  487a ff04
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH    | e2b1c6  4eb9 00e2 0718
        addq.l  #4,%sp                          | e2b1cc  588f
        addi.w  #0x1047,(TIME_$CLOCKL).l        | e2b1ce  0679 1047 00e2 b0e0
        bcs.s   .Le2b1de                        | e2b1d6  6506
        jmp     PROC1_$INT_EXIT                 | e2b1d8  4ef9 00e2 08fe
.Le2b1de:
        lea     (TIME_$CURRENT_DELTA+4:w,%pc),%a0| e2b1de  41fa ff20
        subq.w  #1,(%a0)                        | e2b1e2  5350
        bne.s   .Le2b1f6                        | e2b1e4  6610
        move.w  #2,(%a0)                        | e2b1e6  30bc 0002
        .if mcr_change_low_bits
        move.w  #0x10f,-(%sp)                   | sau4 f82d89e  3f3c 010f
        .elseif mcr_change_bit_0
        move.w  #1,-(%sp)                       | sau6 7802e6e6  3f3c 0001
        .else
        move.w  #7,-(%sp)                       | e2b1ea  3f3c 0007
        .endif
        jsr     MMU_$MCR_CHANGE                 | e2b1ee  4eb9 00e2 42a0
        addq.l  #2,%sp                          | e2b1f4  548f
.Le2b1f6:
        lea     (TIME_$CLOCKH:w,%pc),%a0        | e2b1f6  41fa fedc
        jmp     PROC1_$INT_ADVANCE              | e2b1fa  4ef9 00e2 08f6
.Le2b200:
        btst    #1,%d0                          | e2b200  0800 0001
        beq.s   .Le2b238                        | e2b204  6732
        moveq   #-1,%d1                         | e2b206  72ff
        movep.w %d1,(0x9,%a0)                   | e2b208  0388 0009
        tst.b   (IN_VT_INT).l                   | e2b20c  4a39 00e2 af6a
        bne.s   .Le2b232                        | e2b212  661e
        st      (IN_VT_INT).l                   | e2b214  50f9 00e2 af6a
        pea     (TIME_$DI_VT:w,%pc)             | e2b21a  487a fef2
        clr.l   -(%sp)                          | e2b21e  42a7
        pea     (TIME_$VT_INT).l                | e2b220  4879 00e1 63e4
        jsr     DI_$ENQ                         | e2b226  4eb9 00e2 09a8
        adda.l  #0xc,%sp                        | e2b22c  dffc 0000 000c
.Le2b232:
        jmp     PROC1_$INT_EXIT                 | e2b232  4ef9 00e2 08fe
.Le2b238:
        btst    #2,%d0                          | e2b238  0800 0002
        beq.s   .Le2b270                        | e2b23c  6732
        moveq   #-1,%d1                         | e2b23e  72ff
        movep.w %d1,(0xd,%a0)                   | e2b240  0388 000d
        tst.b   (IN_RT_INT).l                   | e2b244  4a39 00e2 af6b
        bne.s   .Le2b26a                        | e2b24a  661e
        st      (IN_RT_INT).l                   | e2b24c  50f9 00e2 af6b
        pea     (TIME_$DI_RTE:w,%pc)            | e2b252  487a feca
        clr.l   -(%sp)                          | e2b256  42a7
        pea     (TIME_$RTE_INT).l               | e2b258  4879 00e1 63a6
        jsr     DI_$ENQ                         | e2b25e  4eb9 00e2 09a8
        adda.l  #0xc,%sp                        | e2b264  dffc 0000 000c
.Le2b26a:
        jmp     PROC1_$INT_EXIT                 | e2b26a  4ef9 00e2 08fe
.Le2b270:
        jsr     IO_$COND_SWITCH_BACK            | e2b270  4eb9 00e2 e846
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | e2b276  4cdf 0303
        jmp     FIM_$SPURIOUS_INT               | e2b27a  4ef9 00e2 1f20
        .endif  /* timer_int_pic */

        .endif
