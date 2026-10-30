|
| gpu/sau5/gpu_asm.s - GPU_ASM: the graphics processor driver's
| hand-written data and its interrupt handler, GPU_$INTERRUPT
|
| SAU5 map: "D E285DC GPU_ASM size = 5C" (WIRED_DATA), the symbols:
|
|   0xE285DC  GPU_$DONE_EC     an eventcount, 12 bytes, zero
|   0xE285E8  GPU_$PAGE_EC     an eventcount, 12 bytes, zero
|   0xE285F4  GPU_$USER_PID    a word, the process that holds the
|                              processor (gpu/lock.pas)
|   0xE285F6  GPU_$PRESENT     a boolean byte and its pad
|   0xE285F8  GPU_$ML_LOCK     an exclusion lock, 0x14 bytes to the code
|   0xE28618  GPU_$INTERRUPT   the handler
|
| GPU_$COLD_INIT initializes the eventcounts and the lock (gpu/cold_init.pas);
| in the image every byte of the data is zero.
|
| Hand-written (the `_ASM' segment, code in a data section, no frame;
| `cmp.b' with an immediate source in its non-immediate form, which
| compiled code does not use): VME_$INIT puts GPU_$INTERRUPT in
| VME_$INT_VEC's level 4 (vme/vme.ins.pas), and VME_$INT calls it with
| the bus's vector, a longword by value.  For vector 0xA0 (the
| processor's done interrupt) it advances GPU_$DONE_EC, for 0xA1 (its
| page fault) GPU_$PAGE_EC, each with EC_$ADVANCE_WITHOUT_DISPATCH, and
| returns true in D0's byte; any other vector returns false.  The two
| advances are reached through two unnamed stubs before the handler's
| entry, each pushing its eventcount's address and branching to the
| shared call.  The SAU6's GPU_ASM (0x60 bytes) names its stubs
| GPU_$DONE_INT and GPU_$PAGE_INT; the SAU5 map has no symbols for them,
| so they are local labels here.
|
| The Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU5 build takes
| this file.  The bytes were checked against the image by assembling the
| file (`m68k-elf-as', `objdump -d'): the 0x5C bytes are the image's,
| the jsr's absolute address a relocation.
|
        .section ".text.GPU_$DONE_EC","ax",@progbits
        .even

        .globl  GPU_$DONE_EC
        .globl  GPU_$PAGE_EC
        .globl  GPU_$USER_PID
        .globl  GPU_$PRESENT
        .globl  GPU_$ML_LOCK
        .globl  GPU_$INTERRUPT

GPU_$DONE_EC:                           | 0xE285DC
        .long   0, 0, 0
GPU_$PAGE_EC:                           | 0xE285E8
        .long   0, 0, 0
GPU_$USER_PID:                          | 0xE285F4
        .word   0
GPU_$PRESENT:                           | 0xE285F6
        .byte   0, 0
GPU_$ML_LOCK:                           | 0xE285F8
        .long   0, 0, 0, 0, 0

.Ldone_int:                             | 0xE2860C
        pea     %pc@(GPU_$DONE_EC)      | e2860c  487a ffce
        bras    .Ladvance               | e28610  601a
.Lpage_int:                             | 0xE28612
        pea     %pc@(GPU_$PAGE_EC)      | e28612  487a ffd4
        bras    .Ladvance               | e28616  6014

GPU_$INTERRUPT:                         | 0xE28618
        movel   %sp@(4),%d0             | e28618  202f 0004  the vector
        .short  0xb03c, 0x00a0          | e2861c  cmp.b #0xa0,%d0
        beqs    .Ldone_int              | e28620  67ea
        .short  0xb03c, 0x00a1          | e28622  cmp.b #0xa1,%d0
        beqs    .Lpage_int              | e28626  67ea
        clrb    %d0                     | e28628  4200  not ours: false
        bras    .Lreturn                | e2862a  600a
.Ladvance:                              | 0xE2862C
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH | e2862c  4eb9 00e2 13e0
        addql   #4,%sp                  | e28632  588f
        st      %d0                     | e28634  50c0  true
.Lreturn:
        rts                             | e28636  4e75
