| NULLPROC - Null/Idle Process for Domain/OS (SAU2, SAU5, SAU9 - M68K)
|
| The SAU2, SAU3, SAU5 and SAU9 images have the same code here except the idle
| loop's first instruction: where the null process spins
| (`null_process_spins', base/config.ins.pas: the SAU9's, sau9
| 0x3C428470) it is `andi.w #0xF8FF,SR', which forces IPL 0, in place of
| `stop #0x2000'.  The address and byte columns below are the SAU2
| image's.
|
| This is the idle process that runs when no other process is ready to execute.
| It initializes all general-purpose registers to -1 (0xFFFFFFFF) and then
| enters an infinite loop calling STOP, which puts the processor in a low-power
| state waiting for interrupts.
|
| The STOP instruction with status word 0x2000 sets:
|   - Supervisor mode (S=1)
|   - Interrupt priority level 0 (allowing all interrupts)
|
| When an interrupt occurs, the processor exits the STOP state, handles the
| interrupt, and returns to execute the BRA which loops back to STOP.
|
| Address: 0x00e24c60
| Size: 22 bytes, and the segment's zero pad word to its map size
|
| SAU2 map: "D E24C60 NULLPROC size = 18", symbol NULL_LOOP (module-local:
| no `$') at its start.  OS_$INIT stores NULL_LOOP's address in NULL_PC
| (0xE33CE6), the null process's first return address.  The label is the
| map's symbol, not the segment's name (NULLPROC).

        .include "base/config.inc"

        .section ".text.NULLPROC","ax",@progbits
        .globl  NULL_LOOP

NULL_LOOP:
        moveq   #0x0f,%d0               | Initialize loop counter to 15 (16 iterations)
.Lpush_loop:
        move.l  #-1,-(%sp)              | Push 0xFFFFFFFF onto stack
        dbf     %d0,.Lpush_loop         | Decrement d0, loop until d0 == -1

        | Pop 15 values into registers D0-D7 and A0-A6
        | This sets all general registers to -1 (0xFFFFFFFF)
        movem.l (%sp)+,%d0-%d7/%a0-%a6

.Lidle_loop:
        .if null_process_spins
        andi.w  #0xf8ff,%sr             | IPL 0, and spin (sau9 3c428470  027c f8ff)
        .else
        stop    #0x2000                 | Enter low-power state, supervisor mode, IPL=0
        .endif
        bra.s   .Lidle_loop             | Loop back after interrupt returns
        .word   0                       | 0xE24C76: pad to the segment size
