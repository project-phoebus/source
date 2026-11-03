| dtty/m68k/prom_io.s - PROM I/O routines for Display TTY
|
| The SAU2, SAU3 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.  With `trap_page_high'
| (base/config.ins.pas: the SAU7, SAU9) the trap page, and with it the
| PROM's entry cells, is not at 0: each cell is reached at TRAP_PAGE
| plus its offset, an absolute long (the SAU9's DTTY_WIRED is 0x4C
| bytes, the SAU2's 0x48).
|
| These functions call PROM entry points for basic console I/O.
| They save and restore all caller-saved registers and protect
| against interrupt changes using SR save/restore.
|
| Original addresses:
|   DTTY_$PUTC:        0x00E2E018
|   RELOAD_FONT:       0x00E2E032 (module-local)
|   DTTY_$CLEAR_SCREEN: 0x00E2E048

        .include "base/config.inc"

        .section ".text.DTTY_$PUTC","ax",@progbits
        .even

        .if trap_page_high
        .extern TRAP_PAGE
        .endif

| PROM entry point addresses (low memory): common to every m68k Apollo,
| legitimately absolute
        .equ    PROM_PUTC_ADDR,   0x00000108
        .equ    PROM_CLEAR_ADDR,  0x00000140
        .equ    PROM_RELOAD_FONT_ADDR, 0x00000114

|------------------------------------------------------------------------------
| DTTY_$PUTC - Output a single character through PROM
|
| Calls the PROM character output routine at the address stored
| in low memory location 0x108.
|
| Parameters:
|   4(SP) - Pointer to character to output
|
| Original address: 0x00E2E018
|------------------------------------------------------------------------------
        .globl  DTTY_$PUTC
DTTY_$PUTC:
        movem.l %d2-%d7/%a2-%a4,-(%sp)  | Save registers
        movea.l (0x28,%sp),%a0          | Get char pointer (offset past saved regs)
        move.b  (%a0),%d1               | Load character into D1
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_PUTC_ADDR).l,%a0
        .else
        movea.l (PROM_PUTC_ADDR).w,%a0  | Get PROM PUTC address from low memory
        .endif
        move    %sr,-(%sp)              | Save status register
        jsr     (%a0)                   | Call PROM routine
        move    (%sp)+,%sr              | Restore status register
        movem.l (%sp)+,%d2-%d7/%a2-%a4  | Restore registers
        rts

|------------------------------------------------------------------------------
| RELOAD_FONT - Reload the PROM's display font
|
| Calls the PROM routine at the address stored in low memory location
| 0x114, then returns 0 in D0.  Module-local (the map's symbol has no `$');
| it follows DTTY_$PUTC in the map's DTTY_WIRED segment, so it shares
| PUTC's section.
|
| Parameters:
|   None
|
| Original address: 0x00E2E032
|------------------------------------------------------------------------------
RELOAD_FONT:
        movem.l %d2-%d7/%a2-%a4,-(%sp)  | Save registers
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_RELOAD_FONT_ADDR).l,%a0
        .else
        movea.l (PROM_RELOAD_FONT_ADDR).w,%a0 | Get PROM font reload address from low memory
        .endif
        move    %sr,-(%sp)              | Save status register
        jsr     (%a0)                   | Call PROM routine
        move    (%sp)+,%sr              | Restore status register
        movem.l (%sp)+,%d2-%d7/%a2-%a4  | Restore registers
        clr.l   %d0                     | Result 0
        rts

|------------------------------------------------------------------------------
| DTTY_$CLEAR_SCREEN - Clear the display through PROM
|
| Calls the PROM screen clear routine at the address stored
| in low memory location 0x140. Uses function code 3 for full clear.
|
| Parameters:
|   None
|
| Original address: 0x00E2E048
|------------------------------------------------------------------------------
        .globl  DTTY_$CLEAR_SCREEN
        .section ".text.DTTY_$CLEAR_SCREEN","ax",@progbits
        .balign 2
DTTY_$CLEAR_SCREEN:
        movem.l %d2-%d7/%a2-%a4,-(%sp)  | Save registers
        moveq   #3,%d0                   | Function code 3 = full screen clear
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_CLEAR_ADDR).l,%a0
        .else
        movea.l (PROM_CLEAR_ADDR).w,%a0 | Get PROM clear address from low memory
        .endif
        move    %sr,-(%sp)              | Save status register
        jsr     (%a0)                   | Call PROM routine
        move    (%sp)+,%sr              | Restore status register
        movem.l (%sp)+,%d2-%d7/%a2-%a4  | Restore registers
        rts

        .end
