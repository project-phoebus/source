# The DI subsystem in Domain Pascal

The deferred-interrupt queue's two routines, DI_$ENQ and
DI_$INIT_Q_ELEM, are **hand-written assembly** in the SR10.2 SAU2 image,
part of the PROC1 assembler module, so this subsystem has no Pascal: no
module file and no fragments; its insert file, `di.ins.pas`, holds what
TIME_$INIT calls (below).

## Layout

There is no DI segment.  The three DI symbols lie inside the map's
PROC1_ASM data segment (0x24A4 bytes, in WIRED_DATA), PROC1's
hand-written code and data (the dispatcher, the eventcount waits,
PROC1_$SET_LOCK, ...):

| symbol | what |
|--------|------|
| DI_$Q_HEAD | the queue's head, a longword (between PROC1_$SUSPEND_EC and PROC1_$CURRENT) |
| DI_$ENQ | 0x2E bytes, then DI_$INIT_Q_ELEM |
| DI_$INIT_Q_ELEM | 0x10 bytes, then PROC1_$BEGIN_ATOMIC_OP |

## Why it is hand assembly

The signs of hand assembly:
- **Location.** Code inside a `D` segment whose name ends in `_ASM`.
- **No frame.** No `link`/`unlk`: both routines read their arguments
  off the stack pointer.
- **PC-relative data.** DI_$ENQ reads the queue head PC-relative and
  writes it by its absolute address.
- **A shared exit.** The double-enqueue arm branches into another
  routine's crash stub, whose call of CRASH_SYSTEM is followed by a
  branch into PROC1_$SET_LOCK's body.
- **Encodings.** DI_$INIT_Q_ELEM loads its `dbf` count with a word move
  where compiled code uses `moveq`.
- No module-end filler: DI_$INIT_Q_ELEM's return is followed directly by
  PROC1_$BEGIN_ATOMIC_OP's code.

## Routines

| routine | Pascal |
|---------|--------|
| DI_$ENQ | none: hand assembly (`m68k/enq.s`; DI_$Q_HEAD is in `../proc1/m68k/proc1_data.s`) |
| DI_$INIT_Q_ELEM | none: hand assembly (`m68k/init_q_elem.s`) |

## For a Pascal caller

The callers are TIME_ routines (DI_$ENQ: TIME_$TIMER_HANDLER, twice, in
TIME_ASM; DI_$INIT_Q_ELEM: TIME_$INIT, twice, compiled).
`di/di.ins.pas` holds the element type and DI_$INIT_Q_ELEM's heading,
from how TIME_$INIT pushes its argument, as `ml/ml.ins.pas` holds the
headings of hand-written routines (time/init.pas).

## Open items

Layout fix: `di_$q_elem_t`'s 3-char `reserved` array was word aligned
(ref 3.10.5.5) and made the element 0x12 bytes; it is now three chars,
reserved_0d.._0f, and the element 0x10 bytes, as TIME_$DI_VT and
TIME_$DI_RTE are 0x10 apart.
