|
| sm_c/m68k/end_addr.s - SM_C_END_ADDR, the end of the SM_C code range
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E70A48 SM_C_END_ADDR size = 4' (the section is named
| after the map segment, so the run starts at its first byte).
|
| SAU2 map: "I E70A48 SM_C_END_ADDR size = 4", one name, SM_C_$PROC_END at
| 0xE70A4A (+2).  Four zero bytes in a code section, with a label inside:
| no compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  The segment is the same on every
| SR10.2 SAU, the driver before it or not: SR10.2 SAU3: `I E6EDD0 SM_C
| size = D58' (SM_C_$PROC_START 0xE6EDD0), then `I E6FB94 SM_C_END_ADDR
| size = 4' with SM_C_$PROC_END 0xE6FB96.  So it is a marker module,
| linked after the driver's code; on the SAU2 the driver's code is absent.
|
| Not this file's: SM_C_$PROC_START (0xE70A48), the range's start: a
| layout mark (tools/gen_layout_ld.py TEXT_MARKS), not an object here.
|
        .section ".text.SM_C_END_ADDR","ax",@progbits
        .balign 2

        .globl  SM_C_$PROC_END

        .word   0                       | e70a48  0000
SM_C_$PROC_END:                     | 0xE70A4A
        .word   0                       | e70a4a  0000
