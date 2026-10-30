|
| proc1/m68k/atomic_op.s - PROC1_$BEGIN_ATOMIC_OP, PROC1_$END_ATOMIC_OP
| and the dispatcher's crash stub between them
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE209E6..0xE20A18:
|   0xE209E6  PROC1_$BEGIN_ATOMIC_OP  bump PROC1_$ATOMIC_OP_DEPTH (0xE2060E)
|   0xE209EE  (no symbol)             atomic_op_error: crash with
|                                     Bad_atomic_operation_err (0xE20DE8,
|                                     0x000A0007, ml/m68k/lock_data.s),
|                                     looping on the jsr; reached by
|                                     PROC1_$DISPATCH_INT2's `bne.b' at
|                                     0xE20A32 (proc1/m68k/dispatch.s)
|   0xE209FA  PROC1_$END_ATOMIC_OP    drop the depth; on an overflow
|                                     (`bvc' not taken) raise the IPL,
|                                     zero the depth, dispatch
|                                     (PROC1_$DISPATCH_INT 0xE20A20) and
|                                     force the IPL to 0
| PROC1_$DISPATCH (0xE20A18) follows, proc1/m68k/dispatch.s, which
| branches here, as the image does.
|
        .section ".text.PROC1_$BEGIN_ATOMIC_OP","ax",@progbits
        .balign 2

        .globl  PROC1_$BEGIN_ATOMIC_OP
        .globl  atomic_op_error
        .globl  PROC1_$END_ATOMIC_OP

        .extern PROC1_$ATOMIC_OP_DEPTH          | proc1/m68k/proc1_data.s
        .extern Bad_atomic_operation_err        | ml/m68k/lock_data.s
        .extern CRASH_SYSTEM                    | misc/m68k/crash_system.s
        .extern PROC1_$DISPATCH_INT             | proc1/m68k/dispatch.s

PROC1_$BEGIN_ATOMIC_OP:
        addq.w  #1,(PROC1_$ATOMIC_OP_DEPTH).l   | e209e6  5279 00e2 060e
        rts                                     | e209ec  4e75
atomic_op_error:
        pea     (Bad_atomic_operation_err:w,%pc)| e209ee  487a 03f8
.Le209f2:
        jsr     CRASH_SYSTEM                    | e209f2  4eb9 00e1 e700
        bra.s   .Le209f2                        | e209f8  60f8
PROC1_$END_ATOMIC_OP:
        subq.w  #1,(PROC1_$ATOMIC_OP_DEPTH).l   | e209fa  5379 00e2 060e
        bvc.s   .Le20a16                        | e20a00  6814
        ori.w   #0x700,%sr                      | e20a02  007c 0700
        move.w  #0,(PROC1_$ATOMIC_OP_DEPTH).l   | e20a06  33fc 0000 00e2 060e
        bsr.w   PROC1_$DISPATCH_INT             | e20a0e  6100 0010
        andi.w  #0xF8FF,%sr                     | e20a12  027c f8ff
.Le20a16:
        rts                                     | e20a16  4e75
