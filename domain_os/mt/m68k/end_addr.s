|
| mt/m68k/end_addr.s - MT_END_ADDR, the end of the MT code range
| (m68k/SAU2, SAU5)
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.  (SAU5 map: "I E76E08
| MT_END_ADDR size = 4", MT_$PROC_END at 0xE76E0A, after the MT_$SIO
| code segment.)
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E70A50 MT_END_ADDR size = 4' (the section is named after
| the map segment, so the run starts at its first byte).
|
| SAU2 map: "I E70A50 MT_END_ADDR size = 4", one name, MT_$PROC_END at
| 0xE70A52 (+2).  Four zero bytes in a code section, with a label inside:
| no compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  The segment is the same on every
| SR10.2 SAU, the driver before it or not: SR10.2 SAU3: `I E6FB98 MT size
| = 1440', MT_$PROC_START 0xE70FD8 (its end, the start of the next 0x2C0
| bytes), then `I E71298 MT_END_ADDR size = 4' with MT_$PROC_END 0xE7129A.
| So it is a marker module, linked after the driver's code; on the SAU2
| the driver's code is absent.
|
| Not this file's: MT_$PROC_START (0xE70A50; MT_$RELEASE, `I E70A4C MT',
| is before it), the range's start: a layout mark (tools/gen_layout_ld.py
| TEXT_MARKS), not an object here.
|
        .section ".text.MT_END_ADDR","ax",@progbits
        .balign 2

        .globl  MT_$PROC_END

        .word   0                       | e70a50  0000
MT_$PROC_END:                     | 0xE70A52
        .word   0                       | e70a52  0000
