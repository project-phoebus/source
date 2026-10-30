# The TONE subsystem in Domain Pascal

The speaker tone.

## Layout

The two routines are in two map modules:

| module | section | code | routine | fragment, attribute |
|--------|---------|------|---------|---------------------|
| TONE (`tone.pas`, `module tone;`) | WIRED_PROC | TONE, 0x64 bytes (the SAU9's 0xE8) | TONE_$TIME (its code, three cells; no filler on the SAU2, the filler word on the SAU9) | `time.pas`, `[section(wired_proc, wired_data)]` |
| OS_TERM_INIT (`../term/os_term_init.pas`) | WIRED_PROC | OS_TERM_INIT, 0x1F0 bytes | TONE_$ENABLE, the segment's last routine (then the filler) | `enable.pas`, `[section(wired_proc, wired_data)]` |

TONE has no data; its heading names no section, and its one routine
carries the attribute of its section (TTY's form).  TONE_$ENABLE is a
fragment of OS_TERM_INIT's module, as `kbd/reset.pas` (the same
segment's first routine) is; `tone.pas` does not include it,
`term/os_term_init.pas` does, and declares the channel record at +0x1268
of its WIRED_DATA block (no map symbol, so a module variable of
OS_TERM_INIT, tone_$channel).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| TONE_$TIME | `time.pas` |
| TONE_$ENABLE | `enable.pas` (OS_TERM_INIT's) |

dpc compiles both to the SAU2 image's bytes (TONE_$TIME with its three
cells in the image's order).

Insert files:
- `tone.ins.pas`: `procedure tone_$time(duration: time_$clock_t)` (a
  value parameter, copied on entry; an SVC entry) and `procedure
  tone_$enable(in enable: boolean)` (its callers pass constant cells
  for true and false).
- `proc1/proc1.ins.pas` (extended): PROC1_$CLR_LOCK, `val_param`, as
  PROC1_$SET_LOCK.
- `time/time.ins.pas` (extended): TIME_$WAIT, Apollo's customer heading
  `(rel_abs: time_$rel_abs_t; in exp_time: time_$clock_t; out status:
  status_$t)`.  Its body has no entry copy of either argument: the
  6-byte copy of exp_time follows a call, so it is a statement
  (Apollo's `IN` fits); rel_abs is read into a register after the first
  statement, which fits `in` as well as Apollo's value parameter held in
  a register.  TIME_'s own translation settles the callee's heading
  (noted there); the caller's code is the same.
- `cal/cal.ins.pas`: SUB48, with which the `kbd_tone` form of TONE_$TIME
  counts the time down.
- `sio2681/sio2681.ins.pas`: SIO2681_$TONE, `(in channel: univ_ptr; in
  enable: boolean; out status_unused: status_$t)`.  With `kbd_tone`
  TONE_$ENABLE sends the keyboard one of two tone commands through
  KBD_$PUT (kbd/kbd.ins.pas) instead; the commands are OS_TERM_INIT's
  (term/os_term_init.pas).

## Open items

No TODO(pascal), no dpc gap.
