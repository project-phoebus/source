|
| ec/m68k/wait.s - EC_$WAIT, EC_$WAITN and their shared body
| proc1_$ec_waitn, the level-1 eventcount waits
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| SAU2 map: in "D E1EAC8 PROC1_ASM size = 24A4", 0xE20610..0xE206D2:
|   0xE20610  EC_$WAIT      (ecs: 3 pointers, vals: 3 longwords, both by
|                            value on the stack; the list ends at the
|                            first nil in ecs[1..2], ecs[0] is never
|                            tested); returns the 0-based index
|   0xE2063E  EC_$WAITN     (ecs, vals: pointers to arrays; count: a
|                            word by value); returns the 1-based index
|   0xE2065A  (no symbol)   proc1_$ec_waitn, the body: A1 = pcb,
|                            A4 = &ecs[0], A3 = &vals[0],
|                            D0.w = count; also reached by `bsr.w' from
|                            ML_$LOCK (0xE20B4A) and ML_$EXCLUSION_START
|                            (0xE20E28)
| PROC1_$REMOVE_READY (0xE206D2) follows, proc1/m68k/ready_list.s.
|
| proc1_$ec_waitn links one 16-byte waiter cell per eventcount on its own
| stack (value wanted, prev, next = ec, pcb), stopping at the first
| eventcount already satisfied; only when none is does the process leave
| the ready list (proc1_$remove_from_ready_list_int, 0xE206D6), set
| PCB bit 0 of +0x55 (waiting), stamp wait_start (+0x3C) with
| TIME_$CLOCKH and dispatch (PROC1_$DISPATCH_INT2, 0xE20A24).  The
| teardown unlinks every cell, newest first, and D0 ends as the lowest
| satisfied index plus one (0 when none); a count <= 0 returns the count.
| The IPL is raised at entry (no SR saved) and forced to 0 at exit.
|
        .section ".text.EC_$WAIT","ax",@progbits
        .balign 2

        .globl  EC_$WAIT
        .globl  EC_$WAITN
        .globl  proc1_$ec_waitn

        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern proc1_$remove_from_ready_list_int | proc1/m68k/ready_list.s
        .extern PROC1_$DISPATCH_INT2            | proc1/m68k/dispatch.s
        .extern TIME_$CLOCKH                    | time/m68k/time_asm.s

EC_$WAIT:
        movem.l %a3-%a4,-(%sp)                  | e20610  48e7 0018
        lea     (0x10,%sp),%a0                  | e20614  41ef 0010
        moveq   #1,%d0                          | e20618  7001
        tst.l   (%a0)+                          | e2061a  4a98
        beq.s   .Le20626                        | e2061c  6708
        moveq   #2,%d0                          | e2061e  7002
        tst.l   (%a0)+                          | e20620  4a98
        beq.s   .Le20626                        | e20622  6702
        moveq   #3,%d0                          | e20624  7003
.Le20626:
        lea     (0xc,%sp),%a4                   | e20626  49ef 000c
        lea     (0x18,%sp),%a3                  | e2062a  47ef 0018
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e2062e  227a e498
        bsr.w   proc1_$ec_waitn                 | e20632  6100 0026
        movem.l (%sp)+,%a3-%a4                  | e20636  4cdf 1800
        subq.w  #1,%d0                          | e2063a  5340
        rts                                     | e2063c  4e75
EC_$WAITN:
        move.l  %a3,-(%sp)                      | e2063e  2f0b
        move.l  %a4,-(%sp)                      | e20640  2f0c
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20642  227a e484
        movea.l (0xc,%sp),%a4                   | e20646  286f 000c
        movea.l (0x10,%sp),%a3                  | e2064a  266f 0010
        move.w  (0x14,%sp),%d0                  | e2064e  302f 0014
        bsr.s   proc1_$ec_waitn                 | e20652  6106
        movea.l (%sp)+,%a4                      | e20654  285f
        movea.l (%sp)+,%a3                      | e20656  265f
        rts                                     | e20658  4e75
proc1_$ec_waitn:
        move.l  %d2,-(%sp)                      | e2065a  2f02
        move.l  %a2,-(%sp)                      | e2065c  2f0a
        clr.w   %d2                             | e2065e  4242
        ori.w   #0x700,%sr                      | e20660  007c 0700
        subq.w  #1,%d0                          | e20664  5340
        blt.s   .Le206c6                        | e20666  6d5e
.Le20668:
        addq.w  #1,%d2                          | e20668  5242
        movea.l (%a4)+,%a0                      | e2066a  205c
        move.l  (%a3)+,%d1                      | e2066c  221b
        movea.l (0x4,%a0),%a2                   | e2066e  2468 0004
        move.l  %a1,-(%sp)                      | e20672  2f09
        move.l  %a0,-(%sp)                      | e20674  2f08
        move.l  %a2,-(%sp)                      | e20676  2f0a
        move.l  %d1,-(%sp)                      | e20678  2f01
        move.l  %sp,(0x8,%a2)                   | e2067a  254f 0008
        move.l  %sp,(0x4,%a0)                   | e2067e  214f 0004
        sub.l   (%a0),%d1                       | e20682  9290
        tst.l   %d1                             | e20684  4a81
        dble    %d0,.Le20668                    | e20686  5fc8 ffe0
        ble.s   .Le206a0                        | e2068a  6f14
        bsr.s   proc1_$remove_from_ready_list_int| e2068c  6148
        bset    #0,(0x55,%a1)                   | e2068e  08e9 0000 0055
        move.l  (TIME_$CLOCKH).l,(0x3c,%a1)     | e20694  2379 00e2 b0d4 003c
        bsr.w   PROC1_$DISPATCH_INT2            | e2069c  6100 0386
.Le206a0:
        moveq   #-1,%d0                         | e206a0  70ff
        subq.w  #1,%d2                          | e206a2  5342
.Le206a4:
        move.l  (%sp)+,%d1                      | e206a4  221f
        movea.l (%sp)+,%a2                      | e206a6  245f
        movea.l (%sp)+,%a0                      | e206a8  205f
        movea.l (%sp)+,%a1                      | e206aa  225f
        move.l  %a2,(0x4,%a0)                   | e206ac  214a 0004
        move.l  %a0,(0x8,%a2)                   | e206b0  2548 0008
        movea.l -(%a4),%a2                      | e206b4  2464
        sub.l   (%a2),%d1                       | e206b6  9292
        tst.l   %d1                             | e206b8  4a81
        dble    %d2,.Le206a4                    | e206ba  5fca ffe8
        bgt.s   .Le206c6                        | e206be  6e06
        move.l  %d2,%d0                         | e206c0  2002
        dbf     %d2,.Le206a4                    | e206c2  51ca ffe0
.Le206c6:
        andi.w  #0xF8FF,%sr                     | e206c6  027c f8ff
        addq.w  #1,%d0                          | e206ca  5240
        movea.l (%sp)+,%a2                      | e206cc  245f
        move.l  (%sp)+,%d2                      | e206ce  241f
        rts                                     | e206d0  4e75
