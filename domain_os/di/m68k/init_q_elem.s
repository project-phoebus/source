|
| di/m68k/init_q_elem.s - DI_$INIT_Q_ELEM, clear a deferred-interrupt
| element
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's
| encodings.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", DI_$INIT_Q_ELEM
| 0xE209D6..0xE209E6 (16 bytes; PROC1_$BEGIN_ATOMIC_OP follows,
| proc1/m68k/atomic_op.s).  No frame: the element's address is read off
| SP, and its four longwords are cleared with a `dbf' loop (count 3).
|
        .section ".text.DI_$INIT_Q_ELEM","ax",@progbits
        .balign 2

        .globl  DI_$INIT_Q_ELEM

DI_$INIT_Q_ELEM:
        movea.l (0x4,%sp),%a0                   | e209d6  206f 0004
        move.w  #3,%d0                          | e209da  303c 0003
.Le209de:
        clr.l   (%a0)+                          | e209de  4298
        dbf     %d0,.Le209de                    | e209e0  51c8 fffc
        rts                                     | e209e4  4e75
