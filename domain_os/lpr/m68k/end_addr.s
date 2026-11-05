|
| lpr/m68k/end_addr.s - LPR_END_ADDR, the end of the LPR code range
|
| The SAU2, SAU3, SAU5 and SAU6 images have the same code here;
| the address and byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E70A44 LPR_END_ADDR size = 4' (the section is named after
| the map segment, so the run starts at its first byte).
|
| SAU2 map: "I E70A44 LPR_END_ADDR size = 4", one name, LPR_$PROC_END at
| 0xE70A45 (+1).  Four zero bytes in a code section, with a label inside:
| no compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  The segment is the same on every
| SR10.2 SAU, the driver before it or not: SR10.2 SAU3: LPR_$PROC_START
| 0xE6E724, `I E6EDCC LPR_END_ADDR size = 4' with LPR_$PROC_END 0xE6EDCD
| (+1 there too; SAU9 0x3C477148, +1).  So it is a marker module, linked
| after the driver's code; on the SAU2 the driver's code is absent.
|
| Not this file's: LPR_$PROC_START (0xE70A40), the range's start, which
| lpr/m68k/release.s defines at LPR_ASM's first byte.
|
        .section ".text.LPR_END_ADDR","ax",@progbits
        .balign 2

        .globl  LPR_$PROC_END

        .byte   0                       | e70a44  00
LPR_$PROC_END:                     | 0xE70A45
        .byte   0,0,0                   | e70a45  000000
