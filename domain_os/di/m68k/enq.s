|
| di/m68k/enq.s - DI_$ENQ, queue a deferred-interrupt element
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the image's
| encodings, every address operand a relocation resolved against the
| image's.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", DI_$ENQ 0xE209A8..0xE209D6
| (46 bytes; DI_$INIT_Q_ELEM follows, di/m68k/init_q_elem.s).  No frame;
| the arguments are read off SP: DI_$ENQ(arg1, arg2, elem), each a
| longword pushed by value.  The element (16 bytes, di/di.ins.pas): next
| +0x0, arg1 +0x4, arg2 +0x8, the queued flag byte +0xC.
|
| An element already queued crashes the system: `pea' of the status at
| 0xE20DF4 (0x000A000C, "bad deferred interrupt queue", in the status
| cells after LOCK_$EVENT_LISTS, ml/m68k/lock_data.s; reached here as
| Illegal_lock_err+0x10) and `bra.w' to the `jsr CRASH_SYSTEM' of the
| shared crash stub at 0xE20B5A (set_lock_crash+4, ml/m68k/lock.s), which
| loops on the jsr.  Otherwise the element is pushed on DI_$Q_HEAD
| (proc1/m68k/proc1_data.s), read PC-relative and written absolute.
| Callers: TIME_$TIMER_HANDLER (0xE2B226, 0xE2B25E).
|
        .section ".text.DI_$ENQ","ax",@progbits
        .balign 2

        .globl  DI_$ENQ

        .extern DI_$Q_HEAD                      | proc1/m68k/proc1_data.s
        .extern Illegal_lock_err                | ml/m68k/lock_data.s
        .extern set_lock_crash                  | ml/m68k/lock.s

DI_$ENQ:
        movea.l (0xc,%sp),%a0                   | e209a8  206f 000c
        tst.b   (0xc,%a0)                       | e209ac  4a28 000c
        beq.s   .Le209ba                        | e209b0  6708
        pea     (Illegal_lock_err+0x10:w,%pc)   | e209b2  487a 0440
        bra.w   set_lock_crash+0x4              | e209b6  6000 01a2
.Le209ba:
        move.l  (DI_$Q_HEAD:w,%pc),(%a0)        | e209ba  20ba fc46
        move.l  %a0,(DI_$Q_HEAD).l              | e209be  23c8 00e2 0602
        move.l  (0x4,%sp),(0x4,%a0)             | e209c4  216f 0004 0004
        move.l  (0x8,%sp),(0x8,%a0)             | e209ca  216f 0008 0008
        st      (0xc,%a0)                       | e209d0  50e8 000c
        rts                                     | e209d4  4e75
