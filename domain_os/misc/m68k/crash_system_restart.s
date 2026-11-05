/*
 * misc/m68k/crash_system_restart.s - the CRASH_SYSTEM module: CRASH_SYSTEM,
 * the restart through the PROM, the crash console, FIM_$CRASH and the
 * crash report (SAU8, SAU9)
 *
 * SAU9 map: "D 3C421300 CRASH_SYSTEM size = 3C4" (WIRED_DATA),
 * 0x3C421300..0x3C4216C3, hand-written code and data:
 *
 *   0x3C421300  CRASH_PAUSE, CRASH_SYSTEM (the label the map marks)
 *   0x3C421420  the SR stash (CRASH_SAVED_SR, no map name)
 *   0x3C421422  CRASH
 *   0x3C42142C  crash_call_prom_restart     (no map name)
 *   0x3C421440  CRASH_SHOW_STRING
 *   0x3C421450  crash_puts_string           (no map name; A0 = string)
 *   0x3C42149A  call_prom_putc              (no map name; D1 = char)
 *   0x3C4214AC  call_prom_reload_font       (no map name)
 *   0x3C4214B6  REMAP_CSR_PPN, REMAP_FRM_PPN, REMAP_CSR_CNT,
 *               REMAP_FRM_CNT               (COLD stores them)
 *   0x3C4214C2  REMAP_DISPLAY
 *   0x3C4214FC  FIM_$CRASH, its report template from 0x3C421586
 *   0x3C421602  the crash report (CRASH_REPORT, no map name): CRASH_STATUS,
 *               CRASH_ECB, SERVER_$FLAG, CRASH_REGS, CRASH_SP, CRASH_USP,
 *               CRASH_$OK_TO_REBOOT, then DUMP's and DUMP_$AUTO_REBOOT's
 *               addresses
 *   0x3C42167C  crash_reboot_check          (no map name)
 *
 * The SAU2's module (misc/m68k/crash_system.s, misc/m68k/crash_report.s,
 * fim/m68k/crash.s) without the restart: on the SAU9 (`crash_reboot',
 * base/config.ins.pas) a crash that may restart the node hands the PROM a
 * restart code and the physical address of DUMP_$AUTO_REBOOT instead of
 * entering the debugger, and the PROM's entry cells are at TRAP_PAGE
 * plus their offsets (`trap_page_high').  FIM_$CRASH, the report
 * template and the console routines have the SAU2's code; the module's
 * cells are reached off A5 = CRASH_SYSTEM (`lea (d,PC),A5') or
 * PC-relatively, so the whole segment is one section here and every
 * displacement is a difference of two of its labels.
 *
 * Hand-written: no frames, the whole register file saved with `movem'
 * (A7 included), the USP read with `movec', register arguments, SR
 * written directly, `trap #15'.  The Apollo assembler's <ea>=#imm forms
 * (cmp/add #imm,Dn), which gas spells cmpi/addi, are written as `.short'.
 *
 * The SAU8's module (`D 3C1FF00 CRASH_SYSTEM size = 3E8') is the SAU9's
 * with these differences, `.if' arms below:
 *   trap_page_high  the SAU9's PROM cells are TRAP_PAGE + their offsets,
 *                   absolute longs; the SAU8's trap page is at 0, and
 *                   the cells are absolute words (dtty/m68k/prom_io.s);
 *                   the DUMP page is where COLD put it: physical
 *                   0x04001400 on the SAU9, 0x00100C00 on the SAU8 (the
 *                   SAU2's PPN 0x403);
 *   crash_remap_cold_display
 *                   REMAP_DISPLAY maps the display COLD found: its
 *                   REMAP_CSR_CNT control pages from REMAP_CSR_PPN at
 *                   DISP1, then its REMAP_FRM_CNT frame-buffer pages from
 *                   REMAP_FRM_PPN at DISP1_MEM, where the SAU9's maps the
 *                   128 pages from PPN 0x4000 at DISP1_MEM.  It is 0x2A
 *                   bytes longer, so every cell after it is too.
 * The SAU7's module (`D 3C422B00 CRASH_SYSTEM size = 444') is the SAU8's
 * with the SAU9's PROM cells (`trap_page_high') and:
 *   crash_cache_off CRASH_SYSTEM, unless its status is "manual stop",
 *                   and FIM_$CRASH first turn the physical cache off
 *                   (a zero byte at MMU + 0x200) on a ROADRUNNER board
 *                   or an MC68020 CPU, 0x32 and 0x22 bytes before their
 *                   entry sequences;
 *   cold_ram_16mb   the DUMP page is at physical 0x01000C00.
 * The address and byte columns are the SAU9 image's, except in the `.if'
 * arms, which carry the SAU8 image's (CRASH_SYSTEM 0x3C1FF00, REMAP_DISPLAY
 * 0x3C200BA, FIM_$CRASH 0x3C2011E, CRASH_REPORT 0x3C20224) or the SAU7
 * image's (CRASH_SYSTEM 0x3C422B00, FIM_$CRASH 0x3C422D58).
 *
 * Not on the SAUs whose crash does not restart the node, or restarts it
 * through the PROM's cell 0x128 from the SAU2's code (misc/m68k/
 * crash_system.s: `crash_reboot', `crash_prom_restart'), nor on the SAU4
 * (`crash_cache_check': misc/sau4/crash_system.s) and the SAU6
 * (`crash_win6_save': misc/sau6/crash_system.s).
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm',
 * `make TARGET_SAU=sau8 check-asm'): encodings identical to the image;
 * address operands resolve to our objects.  The SAU7 (no tables yet):
 * assembled with `m68k-elf-as -m68030 -m68881' and compared with the
 * SAU7 image at the map's addresses by the same rules.
 */

        .include "base/config.inc"
        /* (not `a || b': `|' starts a comment in m68k gas) */
        .if     crash_reboot && !crash_prom_restart && !crash_cache_check && !crash_win6_save

        .section ".text.CRASH_SYSTEM","ax",@progbits
        .even

        .globl  CRASH_SYSTEM
        .globl  CRASH_PAUSE
        .globl  CRASH
        .globl  CRASH_SHOW_STRING
        .globl  REMAP_CSR_PPN
        .globl  REMAP_FRM_PPN
        .globl  REMAP_CSR_CNT
        .globl  REMAP_FRM_CNT
        .globl  REMAP_DISPLAY
        .globl  FIM_$CRASH
        .globl  CRASH_STATUS
        .globl  CRASH_ECB
        .globl  SERVER_$FLAG
        .globl  CRASH_REGS
        .globl  CRASH_SP
        .globl  CRASH_USP
        .globl  CRASH_$OK_TO_REBOOT

        .if trap_page_high
        .extern TRAP_PAGE               /* the vector page, the PROM's cells at +0x100.. */
        .endif
        .if crash_cache_off
        .extern M68030                  /* mmu/mmu.ins.pas: the CPU is an MC68030 */
        .extern ROADRUNNER              /* mmu/mmu.ins.pas */
        .extern MMU                     /* the MMU's page; + 0x200 the physical cache's register */
        .endif

/* The PROM's entry cells, offsets in the trap page (dtty/m68k/prom_io.s). */
        .equ    PROM_PUTC_CELL,         0x108   /* putc, D1 = the character */
        .equ    PROM_RELOAD_FONT_CELL,  0x114   /* reload the console font */
        .equ    PROM_QUIET_RET_CELL,    0x11C   /* back to the PROM's monitor */
        .equ    PROM_RESTART_CELL,      0x128   /* restart: (code.w, address.l) */

/* Where COLD put the DUMP page: physical 0x04001400 (it copies the file's
   DUMP page there; the kernel's VAs are their physical address +
   0x38400000); on the SAU8 0x00100C00, PPN 0x403, as on the SAU2.  CRASH
   hands the PROM DUMP + 4. */
        .if cold_ram_16mb
        .equ    DUMP_PHYS,              0x01000C00      /* the SAU7's: its RAM starts at 16 MB */
        .elseif trap_page_high
        .equ    DUMP_PHYS,              0x04001400
        .else
        .equ    DUMP_PHYS,              0x00100C00
        .endif

/* The status a clean restart passes (OS_$SHUTDOWN): no report, and on a
   server or a node that may not restart, the PROM's monitor. */
        .equ    STATUS_REBOOT,          0x001B0008
/* "manual stop: type G<ret>G *+2<ret> to continue" */
        .equ    STATUS_MANUAL_STOP,     0x000B0008

/* -------------------------------------------------------------------------
 * CRASH_SYSTEM(status) - 0x3C421300
 *
 * 4(SP) holds a status_$t *.  After the entry sequence:
 *   0x00(SP) .. 0x3F(SP)  the 16 saved registers, D0 lowest, A7 highest
 *   0x40(SP)              the SR pushed at entry (a word)
 *   0x42(SP)              the caller's return address
 *   0x46(SP)              the status_$t * argument
 * With `crash_cache_off' the physical cache goes off first, A0 kept,
 * unless the status is STATUS_MANUAL_STOP: on a ROADRUNNER board, or
 * when the CPU is not an MC68030.
 * ------------------------------------------------------------------------- */
CRASH_PAUSE:
CRASH_SYSTEM:
        .if crash_cache_off
        move.l  %a0,-(%sp)                      | sau7 3c422b00  2f08
        movea.l (8,%sp),%a0                     | sau7 3c422b02  206f 0008  the status pointer
        cmpi.l  #STATUS_MANUAL_STOP,(%a0)       | sau7 3c422b06  0c90 000b 0008
        beq.s   .Lcs_cache_kept                 | sau7 3c422b0c  6722
        tst.b   (ROADRUNNER).l                  | sau7 3c422b0e  4a39 3c42 90ec
        beq.s   .Lcs_not_rr                     | sau7 3c422b14  670a
        move.b  #0,(MMU+0x200).l                | sau7 3c422b16  13fc 0000 3fff b600  the cache off
        bra.s   .Lcs_cache_kept                 | sau7 3c422b1e  6010
.Lcs_not_rr:
        tst.b   (M68030).l                      | sau7 3c422b20  4a39 3c42 90ea
        bne.s   .Lcs_cache_kept                 | sau7 3c422b26  6608
        move.b  #0,(MMU+0x200).l                | sau7 3c422b28  13fc 0000 3fff b600  the cache off
.Lcs_cache_kept:
        movea.l (%sp)+,%a0                      | sau7 3c422b30  205f
        .endif
        move.w  %sr,-(%sp)                      | 3c421300  40e7
        ori.w   #0x700,%sr                      | 3c421302  007c 0700  IPL 7
        movem.l %d0-%d7/%a0-%a7,-(%sp)          | 3c421306  48e7 ffff
        lea     (CRASH_SYSTEM,%pc),%a5          | 3c42130a  4bfa fff4
        movea.l (0x46,%sp),%a0                  | 3c42130e  206f 0046  the status pointer
        move.l  (%a0),(CRASH_STATUS-CRASH_SYSTEM:w,%a5) | 3c421312  2b50 0312
        beq.b   .Lno_message                    | 3c421316  6720  status 0: shutdown
        cmpi.l  #STATUS_REBOOT,(CRASH_STATUS-CRASH_SYSTEM:w,%a5) | 3c421318  0cad 001b 0008 0312
        beq.b   .Lno_message                    | 3c421320  6716
        move.l  (0x42,%sp),(CRASH_ECB-CRASH_SYSTEM:w,%a5) | 3c421322  2b6f 0042 031c  the return address
        move.w  PROC1_$CURRENT,(crash_pid-CRASH_SYSTEM:w,%a5) | 3c421328  3b79 3c42 3204 0326
        lea     (CRASH_REPORT,%pc),%a0          | 3c421330  41fa 02d0
        bsr.w   crash_puts_string               | 3c421334  6100 011a

.Lno_message:
        lea     CRASH_$RECORD,%a1               | 3c421338  43f9 3c40 0000  the crash record
        clr.l   (%a1)                           | 3c42133e  4291
        tst.l   (CRASH_STATUS-CRASH_SYSTEM:w,%a5) | 3c421340  4aad 0312
        beq.b   .Lsave_regs                     | 3c421344  671a
        cmpi.l  #STATUS_REBOOT,(CRASH_STATUS-CRASH_SYSTEM:w,%a5) | 3c421346  0cad 001b 0008 0312
        beq.b   .Lsave_regs                     | 3c42134e  6710
        move.l  #0xabcdef01,(%a1)+              | 3c421350  22fc abcd ef01  magic
        move.l  TIME_$CLOCKH,(%a1)+             | 3c421356  22f9 3c42 e850
        move.l  (CRASH_STATUS,%pc),(%a1)        | 3c42135c  22ba 02b4

.Lsave_regs:
        lea     (%sp),%a0                       | 3c421360  41d7  the movem block
        lea     (CRASH_REGS,%pc),%a1            | 3c421362  43fa 02c6
        moveq   #15,%d0                         | 3c421366  700f  16 longwords
.Lcopy_reg:
        move.l  (%a0)+,(%a1)+                   | 3c421368  22d8
        dbf     %d0,.Lcopy_reg                  | 3c42136a  51c8 fffc
        movec   %usp,%d0                        | 3c42136e  4e7a 0800
        move.l  %d0,(CRASH_USP-CRASH_SYSTEM:w,%a5) | 3c421372  2b40 036e
        jsr     KBD_$RESET                      | 3c421376  4eb9 3c41 d660

        /* Restart?  D0 < 0: a server; 0: restart; > 0: no restart. */
        lea     (CRASH_STATUS,%pc),%a0          | 3c42137c  41fa 0294
        bsr.w   crash_reboot_check              | 3c421380  6100 02fa
        tst.w   %d0                             | 3c421384  4a40
        bmi.b   .Lserver                        | 3c421386  6b22
        cmpi.l  #STATUS_REBOOT,(%a0)            | 3c421388  0c90 001b 0008
        bne.b   .Lnot_clean                     | 3c42138e  6602
        clr.l   (%a0)                           | 3c421390  4290  a clean restart reports nothing
.Lnot_clean:
        tst.w   %d0                             | 3c421392  4a40
        bne.b   .Ldone                          | 3c421394  664e
.Lauto_reboot:
        /* restart code 0xF1 at DUMP_$AUTO_REBOOT's physical address */
        move.l  (crash_auto_reboot,%pc),%d0     | 3c421396  203a 02e0
        sub.l   (crash_dump,%pc),%d0            | 3c42139a  90ba 02d8
        .short  0xd0bc                          | 3c42139e  d0bc 0400 1400  add.l #DUMP_PHYS,%d0
        .long   DUMP_PHYS
        move.w  #0xf1,%d1                       | 3c4213a4  323c 00f1
        bra.b   .Lrestart                       | 3c4213a8  6026
.Lserver:
        lea     (CRASH_STATUS,%pc),%a0          | 3c4213aa  41fa 0266
        tst.l   (%a0)                           | 3c4213ae  4a90
        beq.b   .Lserver_shutdown               | 3c4213b0  670c
        cmpi.l  #STATUS_REBOOT,(%a0)            | 3c4213b2  0c90 001b 0008
        bne.b   .Lserver_crash                  | 3c4213b8  660c
        clr.l   (%a0)                           | 3c4213ba  4290
        bra.b   .Lauto_reboot                   | 3c4213bc  60d8
.Lserver_shutdown:
        clr.l   %d0                             | 3c4213be  4280  restart code 0xFF, address 0
        move.w  #0xff,%d1                       | 3c4213c0  323c 00ff
        bra.b   .Lrestart                       | 3c4213c4  600a
.Lserver_crash:
        move.l  #DUMP_PHYS+4,%d0                | 3c4213c6  203c 0400 1404  restart code 0xF1 at DUMP + 4
        move.w  #0xf1,%d1                       | 3c4213cc  323c 00f1
.Lrestart:
        move.l  %d0,-(%sp)                      | 3c4213d0  2f00
        move.w  %d1,-(%sp)                      | 3c4213d2  3f01
        bsr.b   crash_call_prom_restart         | 3c4213d4  6156
        addq.w  #6,%sp                          | 3c4213d6  5c4f
        move.w  (0x40,%sp),(CRASH_SAVED_SR-CRASH_SYSTEM:w,%a5) | 3c4213d8  3b6f 0040 0120
        movem.l (%sp)+,%d0-%d7/%a0-%a7          | 3c4213de  4cdf ffff
        addq.w  #2,%sp                          | 3c4213e2  544f
.Ldone:
        tst.l   (CRASH_STATUS-CRASH_SYSTEM:w,%a5) | 3c4213e4  4aad 0312
        bne.b   .Lenter_debugger                | 3c4213e8  6608
        /* status 0: back to the PROM's monitor, through its cell */
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_QUIET_RET_CELL).l,%a0 | 3c4213ea  2079 3c40 111c
        .else
        movea.l (PROM_QUIET_RET_CELL).w,%a0     | sau8 3c1ffea  2078 011c
        .endif
        jmp     (%a0)                           | 3c4213f0  4ed0
.Lenter_debugger:
        move.w  (0x40,%sp),(CRASH_SAVED_SR-CRASH_SYSTEM:w,%a5) | 3c4213f2  3b6f 0040 0120
        movem.l (%sp)+,%d0-%d7/%a0-%a7          | 3c4213f8  4cdf ffff
        addq.w  #2,%sp                          | 3c4213fc  544f  drop the SR word
        trap    #15                             | 3c4213fe  4e4f  into the debugger

        /* Reached only if the trap #15 handler returns. */
        jsr     KBD_$CRASH_INIT                 | 3c421400  4eb9 3c41 fba2
        movem.l %d0/%a0,-(%sp)                  | 3c421406  48e7 8080
        lea     (CRASH_REGS,%pc),%a0            | 3c42140a  41fa 021e
        moveq   #15,%d0                         | 3c42140e  700f
.Lclear_reg:
        clr.l   (%a0)+                          | 3c421410  4298
        dbf     %d0,.Lclear_reg                 | 3c421412  51c8 fffc
        movem.l (%sp)+,%d0/%a0                  | 3c421416  4cdf 0101
        move.w  (CRASH_SAVED_SR,%pc),%sr        | 3c42141a  46fa 0004
        rts                                     | 3c42141e  4e75

CRASH_SAVED_SR:                                 | 3c421420  the SR stash; zero
        .word   0

/* -------------------------------------------------------------------------
 * CRASH(code, param) - 0x3C421422: restart the node through the PROM
 * with restart code `code' (4(SP), a word) at DUMP + 4; the longword
 * argument (6(SP)) is replaced by that address.
 * ------------------------------------------------------------------------- */
CRASH:
        movea.l #DUMP_PHYS+4,%a0                | 3c421422  207c 0400 1404
        move.l  %a0,(6,%sp)                     | 3c421428  2f48 0006

/* crash_call_prom_restart - 0x3C42142C: call the PROM's restart entry with
   the code word at 4(SP) and the address longword at 6(SP). */
crash_call_prom_restart:
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_RESTART_CELL).l,%a0 | 3c42142c  2079 3c40 1128
        .else
        movea.l (PROM_RESTART_CELL).w,%a0       | sau8 3c2002a  2078 0128
        .endif
        move.l  (6,%sp),-(%sp)                  | 3c421432  2f2f 0006
        move.w  (8,%sp),-(%sp)                  | 3c421436  3f2f 0008
        jsr     (%a0)                           | 3c42143a  4e90
        addq.l  #6,%sp                          | 3c42143c  5c8f
        rts                                     | 3c42143e  4e75

/* -------------------------------------------------------------------------
 * CRASH_SHOW_STRING(str) - 0x3C421440: print a crash_puts_string string.
 * ------------------------------------------------------------------------- */
CRASH_SHOW_STRING:
        movem.l %d0-%d7/%a0-%a7,-(%sp)          | 3c421440  48e7 ffff
        movea.l (0x44,%sp),%a0                  | 3c421444  206f 0044
        bsr.b   crash_puts_string               | 3c421448  6106
        movem.l (%sp)+,%d0-%d7/%a0-%a7          | 3c42144a  4cdf ffff
        rts                                     | 3c42144e  4e75

/* crash_puts_string - 0x3C421450: A0 = the string.  Bytes > 0 are printed,
   '%' ends the line (CR LF), 0x00 prefixes a word printed as 4 hex digits,
   a negative byte a longword printed as 8. */
crash_puts_string:
        move.l  %a0,-(%sp)                      | 3c421450  2f08
        bsr.w   REMAP_DISPLAY                   | 3c421452  6100 006e
        bsr.b   call_prom_reload_font           | 3c421456  6154
        movea.l (%sp)+,%a0                      | 3c421458  205f
.Lputs_next:
        move.b  (%a0)+,%d1                      | 3c42145a  1218
        ble.b   .Lputs_hex                      | 3c42145c  6f14
        .short  0xb23c, 0x0025                  | 3c42145e  b23c 0025  cmp.b #'%',%d1
        beq.b   .Lputs_end                      | 3c421462  6704
        bsr.b   call_prom_putc                  | 3c421464  6134
        bra.b   .Lputs_next                     | 3c421466  60f2
.Lputs_end:
        moveq   #13,%d1                         | 3c421468  720d
        bsr.b   call_prom_putc                  | 3c42146a  612e
        moveq   #10,%d1                         | 3c42146c  720a
        bsr.b   call_prom_putc                  | 3c42146e  612a
        rts                                     | 3c421470  4e75
.Lputs_hex:
        blt.b   .Lputs_long                     | 3c421472  6d08
        move.w  (%a0)+,%d2                      | 3c421474  3418
        swap    %d2                             | 3c421476  4842
        moveq   #3,%d0                          | 3c421478  7003
        bra.b   .Lputs_nibble                   | 3c42147a  6004
.Lputs_long:
        move.l  (%a0)+,%d2                      | 3c42147c  2418
        moveq   #7,%d0                          | 3c42147e  7007
.Lputs_nibble:
        rol.l   #4,%d2                          | 3c421480  e99a
        moveq   #15,%d1                         | 3c421482  720f
        and.b   %d2,%d1                         | 3c421484  c202
        .short  0xb23c, 0x000a                  | 3c421486  b23c 000a  cmp.b #10,%d1
        blt.b   .Lputs_digit                    | 3c42148a  6d02
        addq.b  #7,%d1                          | 3c42148c  5e01
.Lputs_digit:
        .short  0xd23c, 0x0030                  | 3c42148e  d23c 0030  add.b #'0',%d1
        bsr.b   call_prom_putc                  | 3c421492  6106
        dbf     %d0,.Lputs_nibble               | 3c421494  51c8 ffea
        bra.b   .Lputs_next                     | 3c421498  60c0

/* call_prom_putc - 0x3C42149A: D1 = the character. */
call_prom_putc:
        movem.l %d0-%d2/%a0,-(%sp)              | 3c42149a  48e7 e080
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_PUTC_CELL).l,%a0 | 3c42149e  2079 3c40 1108
        .else
        movea.l (PROM_PUTC_CELL).w,%a0          | sau8 3c2009a  2078 0108
        .endif
        jsr     (%a0)                           | 3c4214a4  4e90
        movem.l (%sp)+,%d0-%d2/%a0              | 3c4214a6  4cdf 0107
        rts                                     | 3c4214aa  4e75

/* call_prom_reload_font - 0x3C4214AC */
call_prom_reload_font:
        .if trap_page_high
        movea.l (TRAP_PAGE+PROM_RELOAD_FONT_CELL).l,%a1 | 3c4214ac  2279 3c40 1114
        .else
        movea.l (PROM_RELOAD_FONT_CELL).w,%a1   | sau8 3c200a6  2278 0114
        .endif
        jmp     (%a1)                           | 3c4214b2  4ed1
        rts                                     | 3c4214b4  4e75  (not reached)

/* The display's remap cells, which COLD fills (0x3C4214B6..0x3C4214C1). */
REMAP_CSR_PPN:                                  | 3c4214b6
        .long   0
REMAP_FRM_PPN:                                  | 3c4214ba
        .long   0
REMAP_CSR_CNT:                                  | 3c4214be
        .word   0
REMAP_FRM_CNT:                                  | 3c4214c0
        .word   0

/* -------------------------------------------------------------------------
 * REMAP_DISPLAY - 0x3C4214C2: map the 128 frame-buffer pages (PPN 0x4000
 * ..0x407F) at DISP1_MEM, global, so the console works whatever the
 * crashed process had mapped: MMU_$INSTALL(ppn, va, asid 0, prot 0x26)
 * per page, at IPL 7.  With `crash_remap_cold_display' (the SAU8's,
 * 0x3C200BA) the display's REMAP_CSR_CNT control pages from REMAP_CSR_PPN
 * at DISP1, then its REMAP_FRM_CNT frame-buffer pages from REMAP_FRM_PPN
 * at DISP1_MEM, the cells COLD filled; the count is the argument block's
 * last word.
 * ------------------------------------------------------------------------- */
REMAP_DISPLAY:
        .if crash_remap_cold_display
        move.w  %sr,-(%sp)                      | sau8 3c200ba  40e7
        ori.w   #0x700,%sr                      | sau8 3c200bc  007c 0700
        move.w  (REMAP_CSR_CNT,%pc),-(%sp)      | sau8 3c200c0  3f3a fff4  the count
        move.w  #0x26,-(%sp)                    | sau8 3c200c4  3f3c 0026  protection
        clr.w   -(%sp)                          | sau8 3c200c8  4267  ASID 0
        move.l  #DISP1,-(%sp)                   | sau8 3c200ca  2f3c 03ff 9400  the VA
        move.l  (REMAP_CSR_PPN,%pc),-(%sp)      | sau8 3c200d0  2f3a ffdc  the PPN
.Lremap_csr:
        subq.w  #1,(0xc,%sp)                    | sau8 3c200d4  536f 000c
        blt.s   .Lremap_frm                     | sau8 3c200d8  6d12
        jsr     MMU_$INSTALL                    | sau8 3c200da  4eb9 03c2 59e0
        addq.l  #1,(%sp)                        | sau8 3c200e0  5297
        addi.l  #0x400,(4,%sp)                  | sau8 3c200e2  06af 0000 0400 0004
        bra.s   .Lremap_csr                     | sau8 3c200ea  60e8
.Lremap_frm:
        move.l  #DISP1_MEM,(4,%sp)              | sau8 3c200ec  2f7c 03fa 0000 0004
        move.l  (REMAP_FRM_PPN,%pc),(%sp)       | sau8 3c200f4  2eba ffbc
        move.w  (REMAP_FRM_CNT,%pc),(0xc,%sp)   | sau8 3c200f8  3f7a ffbe 000c
.Lremap_frm_next:
        subq.w  #1,(0xc,%sp)                    | sau8 3c200fe  536f 000c
        blt.s   .Lremap_end                     | sau8 3c20102  6d12
        jsr     MMU_$INSTALL                    | sau8 3c20104  4eb9 03c2 59e0
        addq.l  #1,(%sp)                        | sau8 3c2010a  5297
        addi.l  #0x400,(4,%sp)                  | sau8 3c2010c  06af 0000 0400 0004
        bra.s   .Lremap_frm_next                | sau8 3c20114  60e8
.Lremap_end:
        adda.w  #14,%sp                         | sau8 3c20116  defc 000e
        move.w  (%sp)+,%sr                      | sau8 3c2011a  46df
        rts                                     | sau8 3c2011c  4e75
        .else
        move.w  %sr,-(%sp)                      | 3c4214c2  40e7
        ori.w   #0x700,%sr                      | 3c4214c4  007c 0700
        move.w  #0x26,-(%sp)                    | 3c4214c8  3f3c 0026  protection
        clr.w   -(%sp)                          | 3c4214cc  4267  ASID 0
        move.l  #DISP1_MEM,-(%sp)               | 3c4214ce  2f3c 3ffa 0000  the VA
        move.l  #0x4000,-(%sp)                  | 3c4214d4  2f3c 0000 4000  the PPN
.Lremap_loop:
        jsr     MMU_$INSTALL                    | 3c4214da  4eb9 3c42 6ee8
        addq.l  #1,(%sp)                        | 3c4214e0  5297
        cmpi.l  #0x4080,(%sp)                   | 3c4214e2  0c97 0000 4080
        beq.b   .Lremap_done                    | 3c4214e8  670a
        addi.l  #0x400,(4,%sp)                  | 3c4214ea  06af 0000 0400 0004
        bra.b   .Lremap_loop                    | 3c4214f2  60e6
.Lremap_done:
        adda.w  #12,%sp                         | 3c4214f4  defc 000c
        move.w  (%sp)+,%sr                      | 3c4214f8  46df
        rts                                     | 3c4214fa  4e75
        .endif

/* -------------------------------------------------------------------------
 * FIM_$CRASH(frame, regs, status) - 0x3C4214FC: the fatal-fault report.
 * The SAU2's code (fim/m68k/crash.s, whose analysis applies): the frame's
 * SR, PC and format word, a class character for the vector, the fault
 * address and special status word for a bus or address error, into the
 * template below; the template printed; the registers loaded from the
 * block and CRASH_SYSTEM called with the status.
 *   0x6(SP) the exception frame, 0xA(SP) the register block, 0xE(SP)
 *   the status pointer (after the SR push)
 * With `crash_cache_off' the physical cache goes off first, as in
 * CRASH_SYSTEM, whatever the status.
 * ------------------------------------------------------------------------- */
FIM_$CRASH:
        .if crash_cache_off
        tst.b   (ROADRUNNER).l                  | sau7 3c422d58  4a39 3c42 90ec
        beq.s   .Lfc_not_rr                     | sau7 3c422d5e  670a
        move.b  #0,(MMU+0x200).l                | sau7 3c422d60  13fc 0000 3fff b600  the cache off
        bra.s   .Lfc_cache_off                  | sau7 3c422d68  6010
.Lfc_not_rr:
        tst.b   (M68030).l                      | sau7 3c422d6a  4a39 3c42 90ea
        bne.s   .Lfc_cache_off                  | sau7 3c422d70  6608
        move.b  #0,(MMU+0x200).l                | sau7 3c422d72  13fc 0000 3fff b600  the cache off
.Lfc_cache_off:
        .endif
        move.w  %sr,-(%sp)                      | 3c4214fc  40e7
        ori.w   #0x700,%sr                      | 3c4214fe  007c 0700
        lea     (CRASH_SYSTEM,%pc),%a5          | 3c421502  4bfa fdfc
        movea.l (6,%sp),%a2                     | 3c421506  246f 0006  the frame
        move.l  %a2,(fim_crash_frame-CRASH_SYSTEM:w,%a5) | 3c42150a  2b4a 02a0
        move.w  (%a2),(fim_crash_sr-CRASH_SYSTEM:w,%a5) | 3c42150e  3b52 02aa
        move.l  (2,%a2),(fim_crash_pc-CRASH_SYSTEM:w,%a5) | 3c421512  2b6a 0002 02b2
        move.w  (6,%a2),%d0                     | 3c421518  302a 0006  format/vector word
        move.w  %d0,(fim_crash_fmt-CRASH_SYSTEM:w,%a5) | 3c42151c  3b40 02bc
        lsr.w   #2,%d0                          | 3c421520  e448  the vector number
        lea     (fim_crash_trap,%pc),%a0        | 3c421522  41fa 00cc
        .short  0xb03c, 0x0020                  | 3c421526  b03c 0020  cmp.b #0x20,%d0
        blt.b   .Lfc_scan                       | 3c42152a  6d06
        .short  0xb03c, 0x0030                  | 3c42152c  b03c 0030  cmp.b #0x30,%d0
        blt.b   .Lfc_class                      | 3c421530  6d0c  TRAP #n: 'S'
.Lfc_scan:
        lea     (fim_crash_codes,%pc),%a0       | 3c421532  41fa 00a1
.Lfc_next:
        move.b  (%a0)+,%d1                      | 3c421536  1218
        beq.b   .Lfc_class                      | 3c421538  6704
        cmp.b   %d0,%d1                         | 3c42153a  b200
        bne.b   .Lfc_next                       | 3c42153c  66f8
.Lfc_class:
        move.b  (%a0),(fim_crash_type-CRASH_SYSTEM:w,%a5) | 3c42153e  1b50 02c0
        moveq   #0x25,%d4                       | 3c421542  7825  '%': the line ends here
        .short  0xb03c, 0x0003                  | 3c421544  b03c 0003  cmp.b #3,%d0
        bgt.b   .Lfc_more                       | 3c421548  6e0e
        moveq   #0x20,%d4                       | 3c42154a  7820  bus or address error: FA, SW too
        move.w  (10,%a2),(fim_crash_sw-CRASH_SYSTEM:w,%a5) | 3c42154c  3b6a 000a 02d2
        move.l  (16,%a2),(fim_crash_fa-CRASH_SYSTEM:w,%a5) | 3c421552  2b6a 0010 02c8
.Lfc_more:
        move.b  %d4,(fim_crash_more-CRASH_SYSTEM:w,%a5) | 3c421558  1b44 02c2
        lea     (fim_crash_msg,%pc),%a0         | 3c42155c  41fa 0028
        bsr.w   crash_puts_string               | 3c421560  6100 feee
        movea.l (10,%sp),%a0                    | 3c421564  206f 000a  the register block
        move.l  (60,%a0),(CRASH_SP-CRASH_SYSTEM:w,%a5) | 3c421568  2b68 003c 036a
        move.l  (32,%a0),-(%sp)                 | 3c42156e  2f28 0020  its A0
        movem.l (%a0)+,%d0-%d7/%a0-%a6          | 3c421572  4cd8 7fff
        movea.l (%sp)+,%a0                      | 3c421576  205f
        move.l  (14,%sp),-(%sp)                 | 3c421578  2f2f 000e  the status pointer
        jsr     (CRASH_SYSTEM,%pc)              | 3c42157c  4eba fd82
        addq.w  #4,%sp                          | 3c421580  584f
        move.w  (%sp)+,%sr                      | 3c421582  46df
        rts                                     | 3c421584  4e75

/* The report template, 0x3C421586..0x3C421601: the SAU2's bytes
   (fim/m68k/crash.s).  The value slots ship as zero. */
fim_crash_msg:
        .ascii  "\r\n\r\nFAULT IN DOMAIN/OS:\r\n"  | 3c421586
        .byte   0xff                            | 3c42159f  long follows
fim_crash_frame:
        .long   0                               | 3c4215a0  the frame pointer
        .ascii  ": SR:"                         | 3c4215a4
        .byte   0x00                            | 3c4215a9  word follows
fim_crash_sr:
        .short  0                               | 3c4215aa
        .ascii  "  PC:"                         | 3c4215ac
        .byte   0xff                            | 3c4215b1
fim_crash_pc:
        .long   0                               | 3c4215b2
        .ascii  "  FF:"                         | 3c4215b6
        .byte   0x00                            | 3c4215bb
fim_crash_fmt:
        .short  0                               | 3c4215bc  format/vector
        .ascii  " ("                            | 3c4215be
fim_crash_type:
        .byte   0x20                            | 3c4215c0  the fault class char
        .ascii  ")"                             | 3c4215c1
fim_crash_more:
        .byte   0x25                            | 3c4215c2  '%' ends the report, ' ' prints FA/SW
        .ascii  " FA:"                          | 3c4215c3
        .byte   0xff                            | 3c4215c7
fim_crash_fa:
        .long   0                               | 3c4215c8  the fault address
        .ascii  "  SW:"                         | 3c4215cc
        .byte   0x00                            | 3c4215d1
fim_crash_sw:
        .short  0                               | 3c4215d2  the special status word
        .ascii  "%"                             | 3c4215d4
/* (vector number, class char) pairs; a 0 code ends the list and selects
   the char after it, 'I'.  Vectors 0x20..0x2F (TRAP #n) take the 'S'. */
fim_crash_codes:
        .byte   0x02,0x42, 0x03,0x41, 0x04,0x55, 0x05,0x5a  | 3c4215d5  B A U Z
        .byte   0x06,0x43, 0x07,0x54, 0x08,0x4d, 0x09,0x54  | 3c4215dd  C T M T
        .byte   0x0a,0x55, 0x0b,0x55, 0x0e,0x46, 0x18,0x4a  | 3c4215e5  U U F J
        .byte   0x1f,0x50, 0x20                             | 3c4215ed  P, TRAP
fim_crash_trap:
        .byte   0x53                                        | 3c4215f0  'S'
        .byte   0x30,0x4f, 0x31,0x4f, 0x32,0x4f, 0x33,0x4f  | 3c4215f1  O O O O
        .byte   0x34,0x4f, 0x35,0x4f, 0x36,0x4f             | 3c4215f9  O O O
        .byte   0x00, 0x49                                  | 3c4215ff  end, 'I'
        .byte   0x00                                        | 3c421601  pad

/* -------------------------------------------------------------------------
 * The crash report, 0x3C421602 (misc/m68k/crash_report.s's block, with
 * SERVER_$FLAG in the byte after the '%' and the restart cells after it).
 * ------------------------------------------------------------------------- */
CRASH_REPORT:
        .byte   0x0d, 0x0a                      | 3c421602
        .ascii  "Crash_Status "                 | 3c421604
        .byte   0xff                            | 3c421611
CRASH_STATUS:                                   | 3c421612
        .long   0
        .ascii  "  PC "                         | 3c421616
        .byte   0xff                            | 3c42161b
CRASH_ECB:                                      | 3c42161c
        .long   0
        .ascii  " pid "                         | 3c421620
        .byte   0x00                            | 3c421625
crash_pid:                                      | 3c421626  the pid
        .word   0
        .byte   0x25                            | 3c421628  '%'
SERVER_$FLAG:                                   | 3c421629  a boolean byte (misc/crash_system.ins.pas)
        .byte   0
CRASH_REGS:                                     | 3c42162a
        .space  16 * 4
CRASH_SP:                                       | 3c42166a
        .long   0
CRASH_USP:                                      | 3c42166e
        .long   0
CRASH_$OK_TO_REBOOT:                            | 3c421672  a boolean byte (misc/crash_system.ins.pas)
        .byte   0
        .byte   0x74                            | 3c421673  not referenced
crash_dump:                                     | 3c421674
        .long   DUMP
crash_auto_reboot:                              | 3c421678
        .long   DUMP_$AUTO_REBOOT

/* -------------------------------------------------------------------------
 * crash_reboot_check - 0x3C42167C: A0 = &CRASH_STATUS.  D0.w = -1 on a
 * server (SERVER_$FLAG); else 1 (no restart) when MMU_$NORMAL_MODE is
 * false, CRASH_$OK_TO_REBOOT is clear, or the status is 0, 0x00010002 or
 * 0x000B0008; else 0 (restart).
 * ------------------------------------------------------------------------- */
crash_reboot_check:
        movem.l %a0/%a5,-(%sp)                  | 3c42167c  48e7 0084
        jsr     MMU_$NORMAL_MODE                | 3c421680  4eb9 3c42 7224
        lea     (CRASH_SYSTEM,%pc),%a5          | 3c421686  4bfa fc78
        tst.b   %d0                             | 3c42168a  4a00
        beq.b   .Lrc_no                         | 3c42168c  672e
        tst.b   (SERVER_$FLAG).l                | 3c42168e  4a39 3c42 1629
        bne.b   .Lrc_server                     | 3c421694  662a
        tst.b   (CRASH_$OK_TO_REBOOT).l         | 3c421696  4a39 3c42 1672
        beq.b   .Lrc_no                         | 3c42169c  671e
        movea.l (%sp),%a0                       | 3c42169e  2057
        tst.l   (%a0)                           | 3c4216a0  4a90
        beq.b   .Lrc_no                         | 3c4216a2  6718
        cmpi.l  #0x00010002,(%a0)               | 3c4216a4  0c90 0001 0002
        beq.b   .Lrc_no                         | 3c4216aa  6710
        cmpi.l  #0x000b0008,(%a0)               | 3c4216ac  0c90 000b 0008
        beq.b   .Lrc_no                         | 3c4216b2  6708
        clr.w   %d0                             | 3c4216b4  4240
.Lrc_exit:
        movem.l (%sp)+,%a0/%a5                  | 3c4216b6  4cdf 2100
        rts                                     | 3c4216ba  4e75
.Lrc_no:
        moveq   #1,%d0                          | 3c4216bc  7001
        bra.b   .Lrc_exit                       | 3c4216be  60f6
.Lrc_server:
        moveq   #-1,%d0                         | 3c4216c0  70ff
        bra.b   .Lrc_exit                       | 3c4216c2  60f2
        .if crash_remap_cold_display
        .short  0                               | sau8 3c202e6  to the segment's end (size 3E8)
        .endif

        .endif
