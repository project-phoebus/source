|
| io/m68k/saved_os_sp.s - IO_$SAVED_OS_SP, the OS stack pointer saved
| while an interrupt runs on the interrupt stack
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's four
| zero bytes.
|
| SAU2 map: "D E2E800 IO_$TBLS size = 480", IO_$SAVED_OS_SP 0xE2E822..
| 0xE2E826, a longword between IO_$TRAP (io/m68k/trap.s) and
| IO_$USE_INT_STACK (io/m68k/use_int_stack.s); zero in the image.
| IO_$USE_INT_STACK stores SP there when it switches to the interrupt
| stack and tests it to tell whether it already has; IO_$COND_SWITCH_BACK
| and PROC1_$INT_EXIT reload SP from it and clear it.
|
        .section ".text.IO_$SAVED_OS_SP","ax",@progbits
        .balign 2

        .globl  IO_$SAVED_OS_SP

IO_$SAVED_OS_SP:                        | 0xE2E822
        .long   0
