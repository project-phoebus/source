# The PAS subsystem in Domain Pascal

PAS_$SET_BUILD, the Pascal run-time support routine that builds a set
from a template and a range (the set constructor `[lo..hi]`), is
**hand-written assembly** in the SR10.2 SAU2 image, so this subsystem
has no Pascal: no module file, no insert file, no fragments.

## Layout

| segment | size | section | symbols |
|---------|------|---------|---------|
| PAS_$SET_BUILD | 0x4C | WIRED_PROC | PAS_$SET_BUILD |

No data segment.  The segment is named after the routine; the
compiler's other run-time support, M$ARITH, is likewise a hand-written
segment of its own.

## Why it is hand assembly

The signs of hand assembly:
- **No frame.** No `link`/`unlk`: the routine saves its registers on the
  stack at entry and pops them before the return, where compiled code
  restores from the frame.
- **Arguments read off the stack pointer**, after the saved registers.
- **Encodings.** It uses the OR form with an immediate effective
  address, which compiled code does not use (it would use `ori`).
- **Padding.** The return is followed by a zero word, not the compiled
  module-end filler.
- It is the compiler's run-time support (the set constructor), like
  M$ARITH, which compiled code calls but which is not compiler output.

## Where the build gets it

| routine | Pascal | object |
|---------|--------|--------|
| PAS_$SET_BUILD | none: hand assembly | dpc's run-time archive (`dpc --print-runtime=m68k`), extracted by the Makefile as `build/sau2/runtime/pas_set_build.o` and linked like a hand-written routine |

## Callers

None in the image: no compiled call, and no cell or operand holds its
address.  The argument
layout, from the body: the destination and the template by address,
then lo, hi and the member count as words by value, in that order.  A
Pascal translation needs no heading for it: a compiler would emit such
a call for a set constructor with a run-time range.

## Open items

None.  The routine is the Pascal run-time's set builder, not a "Process
Address Space" operation.
