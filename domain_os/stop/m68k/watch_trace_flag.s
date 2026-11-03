|
| stop/m68k/watch_trace_flag.s - STOP_$WATCH_TRACE_FLAG
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's two
| zero bytes.
|
| SAU2 map: "D E213A0 FIM_UNWIRED size = 4F0", STOP_$WATCH_TRACE_FLAG
| 0xE21596..0xE21598, between FIM_$ILLEGAL_USP (fim/m68k/illegal_usp.s)
| and FIM_$TRACE (fim/m68k/trace.s), in FIM's segment though STOP's name.
| A byte flag (and a pad byte), zero in the image: STOP_$WATCH_UII sets it
| (`st', stop/m68k/watch.s) to route the re-taken trace trap through
| STOP_$WATCH_TRACE, which clears it; FIM_$TRACE tests it (`tst.b').
|
        .section ".text.STOP_$WATCH_TRACE_FLAG","ax",@progbits
        .balign 2

        .globl  STOP_$WATCH_TRACE_FLAG

STOP_$WATCH_TRACE_FLAG:                 | 0xE21596
        .byte   0
        .byte   0                       | 0xE21597
