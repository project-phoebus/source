|
| lpr/m68k/release.s - LPR_$RELEASE, the line-printer stub
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's four bytes.
|
| SAU2 map: "I E70A40 LPR_ASM size = 4", two names at its start,
| LPR_$PROC_START and LPR_$RELEASE: a bare `rts' and a zero pad word.  The
| line-printer driver is configured out of the SR10.2 SAU2 kernel; what is
| left is this stub, which PROC2's cleanup calls as LPR_$RELEASE(false,
| status) (lpr/lpr.ins.pas) and which returns without touching either
| argument.  LPR_END_ADDR (`I E70A44', LPR_$PROC_END) follows.
|
        .section ".text.LPR_$RELEASE","ax",@progbits
        .balign 2

        .globl  LPR_$PROC_START
        .globl  LPR_$RELEASE

LPR_$PROC_START:                        | 0xE70A40
LPR_$RELEASE:
        rts                             | e70a40  4e75
        .word   0                       | e70a42  0000  pad to the segment size
