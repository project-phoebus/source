# The STOP subsystem in Domain Pascal

The stopwatch (STOP_$WATCH and its trap handlers) is **hand-written
assembly** in the SR10.2 SAU2 image, so this subsystem has no Pascal: no
module file, no insert file, no fragments.

## Layout

| segment / symbol | what |
|------------------|------|
| the map's STOP_WATCH segment (.DATA, 0x914 bytes) | the code (STOP_$WATCH, STOP_$WATCH_UII, STOP_$WATCH_TRACE, and the register-argument helpers) and the module's data after it; all of it is `m68k/watch.s`, one section |
| STOP_$WATCH_TRACE_FLAG | a byte inside FIM_UNWIRED's data segment (FIM's hand-written run), between FIM_$ILLEGAL_USP and FIM_$TRACE (`m68k/watch_trace_flag.s`) |

## Why it is hand assembly

The signs of hand assembly:
- **Location.** Code inside a `D` (data) segment.
- **A5 loaded PC-relative.** STOP_$WATCH sets A5 to its own address
  PC-relative, where compiled code loads it with an absolute address
  (STOP_$WATCH).
- **Encodings.** Compares with an immediate in the general
  effective-address form, which compiled code does not use; a
  PC-relative indexed branch table.
- **Register arguments, `rte`, no `rts`.** STOP_$WATCH_UII and
  STOP_$WATCH_TRACE are exception entries returning from the exception;
  STOP_$MEASURE_LOOP falls through into STOP_$NULL_PROC; STOP_$HOOK and
  STOP_$UNHOOK take their arguments in registers (`m68k/watch.s`,
  header).
- STOP_$WATCH_TRACE_FLAG is a cell of FIM's hand-written data.

`m68k/watch.s` has the listing and its evidence, and is byte-gated
against the image by `tools/asm_compare.py`.

## Routines and data

| routine / data | Pascal |
|----------------|--------|
| STOP_$WATCH | none: hand assembly (`m68k/watch.s`) |
| STOP_$WATCH_UII, STOP_$WATCH_TRACE and the helpers | none: hand assembly (`m68k/watch.s`) |
| (data) | none: the module's own data, after its code, in `m68k/watch.s`'s one section |
| STOP_$WATCH_TRACE_FLAG | none: hand assembly (`m68k/watch_trace_flag.s`) |

## For a Pascal caller

STOP_$WATCH is user callable (an SVC entry, six arguments by address);
no compiled kernel routine calls it.  A heading would go in a new
`stop/stop.ins.pas` when a Pascal caller needs one.

## Open items

None.
