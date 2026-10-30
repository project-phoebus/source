# The LPR subsystem in Domain Pascal

The line printer driver is configured out of the SR10.2 SAU2 kernel.
What is left is one routine, and it is **hand-written assembly**, so
this subsystem has no Pascal: no module file and no fragments. Its one
insert file, `lpr.ins.pas`, holds LPR_$RELEASE's heading for its
compiled caller, PROC2's proc2_$cleanup_handlers_internal (its first
parameter an `in` boolean: PROC2_$GET_ASID shares the caller's `false`
cell).

## Layout

The SAU2 map has two LPR segments, both in the default code section
.TEXT:

| segment | size | symbols | contents |
|---------|------|---------|----------|
| LPR_ASM | 4 | LPR_$PROC_START, LPR_$RELEASE (one address) | a bare return and a zero pad word |
| LPR_END_ADDR | 4 | LPR_$PROC_END (odd: the segment's start + 1) | zeros |

and two data symbols with no LPR data segment of their own:
LPR_$DATA_END (the last byte of the PEB_WIRED data segment) and
LPR_$DATA_START (the start of the AUDIT data segment, with the MT_, CT_
and SM_C_ markers): empty data, markers only.

## Why it is hand assembly

- The segment's name ends in `_ASM`.
- LPR_$RELEASE is a return padded with a **zero** word.  Compiled
  modules end in the compiled module-end filler: MT_$RELEASE and
  CT_$RELEASE, the same configured-out return, end in it
  (which names LPR_ASM as the
  hand-written counterexample; 7, the module-end filler).
- LPR_END_ADDR is a marker segment of zeros, with an odd symbol, as
  MT_END_ADDR and CT_END_ADDR are; no compiler output.

## Files

| routine | Pascal | assembly |
|---------|--------|----------|
| LPR_$RELEASE | none: its heading in `lpr.ins.pas` | `m68k/release.s` |
| (LPR_END_ADDR marker) | none | `m68k/end_addr.s` |

Both are byte-identical with the image (`make check-asm`).

## For a Pascal caller

The only caller is PROC2_$CLEANUP_HANDLERS_INTERNAL: two arguments by
address, the first a constant word cell holding 0, the second the
caller's status.  The default convention, which the bare return cannot
confirm.

## Open items

None.
