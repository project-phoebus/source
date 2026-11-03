|
| ct/m68k/end_addr.s - CT_END_ADDR, the end of the CT code range
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E70AF8 CT_END_ADDR size = 4' (the section is named after
| the map segment, so the run starts at its first byte).
|
| SAU2 map: "I E70AF8 CT_END_ADDR size = 4", one name, CT_$PROC_END at
| 0xE70AFA (+2).  Four zero bytes in a code section, with a label inside:
| no compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  The segment is the same on every
| SR10.2 SAU, the driver before it or not: SR10.2 SAU3: `I E721C8 CT size
| = 4' (CT_$PROC_START), `I E721CC CT_END_ADDR size = 4' with CT_$PROC_END
| 0xE721CE; SAU9 `I 3C4771F8 CT size = 130C', CT_$PROC_END 0x3C478506
| (CT_END_ADDR 0x3C478504 + 2).  So it is a marker module, linked after
| the driver's code; on the SAU2 the driver's code is absent.
|
| Not this file's: CT_$PROC_START (0xE70AF4, CT's first byte: ct/ct.pas),
| the range's start: a layout mark (tools/gen_layout_ld.py TEXT_MARKS),
| not an object here.
|
        .section ".text.CT_END_ADDR","ax",@progbits
        .balign 2

        .globl  CT_$PROC_END

        .word   0                       | e70af8  0000
CT_$PROC_END:                     | 0xE70AFA
        .word   0                       | e70afa  0000
