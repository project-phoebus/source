|
| fim/m68k/initial_stack_size.s - FIM_$INITIAL_STACK_SIZE
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's
| longword.
|
| SAU2 map: "D E213A0 FIM_UNWIRED size = 4F0", FIM_$INITIAL_STACK_SIZE
| 0xE21824..0xE21828, a longword cell between FIM_$SINGLE_STEP
| (fim/m68k/single_step.s) and FIM_$FAULT_RETURN (fim/sau2/
| fault_return.s); 8 in the image.  The bytes reserved above a new
| process's startup context on its initial stack (PROC2_$CREATE,
| PROC2_$FORK).
|
        .section ".text.FIM_$INITIAL_STACK_SIZE","ax",@progbits
        .balign 2

        .globl  FIM_$INITIAL_STACK_SIZE

FIM_$INITIAL_STACK_SIZE:                | 0xE21824
        .long   8
