{ cal/cal.ins.pas - the 48-bit clock arithmetic, the CAL_ routines, for
  the Domain Pascal tree.

  What the Pascal files use.  The declarations are Apollo's where the
  customer cal.ins.pas of SR10.2 has them (sr10.2-install/install/
  ri.apollo.os.v.10.2/sys/ins/cal.ins.pas): the statuses, the timezone
  record, the date record, the weekday enumeration and the user
  routines' headings, checked against the image.  The kernel's own are
  written from the image.

  The CAL routines are two compiled map modules, OS_CAL_WIRED
  (cal/os_cal_wired.pas, with the data block) and OS_CAL_UNWIRED
  (cal/os_cal_unwired.pas), and the hand assembly of OS_CAL_ASM and of
  TIME_ASM (ADD48, SUB48).  Include base/base.ins.pas before it.
}

const
  { Apollo's (cal.ins.pas).  CAL_$WRITE_TIMEZONE stores the first for a
    name character out of range; CAL_$VERIFY the second when the
    operator refuses the calendar. }
  cal_$out_of_range = 16#00150002;
  cal_$refused      = 16#00150007;

  { Apollo's. }
  cal_$string_size = 80;

type
  { Apollo's (cal.ins.pas). }
  cal_$string_t = array[1..cal_$string_size] of char;

  cal_$tz_name_t = array[1..4] of char;   { timezone name }

  { Apollo's, returned from cal_$decode_time: six words, year at 0 to
    second at 0xA.  CAL_$DECODE_TIME stores second, minute and hour at
    +0xA, +0x8, +0x6, the year at +0, the month, the day at +0x2, +0x4. }
  cal_$timedate_rec_t = packed record
    year: integer;
    month: integer;
    day: integer;
    hour: integer;
    minute: integer;
    second: integer;
  end;

  { Apollo's.  CAL_$WEEKDAY's jump table maps 0..6 to these in order. }
  cal_$weekday_t = (cal_$sun, cal_$mon, cal_$tue, cal_$wed, cal_$thu,
                    cal_$fri, cal_$sat);

  { Apollo's, under its `%if isp_$m68k or isp_$a88k' arm: 12 bytes, the
    drift at 6 (CAL_$SET_DRIFT's six-byte store; the three-longword
    copies of CAL_$GET_INFO, CAL_$READ_TIMEZONE). }
  cal_$timezone_rec_t = packed record
    utc_delta: integer;                   { # minutes from UTC }
    tz_name: cal_$tz_name_t;              { timezone name }
    drift: [aligned(1)] time_$clock_t;    { drift adjustment made by user }
  end;

var
  { CAL_$TIMEZONE, CAL_$LAST_VALID_TIME (map symbols, the first two
    objects of the map's OS_CAL_WIRED data segment, 0x14 bytes, in
    .DATA; defined by cal/os_cal_wired.pas).  The OS_CAL_WIRED routines
    reach them through A5; the OS_CAL_UNWIRED ones, with other units
    (OS_$INIT, ASKNODE), by their absolute addresses.  The last valid
    time is a copy of the label's mount time, TIME_$CLOCKH's high word
    (bat/bat.ins.pas last_valid_time).  The names are the map's, the
    types Apollo's and the label's. }
  cal_$timezone: extern cal_$timezone_rec_t;
  cal_$last_valid_time: extern time_$clockh_t;

  { CAL_$BOOT_VOLX (map symbol in CAL's block): the boot volume's index,
    a word (VOLX_$DISMOUNT compares a word with it). }
  cal_$boot_volx: extern integer;

  { CAL_$DAYS_PER_MONTH (map symbol, inside the map's OS_CAL_ASM data
    segment, 0x170 bytes, between the code of CAL_$SEC_TO_CLOCK and
    CAL_$CLOCK_TO_SEC: hand-written data): twelve words, 31 29 31 30 31
    30 31 31 30 31 30 31.  CAL_$DECODE_TIME copies them word by word.
    The bounds 1..12 are the copy loop's (cal/os_cal_unwired.pas,
    decode_time.pas). }
  cal_$days_per_month: extern array[1..12] of integer;

{ ADD48 (hand assembly, in the map's TIME_ASM code segment, with SUB48):
  adds one 48-bit clock to another in place, with no frame, its
  arguments read off the stack, both by address.  No result: D0 holds
  the low word of the source. }
procedure add48(in out dst: time_$clock_t; in src: time_$clock_t); extern;

{ SUB48 (hand assembly, TIME_ASM): subtracts one 48-bit clock from
  another in place, both arguments by address off the stack.  The
  result, D0's byte, is true when the difference is not negative. }
function sub48(in out dst: time_$clock_t; in src: time_$clock_t): boolean;
  extern;

{ The compiled routines, in map order.  Every CAL_ routine but
  CAL_$VERIFY and CAL_$SHUTDOWN is user callable, under the default
  convention; the headings of the user routines are Apollo's. }

{ CAL_$READ_TIMEZONE - load the timezone record from the boot volume
  label. }
procedure cal_$read_timezone(out tz_out: cal_$timezone_rec_t;
                             out status: status_$t);
  extern;

{ CAL_$WRITE_TIMEZONE - install a timezone record and write it to the boot
  volume label. }
procedure cal_$write_timezone(in tz_rec: cal_$timezone_rec_t;
                              out status: status_$t);
  extern;

{ CAL_$SHUTDOWN - stamp the boot volume's label with the time at shutdown. }
procedure cal_$shutdown(out status: status_$t); extern;

{ CAL_$VERIFY - check the calendar against the label's last valid time. }
function cal_$verify(in max_delta: integer32; in msg_arg: univ cal_$string_t;
                     in interactive: boolean; out status_ret: status_$t):
                     boolean;
  extern;

{ CAL_$GET_INFO - return a copy of the timezone record. }
procedure cal_$get_info(out tz_rec: cal_$timezone_rec_t); extern;

{ CAL_$SET_DRIFT - set the calendar's drift correction. }
procedure cal_$set_drift(in drift: time_$clock_t); extern;

{ CAL_$GET_LOCAL_TIME - the clock with the local offset and the drift. }
procedure cal_$get_local_time(out clock: time_$clock_t); extern;

{ CAL_$APPLY_LOCAL_OFFSET - add the local timezone offset to a clock.
  CAL_$REMOVE_LOCAL_OFFSET - subtract the local timezone offset from a
  clock. }
procedure cal_$apply_local_offset(in out clock: time_$clock_t); extern;
procedure cal_$remove_local_offset(in out clock: time_$clock_t); extern;

{ CAL_$WEEKDAY - the day of the week of a date. }
function cal_$weekday(in year: integer; in month: integer; in day: integer):
                      cal_$weekday_t;
  extern;

{ CAL_$DECODE_TIME - a 48-bit clock to year, month, day, hour, minute and
  second. }
procedure cal_$decode_time(in clock: time_$clock_t;
                           out clockh_rec: cal_$timedate_rec_t);
  extern;

{ CAL_$SEC_TO_CLOCK (hand assembly in the map's OS_CAL_ASM segment, the
  arguments read off the stack): Apollo's heading; the seconds by
  address, the clock written. }
procedure cal_$sec_to_clock(in sec: linteger; out clock: time_$clock_t);
  extern;

{ CAL_$CLOCK_TO_SEC (hand assembly in .DATA, the argument read off the
  stack): the clock by address, the seconds in D0, Apollo's linteger
  (unsigned). }
function cal_$clock_to_sec(in clock: time_$clock_t): linteger; extern;

{ CAL_$WRITE_CALENDAR (hand assembly in the map's OS_CAL_ASM segment,
  the arguments read off the stack): writes the calendar chip from
  seven words, each by address. }
procedure cal_$write_calendar(in year: integer; in month: integer;
                              in day: integer; in weekday: cal_$weekday_t;
                              in hour: integer; in minute: integer;
                              in second: integer); extern;
