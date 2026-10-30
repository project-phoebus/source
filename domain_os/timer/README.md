# The TIMER subsystem in Domain Pascal

TIMER_$INIT, which programs the hardware timers.

## Layout

No module of its own.  The map has no TIMER segment: TIMER_$INIT is the
first symbol of a TIME_ code segment in WIRED_PROC (0x7A8 bytes), so it
is a routine of the TIME_ module, whose module file (`../time/time.pas`)
includes `init.pas` first in that segment.  There is no
`timer/timer.pas`.

| routine | section | fragment |
|---------|---------|----------|
| TIMER_$INIT | WIRED_PROC (TIME_) | `init.pas`: a function, 0x5C bytes and five constant cells; no section attribute (TIME_'s heading names wired_proc, wired_data) |

Insert files:
- `timer.ins.pas`: `timer_$byte_t`, the register block `timer_$regs_t`
  (`[device]`), the extern variable `timr` (the map's IODEFS symbol
  TIMR, reached by its absolute address) and TIMER_$INIT's heading,
  `function timer_$init: integer32`.
- `time/time.ins.pas`: TIME_$SET_VECTOR (no parameters) and
  TIME_$WRT_TIMER (`in timer_index: pinteger; in value: pinteger`), both
  hand-written in TIME_ASM, with their evidence.

With `timer_dcte` (base/config.ins.pas; the SAU9) TIMER_$INIT is the
initialization routine of the map's TIMER_DCTE, called from IO_$INIT's
device walk rather than by TIME_$INIT: it sets the map's TIMER block
(`timer_$timer_regs_t`, the extern `timer`) up from TIME_$SYS_FREQ,
programs the real-time counter with 4167, and enables the timer's three
interrupts through SYSBUS_$ENABLE_DEVICE (`init.pas`'s id local, the
SAU2 frame's unaddressed top 4 bytes).  `time/time.pas` includes
`ml/ml.ins.pas`, `io/io.ins.pas` and `sysbus/sysbus.ins.pas` for it.

## Open items

TODO(pascal): `init.pas`, the 4 frame bytes nothing addresses (stand-in
unused_8; a `with` statement's temporary might explain them).
