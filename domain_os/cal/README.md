# The CAL subsystem in Domain Pascal

The calendar (the timezone record and its copy on the boot volume's
label, the check of the calendar at boot, the local-time offsets, the
date and weekday conversions).

## Layout

The map has no module named CAL, so there is no `cal/cal.pas`.  The
compiled routines are two map modules, one module file each, which
`tools/pascal_check.sh` finds by their headings:

| file | heading | code | data |
|------|---------|------|------|
| `os_cal_wired.pas` | `module os_cal_wired;` | OS_CAL_WIRED, 0x224 bytes, .TEXT: CAL_$READ_TIMEZONE, CAL_$WRITE_TIMEZONE, CAL_$SHUTDOWN | OS_CAL_WIRED, 0x14 bytes, .DATA, through A5 |
| `os_cal_unwired.pas` | `module os_cal_unwired;` | OS_CAL_UNWIRED, 0x4E4 bytes, .TEXT: CAL_$VERIFY, _$GET_INFO, _$SET_DRIFT, _$GET_LOCAL_TIME, _$APPLY_LOCAL_OFFSET, _$REMOVE_LOCAL_OFFSET, _$WEEKDAY, _$DECODE_TIME | none (OS_CAL_WIRED's variables by their absolute addresses; no A5) |

Both are in the default sections (.TEXT and .DATA), so neither heading
names one.  OS_CAL_WIRED's code, its block are the last objects before
the OS_DISK_END and OS_DISK_DATA_END markers, the run of .TEXT and
.DATA the module's name calls wired.

OS_CAL_WIRED's block, all zero in the image:

| offset | variable | type |
|--------|----------|------|
| +0x00 | CAL_$TIMEZONE (`define`d, map symbol) | cal_$timezone_rec_t (Apollo's), 12 bytes |
| +0x0C | CAL_$LAST_VALID_TIME (`define`d, map symbol) | time_$clockh_t |
| +0x10 | CAL_$BOOT_VOLX (`define`d, map symbol) | integer |
| +0x12 | 2 bytes: the block's rounding to 4 | |

The image addresses the block through A5 in OS_CAL_WIRED's three
routines, by absolute address in OS_CAL_UNWIRED, OS_$INIT, FILE_,
ASKNODE and VOLX: module variables of OS_CAL_WIRED, `extern` in
`cal.ins.pas`.

Hand assembly, no Pascal:
- OS_CAL_ASM, 0x170 bytes (a D segment in .DATA, named `_ASM`):
  CAL_$WRITE_CALENDAR with its local entries (two digits, one digit,
  finish, two delays); CAL_$SEC_TO_CLOCK; the table CAL_$DAYS_PER_MONTH
  (twelve words, `extern` in `cal.ins.pas`); CAL_$CLOCK_TO_SEC.  No
  frames, the arguments read off the stack, registers saved on it.
  Transcribed in `cal/m68k/os_cal_asm.s`.
- ADD48, SUB48, in the TIME_ASM code segment, 0x2C bytes (frameless,
  the arguments off the stack).  Transcribed in `time/m68k/add48.s`.

Routines: eleven compiled globals, every CAL_ map symbol of the two
code segments; none module-local, none nested.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| CAL_$READ_TIMEZONE | `read_timezone.pas` |
| CAL_$WRITE_TIMEZONE | `write_timezone.pas` |
| CAL_$SHUTDOWN | `shutdown.pas` |
| CAL_$VERIFY | `verify.pas` (with its constant cells) |
| CAL_$GET_INFO | `get_info.pas` |
| CAL_$SET_DRIFT | `set_drift.pas` |
| CAL_$GET_LOCAL_TIME | `get_local_time.pas` |
| CAL_$APPLY_LOCAL_OFFSET | `apply_local_offset.pas` |
| CAL_$REMOVE_LOCAL_OFFSET | `remove_local_offset.pas` |
| CAL_$WEEKDAY | `weekday.pas` (with its jump table) |
| CAL_$DECODE_TIME | `decode_time.pas` |
| CAL_$WRITE_CALENDAR, cal_$write_calendar_0_to_99, cal_$write_calendar_digit, cal_$finish_write, cal_$delay_40, cal_$delay | none: hand assembly (OS_CAL_ASM) |
| CAL_$SEC_TO_CLOCK | none: hand assembly (OS_CAL_ASM) |
| CAL_$CLOCK_TO_SEC | none: hand assembly (OS_CAL_ASM) |
| ADD48 | none: hand assembly (TIME_ASM) |
| SUB48 | none: hand assembly (TIME_ASM) |
| (data) | the `define`d variables of `os_cal_wired.pas` |

Headings (`cal.ins.pas`): every routine the default convention, every
argument by address: all but CAL_$VERIFY, CAL_$SHUTDOWN are SVC
targets, and the compiled callers of CAL_$VERIFY (OS_$INIT),
CAL_$SHUTDOWN (two), CAL_$WEEKDAY, CAL_$DECODE_TIME (TIME_) push
addresses.  The user routines' headings are Apollo's
(`sys/ins/cal.ins.pas`); CAL_$VERIFY, CAL_$WEEKDAY are boolean and
enumeration functions.  No routine returns a pointer, so no D0 parking.

## Insert files

- `cal.ins.pas` (rewritten around its earlier declarations): Apollo's
  statuses cal_$out_of_range, cal_$refused, cal_$string_t,
  cal_$tz_name_t, cal_$timedate_rec_t, cal_$weekday_t,
  cal_$timezone_rec_t; cal_lock_id; the variables CAL_$TIMEZONE,
  CAL_$LAST_VALID_TIME, CAL_$DAYS_PER_MONTH; the headings of ADD48, the
  eleven compiled routines, CAL_$SEC_TO_CLOCK.  Kept as they were:
  SUB48's heading, CAL_$BOOT_VOLX.  Changed: CAL_$CLOCK_TO_SEC's result
  is Apollo's linteger (was integer32): CAL_$DECODE_TIME divides it with
  the unsigned runtime (M$OIU$WLW, M$DIU$LLW), the routine itself
  divides unsigned.  Its other Pascal user, `pacct/log.pas` (a longword
  add to a constant), checks unchanged, as do `volx/volx.pas`,
  `tty/tty.pas`, `term/os_term.pas`, `term/os_term_init.pas`, which
  include the file.  It still needs only `base/base.ins.pas` before it.
- `bat/bat.ins.pas`: bat_$label_t's reserved_d0 (0x0D0..0x0FB) is split
  into reserved_d0 (0x0D0..0x0DF), utc_delta (0x0E0), tz_name
  (0x0E2..0x0E5), last_valid_time (0x0E6) and reserved_ea (0x0EA..0x0FB),
  the fields the three OS_CAL_WIRED routines address.  No offset moves;
  no earlier user named reserved_d0.  Its includers, `bat/bat.pas`,
  `volx/volx.pas`, still check.
- `network/network.ins.pas`: added NETWORK_$DISKLESS (a boolean).  Its
  includers (bat, net_io, netbuf, netlog, pkt, volx) still check.
- Used as they are: `dbuf/dbuf.ins.pas` (DBUF_$GET_BLOCK, DBUF_$SET_BUFF,
  the flags), `proc1/proc1.ins.pas` (PROC1_$SET_LOCK, _$CLR_LOCK),
  `uid/uid.ins.pas` (LV_LABEL_$UID), `time/time.ins.pas` (TIME_$CLOCK,
  TIME_$CLOCKH), `misc/crash_system.ins.pas`, `vfmt/vfmt.ins.pas`
  (VFMT_$WRITE2), `term/term.ins.pas` (TERM_$READ).

## Open items

### Types and names

- 16#150002, 16#150007 are Apollo's cal_$out_of_range, cal_$refused.
- CAL_$REMOVE_LOCAL_OFFSET is a procedure, as Apollo declares it; it
  leaves SUB48's byte in D0, but no compiled caller reads D0 (its one
  reference is the SVC table).
- CAL_$VERIFY's msg_arg is the `%a` string of "More than %a days ..."
  (OS_$INIT's cell holds "5  ", its length 3 the call's second
  argument).
- The label's timezone fields are bat_$label_t's own.
- CAL_$CLOCK_TO_SEC returns Apollo's linteger; `cal.ins.pas` had
  integer32 before (PACCT's addition, above).
- CAL_$DECODE_TIME's record is Apollo's cal_$timedate_rec_t.

### TODO(pascal)

None.  The SAU2 frames are explained: CAL_$VERIFY's with the 8-byte
alignment lead for its record, CAL_$DECODE_TIME's with a `with`
temporary; the rest exactly by their locals, result variables and
temporaries.
