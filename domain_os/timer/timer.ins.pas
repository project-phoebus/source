{ timer/timer.ins.pas - the hardware timers (TIMER_$INIT and the IODEFS
  register block TIMR), for the Domain Pascal tree.

  The timer chip's register block, the map's IODEFS symbol TIMR that
  names it, and TIMER_$INIT's heading.  TIMER_$INIT is a routine of the
  TIME_ module (time/time.ins.pas has the TIME_ headings; timer/
  README.md).  Apollo's customer insert files of SR10.2 declare
  none of these.  Include base/base.ins.pas before it.
}

type
  { A byte register, an unsigned 8-bit integer (ref 3.15.5: "[byte]
    0..255 corresponds to the unsigned char data type in Domain/C"), the
    form of suma/suma.ins.pas's suma_$byte_t. }
  timer_$byte_t = [byte] 0..255;

  { The timer chip's registers at TIMR (below): one byte at each odd
    address, the even ones unused.  Counter n (1 the real-time counter,
    2 the virtual timer, 3 the auxiliary timer) is the byte pair at
    TIMR + 4n + 1 and + 3, which the hand-written TIME_$WRT_TIMER writes
    as one alternate-byte word.  `[device]' (ref 3.15.3): hardware
    registers, whose stores the compiler must keep and not merge. }
  timer_$regs_t = [device] record
    unused_00: timer_$byte_t;             { 0x00 }
    reg_01: timer_$byte_t;                { 0x01: written by TIMER_$INIT
                                            (with 0x03, the control
                                            registers) }
    unused_02: timer_$byte_t;             { 0x02 }
    ctrl: timer_$byte_t;                  { 0x03: control/status }
    unused_04: timer_$byte_t;             { 0x04 }
    rte_hi: timer_$byte_t;                { 0x05 }
    unused_06: timer_$byte_t;             { 0x06 }
    rte_lo: timer_$byte_t;                { 0x07 }
    unused_08: timer_$byte_t;             { 0x08 }
    vt_hi: timer_$byte_t;                 { 0x09 }
    unused_0a: timer_$byte_t;             { 0x0A }
    vt_lo: timer_$byte_t;                 { 0x0B }
    unused_0c: timer_$byte_t;             { 0x0C }
    aux_hi: timer_$byte_t;                { 0x0D }
    unused_0e: timer_$byte_t;             { 0x0E }
    aux_lo: timer_$byte_t;                { 0x0F }
  end;

var
  { TIMR: a map symbol of the I/O definitions (IODEFS; 0xFFAC00 on the
    SAU2), another unit's variable. }
  timr: extern timer_$regs_t;

%if timer_dcte %then
type
  { The timer block at the map's IODEFS symbol TIMER (`timer_dcte'):
    byte registers 4 bytes apart.  TIMER_$INIT writes three control
    words to +0x0C (16#34, 16#70, 16#B0: an 8254-style control word for
    each of three counters), the system clock in MHz less 1 to +0x10,
    and 0 to +0x18; it writes nothing else here.  `[device]': hardware
    registers. }
  timer_$timer_regs_t = [device] record
    unused_00: array[0..11] of timer_$byte_t;  { 0x00..0x0B }
    ctrl: timer_$byte_t;                  { 0x0C }
    unused_0d: timer_$byte_t;             { 0x0D }
    unused_0e: array[1..2] of timer_$byte_t;   { 0x0E..0x0F }
    clock_mhz: timer_$byte_t;             { 0x10 }
    unused_11: timer_$byte_t;             { 0x11 }
    unused_12: array[1..6] of timer_$byte_t;   { 0x12..0x17 }
    reg_18: timer_$byte_t;                { 0x18 }
  end;

var
  { TIMER: a map symbol of the I/O definitions (IODEFS), another unit's
    variable. }
  timer: extern timer_$timer_regs_t;
%endif

{ TIMER_$INIT - program the hardware timers. }
function timer_$init: integer32; extern;
