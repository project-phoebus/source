|
| ml/m68k/exclusion.s - the exclusion locks (ML_$EXCLUSION_START, _INIT,
| _CHECK, ML_$COND_EXCLUSION_START, _STOP, ML_$EXCLUSION_STOP) and the
| inhibit routines they end in (PROC1_$INHIBIT_END with the release tail,
| PROC1_$INHIBIT_CHECK, PROC1_$INHIBIT_BEGIN)
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| One section for both groups: ML_$EXCLUSION_STOP reaches
| PROC1_$INHIBIT_END with byte branches (`blt.b' 0xE20E86, `beq.b'
| 0xE20E9A), which gas cannot emit to another section this far into one
| (it range-checks the in-place value of an external PC8 fixup).
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE20DF8..0xE20F0C, after
| the status cells that end LOCK_$EVENT_LISTS (ml/m68k/lock_data.s);
| PROC1_$GET_USP (0xE20F0C) follows, proc1/m68k/misc.s.
|
| The exclusion locks, 0xE20DF8..0xE20EA2.  Every routine takes the
| exclusion's address at (4,SP); the exclusion (ml/ml.ins.pas
| ml_$exclusion_t, 0x12 bytes): an eventcount +0x0 (value, head, tail),
| the waiter count +0xC, the state word +0x10 (-1 free).
|
|   ML_$EXCLUSION_START       inhibit (PCB nesting depth +0x5A up, PCB
|                             +0x43 bit 0 set), take the state word; if
|                             it was taken, wait on the eventcount for
|                             the bumped waiter count under IPL 7
|                             (proc1_$ec_waitn 0xE2065A, ec/m68k/wait.s,
|                             one cell on the stack)
|   ML_$EXCLUSION_INIT        value 0, head = tail = itself, count 0,
|                             state -1
|   ML_$EXCLUSION_CHECK       D0 = state >= 0 (sge)
|   ML_$COND_EXCLUSION_START  under a saved and raised SR, D0 = state >= 0,
|                             and if it was free (-1) take it (state 0)
|   ML_$COND_EXCLUSION_STOP   state down by one, nothing else
|   ML_$EXCLUSION_STOP        state down by one; if no waiter (< 0) end
|                             the inhibit (`blt.b' to PROC1_$INHIBIT_END);
|                             else advance the eventcount under IPL 7
|                             (ADVANCE_INT 0xE2072C), drop the nesting
|                             depth, and at zero join PROC1_$INHIBIT_END
|                             past its IPL raise (`beq.b' to 0xE20EB0,
|                             PROC1_$INHIBIT_END+0xE), else force IPL 0
|
| The inhibit routines, 0xE20EA2..0xE20F0C:
|   0xE20EA2  PROC1_$INHIBIT_END    nesting depth (PCB +0x5A) down; at
|                                   zero raise the IPL and fall into:
|   0xE20EB0  (PROC1_$INHIBIT_END+0xE)  clear PCB +0x43 bit 0 (the
|                                   inhibit bit, bit 0 of
|                                   resource_locks_held); the target of
|                                   PROC1_$CLR_LOCK's `beq.w' (0xE20BAE)
|                                   and ML_$EXCLUSION_STOP's `beq.b'
|                                   (0xE20E9A)
|   0xE20EB6  (no symbol)           proc1_$release_tail
|                                   (PROC1_$CLR_LOCK's `bra.w' at
|                                   0xE20BB2): reorder the ready list
|                                   (proc1_$reorder_if_needed_int
|                                   0xE207D8); with no lock held, honour a
|                                   deferred re-queue (PCB +0x55 bit 4:
|                                   remove and re-add,
|                                   proc1_$remove_from_ready_list_int
|                                   0xE206D6, proc1_$add_ready_body_int
|                                   0xE20824) and a deferred suspend (bit
|                                   2: PROC1_$TRY_TO_SUSPEND, Pascal);
|                                   then dispatch (PROC1_$DISPATCH_INT2
|                                   0xE20A24) and force IPL 0
|   0xE20EF0  PROC1_$INHIBIT_CHECK  (pcb: pointer at (4,SP)) D0 = its
|                                   nesting depth <> 0 (sne)
|   0xE20EFC  PROC1_$INHIBIT_BEGIN  depth up, inhibit bit set
|
        .section ".text.ML_$EXCLUSION_START","ax",@progbits
        .balign 2

        .globl  ML_$EXCLUSION_START
        .globl  ML_$EXCLUSION_INIT
        .globl  ML_$EXCLUSION_CHECK
        .globl  ML_$COND_EXCLUSION_START
        .globl  ML_$COND_EXCLUSION_STOP
        .globl  ML_$EXCLUSION_STOP
        .globl  PROC1_$INHIBIT_END
        .globl  proc1_$release_tail
        .globl  PROC1_$INHIBIT_CHECK
        .globl  PROC1_$INHIBIT_BEGIN

        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern proc1_$ec_waitn                 | ec/m68k/wait.s
        .extern ADVANCE_INT                     | ec/m68k/advance_int.s
        .extern proc1_$reorder_if_needed_int    | proc1/m68k/ready_list.s
        .extern proc1_$remove_from_ready_list_int | proc1/m68k/ready_list.s
        .extern proc1_$add_ready_body_int       | proc1/m68k/ready_list.s
        .extern PROC1_$TRY_TO_SUSPEND           | proc1/try_to_suspend.pas
        .extern PROC1_$DISPATCH_INT2            | proc1/m68k/dispatch.s

ML_$EXCLUSION_START:
        movea.l (0x4,%sp),%a0                   | e20df8  206f 0004
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20dfc  227a dcca
        addq.w  #1,(0x5a,%a1)                   | e20e00  5269 005a
        bset    #0,(0x43,%a1)                   | e20e04  08e9 0000 0043
        addq.w  #1,(0x10,%a0)                   | e20e0a  5268 0010
        beq.s   .Le20e32                        | e20e0e  6722
        ori.w   #0x700,%sr                      | e20e10  007c 0700
        addq.l  #1,(0xc,%a0)                    | e20e14  52a8 000c
        move.l  %a3,-(%sp)                      | e20e18  2f0b
        move.l  %a4,-(%sp)                      | e20e1a  2f0c
        move.l  (0xc,%a0),-(%sp)                | e20e1c  2f28 000c
        lea     (%sp),%a3                       | e20e20  47d7
        pea     (%a0)                           | e20e22  4850
        lea     (%sp),%a4                       | e20e24  49d7
        moveq   #1,%d0                          | e20e26  7001
        bsr.w   proc1_$ec_waitn                 | e20e28  6100 f830
        addq.w  #8,%sp                          | e20e2c  504f
        movea.l (%sp)+,%a4                      | e20e2e  285f
        movea.l (%sp)+,%a3                      | e20e30  265f
.Le20e32:
        rts                                     | e20e32  4e75
ML_$EXCLUSION_INIT:
        movea.l (0x4,%sp),%a0                   | e20e34  206f 0004
        movea.l %a0,%a1                         | e20e38  2248
        moveq   #0,%d0                          | e20e3a  7000
        move.l  %d0,(%a1)+                      | e20e3c  22c0
        move.l  %a0,(%a1)+                      | e20e3e  22c8
        move.l  %a0,(%a1)+                      | e20e40  22c8
        move.l  %d0,(%a1)+                      | e20e42  22c0
        move.w  #-1,(%a1)                       | e20e44  32bc ffff
        rts                                     | e20e48  4e75
ML_$EXCLUSION_CHECK:
        movea.l (0x4,%sp),%a0                   | e20e4a  206f 0004
        tst.w   (0x10,%a0)                      | e20e4e  4a68 0010
        sge     %d0                             | e20e52  5cc0
        rts                                     | e20e54  4e75
ML_$COND_EXCLUSION_START:
        movea.l (0x4,%sp),%a0                   | e20e56  206f 0004
        move.w  %sr,-(%sp)                      | e20e5a  40e7
        ori.w   #0x700,%sr                      | e20e5c  007c 0700
        tst.w   (0x10,%a0)                      | e20e60  4a68 0010
        sge     %d0                             | e20e64  5cc0
        bge.w   .Le20e70                        | e20e66  6c00 0008
        move.w  #0,(0x10,%a0)                   | e20e6a  317c 0000 0010
.Le20e70:
        move.w  (%sp)+,%sr                      | e20e70  46df
        rts                                     | e20e72  4e75
ML_$COND_EXCLUSION_STOP:
        movea.l (0x4,%sp),%a0                   | e20e74  206f 0004
        subq.w  #1,(0x10,%a0)                   | e20e78  5368 0010
        rts                                     | e20e7c  4e75
ML_$EXCLUSION_STOP:
        movea.l (0x4,%sp),%a0                   | e20e7e  206f 0004
        subq.w  #1,(0x10,%a0)                   | e20e82  5368 0010
        blt.s   PROC1_$INHIBIT_END              | e20e86  6d1a
        lea     (%a0),%a0                       | e20e88  41d0
        ori.w   #0x700,%sr                      | e20e8a  007c 0700
        bsr.w   ADVANCE_INT                     | e20e8e  6100 f89c
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20e92  227a dc34
        subq.w  #1,(0x5a,%a1)                   | e20e96  5369 005a
        beq.s   .Le20eb0                        | e20e9a  6714
        andi.w  #0xF8FF,%sr                     | e20e9c  027c f8ff
        rts                                     | e20ea0  4e75
PROC1_$INHIBIT_END:
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20ea2  227a dc24
        subq.w  #1,(0x5a,%a1)                   | e20ea6  5369 005a
        bne.s   .Le20eee                        | e20eaa  6642
        ori.w   #0x700,%sr                      | e20eac  007c 0700
.Le20eb0:
        bclr    #0,(0x43,%a1)                   | e20eb0  08a9 0000 0043
proc1_$release_tail:
        bsr.w   proc1_$reorder_if_needed_int    | e20eb6  6100 f920
        tst.l   (0x40,%a1)                      | e20eba  4aa9 0040
        bne.s   .Le20ee6                        | e20ebe  6626
        bclr    #4,(0x55,%a1)                   | e20ec0  08a9 0004 0055
        beq.s   .Le20ed0                        | e20ec6  6708
        bsr.w   proc1_$remove_from_ready_list_int| e20ec8  6100 f80c
        bsr.w   proc1_$add_ready_body_int       | e20ecc  6100 f956
.Le20ed0:
        btst    #2,(0x55,%a1)                   | e20ed0  0829 0002 0055
        beq.s   .Le20ee6                        | e20ed6  670e
        pea     (%a1)                           | e20ed8  4851
        jsr     PROC1_$TRY_TO_SUSPEND           | e20eda  4eb9 00e1 471c
        addq.w  #4,%sp                          | e20ee0  584f
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20ee2  227a dbe4
.Le20ee6:
        bsr.w   PROC1_$DISPATCH_INT2            | e20ee6  6100 fb3c
        andi.w  #0xF8FF,%sr                     | e20eea  027c f8ff
.Le20eee:
        rts                                     | e20eee  4e75
PROC1_$INHIBIT_CHECK:
        movea.l (0x4,%sp),%a1                   | e20ef0  226f 0004
        tst.w   (0x5a,%a1)                      | e20ef4  4a69 005a
        sne     %d0                             | e20ef8  56c0
        rts                                     | e20efa  4e75
PROC1_$INHIBIT_BEGIN:
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20efc  227a dbca
        addq.w  #1,(0x5a,%a1)                   | e20f00  5269 005a
        bset    #0,(0x43,%a1)                   | e20f04  08e9 0000 0043
        rts                                     | e20f0a  4e75
