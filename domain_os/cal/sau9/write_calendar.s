/*
 * cal/sau9/write_calendar.s - CAL_$WRITE_CALENDAR for the indexed
 * real-time clock (SAU9)
 *
 * SAU9 map: "D 3C499DD0 OS_CAL_ASM size = 1A0" (.DATA): CAL_$WRITE_CALENDAR
 * from 0x3C499DD0 to CAL_$SEC_TO_CLOCK (0x3C499EE0), 0x110 bytes; the rest
 * of the segment, CAL_$SEC_TO_CLOCK .. CAL_$CLOCK_TO_SEC, is the SAU2's
 * code (cal/m68k/os_cal_asm.s).
 *
 * The SAU9's calendar (`calendar_indexed_rtc', base/config.ins.pas) is a
 * clock chip of numbered registers: a register is selected by writing
 * its number to CAL (0x3FF9F280) and read or written at CAL + 4.  The
 * routine (its seven arguments by address, as on the SAU2: year, month,
 * day, weekday, hour, minute, second, cal/cal.ins.pas):
 *   - register 10 = 0x40, 13 = 0, 10 = 0x20 (the oscillator and its
 *     divider; register 13 cleared), then waits (at most 1001 reads) for
 *     bit 7 of register 10 (update in progress) to clear;
 *   - register 11 = 0x86 (SET: the clock stopped, binary, 24-hour);
 *   - register 9 = year mod 100, 8 = month, 7 = day of month, 6 = the
 *     weekday, 4 = hours, 2 = minutes, 0 = seconds, as binary values (no
 *     BCD, no inversion);
 *   - register 11 = 6 (SET released: binary, 24-hour).
 * A delay helper follows the routine, which nothing calls (the SAU2's
 * strobe delay, 0x28 + 1 turns).
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU9 image's.
 */

        .section ".text.CAL_$WRITE_CALENDAR","ax",@progbits
        .even

        .globl  CAL_$WRITE_CALENDAR

        .extern CAL                     /* arch/m68k/sau9/iodefs.s: the register select */
        .set    CAL_DATA, CAL + 4       /* the selected register */

CAL_$WRITE_CALENDAR:
        movem.l %d2-%d7,-(%sp)                  | 3c499dd0  48e7 3f00
        move.b  #10,(CAL).l                     | 3c499dd4  13fc 000a 3ff9 f280
        move.b  #0x40,(CAL_DATA).l              | 3c499ddc  13fc 0040 3ff9 f284
        move.b  #13,(CAL).l                     | 3c499de4  13fc 000d 3ff9 f280
        move.b  #0,(CAL_DATA).l                 | 3c499dec  13fc 0000 3ff9 f284
        move.b  #10,(CAL).l                     | 3c499df4  13fc 000a 3ff9 f280
        move.b  #0x20,(CAL_DATA).l              | 3c499dfc  13fc 0020 3ff9 f284
        move.w  #1000,%d5                       | 3c499e04  3a3c 03e8
.Lwait_update:
        move.b  (CAL_DATA).l,%d0                | 3c499e08  1039 3ff9 f284
        btst    #7,%d0                          | 3c499e0e  0800 0007  update in progress?
        beq.b   .Lset                           | 3c499e12  6704
        dbf     %d5,.Lwait_update               | 3c499e14  51cd fff2
.Lset:
        move.b  #11,(CAL).l                     | 3c499e18  13fc 000b 3ff9 f280
        move.b  #0x86,(CAL_DATA).l              | 3c499e20  13fc 0086 3ff9 f284  SET
        movea.l (28,%sp),%a0                    | 3c499e28  206f 001c  the year
        move.w  (%a0),%d1                       | 3c499e2c  3210
        ext.l   %d1                             | 3c499e2e  48c1
        divu.w  #100,%d1                        | 3c499e30  82fc 0064
        swap    %d1                             | 3c499e34  4841  year mod 100
        move.w  %d1,%d2                         | 3c499e36  3401
        move.b  #9,(CAL).l                      | 3c499e38  13fc 0009 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499e40  13c1 3ff9 f284
        movea.l (32,%sp),%a0                    | 3c499e46  206f 0020  the month
        move.w  (%a0),%d1                       | 3c499e4a  3210
        move.w  %d1,%d3                         | 3c499e4c  3601
        move.b  #8,(CAL).l                      | 3c499e4e  13fc 0008 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499e56  13c1 3ff9 f284
        movea.l (36,%sp),%a0                    | 3c499e5c  206f 0024  the day
        move.w  (%a0),%d1                       | 3c499e60  3210
        move.b  #7,(CAL).l                      | 3c499e62  13fc 0007 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499e6a  13c1 3ff9 f284
        movea.l (40,%sp),%a0                    | 3c499e70  206f 0028  the weekday
        move.w  (%a0),%d1                       | 3c499e74  3210
        move.b  #6,(CAL).l                      | 3c499e76  13fc 0006 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499e7e  13c1 3ff9 f284
        movea.l (44,%sp),%a0                    | 3c499e84  206f 002c  the hour
        move.w  (%a0),%d1                       | 3c499e88  3210
        move.b  #4,(CAL).l                      | 3c499e8a  13fc 0004 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499e92  13c1 3ff9 f284
        movea.l (48,%sp),%a0                    | 3c499e98  206f 0030  the minute
        move.w  (%a0),%d1                       | 3c499e9c  3210
        move.b  #2,(CAL).l                      | 3c499e9e  13fc 0002 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499ea6  13c1 3ff9 f284
        movea.l (52,%sp),%a0                    | 3c499eac  206f 0034  the second
        move.w  (%a0),%d1                       | 3c499eb0  3210
        move.b  #0,(CAL).l                      | 3c499eb2  13fc 0000 3ff9 f280
        move.b  %d1,(CAL_DATA).l                | 3c499eba  13c1 3ff9 f284
        move.b  #11,(CAL).l                     | 3c499ec0  13fc 000b 3ff9 f280
        move.b  #6,(CAL_DATA).l                 | 3c499ec8  13fc 0006 3ff9 f284  SET released
        movem.l (%sp)+,%d2-%d7                  | 3c499ed0  4cdf 00fc
        rts                                     | 3c499ed4  4e75

/* not referenced: a delay of 0x28 + 1 turns */
        move.w  #0x28,%d5                       | 3c499ed6  3a3c 0028
.Ldelay:
        subq.w  #1,%d5                          | 3c499eda  5345
        bge.b   .Ldelay                         | 3c499edc  6cfc
        rts                                     | 3c499ede  4e75
