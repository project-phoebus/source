|
| ml/m68k/lock.s - ML_$LOCK, ML_$UNLOCK and the shared lock crash stub
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE20B12..0xE20B92
| (ml/README.md has the segment's ML layout):
|   0xE20B12  ML_$LOCK      (lock_id: word by value at (4,SP))
|   0xE20B56  (no symbol)   set_lock_crash: crash with
|                           Illegal_lock_err (0xE20DE4, 0x000A0002,
|                           "illegal lock"), looping on the jsr.  Shared:
|                           PROC1_$SET_LOCK's `bls.b' (0xE20AF8),
|                           PROC1_$CLR_LOCK's `beq.b' (0xE20BA4) and
|                           DI_$ENQ's `bra.w' to the jsr (0xE209B6)
|   0xE20B62  ML_$UNLOCK    (lock_id: word by value at (4,SP))
| PROC1_$CLR_LOCK (0xE20B92) follows, proc1/m68k/clr_lock.s.
|
| ML_$LOCK takes the lock in the PCB first (`bsr.b' into PROC1_$SET_LOCK
| past its argument load, proc1_$set_lock_body 0xE20AE8), then sets the
| lock's byte in LOCK_BYTE under IPL 7; if it was set, it bumps the lock's
| waiter count (LOCK_$EVENT_LISTS entry +0xC), waits on the lock's
| eventcount for that count (one waiter cell on the stack, proc1_$ec_waitn
| 0xE2065A, ec/m68k/wait.s) and tries again.  ML_$UNLOCK clears the byte,
| advances the eventcount (ADVANCE_INT 0xE2072C, ec/m68k/advance_int.s)
| when its value is short of the waiter count, and joins PROC1_$CLR_LOCK's
| body (proc1_$clr_lock_body 0xE20B9E) with A1 = PROC1_$CURRENT_PCB and
| D0 = the lock.
|
        .section ".text.ML_$LOCK","ax",@progbits
        .balign 2

        .globl  ML_$LOCK
        .globl  set_lock_crash
        .globl  ML_$UNLOCK

        .extern proc1_$set_lock_body            | proc1/m68k/set_lock.s
        .extern LOCK_BYTE                       | ml/m68k/lock_data.s
        .extern Illegal_lock_err                | ml/m68k/lock_data.s
        .extern proc1_$ec_waitn                 | ec/m68k/wait.s
        .extern CRASH_SYSTEM                    | misc/m68k/crash_system.s
        .extern ADVANCE_INT                     | ec/m68k/advance_int.s
        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern proc1_$clr_lock_body            | proc1/m68k/clr_lock.s

ML_$LOCK:
        move.w  (0x4,%sp),%d0                   | e20b12  302f 0004
        bsr.s   proc1_$set_lock_body            | e20b16  61d0
.Le20b18:
        lea     (LOCK_BYTE:w,%pc),%a0           | e20b18  41fa 00aa
        move.w  (0x4,%sp),%d0                   | e20b1c  302f 0004
        ori.w   #0x700,%sr                      | e20b20  007c 0700
        bset    #0,(0x0,%a0,%d0.w)              | e20b24  08f0 0000 0000
        bne.s   .Le20b32                        | e20b2a  6606
        andi.w  #0xF8FF,%sr                     | e20b2c  027c f8ff
        rts                                     | e20b30  4e75
.Le20b32:
        move.l  %a3,-(%sp)                      | e20b32  2f0b
        move.l  %a4,-(%sp)                      | e20b34  2f0c
        lsl.w   #4,%d0                          | e20b36  e948
        addq.l  #1,(0x2c,%a0,%d0.w)             | e20b38  52b0 002c
        move.l  (0x2c,%a0,%d0.w),-(%sp)         | e20b3c  2f30 002c
        lea     (%sp),%a3                       | e20b40  47d7
        pea     (0x20,%a0,%d0.w)                | e20b42  4870 0020
        lea     (%sp),%a4                       | e20b46  49d7
        moveq   #1,%d0                          | e20b48  7001
        bsr.w   proc1_$ec_waitn                 | e20b4a  6100 fb0e
        addq.w  #8,%sp                          | e20b4e  504f
        movea.l (%sp)+,%a4                      | e20b50  285f
        movea.l (%sp)+,%a3                      | e20b52  265f
        bra.s   .Le20b18                        | e20b54  60c2
set_lock_crash:
        pea     (Illegal_lock_err:w,%pc)        | e20b56  487a 028c
.Le20b5a:
        jsr     CRASH_SYSTEM                    | e20b5a  4eb9 00e1 e700
        bra.s   .Le20b5a                        | e20b60  60f8
ML_$UNLOCK:
        lea     (LOCK_BYTE:w,%pc),%a0           | e20b62  41fa 0060
        move.w  (0x4,%sp),%d0                   | e20b66  302f 0004
        ori.w   #0x700,%sr                      | e20b6a  007c 0700
        bclr    #0,(0x0,%a0,%d0.w)              | e20b6e  08b0 0000 0000
        lsl.w   #4,%d0                          | e20b74  e948
        move.l  (0x20,%a0,%d0.w),%d1            | e20b76  2230 0020
        cmp.l   (0x2c,%a0,%d0.w),%d1            | e20b7a  b2b0 002c
        beq.s   .Le20b88                        | e20b7e  6708
        lea     (0x20,%a0,%d0.w),%a0            | e20b80  41f0 0020
        bsr.w   ADVANCE_INT                     | e20b84  6100 fba6
.Le20b88:
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20b88  227a df3e
        move.w  (0x4,%sp),%d0                   | e20b8c  302f 0004
        bra.s   proc1_$clr_lock_body            | e20b90  600c
