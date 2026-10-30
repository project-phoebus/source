# The ML subsystem in Domain Pascal

The machine-level locks (ML_$LOCK and ML_$UNLOCK, the spin locks, the
exclusion locks) are **hand-written assembly** in the SR10.2 SAU2 image,
part of the PROC1 assembler run, so this subsystem has no Pascal
routines: no module file and no fragments. The insert file
`ml/ml.ins.pas` holds the headings Pascal callers compile against (read
from the compiled callers' pushes; the image agrees with each, below).

## Layout

There is no ML segment.  The ML symbols lie inside the map's PROC1_ASM
data segment in WIRED_DATA (0x24A4 bytes), PROC1's hand-written code and
data, between PROC1_$SET_LOCK / PROC1_$CLR_LOCK and PROC1_$INHIBIT_END,
in this order:

| symbol | what |
|--------|------|
| ML_$LOCK | code, 0x44 bytes and the shared crash stub |
| ML_$UNLOCK | code, to PROC1_$CLR_LOCK, whose body it shares |
| ML_$SPIN_CHECK, ML_$SPIN_LOCK | one entry, two names: save SR in D0, raise the IPL to 7 |
| ML_$SPIN_UNLOCK | restore SR from the token |
| LOCK_BYTE | data: 32 lock bytes |
| LOCK_$EVENT_LISTS | data: 32 eventcounts with wait counts, 16 bytes each |
| ML_$EXCLUSION_START | code |
| ML_$EXCLUSION_INIT | code |
| ML_$EXCLUSION_CHECK | code |
| ML_$COND_EXCLUSION_START | code |
| ML_$COND_EXCLUSION_STOP | code |
| ML_$EXCLUSION_STOP | code, to PROC1_$INHIBIT_END, which it branches into |

## Why it is hand assembly

The signs of hand assembly:
- **Location.** Code inside a data segment whose name ends in `_ASM`.
- **No frame.** No frame anywhere in the run: the arguments are read
  off the stack pointer (ML_$LOCK, ML_$UNLOCK, every exclusion routine,
  ML_$SPIN_UNLOCK).
- **PC-relative data.** LOCK_BYTE and PROC1_$CURRENT_PCB are reached
  PC-relative.
- **Register arguments and shared code.** ML_$LOCK loads D0 and calls
  into PROC1_$SET_LOCK's body past its entry; ML_$UNLOCK branches into
  PROC1_$CLR_LOCK; ML_$EXCLUSION_STOP into PROC1_$INHIBIT_END's tail;
  EC_$WAITN's worker is called with its lists in A3/A4 and the count in
  D0.
- **SR saved on the stack** (ML_$COND_EXCLUSION_START), which compiled
  code never does.
- **Encodings.** A move of the immediate 0 where compiled code clears.

## Routines and their transcriptions

| routine | Pascal |
|---------|--------|
| ML_$LOCK | none: hand assembly (`m68k/lock.s`) |
| ML_$UNLOCK | none: hand assembly (`m68k/lock.s`) |
| ML_$SPIN_LOCK | none: hand assembly (`m68k/spin_lock.s`; ML_$SPIN_CHECK is the same entry) |
| ML_$SPIN_UNLOCK | none: hand assembly (`m68k/spin_unlock.s`) |
| ML_$EXCLUSION_START | none: hand assembly (`m68k/exclusion.s`) |
| ML_$EXCLUSION_INIT | none: hand assembly (`m68k/exclusion.s`) |
| ML_$EXCLUSION_CHECK | none: hand assembly (`m68k/exclusion.s`) |
| ML_$COND_EXCLUSION_START | none: hand assembly (`m68k/exclusion.s`) |
| ML_$COND_EXCLUSION_STOP | none: hand assembly (`m68k/exclusion.s`) |
| ML_$EXCLUSION_STOP | none: hand assembly (`m68k/exclusion.s`) |
| (data) | none: hand assembly (LOCK_BYTE and LOCK_$EVENT_LISTS, data of the PROC1_ASM run; no Pascal declares them; `m68k/lock_data.s`) |

## For a Pascal caller

`ml/ml.ins.pas` declares ML_$LOCK, ML_$UNLOCK (`val_param`, a word),
ML_$SPIN_LOCK (a pinteger function, the lock by address), ML_$SPIN_UNLOCK
(`val_param`, the token a word), ML_$EXCLUSION_INIT (`out`),
ML_$EXCLUSION_START and ML_$EXCLUSION_STOP (`var`), and the exclusion
record.  The image confirms them: ML_$LOCK and ML_$UNLOCK read the word
the caller pushes after the alignment pad; ML_$SPIN_UNLOCK the token
above the lock's address; the exclusion routines the record's address
and its fields at 0x0C (a longword) and at 0x10 (a word) in place.  ML_$EXCLUSION_CHECK (a boolean function: the sign of the word at 0x10),
ML_$COND_EXCLUSION_START (the same result) and ML_$COND_EXCLUSION_STOP
are declared from the SAU9 Ethernet driver's calls (the lock by
address, the results tested as booleans).  MAC calls only
ML_$EXCLUSION_START and _STOP, as declared.

## Open items

No dpc gap, no TODO.  No conformance unit of
`../domain-pascal/tests/conformance/` covers ML_ (its callers' units
declare the headings, `acl_clear_super.pas`, `pkt_next_id.pas`).
