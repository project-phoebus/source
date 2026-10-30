|
| os/m68k/os_end.s - OS_END, the end of the kernel code range
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes, `I E78018 OS_END size = 4' (the section is named after the
| map segment, so the run starts at its first byte).
|
| SAU2 map: "I E78018 OS_END size = 4", one name, OS_PROC_END at 0xE7801A
| (+2).  Four zero bytes in a code section, with a label inside: no
| compiled code (compiled code ends in the filler 2048, and a Pascal
| module puts no object in a code section), so a module of the original's
| own assembly, here hand assembly.  It is the last code of the kernel:
| the load section `I19 E78018 OS_PROC_END size = 4' is this module
| alone, after ETHER_PROC and before `.DATA' at 0xE78400.  The same on
| the other SR10.2 SAUs: SAU3 `I19 E79818 OS_PROC_END', OS_PROC_END
| 0xE7981A; SAU9 OS_END 0x3C48941C, OS_PROC_END 0x3C48941E (+2).
|
| Not this file's: OS_PROC (0xE00800), the range's start, which kernel.ld
| defines.
|
        .section ".text.OS_END","ax",@progbits
        .balign 2

        .globl  OS_PROC_END

        .word   0                       | e78018  0000
OS_PROC_END:                     | 0xE7801A
        .word   0                       | e7801a  0000
