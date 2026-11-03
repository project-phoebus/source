|
| proc1/m68k/proc1_data.s - the data at the head of the hand-written
| PROC1_ASM segment: the current PCB, the PCB table and the 64 PCBs, the
| timeslice table, PROC1_$SUSPEND_EC and the dispatcher's cells
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): every
| byte is compared with the image, every pointer is a relocation resolved
| against the image's longword.
|
| SAU2 map: "D E1EAC8 PROC1_ASM size = 24A4" (0xE1EAC8..0xE20F6C), the
| hand-written proc1/ec/ml/di segment of .DATA.  This file holds its first
| 0x1B48 bytes, 0xE1EAC8..0xE20610, up to EC_$WAIT (ec/m68k/wait.s); the
| map symbols here:
|
|   0xE1EAC8  PROC1_$CURRENT_PCB   4      the running process's PCB
|   0xE1EACC  PCBS                 65 * 4 PCB pointer per pid, 0 for pid 0
|   0xE1EBD0  PROC1_$READY_COUNT   2      processes on the ready list
|   0xE1EBD2  (proc1_$pcb_pool)    64 * 0x68  the PCBs of pids 1..64
|   0xE1EC3A  PROC1_$READY_PCB            the PCB of pid 2 (the null
|                                         process), the head of the ready
|                                         list: its nextp is the ready PCB
|   0xE205D2  PROC1_$TSVV          18 * 2 timeslice per state
|   0xE205F6  PROC1_$SUSPEND_EC    12     eventcount
|   0xE20602  DI_$Q_HEAD           4      deferred-interrupt queue head
|   0xE20606  (2 bytes, no symbol) the DI dispatch flag byte and a pad
|   0xE20608  PROC1_$CURRENT       2      the running pid
|   0xE2060A  PROC1_$AS_ID         2      the running address space
|   0xE2060C  PROC1_$PID_TN        2      0x40
|   0xE2060E  (PROC1_$ATOMIC_OP_DEPTH, no map symbol) 2
|
| Names not in the map: proc1_$pcb_pool (tools/asm_compare.py
| LOCAL_SYMBOLS) and PROC1_$ATOMIC_OP_DEPTH; the byte at 0xE20606 is
| reached as DI_$Q_HEAD+4 (proc1/m68k/int_handler.s).
|
| Initial values (the image's): PROC1_$CURRENT and PROC1_$AS_ID are 1,
| PROC1_$PID_TN is 0x40, PCB 1 is the running process (pid 1,
| asid 1, priority 0..8, on the ready list after PCB 2) and PCB 2 the null
| process (pid 2, state 0, its saved SP NULL_PC at the top of the null
| stack, a symbol of the layout's STACK window).  PCBs 3..64 carry only
| their pid, vtimer -1, state 0x10, inh_count 1 and sw_bsr 0x10.
|
| The PCB's fields (proc1/proc1.ins.pas proc1_$pcb_t, 0x68 bytes):
|   0x00 nextp  0x04 prevp  0x08..0x34 saved D2-D7/A2-A7  0x38 save_usp
|   0x3C wait_start  0x40 resource_locks_held  0x44 mypid  0x46 asid
|   0x48 vtimer  0x4A pad  0x4C cpu_total  0x50 cpu_usage  0x52 state
|   0x54 pri_min  0x55 pri_max  0x56 inh_count  0x58 sw_bsr
|   0x5A nesting_depth  0x5C..0x67 three longwords
|
        .section ".text.PROC1_$CURRENT_PCB","ax",@progbits
        .balign 2

        .globl  PROC1_$CURRENT_PCB
        .globl  PCBS
        .globl  PROC1_$READY_COUNT
        .globl  proc1_$pcb_pool
        .globl  PROC1_$READY_PCB
        .globl  PROC1_$TSVV
        .globl  PROC1_$SUSPEND_EC
        .globl  DI_$Q_HEAD
        .globl  PROC1_$CURRENT
        .globl  PROC1_$AS_ID
        .globl  PROC1_$PID_TN
        .globl  PROC1_$ATOMIC_OP_DEPTH

        .extern NULL_PC                 | 0xEB07FC, the STACK window (layout)

| One PCB: pcb NEXTP, PREVP, SAVE_A7, MYPID, ASID, STATE, PRI_MIN,
| PRI_MAX, INH_COUNT, SW_BSR; every other field is zero, vtimer -1.
        .macro  pcb nextp, prevp, save_a7, mypid, asid, state, pri_min, pri_max, inh, swbsr
        .long   \nextp, \prevp          | 0x00 nextp, prevp
        .long   0, 0, 0, 0, 0, 0        | 0x08 saved D2-D7
        .long   0, 0, 0, 0, 0           | 0x20 saved A2-A6
        .long   \save_a7                | 0x34 saved A7
        .long   0, 0, 0                 | 0x38 save_usp, wait_start, locks
        .word   \mypid, \asid, 0xFFFF, 0 | 0x44 mypid, asid, vtimer, pad
        .long   0                       | 0x4C cpu_total
        .word   0, \state               | 0x50 cpu_usage, state
        .byte   \pri_min, \pri_max      | 0x54
        .word   \inh, \swbsr, 0         | 0x56 inh_count, sw_bsr, depth
        .long   0, 0, 0                 | 0x5C
        .endm

| A free PCB, pid 3..64.
        .macro  pcb_free pid
        pcb     0, 0, 0, \pid, 0, 0x10, 0, 0, 1, 0x10
        .endm

PROC1_$CURRENT_PCB:                     | 0xE1EAC8
        .long   proc1_$pcb_pool         | PCB 1

PCBS:                                   | 0xE1EACC, pid 0..64
        .long   0
        .set    pcbn, 0
        .rept   64
        .long   proc1_$pcb_pool + pcbn * 0x68
        .set    pcbn, pcbn + 1
        .endr

PROC1_$READY_COUNT:                     | 0xE1EBD0
        .word   1

proc1_$pcb_pool:                        | 0xE1EBD2, PCB 1
        pcb     PROC1_$READY_PCB, PROC1_$READY_PCB, 0, 1, 1, 0x10, 0, 8, 1, 0x10
PROC1_$READY_PCB:                       | 0xE1EC3A, PCB 2
        pcb     proc1_$pcb_pool, proc1_$pcb_pool, NULL_PC, 2, 0, 0, 0, 8, 0, 0
        .irp    pid, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64
        pcb_free \pid
        .endr

PROC1_$TSVV:                            | 0xE205D2, 18 words
        .word   0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF
        .word   0x7D00, 0x7D00, 0x7D00, 0x7D00
        .word   0x30D4, 0x30D4, 0x30D4, 0x30D4, 0x30D4
        .word   0xFFFF, 0xFFFF

PROC1_$SUSPEND_EC:                      | 0xE205F6: value 0, empty queue
        .long   0, PROC1_$SUSPEND_EC, PROC1_$SUSPEND_EC

DI_$Q_HEAD:                             | 0xE20602
        .long   0
        .byte   0                       | 0xE20606: DI dispatch flag
        .byte   0                       | 0xE20607

PROC1_$CURRENT:                         | 0xE20608
        .word   1
PROC1_$AS_ID:                           | 0xE2060A
        .word   1
PROC1_$PID_TN:                          | 0xE2060C
        .word   0x40
PROC1_$ATOMIC_OP_DEPTH:                 | 0xE2060E
        .word   0
