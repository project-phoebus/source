# The MATH subsystem (M$ARITH) in Domain Pascal

The map's M$ARITH code segment (WIRED_PROC, 0x1DC bytes) is the
compiler's arithmetic runtime: hand-written stack-argument routines (no
`link`, arguments read off SP, the result in D0) that compiled code
calls for the 32-bit multiplies, divides and remainders the 68010
cannot do in one instruction.  They are not kernel source: they are the
runtime of the Domain Pascal compiler.  The m68k kernel links dpc's
runtime for them (`m_arith.o`, the image's bytes, byte-checked by `make
check`; the Makefile's note on RUNTIME_OBJS).

So MATH gets no Pascal.  The Pascal translation never calls these
routines: a call of one of them is the compiler's code for an ordinary
`*`, `div` or `mod` on operands of the widths and signedness the name
gives, and no insert file declares them.  There is no module file
and no insert file.

## Routines

All hand assembly, the dpc runtime; no fragment.  In map order:

    Image addresses:
      sau2  0x00E0ABD4  M$MIS$LLL
      sau2  0x00E0AC02  M$MIU$LLW
      sau2  0x00E0AC1C  M$MIU$LLL
      sau2  0x00E0AC44  M$MIS$LLW
      sau2  0x00E0AC68  M$DIU$LLW
      sau2  0x00E0AC84  M$DIS$LLW
      sau2  0x00E0ACC0  M$OIU$WLW
      sau2  0x00E0ACD8  M$DIS$LLL
      sau2  0x00E0AD0C  M$DIU$LLL
      sau2  0x00E0AD54  M$OIS$WLW
      sau2  0x00E0AD68  M$OIS$WWL
      sau2  0x00E0AD7C  M$OIS$LLL

The names are the map's.  The map also names M$OIU$LLL at M$OIS$LLL's
address: one entry for both.  Reading a name: M$ then MI (multiply), DI
(divide) or OI (remainder), S or U (signed, unsigned), then the operand
sizes, L longword, W word, the first the result's.

## Open items

None: no Pascal, no insert file, no dpc gap.  No conformance unit of
`../domain-pascal/tests/conformance/` covers M$ARITH (dpc provides it
as its runtime, `dpc --print-runtime`).
