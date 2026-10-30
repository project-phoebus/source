|
| proc2/m68k/ec.s - PROC2_$EC, the per-process eventcount pairs
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's 0x690
| zero bytes.
|
| SAU2 map: "D E2B978 PROC2_WIRED_ASM size = 690" (WIRED_DATA), one
| symbol, PROC2_$EC, at its start: 70 entries of 0x18 bytes, two
| eventcounts each, indexed from 1 (proc2/proc2_data.ins.pas
| proc2_ec_entry_t).  Hand-written data (the segment's name ends in
| `_ASM'), all zero in the image; PROC2_$INIT initialises the eventcounts
| at run time.
|
        .section ".text.PROC2_$EC","ax",@progbits
        .balign 2

        .globl  PROC2_$EC

PROC2_$EC:                              | 0xE2B978
        .space  70 * 0x18
