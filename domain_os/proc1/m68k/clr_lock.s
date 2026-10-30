|
| proc1/m68k/clr_lock.s - PROC1_$CLR_LOCK, release a resource lock
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's encodings, every address operand a relocation resolved against
| the image's.
|
| The tail is the image's branches into PROC1_$INHIBIT_END
| (ml/m68k/exclusion.s), the crash stub is the image's own
| (set_lock_crash, ml/m68k/lock.s), and the PC-relative operand is the
| image's (d16,PC).
|
| Releases a lock by clearing its bit in resource_locks_held (PCB +0x40);
| a lock not held crashes the system ("illegal lock").  The lock depth
| (PCB +0x5A) drops; at zero the release clears the inhibit bit (PCB +0x43
| bit 0) first (`beq.w' to PROC1_$INHIBIT_END+0xE, 0xE20EB0), otherwise it
| goes straight to the shared release tail (`bra.w' to
| proc1_$release_tail, 0xE20EB6): reorder, the deferred re-queue and
| suspend, dispatch, IPL 0.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4", 0xE20B92..0xE20BB6:
|   0xE20B92  PROC1_$CLR_LOCK       (lock_id: word by value at (4,SP));
|                                   raises the IPL
|   0xE20B9E  (no symbol)           proc1_$clr_lock_body: D0 = lock_id,
|                                   A1 = the current PCB, IPL 7;
|                                   ML_$UNLOCK's `bra.b' at 0xE20B90
| ML_$SPIN_LOCK (0xE20BB6) follows, ml/m68k/spin_lock.s.
|
        .section ".text.PROC1_$CLR_LOCK","ax",@progbits
        .balign 2

        .globl  PROC1_$CLR_LOCK
        .globl  proc1_$clr_lock_body

        .extern PROC1_$CURRENT_PCB              | proc1/m68k/proc1_data.s
        .extern set_lock_crash                  | ml/m68k/lock.s
        .extern PROC1_$INHIBIT_END              | ml/m68k/exclusion.s
        .extern proc1_$release_tail             | ml/m68k/exclusion.s

PROC1_$CLR_LOCK:
        move.w  (0x4,%sp),%d0                   | e20b92  302f 0004
        movea.l (PROC1_$CURRENT_PCB:w,%pc),%a1  | e20b96  227a df30
        ori.w   #0x700,%sr                      | e20b9a  007c 0700
proc1_$clr_lock_body:
        move.l  (0x40,%a1),%d1                  | e20b9e  2229 0040
        bclr    %d0,%d1                         | e20ba2  0181
        beq.s   set_lock_crash                  | e20ba4  67b0
        move.l  %d1,(0x40,%a1)                  | e20ba6  2341 0040
        subq.w  #1,(0x5a,%a1)                   | e20baa  5369 005a
        beq.w   PROC1_$INHIBIT_END+0xe          | e20bae  6700 0300
        bra.w   proc1_$release_tail             | e20bb2  6000 0302
