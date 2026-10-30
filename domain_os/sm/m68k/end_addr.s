|
| sm/m68k/end_addr.s - SM_END_ADDR, the end of the SM code range
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E6D6F8 SM_END_ADDR size = 4' (the section is named after
| the map segment, so the run starts at its first byte).
|
| SAU2 map: "I E6D6F8 SM_END_ADDR size = 4", one name, SM_$PROC_END at
| 0xE6D6FA (+2).  Four zero bytes in a code section, with a label inside:
| no compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  The segment is the same on every
| SR10.2 SAU, the driver before it or not: SR10.2 SAU3: `I E6DB00 SM size
| = B1C' (SM_$PROC_START 0xE6DB00, its first byte), then `I E6E61C
| SM_END_ADDR size = 4' with SM_$PROC_END 0xE6E61E.  So it is a marker
| module, linked after the driver's code; on the SAU2 the driver's code is
| absent.
|
| Not this file's: SM_$PROC_START (0xE6D6F8, the segment's first byte on
| the SAU2), the range's start: a layout mark (tools/gen_layout_ld.py
| TEXT_MARKS), not an object here.
|
        .section ".text.SM_END_ADDR","ax",@progbits
        .balign 2

        .globl  SM_$PROC_END

        .word   0                       | e6d6f8  0000
SM_$PROC_END:                     | 0xE6D6FA
        .word   0                       | e6d6fa  0000
