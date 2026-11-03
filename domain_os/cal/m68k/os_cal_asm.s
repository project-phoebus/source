/*
 * cal/m68k/os_cal_asm.s - the OS_CAL_ASM segment: CAL_$WRITE_CALENDAR,
 * CAL_$SEC_TO_CLOCK, CAL_$DAYS_PER_MONTH and CAL_$CLOCK_TO_SEC
 * (m68k/SAU2, SAU3, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here except where
 * CAL_$WRITE_CALENDAR reaches the MSM5832 calendar, which the SAU5 does
 * through a word port at CALENDAR + 0x200 (base/config.ins.pas's part
 * `calendar_word_port', as TIME_$READ_CAL in time/m68k/time_asm.s): the
 * control byte at +0x200 for HOLD, and each digit written as one word
 * (the register select in the high byte, the digit uninverted in the
 * low) with the strobe bit 0x200 set and cleared, where the SAU2 writes
 * the inverted digit at +0x22 and the select and strobe bytes at +0x20.
 * The SAU9's calendar is another chip (`calendar_indexed_rtc'): its
 * CAL_$WRITE_CALENDAR is cal/sau9/write_calendar.s, and the routines
 * after it are this file's (SAU9 0x3C499EE0 on).  The SAU8's chip has its
 * registers in the calendar page's bytes (`calendar_mapped_rtc'): its
 * CAL_$WRITE_CALENDAR (`D 3C9A1BC OS_CAL_ASM size = 120', 0x90 bytes) is
 * the arm below, with the SAU8 image's addresses.
 * The SAU5's segment (`D E8899C OS_CAL_ASM size = 16C') is 4 bytes
 * shorter: CAL_$SEC_TO_CLOCK and the rest are at the SAU2's offsets less
 * 4.  The address and byte columns are the SAU2 image's, except on the
 * lines of the `.if calendar_word_port' arm, which carry the SAU5 image's.
 *
 * The SAU3's CAL_$WRITE_CALENDAR writes the calendar whether or not the
 * node is diskless (`calendar_write_unconditional': no test of
 * NETWORK_$REALLY_DISKLESS, 10 bytes), and reaches the chip at the start
 * of its own page (`calendar_own_page', as in time/m68k/time_asm.s:
 * control CALENDAR + 0, data + 2; the map's CALENDAR 0xFFA400).  Its
 * segment (`D E82D9C OS_CAL_ASM size = 164') ends with CAL_$CLOCK_TO_SEC:
 * the zero word after it, which ends the SAU2's and SAU5's segments on a
 * longword, is not there (0xE82F00 is one).
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image; address operands resolve to our objects.
 *
 * SAU2 map: "D E8167C OS_CAL_ASM size = 170" (.DATA), 0x00E8167C..
 * 0x00E817EB, PACCT following at 0xE817EC.  Hand-written routines and a
 * table in a data segment (the `_ASM' segment name; no `link',
 * arguments read off SP, register-passed nested helpers):
 *
 *   0xE8167C  CAL_$WRITE_CALENDAR   0xE0 bytes, with its local helpers
 *                                   (digit pair 0xE81704, digit 0xE81716,
 *                                   finish 0xE81744, delays 0xE81752 and
 *                                   0xE81756)
 *   0xE8175C  CAL_$SEC_TO_CLOCK     0x50 bytes
 *   0xE817AC  CAL_$DAYS_PER_MONTH   twelve words
 *   0xE817C4  CAL_$CLOCK_TO_SEC     0x26 bytes, then a zero word to the
 *                                   segment's end
 *
 * The headings Pascal callers use are cal/cal.ins.pas's.  Each map symbol
 * starts a section of its own, keyed by it.
 *
 * Operands written as symbols:
 *   0x00E24C4A  NETWORK_$REALLY_DISKLESS (map symbol in NETWORK's block)
 *   0x00FFA820  CALENDAR + 0x20, the MSM5832 calendar chip's control
 *               register (the map's IODEFS symbol CALENDAR 0xFFA800,
 *               with FLOP, DISK and WIN at the same address)
 *   0x00FFA822  CALENDAR + 0x22, its data register
 *
 * The Apollo assembler's <ea>=#imm forms (cmp/and/add/or/sub #imm,Dn,
 * opcodes b67c, b47c, c47c, d27c, 8a3c, 907c), which gas spells as
 * cmpi/andi/addi/ori/subi, are written as `.short'.
 */

/* ------------------------------------------------------------------------
 * CAL_$WRITE_CALENDAR(in year, month, day, weekday, hour, minute, second:
 *                     integer)
 *
 * Writes the calendar chip's thirteen digit registers from the year's
 * tens digit down to the seconds' units, unless NETWORK_$REALLY_DISKLESS
 * is set.  D0 holds the control byte: 0xC1 (register 12 with HOLD) to
 * start, lowered by 0x10, one register, after each digit (the digit
 * routine's `sub.w #0x10,D0w').  The year is reduced mod 100; the day's
 * tens digit gets 8 added (`add.w #0x50' before the split) when the year,
 * plus one after February with 100 wrapping to 0, is a multiple of 4; the
 * hour's tens digit gets 8 too (the chip's 24-hour bit).  D5 is the delay
 * count (0xC8 first, 0x28 between the strobes).
 * ------------------------------------------------------------------------ */
        .include "base/config.inc"

        /* the calendar's control register, as an offset in its page */
        .if calendar_word_port
        .set    CAL_CTL, 0x200                  /* sau5: the word port */
        .elseif calendar_own_page
        .set    CAL_CTL, 0                      /* sau3: the page's start */
        .set    CAL_WDATA, 2
        .else
        .set    CAL_CTL, 0x20
        .set    CAL_WDATA, 0x22
        .endif

        .if !calendar_indexed_rtc
        .section ".text.CAL_$WRITE_CALENDAR","ax",@progbits
        .even

        .globl  CAL_$WRITE_CALENDAR
CAL_$WRITE_CALENDAR:
        movem.l %d2-%d7,-(%sp)                  /* e8167c  48e7 3f00 */
        .if calendar_mapped_rtc
        /* sau8: the clock chip's registers are the bytes of the calendar
           page.  Register 10 (divider 16#20) is written, its update bit
           (7) waited out for up to 1001 turns, register 11 set to 16#86
           (SET, binary, 24 hours); the year mod 100, month, day and
           weekday go to registers 9..6, the hour to 4, the minute to 2
           and the second to 0, written downward from register 10; then
           register 11 = 6 (binary, 24 hours) lets the clock run. */
        move.b  #0x20,(CALENDAR+10).l           /* sau8 3c9a1c0  13fc 0020 03ff ad0a */
        move.w  #1000,%d5                       /* sau8 3c9a1c8  3a3c 03e8 */
.Lrtc_uip:
        move.b  (CALENDAR+10).l,%d0             /* sau8 3c9a1cc  1039 03ff ad0a */
        btst    #7,%d0                          /* sau8 3c9a1d2  0800 0007 */
        beq.s   .Lrtc_set                       /* sau8 3c9a1d6  6704 */
        dbf     %d5,.Lrtc_uip                   /* sau8 3c9a1d8  51cd fff2 */
.Lrtc_set:
        move.b  #0x86,(CALENDAR+11).l           /* sau8 3c9a1dc  13fc 0086 03ff ad0b */
        lea     (CALENDAR+10).l,%a1             /* sau8 3c9a1e4  43f9 03ff ad0a */
        movea.l (0x1c,%sp),%a0                  /* sau8 3c9a1ea  206f 001c  year */
        move.w  (%a0),%d1                       /* sau8 3c9a1ee  3210 */
        ext.l   %d1                             /* sau8 3c9a1f0  48c1 */
        divu.w  #100,%d1                        /* sau8 3c9a1f2  82fc 0064 */
        swap    %d1                             /* sau8 3c9a1f6  4841  year mod 100 */
        move.w  %d1,%d2                         /* sau8 3c9a1f8  3401 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a1fa  1301  register 9 */
        movea.l (0x20,%sp),%a0                  /* sau8 3c9a1fc  206f 0020  month */
        move.w  (%a0),%d1                       /* sau8 3c9a200  3210 */
        move.w  %d1,%d3                         /* sau8 3c9a202  3601 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a204  1301  register 8 */
        movea.l (0x24,%sp),%a0                  /* sau8 3c9a206  206f 0024  day */
        move.w  (%a0),%d1                       /* sau8 3c9a20a  3210 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a20c  1301  register 7 */
        movea.l (0x28,%sp),%a0                  /* sau8 3c9a20e  206f 0028  weekday */
        move.w  (%a0),%d1                       /* sau8 3c9a212  3210 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a214  1301  register 6 */
        subq.l  #1,%a1                          /* sau8 3c9a216  5389 */
        movea.l (0x2c,%sp),%a0                  /* sau8 3c9a218  206f 002c  hour */
        move.w  (%a0),%d1                       /* sau8 3c9a21c  3210 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a21e  1301  register 4 */
        subq.l  #1,%a1                          /* sau8 3c9a220  5389 */
        movea.l (0x30,%sp),%a0                  /* sau8 3c9a222  206f 0030  minute */
        move.w  (%a0),%d1                       /* sau8 3c9a226  3210 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a228  1301  register 2 */
        subq.l  #1,%a1                          /* sau8 3c9a22a  5389 */
        movea.l (0x34,%sp),%a0                  /* sau8 3c9a22c  206f 0034  second */
        move.w  (%a0),%d1                       /* sau8 3c9a230  3210 */
        move.b  %d1,-(%a1)                      /* sau8 3c9a232  1301  register 0 */
        move.b  #6,(CALENDAR+11).l              /* sau8 3c9a234  13fc 0006 03ff ad0b */
        movem.l (%sp)+,%d2-%d7                  /* sau8 3c9a23c  4cdf 00fc */
        rts                                     /* sau8 3c9a240  4e75 */
        /* a delay loop no code reaches (the other form's .Ldelay40) */
        move.w  #0x28,%d5                       /* sau8 3c9a242  3a3c 0028 */
.Lrtc_delay:
        subq.w  #1,%d5                          /* sau8 3c9a246  5345 */
        bge.s   .Lrtc_delay                     /* sau8 3c9a248  6cfc */
        rts                                     /* sau8 3c9a24a  4e75 */
        .else
        .if !calendar_write_unconditional
        tst.b   (NETWORK_$REALLY_DISKLESS).l    /* e81680  4a39 00e2 4c4a */
        bne.w   .Lexit                          /* e81686  6600 00c4 */
        .endif
        move.w  #0xc1,%d0                       /* e8168a  303c 00c1 */
        move.b  #1,(CALENDAR+CAL_CTL).l         /* e8168e  13fc 0001 00ff a820 */
        move.w  #0xc8,%d5                       /* e81696  3a3c 00c8 */
        bsr.w   .Ldelay                         /* e8169a  6100 00ba */
        movea.l (0x1c,%sp),%a0                  /* e8169e  206f 001c  year */
        move.w  (%a0),%d1                       /* e816a2  3210 */
        ext.l   %d1                             /* e816a4  48c1 */
        divu.w  #100,%d1                        /* e816a6  82fc 0064 */
        swap    %d1                             /* e816aa  4841  year mod 100 */
        move.w  %d1,%d2                         /* e816ac  3401 */
        bsr.b   .Lpair                          /* e816ae  6154 */
        movea.l (0x20,%sp),%a0                  /* e816b0  206f 0020  month */
        move.w  (%a0),%d1                       /* e816b4  3210 */
        move.w  %d1,%d3                         /* e816b6  3601 */
        bsr.b   .Lpair                          /* e816b8  614a */
        movea.l (0x24,%sp),%a0                  /* e816ba  206f 0024  day */
        move.w  (%a0),%d1                       /* e816be  3210 */
        .short  0xb67c, 0x0002                  /* e816c0  cmp.w #2,%d3 (<ea>=#imm form; gas: cmpi) */
        ble.b   .Lleap                          /* e816c4  6f0a */
        addq.w  #1,%d2                          /* e816c6  5242 */
        .short  0xb47c, 0x0064                  /* e816c8  cmp.w #100,%d2 (<ea>=#imm form; gas: cmpi) */
        blt.b   .Lleap                          /* e816cc  6d02 */
        clr.w   %d2                             /* e816ce  4242 */
.Lleap:
        .short  0xc47c, 0x0003                  /* e816d0  and.w #3,%d2 (<ea>=#imm form; gas: andi) */
        bne.b   .Lday                           /* e816d4  6604 */
        .short  0xd27c, 0x0050                  /* e816d6  add.w #0x50,%d1 (<ea>=#imm form; gas: addi) */
.Lday:
        bsr.b   .Lpair                          /* e816da  6128 */
        movea.l (0x28,%sp),%a0                  /* e816dc  206f 0028  weekday */
        move.w  (%a0),%d1                       /* e816e0  3210 */
        bsr.b   .Ldigit                         /* e816e2  6132 */
        movea.l (0x2c,%sp),%a0                  /* e816e4  206f 002c  hour */
        move.w  (%a0),%d1                       /* e816e8  3210 */
        .short  0xd27c, 0x0050                  /* e816ea  add.w #0x50,%d1 (<ea>=#imm form; gas: addi) */
        bsr.b   .Lpair                          /* e816ee  6114 */
        movea.l (0x30,%sp),%a0                  /* e816f0  206f 0030  minute */
        move.w  (%a0),%d1                       /* e816f4  3210 */
        bsr.b   .Lpair                          /* e816f6  610c */
        movea.l (0x34,%sp),%a0                  /* e816f8  206f 0034  second */
        move.w  (%a0),%d1                       /* e816fc  3210 */
        bsr.b   .Lpair                          /* e816fe  6104 */
        bra.w   .Lfinish                        /* e81700  6000 0042 */

/* 0xE81704: write D1 (0..99) as two digits, tens first. */
.Lpair:
        ext.l   %d1                             /* e81704  48c1 */
        divu.w  #10,%d1                         /* e81706  82fc 000a */
        move.l  %d1,%d4                         /* e8170a  2801 */
        bsr.b   .Ldigit                         /* e8170c  6108  tens */
        swap    %d4                             /* e8170e  4844 */
        move.w  %d4,%d1                         /* e81710  3204 */
        bsr.b   .Ldigit                         /* e81712  6102  units */
        rts                                     /* e81714  4e75 */

/* 0xE81716: write the digit in D1 to the register D0 selects (the data
   inverted), strobe it, and step D0 to the next register. */
.Ldigit:
        .if calendar_word_port
        move.w  %d0,%d6                         /* sau5 e88a36  3c00 */
        lsl.w   #8,%d6                          /* sau5 e88a38  e14e: the select high */
        or.b    %d1,%d6                         /* sau5 e88a3a  8c01: the digit low */
        move.w  %d6,(CALENDAR+CAL_CTL).l        /* sau5 e88a3c  33c6 00ff aa00 */
        bsr.b   .Ldelay40                       /* sau5 e88a42  612a */
        move.w  %d6,%d7                         /* sau5 e88a44  3e06 */
        .short  0x8e7c, 0x0200                  /* sau5 e88a46  or.w #0x200,%d7 (<ea>=#imm form; gas: ori) */
        move.w  %d7,(CALENDAR+CAL_CTL).l        /* sau5 e88a4a  33c7 00ff aa00: strobe */
        bsr.b   .Ldelay40                       /* sau5 e88a50  611c */
        move.w  %d6,(CALENDAR+CAL_CTL).l        /* sau5 e88a52  33c6 00ff aa00 */
        bsr.b   .Ldelay40                       /* sau5 e88a58  6114 */
        .else
        not.b   %d1                             /* e81716  4601 */
        move.b  %d1,(CALENDAR+CAL_WDATA).l      /* e81718  13c1 00ff a822 */
        move.b  %d0,(CALENDAR+CAL_CTL).l        /* e8171e  13c0 00ff a820 */
        bsr.b   .Ldelay40                       /* e81724  612c */
        move.b  %d0,%d5                         /* e81726  1a00 */
        .short  0x8a3c, 0x0002                  /* e81728  or.b #2,%d5 (<ea>=#imm form; gas: ori) */
        move.b  %d5,(CALENDAR+CAL_CTL).l        /* e8172c  13c5 00ff a820 */
        bsr.b   .Ldelay40                       /* e81732  611e */
        move.b  %d0,(CALENDAR+CAL_CTL).l        /* e81734  13c0 00ff a820 */
        bsr.w   .Ldelay40                       /* e8173a  6100 0016 */
        .endif
        .short  0x907c, 0x0010                  /* e8173e  sub.w #0x10,%d0 (<ea>=#imm form; gas: subi) */
        rts                                     /* e81742  4e75 */

/* 0xE81744: release HOLD and return. */
.Lfinish:
        move.b  #0,(CALENDAR+CAL_CTL).l         /* e81744  13fc 0000 00ff a820 */
.Lexit:
        movem.l (%sp)+,%d2-%d7                  /* e8174c  4cdf 00fc */
        rts                                     /* e81750  4e75 */

/* 0xE81752: delay 0x28 + 1 turns; 0xE81756: D5 + 1 turns. */
.Ldelay40:
        move.w  #0x28,%d5                       /* e81752  3a3c 0028 */
.Ldelay:
        subq.w  #1,%d5                          /* e81756  5345 */
        bge.b   .Ldelay                         /* e81758  6cfc */
        rts                                     /* e8175a  4e75 */
        .endif  /* calendar_mapped_rtc */

        .endif

/* ------------------------------------------------------------------------
 * CAL_$SEC_TO_CLOCK(in sec: linteger; out clock: time_$clock_t)
 *
 * clock := sec * 250000 (0x3D090, the clock's 4-microsecond ticks), as a
 * 48-bit product of the seconds' magnitude built from four `mulu.w's by
 * 3 and 0xD090 (the multiplier's high and low words), negated with
 * `neg.l'/`negx.w' when the seconds were negative.  The clock is a high
 * longword and a low word (time/time.ins.pas).
 * ------------------------------------------------------------------------ */
        .section ".text.CAL_$SEC_TO_CLOCK","ax",@progbits
        .even

        .globl  CAL_$SEC_TO_CLOCK
CAL_$SEC_TO_CLOCK:
        movem.l %d2-%d3,-(%sp)                  /* e8175c  48e7 3000 */
        clr.w   %d3                             /* e81760  4243  negative := false */
        movea.l (0xc,%sp),%a0                   /* e81762  206f 000c  &sec */
        move.l  (%a0),%d0                       /* e81766  2010 */
        bge.b   .Lpositive                      /* e81768  6c04 */
        neg.l   %d0                             /* e8176a  4480 */
        moveq   #1,%d3                          /* e8176c  7601 */
.Lpositive:
        movea.l (0x10,%sp),%a0                  /* e8176e  206f 0010  &clock */
        move.w  %d0,%d2                         /* e81772  3400 */
        mulu.w  #0xd090,%d2                     /* e81774  c4fc d090 */
        move.w  %d2,(0x4,%a0)                   /* e81778  3142 0004  low word */
        clr.w   %d2                             /* e8177c  4242 */
        swap    %d2                             /* e8177e  4842 */
        move.w  %d0,%d1                         /* e81780  3200 */
        mulu.w  #3,%d1                          /* e81782  c2fc 0003 */
        add.l   %d1,%d2                         /* e81786  d481 */
        swap    %d0                             /* e81788  4840 */
        move.w  %d0,%d1                         /* e8178a  3200 */
        mulu.w  #0xd090,%d1                     /* e8178c  c2fc d090 */
        add.l   %d1,%d2                         /* e81790  d481 */
        move.l  %d2,(%a0)                       /* e81792  2082 */
        mulu.w  #3,%d0                          /* e81794  c0fc 0003 */
        add.w   (%a0),%d0                       /* e81798  d050 */
        move.w  %d0,(%a0)                       /* e8179a  3080 */
        tst.b   %d3                             /* e8179c  4a03 */
        beq.b   .Ldone                          /* e8179e  6706 */
        neg.l   (0x2,%a0)                       /* e817a0  44a8 0002 */
        negx.w  (%a0)                           /* e817a4  4050 */
.Ldone:
        movem.l (%sp)+,%d2-%d3                  /* e817a6  4cdf 000c */
        rts                                     /* e817aa  4e75 */

/* ------------------------------------------------------------------------
 * CAL_$DAYS_PER_MONTH: twelve words, January to December, February 29
 * (`gsk read 0xe817ac 0x18').  CAL_$DECODE_TIME copies them from
 * `movea.l #0xe817ac,A0' (0xE68748).
 * ------------------------------------------------------------------------ */
        .section ".text.CAL_$DAYS_PER_MONTH","ax",@progbits
        .even

        .globl  CAL_$DAYS_PER_MONTH
CAL_$DAYS_PER_MONTH:
        .word   31, 29, 31, 30, 31, 30          /* e817ac */
        .word   31, 31, 30, 31, 30, 31          /* e817b8 */

/* ------------------------------------------------------------------------
 * CAL_$CLOCK_TO_SEC(in clock: time_$clock_t): linteger
 *
 * The clock divided by 250000: both 48-bit halves shifted right 4 and
 * divided by 15625 (0x3D09) with `divu.w', the first quotient the
 * result's high word and the second (of the first remainder's word and
 * the next sixteen bits) its low word.
 * ------------------------------------------------------------------------ */
        .section ".text.CAL_$CLOCK_TO_SEC","ax",@progbits
        .even

        .globl  CAL_$CLOCK_TO_SEC
CAL_$CLOCK_TO_SEC:
        move.l  %d2,-(%sp)                      /* e817c4  2f02 */
        movea.l (0x8,%sp),%a0                   /* e817c6  206f 0008  &clock */
        move.l  (%a0),%d0                       /* e817ca  2010 */
        lsr.l   #4,%d0                          /* e817cc  e888 */
        divu.w  #0x3d09,%d0                     /* e817ce  80fc 3d09 */
        move.w  %d0,%d1                         /* e817d2  3200  high quotient */
        move.l  (0x2,%a0),%d2                   /* e817d4  2428 0002 */
        lsr.l   #4,%d2                          /* e817d8  e88a */
        move.w  %d2,%d0                         /* e817da  3002 */
        divu.w  #0x3d09,%d0                     /* e817dc  80fc 3d09 */
        swap    %d0                             /* e817e0  4840 */
        move.w  %d1,%d0                         /* e817e2  3001 */
        swap    %d0                             /* e817e4  4840 */
        move.l  (%sp)+,%d2                      /* e817e6  241f */
        rts                                     /* e817e8  4e75 */
        .if !calendar_write_unconditional
        .word   0                               /* e817ea: to the segment's end */
        .endif
