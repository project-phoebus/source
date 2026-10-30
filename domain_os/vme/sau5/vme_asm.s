|
| vme/sau5/vme_asm.s - VME_ASM, VME_$SPURIOUS_INT: leave a hand-written
| interrupt decoder for the spurious interrupt handler
|
| SAU5 map: "D E23620 VME_ASM size = C" (WIRED_DATA), one symbol,
| VME_$SPURIOUS_INT at its start.  Ten bytes of code and a zero pad word:
|
|   e23620  4cdf 0303       movem.l (sp)+,d0-d1/a0-a1
|   e23624  4ef9 00e2 2c3c  jmp     FIM_$SPURIOUS_INT
|   e2362a  0000
|
| Hand-written (the `_ASM' segment, code in a data section, no frame):
| entered by a jump, not called, from the hand-written decoders that
| saved D0-D1/A0-A1 and found the interrupt not theirs (COLOR2_$INT_DECODE
| jumps here when its vector is not 0xA4); it restores those registers
| and goes on to FIM_$SPURIOUS_INT as if the vector had been spurious.
|
| The SAU5's only: the SAU6's VME_ASM is other code (VME_$SAVE_VME and
| VME_$SAVE), and no other SR10.2 map has the segment.  The Makefile
| assembles */$(TARGET_SAU)/*.s, so only a SAU5 build takes this file;
| the bytes above were checked by assembling it by hand (the SAU5 build
| is not linked yet).
|
        .section ".text.VME_$SPURIOUS_INT","ax",@progbits
        .even

        .globl  VME_$SPURIOUS_INT

VME_$SPURIOUS_INT:                      | 0xE23620
        movem.l (%sp)+,%d0-%d1/%a0-%a1  | e23620  4cdf 0303
        jmp     FIM_$SPURIOUS_INT       | e23624  4ef9 00e2 2c3c
        .word   0                       | e2362a  0000
