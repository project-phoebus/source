|
| gpu/sau6/gpu_asm.s - GPU_ASM: the graphics processor driver's
| hand-written data and its two interrupt handlers, GPU_$DONE_INT and
| GPU_$PAGE_INT
|
| SAU6 map: "D 7802A9F8 GPU_ASM size = 60" (WIRED_DATA), the symbols:
|
|   0x7802A9F8  GPU_$DONE_EC     an eventcount, 12 bytes, zero
|   0x7802AA04  GPU_$PAGE_EC     an eventcount, 12 bytes, zero
|   0x7802AA10  GPU_$USER_PID    a word, the process that holds the
|                                processor (gpu/lock.pas)
|   0x7802AA12  GPU_$PRESENT     a boolean byte and its pad
|   0x7802AA14  GPU_$ML_LOCK     an exclusion lock, 0x14 bytes
|   0x7802AA28  GPU_$DONE_INT    the processor's done interrupt
|   0x7802AA40  GPU_$PAGE_INT    its page-fault interrupt
|
| GPU_$COLD_INIT initializes the eventcounts and the lock and puts the
| two handlers in GPU_DONE_VEC (0x280) and GPU_PAGE_VEC (0x284)
| (gpu/cold_init.pas, `gpu_own_vectors'); in the image every byte of
| the data is zero.
|
| Hand-written (the `_ASM' segment, code in a data section, no frame,
| left by a jump).  Each handler is entered by its own vector: it raises
| the IPL to 7, saves D0-D1/A0-A1, switches to the interrupt stack
| (IO_$USE_INT_STACK) and leaves through PROC1_$INT_ADVANCE with its
| eventcount in A0, as the SAU2's interrupt exits.  The SAU5's GPU_ASM
| (gpu/sau5/gpu_asm.s) has one handler, GPU_$INTERRUPT, entered from
| VME_$INT with the vector.
|
| The Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU6 build takes
| this file.  Every byte was checked against the image by assembling the
| file and linking it at the segment's address with the SAU6 map's
| addresses for the other symbols.
|
        .section ".text.GPU_$DONE_EC","ax",@progbits
        .even
        .globl  GPU_$DONE_EC
        .globl  GPU_$PAGE_EC
        .globl  GPU_$USER_PID
        .globl  GPU_$PRESENT
        .globl  GPU_$ML_LOCK
        .globl  GPU_$DONE_INT
        .globl  GPU_$PAGE_INT
GPU_$DONE_EC:                           | 0x7802A9F8
        .long   0, 0, 0
GPU_$PAGE_EC:                           | 0x7802AA04
        .long   0, 0, 0
GPU_$USER_PID:                          | 0x7802AA10
        .word   0
GPU_$PRESENT:                           | 0x7802AA12
        .byte   0, 0
GPU_$ML_LOCK:                           | 0x7802AA14
        .long   0, 0, 0, 0, 0
GPU_$DONE_INT:                          | 0x7802AA28
        oriw    #0x700,%sr              | 7802aa28  007c 0700  IPL 7
        moveml  %d0-%d1/%a0-%a1,%sp@-   | 7802aa2c  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | 7802aa30  4eb9 7803 7026
        lea     %pc@(GPU_$DONE_EC),%a0  | 7802aa36  41fa ffc0
        jmp     PROC1_$INT_ADVANCE      | 7802aa3a  4ef9 7802 2e96
GPU_$PAGE_INT:                          | 0x7802AA40
        oriw    #0x700,%sr              | 7802aa40  007c 0700
        moveml  %d0-%d1/%a0-%a1,%sp@-   | 7802aa44  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | 7802aa48  4eb9 7803 7026
        lea     %pc@(GPU_$PAGE_EC),%a0  | 7802aa4e  41fa ffb4
        jmp     PROC1_$INT_ADVANCE      | 7802aa52  4ef9 7802 2e96
