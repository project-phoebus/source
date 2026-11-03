|
| proc1/m68k/set_lock.s - PROC1_$SET_LOCK, acquire a resource lock
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| The PC-relative operands are the image's (d16,PC), and the crash stub
| and its status are the image's own (set_lock_crash, ml/m68k/lock.s;
| Illegal_lock_err, ml/m68k/lock_data.s).
|
| Acquires a lock by setting a bit in the process's resource_locks_held
| bitmask (PCB +0x40).  The lock is identified by an ID (0-31).  The new
| lock's bit must be above every lock held (the mask compares higher than
| the held set), else the system crashes ("illegal lock").  A process that
| is not the ready one (PROC1_$READY_PCB's nextp) may be reordered in the
| ready list (proc1_$reorder_if_needed_int, under a saved and raised SR).
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE20AE4..0xE20B12:
|   0xE20AE4  PROC1_$SET_LOCK       (lock_id: word by value at (4,SP))
|   0xE20AE8  (no symbol)           proc1_$set_lock_body: lock_id in D0;
|                                   ML_$LOCK's `bsr.b' at 0xE20B16
| ML_$LOCK (0xE20B12) follows, ml/m68k/lock.s.
|
| PCB offsets used: 0x40 resource_locks_held, 0x5A lock depth counter.
|
        .section ".text.PROC1_$SET_LOCK","ax",@progbits
        .balign 2

        .globl  PROC1_$SET_LOCK
        .globl  proc1_$set_lock_body

        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern PROC1_$READY_PCB                | proc1/m68k/proc1_data.s
        .extern set_lock_crash                  | ml/m68k/lock.s
        .extern proc1_$reorder_if_needed_int    | proc1/m68k/ready_list.s

PROC1_$SET_LOCK:
        move.w  (0x4,%sp),%d0                   | e20ae4  302f 0004
proc1_$set_lock_body:
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20ae8  227a dfde
        addq.w  #1,(0x5a,%a1)                   | e20aec  5269 005a
        moveq   #0,%d1                          | e20af0  7200
        bset    %d0,%d1                         | e20af2  01c1
        cmp.l   (0x40,%a1),%d1                  | e20af4  b2a9 0040
        bls.s   set_lock_crash                  | e20af8  635c
        or.l    %d1,(0x40,%a1)                  | e20afa  83a9 0040
        cmpa.l  (PROC1_$READY_PCB:w,%pc),%a1    | e20afe  b3fa e13a
        beq.s   .Le20b10                        | e20b02  670c
        move.w  %sr,-(%sp)                      | e20b04  40e7
        ori.w   #0x700,%sr                      | e20b06  007c 0700
        bsr.w   proc1_$reorder_if_needed_int    | e20b0a  6100 fccc
        move.w  (%sp)+,%sr                      | e20b0e  46df
.Le20b10:
        rts                                     | e20b10  4e75
