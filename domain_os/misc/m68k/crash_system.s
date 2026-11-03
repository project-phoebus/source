/*
 * misc/m68k/crash_system.s - CRASH_SYSTEM and the crash console
 * (m68k/SAU2, SAU3, SAU5)
 *
 * The SAU2 and SAU5 images have the same CRASH_SYSTEM (the map's
 * CRASH_PAUSE) and CRASH_SHOW_STRING except in three places, which test
 * base/config.ins.pas's parts:
 *   crash_report_blank_lines  the report block's header is 4 bytes longer
 *                     on the SAU5 (misc/m68k/crash_report.s), so every
 *                     field CRASH_SYSTEM reaches off A5 = CRASH_REPORT is
 *                     4 further on (.Lcr_hdr below);
 *   disp2_probe       the word DISP2_PRESENT (a map symbol of the SAU4..
 *                     SAU6; SAU5 0xE1F42A) after call_prom_reload_font;
 *   gpu_driver        REMAP_DISPLAY is another routine on the SAU5
 *                     (0xE1F42C, 0x100 bytes against the SAU2's 0x3A):
 *                     it quiets the graphics board when a process holds
 *                     it, maps the graphic device's memory (device 1:
 *                     KOLOR_CTL; device 2: KOLOR_CTL and DISP_MEM_2KX1K),
 *                     then the second display (COLOR_CSTORE and DISP2_MEM)
 *                     when DISP2_PRESENT is set, else DISP1_MEM.  The
 *                     SAU6's REMAP_DISPLAY is the same size; the SAU4's,
 *                     another form, is not compared.
 * The SAU3's module (`D E1D700 CRASH_SYSTEM size = 2F8') is the SAU2's
 * with two more parts:
 *   crash_prom_restart  CRASH_SYSTEM ends in a restart through the PROM
 *                     (its cell 0x128, code and address), never in the
 *                     debugger: a clean restart (status 0x001B0008, then
 *                     cleared) at DUMP_$AUTO_REBOOT's physical address,
 *                     a shutdown (status 0) with code 0xFF, a crash with
 *                     code 0xF1 at DUMP + 4 (the SAU9's restart arms
 *                     without its crash_reboot_check; no KBD_$RESET,
 *                     KBD_$CRASH_INIT or `trap #15'); CRASH, which hands
 *                     the PROM a code at DUMP + 4, follows CRASH_SAVED_SR;
 *   display_driver    no REMAP_DISPLAY and no call_prom_reload_font: the
 *                     console is the PROM's serial line.
 * The address columns are the SAU2 image's, except in the `.if' arms,
 * which carry the SAU5 image's (CRASH_SYSTEM 0x00E1F300, CRASH_SHOW_STRING
 * 0x00E1F3B8, crash_puts_string 0x00E1F3C8, CRASH_REPORT 0x00E1F648) or
 * the SAU3 image's (CRASH_SYSTEM 0x00E1D700, CRASH 0x00E1D7E4,
 * CRASH_SHOW_STRING 0x00E1D800).
 *
 * Byte gate (tools/asm_compare.py, `make check'): encodings identical
 * to the image (modulo the documented widenings); address operands
 * resolve to our objects.
 *
 * Faithful transcription of the hand-written assembly at 0x00E1E700..0x00E1E863.
 * These routines cannot be expressed in C: they save and restore the whole
 * register file with `movem` (including A7), read the USP with `movec`, take
 * their arguments in registers, manipulate SR directly and end in `trap #15`.
 *
 * The crash report block (CRASH_REPORT, 0x00E1E97E, misc/m68k/crash_report.s)
 * and the SR stash (CRASH_SAVED_SR, 0x00E1E7B6, here, between CRASH_SYSTEM
 * and CRASH_SHOW_STRING) are reached in the image through the module base A5
 * = 0x00E1E700 (`lea (-0xc,PC),A5`) or PC-relative; this file names
 * them instead of using those displacements; the original displacement
 * is given in the comment on each access.  The map names neither.  The
 * crash record the image writes at 0x00E00000 (map `D E00000
 * CRASH_RECORD size = C') is CRASH_$RECORD, the link script's symbol.
 * tools/asm_compare.py (`make check') checks the result: encodings
 * identical to the image except the documented A5 rebase and widenings;
 * address operands resolve to our objects.  REMAP_DISPLAY's 0x00FC0000
 * is the display frame buffer VA, the map's absolute DISP1_MEM
 * (arch/m68k/sau2/iodefs.s): the image's fixup table lists the cell
 * (0x00E1E838), so it is a relocation.
 *
 *   0x00E1E700  CRASH_SYSTEM
 *   0x00E1E7B8  CRASH_SHOW_STRING
 *   0x00E1E7C8  crash_puts_string          (argument in A0)
 *   0x00E1E812  call_prom_putc             (character in D1)
 *   0x00E1E822  call_prom_reload_font
 *   0x00E1E82A  REMAP_DISPLAY
 *
 * Not on the other SAUs whose crash may restart the node (`crash_reboot',
 * base/config.ins.pas): their CRASH_SYSTEM module is another form (the
 * SAU9's misc/sau9/crash_system.s).
 */

        .include "base/config.inc"
        /* (not `a || b': `|' starts a comment in m68k gas) */
        .if     !(crash_reboot && !crash_prom_restart)

        .extern TIME_$CLOCKH_EC
        .extern DISP1_MEM               /* arch/m68k/sau2/iodefs.s, 0xFC0000 */

        /* The report block's header before CRASH_STATUS: CR LF and
         * "Crash_Status " 0xFF (0x10 bytes), on the SAU5 "\n\n\n\r\r\n"
         * and the rest (0x14).  The fields' offsets from CRASH_REPORT are
         * the SAU2's plus .Lcr_hdr. */
        .if crash_report_blank_lines
        .set    .Lcr_hdr, 4
        .else
        .set    .Lcr_hdr, 0
        .endif

        .if crash_prom_restart
        .equ    DUMP_PHYS, 0x00100C00   /* PPN 0x403: where COLD copies the DUMP page */
        .endif

        .set    TIME_$CLOCKH, TIME_$CLOCKH_EC   /* the eventcount value word, map 0xE2B0D4 (time/time.ins.pas) */

        .section ".text.CRASH_SYSTEM","ax",@progbits

/* -------------------------------------------------------------------------
 * CRASH_SYSTEM - 0x00E1E700, 182 bytes
 *
 * Pascal/C entry: 4(SP) holds a status_$t *.  After the entry sequence the
 * frame is
 *   0x00(SP) .. 0x3F(SP)  the 16 saved registers, D0 lowest, A7 highest
 *   0x40(SP)              the SR pushed at entry (a word)
 *   0x42(SP)              the caller's return address  -> CRASH_REPORT.pc
 *   0x46(SP)              the status_$t * argument
 * ------------------------------------------------------------------------- */
    .globl  CRASH_SYSTEM
    .globl  _CRASH_SYSTEM
CRASH_SYSTEM:
_CRASH_SYSTEM:
    move.w  %sr, -(%sp)                     /* 0xE1E700 */
    ori.w   #0x0700, %sr                    /* 0xE1E702: IPL 7 */
    movem.l %d0-%d7/%a0-%a7, -(%sp)         /* 0xE1E706: 64 bytes */
    lea     CRASH_REPORT, %a5               /* 0xE1E70A: lea (-0xc,PC),A5 */

    movea.l 0x46(%sp), %a0                  /* 0xE1E70E: the status pointer */
    move.l  (%a0), (0x10+.Lcr_hdr,%a5)                /* 0xE1E712: (0x28e,A5) = *status_p */
    beq.b   Lcrash_no_message               /* 0xE1E716: status 0 -> shutdown */
    cmpi.l  #0x001b0008, (0x10+.Lcr_hdr,%a5)          /* 0xE1E718: clean reboot? */
    beq.b   Lcrash_no_message
    move.l  0x42(%sp), (0x1a+.Lcr_hdr,%a5)            /* 0xE1E722: (0x298,A5) = return addr */
    move.w  PROC1_$CURRENT, (0x24+.Lcr_hdr,%a5)       /* 0xE1E728: (0x2a2,A5), a WORD */
    lea     CRASH_REPORT, %a0               /* 0xE1E730: lea (0x24c,PC),A0 */
    bsr.w   crash_puts_string               /* 0xE1E734 */

Lcrash_no_message:
    lea     (CRASH_$RECORD).l, %a1          /* 0xE1E738: lea (0x00e00000).l,A1 - the crash record */
    clr.l   (%a1)                           /* 0xE1E73E */
    tst.l   (0x10+.Lcr_hdr,%a5)                       /* 0xE1E740 */
    beq.b   Lcrash_save_regs
    cmpi.l  #0x001b0008, (0x10+.Lcr_hdr,%a5)          /* 0xE1E746 */
    beq.b   Lcrash_save_regs
    move.l  #0xabcdef01, (%a1)+             /* 0xE1E750: magic */
    move.l  TIME_$CLOCKH, (%a1)+            /* 0xE1E756 */
    move.l  (0x10+.Lcr_hdr,%a5), (%a1)                /* 0xE1E75C: move.l (0x230,PC),(A1) */

Lcrash_save_regs:
    lea     (%sp), %a0                      /* 0xE1E760: the movem block */
    lea     CRASH_REPORT+0x28+.Lcr_hdr, %a1          /* 0xE1E762: lea (0x242,PC),A1 */
    moveq   #15, %d0                        /* 0xE1E766: 16 longwords */
Lcrash_copy_reg:
    move.l  (%a0)+, (%a1)+                  /* 0xE1E768 */
    dbf     %d0, Lcrash_copy_reg            /* 0xE1E76A */
    movec   %usp, %d0                       /* 0xE1E76E */
    move.l  %d0, (0x6c+.Lcr_hdr,%a5)                  /* 0xE1E772: (0x2ea,A5) */
    .if crash_prom_restart
    /* The restart through the PROM: D1 = the code, D0 = the address. */
    bra.w   Lcrash_restart_which            /* sau3 0xE1D776 */
Lcrash_auto_reboot:
    move.l  (crash_auto_reboot:w,%pc), %d0  /* sau3 0xE1D77A: DUMP_$AUTO_REBOOT, */
    sub.l   (crash_dump:w,%pc), %d0         /* sau3 0xE1D77E:   physical */
    .short  0xd0bc                          /* sau3 0xE1D782: add.l #DUMP_PHYS,%d0 */
    .long   DUMP_PHYS                       /*   (the <ea>=#imm form; gas: addi) */
    move.w  #0xf1, %d1                      /* sau3 0xE1D788 */
    bra.b   Lcrash_restart
Lcrash_restart_which:
    lea     CRASH_REPORT+0x10+.Lcr_hdr, %a0 /* sau3 0xE1D78E: lea (0x1fe,PC),A0 */
    tst.l   (%a0)                           /* sau3 0xE1D792 */
    beq.b   Lcrash_restart_shutdown
    cmpi.l  #0x001b0008, (%a0)              /* sau3 0xE1D796: clean reboot? */
    bne.b   Lcrash_restart_crash
    clr.l   (%a0)                           /* sau3 0xE1D79E: it reports nothing */
    bra.b   Lcrash_auto_reboot
Lcrash_restart_shutdown:
    clr.l   %d0                             /* sau3 0xE1D7A2: code 0xFF, address 0 */
    move.w  #0xff, %d1
    bra.b   Lcrash_restart
Lcrash_restart_crash:
    move.l  #DUMP_PHYS+4, %d0               /* sau3 0xE1D7AA: code 0xF1 at DUMP + 4 */
    move.w  #0xf1, %d1
Lcrash_restart:
    move.l  %d0, -(%sp)                     /* sau3 0xE1D7B4 */
    move.w  %d1, -(%sp)
    bsr.b   crash_call_prom_restart         /* sau3 0xE1D7B8 */
    addq.w  #6, %sp
    move.w  0x40(%sp), CRASH_SAVED_SR       /* sau3 0xE1D7BC: (0xe2,A5) = entry SR */
    movem.l (%sp)+, %d0-%d7/%a0-%a7         /* sau3 0xE1D7C2 */
    addq.w  #2, %sp                         /* sau3 0xE1D7C6: drop the SR word */
    .else
    jsr     KBD_$RESET                      /* 0xE1E776 */

    tst.l   (0x10+.Lcr_hdr,%a5)                       /* 0xE1E77C */
    bne.b   Lcrash_enter_debugger
    /*
     * Clean shutdown: hand control back to the PROM through the vector at
     * absolute address 0x11C.  That cell is PROM_$QUIET_RET_ADDR
     * -- the routine jumps to its *contents*: the name is the vector word's
     * itself.
     */
    movea.l 0x0000011c, %a0                 /* 0xE1E782: movea.l (0x11c).w,A0 */
    jmp     (%a0)                           /* 0xE1E786: does not return */

Lcrash_enter_debugger:
    move.w  0x40(%sp), CRASH_SAVED_SR       /* 0xE1E788: (0xb6,A5) = entry SR */
    movem.l (%sp)+, %d0-%d7/%a0-%a7         /* 0xE1E78E: restore, SP += 64 */
    addq.w  #2, %sp                         /* 0xE1E792: drop the SR word */
    trap    #15                             /* 0xE1E794: into the debugger */

    /* Reached only if the trap #15 handler returns. */
    jsr     KBD_$CRASH_INIT                 /* 0xE1E796 */
    .endif
    movem.l %d0/%a0, -(%sp)                 /* 0xE1E79C */
    lea     CRASH_REPORT+0x28+.Lcr_hdr, %a0          /* 0xE1E7A0: lea (0x204,PC),A0 */
    moveq   #15, %d0                        /* 0xE1E7A4 */
Lcrash_clear_reg:
    clr.l   (%a0)+                          /* 0xE1E7A6 */
    dbf     %d0, Lcrash_clear_reg           /* 0xE1E7A8 */
    movem.l (%sp)+, %d0/%a0                 /* 0xE1E7AC */
    move.w  CRASH_SAVED_SR, %sr             /* 0xE1E7B0: move (0x4,PC),SR */
    rts                                     /* 0xE1E7B4 */

    .globl  CRASH_SAVED_SR
CRASH_SAVED_SR:                             /* 0xE1E7B6: the SR stash, (0xb6,A5); zero */
    .word   0

    .if crash_prom_restart
/* -------------------------------------------------------------------------
 * CRASH(code, param) - sau3 0x00E1D7E4: restart the node through the PROM
 * with restart code `code' (4(SP), a word) at DUMP + 4; the longword
 * argument (6(SP)) is replaced by that address.
 * ------------------------------------------------------------------------- */
    .globl  CRASH
CRASH:
    movea.l #DUMP_PHYS+4, %a0               /* sau3 0xE1D7E4 */
    move.l  %a0, 6(%sp)                     /* sau3 0xE1D7EA */

/* crash_call_prom_restart - sau3 0x00E1D7EE: call the PROM's restart entry
   (its cell 0x128) with the code word at 4(SP) and the address longword
   at 6(SP). */
crash_call_prom_restart:
    movea.l 0x00000128, %a0                 /* sau3 0xE1D7EE: movea.l (0x128).w,A0 */
    move.l  6(%sp), -(%sp)                  /* sau3 0xE1D7F2 */
    move.w  8(%sp), -(%sp)                  /* sau3 0xE1D7F6 */
    jsr     (%a0)                           /* sau3 0xE1D7FA */
    addq.l  #6, %sp                         /* sau3 0xE1D7FC */
    rts                                     /* sau3 0xE1D7FE */
    .endif

/* -------------------------------------------------------------------------
 * CRASH_SHOW_STRING - 0x00E1E7B8, 16 bytes
 *
 * C-callable: 4(SP) is the string, which after the 64-byte movem is 0x44(SP).
 * ------------------------------------------------------------------------- */
    .globl  CRASH_SHOW_STRING
    .globl  _CRASH_SHOW_STRING
CRASH_SHOW_STRING:
_CRASH_SHOW_STRING:
    movem.l %d0-%d7/%a0-%a7, -(%sp)         /* 0xE1E7B8 */
    movea.l 0x44(%sp), %a0                  /* 0xE1E7BC */
    bsr.b   crash_puts_string               /* 0xE1E7C0 */
    movem.l (%sp)+, %d0-%d7/%a0-%a7         /* 0xE1E7C2 */
    rts                                     /* 0xE1E7C6 */

/* -------------------------------------------------------------------------
 * crash_puts_string - 0x00E1E7C8, 74 bytes
 *
 * A0 = format string.  Register convention, NOT C-callable.
 *   byte 0x01..0x24, 0x26..0x7F  emitted literally
 *   byte 0x25 ('%')              emit CR LF and return
 *   byte 0x00                    the next word is emitted as 4 hex digits
 *   byte 0x80..0xFF              the next long is emitted as 8 hex digits
 * Clobbers D0/D1/D2/A0 (call_prom_putc preserves exactly those).
 * ------------------------------------------------------------------------- */
    .globl  crash_puts_string
    .globl  _crash_puts_string
crash_puts_string:
_crash_puts_string:
    move.l  %a0, -(%sp)                     /* 0xE1E7C8 */
    .if display_driver
    bsr.w   REMAP_DISPLAY                   /* 0xE1E7CA */
    bsr.b   call_prom_reload_font           /* 0xE1E7CE */
    .endif
    movea.l (%sp)+, %a0                     /* 0xE1E7D0 */
Lputs_next:
    move.b  (%a0)+, %d1                     /* 0xE1E7D2 */
    ble.b   Lputs_hex                       /* 0xE1E7D4: byte <= 0 */
    cmpi.b  #0x25, %d1                      /* 0xE1E7D6 */
    beq.b   Lputs_end
    bsr.b   call_prom_putc                  /* 0xE1E7DC */
    bra.b   Lputs_next
Lputs_end:
    moveq   #13, %d1                        /* 0xE1E7E0: CR */
    bsr.b   call_prom_putc
    moveq   #10, %d1                        /* 0xE1E7E4: LF */
    bsr.b   call_prom_putc
    rts                                     /* 0xE1E7E8 */
Lputs_hex:
    blt.b   Lputs_long                      /* 0xE1E7EA: negative byte */
    move.w  (%a0)+, %d2                     /* 0xE1E7EC: 16-bit field */
    swap    %d2
    moveq   #3, %d0                         /* 4 nibbles */
    bra.b   Lputs_nibble
Lputs_long:
    move.l  (%a0)+, %d2                     /* 0xE1E7F4: 32-bit field */
    moveq   #7, %d0                         /* 8 nibbles */
Lputs_nibble:
    rol.l   #4, %d2                         /* 0xE1E7F8 */
    moveq   #15, %d1
    and.b   %d2, %d1
    cmpi.b  #10, %d1
    blt.b   Lputs_digit
    addq.b  #7, %d1                         /* 0xE1E804: 'A'-'0'-10 */
Lputs_digit:
    addi.b  #0x30, %d1                      /* 0xE1E806 */
    bsr.b   call_prom_putc
    dbf     %d0, Lputs_nibble               /* 0xE1E80C */
    bra.b   Lputs_next                      /* 0xE1E810 */

/* -------------------------------------------------------------------------
 * call_prom_putc - 0x00E1E812, 16 bytes
 *
 * D1 = character.  Calls the PROM putc through the vector at address 0x108,
 * preserving exactly the registers crash_puts_string keeps live.
 * ------------------------------------------------------------------------- */
    .globl  call_prom_putc
call_prom_putc:
    movem.l %d0-%d2/%a0, -(%sp)             /* 0xE1E812 */
    movea.l 0x00000108, %a0                 /* 0xE1E816 */
    jsr     (%a0)                           /* 0xE1E81A */
    movem.l (%sp)+, %d0-%d2/%a0             /* 0xE1E81C */
    rts                                     /* 0xE1E820 */

/* -------------------------------------------------------------------------
 * call_prom_reload_font - 0x00E1E822, 6 bytes
 *
 * Tail-jumps to the PROM font reload routine (vector at address 0x114).
 * ------------------------------------------------------------------------- */
    .if display_driver
    .globl  call_prom_reload_font
call_prom_reload_font:
    movea.l 0x00000114, %a1                 /* 0xE1E822 */
    jmp     (%a1)                           /* 0xE1E826 */
    rts                                     /* 0xE1E828: never reached */

    .if disp2_probe
    .globl  DISP2_PRESENT
DISP2_PRESENT:                              /* sau5 0xE1F42A: OS_$INIT's answer */
    .word   0                               /* to the second display's probe */
    .endif

/* -------------------------------------------------------------------------
 * REMAP_DISPLAY - 0x00E1E82A, 58 bytes
 *
 * Re-establishes the display mapping so the crash console is visible even if
 * the normal mappings are gone: physical pages 0x80..0xFF are installed at
 * virtual 0x00FC0000 upward, 0x400 bytes apart.
 *
 * MMU_$INSTALL is called with four by-value arguments pushed right to left:
 *   (SP)     long  physical page number, incremented in place by the loop
 *   4(SP)    long  virtual address, advanced by 0x400 in place
 *   8(SP)    word  0
 *   10(SP)   word  0x26
 * The `move SR` / `move (SP)+,SR` pair is a true save/restore.
 * ------------------------------------------------------------------------- */
    .if gpu_driver
    /* The SAU5's REMAP_DISPLAY, 0x00E1F42C, 256 bytes.  The map gives
     * 0xFA0000 two names (DISP2_MEM, DISP_MEM_2KX1K); the graphic device's
     * mapping is written DISP_MEM_2KX1K and the second display's DISP2_MEM
     * (which the original wrote is not known; the cell is the same). */
    .extern GPU                     /* 0xFF8000 (SAU5 map) */
    .extern KOLOR_CTL               /* 0xF90000 (SAU5 map) */
    .extern DISP_MEM_2KX1K          /* 0xFA0000 (SAU5 map) */
    .extern DISP2_MEM               /* 0xFA0000 (SAU5 map) */
    .extern COLOR_CSTORE            /* 0xFF6800 (SAU5 map) */
    .globl  REMAP_DISPLAY
REMAP_DISPLAY:
    move.w  %sr, -(%sp)                     /* sau5 0xE1F42C */
    ori.w   #0x0700, %sr                    /* sau5 0xE1F42E */
    move.w  #0x26, -(%sp)                   /* sau5 0xE1F432 */
    clr.w   -(%sp)                          /* sau5 0xE1F436 */
    tst.w   GPU_$PRESENT                    /* sau5 0xE1F438 */
    beq.b   Lremap_graphic
    tst.w   GPU_$USER_PID                   /* sau5 0xE1F440: a process holds it */
    beq.b   Lremap_graphic
    lea     (GPU).l, %a0                    /* sau5 0xE1F448: 0xFF8000, a fixup-table cell */
    move.w  (2,%a0), %d0                    /* sau5 0xE1F44E */
    andi.w  #0x25, %d0                      /* sau5 0xE1F452 */
    cmpi.w  #0x20, %d0                      /* sau5 0xE1F456 */
    beq.b   Lremap_graphic
    move.w  #0, (6,%a0)                     /* sau5 0xE1F45C */
Lremap_graphic:
    cmpi.w  #2, SMD_$GRAPHIC_DEVICE_ID      /* sau5 0xE1F462 */
    beq.b   Lremap_kolor
    cmpi.w  #1, SMD_$GRAPHIC_DEVICE_ID      /* sau5 0xE1F46C */
    bne.b   Lremap_disp2
Lremap_kolor:
    move.l  #KOLOR_CTL, -(%sp)              /* sau5 0xE1F476: 0xF90000, a fixup-table cell */
    move.l  #0x00000180, -(%sp)             /* sau5 0xE1F47C */
Lremap_g_loop:
    jsr     MMU_$INSTALL                    /* sau5 0xE1F482 */
    addq.l  #1, (%sp)                       /* sau5 0xE1F488 */
    cmpi.l  #0x000001c0, (%sp)              /* sau5 0xE1F48A */
    beq.b   Lremap_g_next
    cmpi.l  #0x00000180, (%sp)              /* sau5 0xE1F492 */
    beq.w   Lremap_done
    addi.l  #0x00000400, 4(%sp)             /* sau5 0xE1F49C */
    bra.b   Lremap_g_loop
Lremap_g_next:
    addq.w  #8, %sp                         /* sau5 0xE1F4A6 */
    cmpi.w  #2, SMD_$GRAPHIC_DEVICE_ID      /* sau5 0xE1F4A8 */
    bne.b   Lremap_disp2
    move.l  #DISP_MEM_2KX1K, -(%sp)         /* sau5 0xE1F4B2: 0xFA0000, a fixup-table cell */
    move.l  #0x00000080, -(%sp)             /* sau5 0xE1F4B8 */
    bra.b   Lremap_g_loop
Lremap_disp2:
    tst.b   (DISP2_PRESENT).l               /* sau5 0xE1F4C0: abs.l, as the image */
    beq.b   Lremap_disp1
    lea     (COLOR_CSTORE).l, %a0           /* sau5 0xE1F4C8: 0xFF6800, a fixup-table cell */
    move.l  %a0, -(%sp)                     /* sau5 0xE1F4CE */
    move.l  #0x0000003a, -(%sp)             /* sau5 0xE1F4D0 */
    jsr     MMU_$INSTALL                    /* sau5 0xE1F4D6 */
    addq.l  #8, %sp                         /* sau5 0xE1F4DC */
    lea     (DISP2_MEM).l, %a0              /* sau5 0xE1F4DE: 0xFA0000, a fixup-table cell */
    move.l  %a0, -(%sp)                     /* sau5 0xE1F4E4 */
    move.l  #0x00000100, -(%sp)             /* sau5 0xE1F4E6 */
    bra.b   Lremap_loop
Lremap_disp1:
    move.l  #DISP1_MEM, -(%sp)              /* sau5 0xE1F4EE: 0xFC0000, a fixup-table cell */
    move.l  #0x00000080, -(%sp)             /* sau5 0xE1F4F4 */
Lremap_loop:
    jsr     MMU_$INSTALL                    /* sau5 0xE1F4FA */
    addq.l  #1, (%sp)                       /* sau5 0xE1F500: next page */
    cmpi.l  #0x00000180, (%sp)              /* sau5 0xE1F502 */
    bne.b   Lremap_not_wrap
    move.l  #0x00000080, (%sp)              /* sau5 0xE1F50A */
    bra.b   Lremap_next
Lremap_not_wrap:
    cmpi.l  #0x00000100, (%sp)              /* sau5 0xE1F512 */
    beq.b   Lremap_done
Lremap_next:
    addi.l  #0x00000400, 4(%sp)             /* sau5 0xE1F51A: next virtual page */
    bra.b   Lremap_loop
Lremap_done:
    adda.w  #12, %sp                        /* sau5 0xE1F524: drop the arguments */
    move.w  (%sp)+, %sr                     /* sau5 0xE1F528 */
    rts                                     /* sau5 0xE1F52A */

    .else
    .globl  REMAP_DISPLAY
REMAP_DISPLAY:
    move.w  %sr, -(%sp)                     /* 0xE1E82A */
    ori.w   #0x0700, %sr                    /* 0xE1E82C */
    move.w  #0x26, -(%sp)                   /* 0xE1E830 */
    clr.w   -(%sp)                          /* 0xE1E834 */
    move.l  #DISP1_MEM, -(%sp)              /* 0xE1E836: 0x00FC0000, a fixup-table cell */
    move.l  #0x00000080, -(%sp)             /* 0xE1E83C */
Lremap_loop:
    jsr     MMU_$INSTALL                    /* 0xE1E842 */
    addq.l  #1, (%sp)                       /* 0xE1E848: next page */
    cmpi.l  #0x00000100, (%sp)              /* 0xE1E84A */
    beq.b   Lremap_done
    addi.l  #0x00000400, 4(%sp)             /* 0xE1E852: next virtual page */
    bra.b   Lremap_loop                     /* 0xE1E85A */
Lremap_done:
    adda.w  #12, %sp                        /* 0xE1E85C: drop the arguments */
    move.w  (%sp)+, %sr                     /* 0xE1E860 */
    rts                                     /* 0xE1E862 */
    .endif
    .endif  /* display_driver */

        .endif
