|
| misc/m68k/crash_report.s - the crash report block at the end of the
| hand-written CRASH_SYSTEM segment: the message template CRASH_SYSTEM
| prints, with the live crash fields embedded in it (m68k/SAU2, SAU3,
| SAU5)
|
| The SAU2 and SAU5 images have the same block except in two places, which
| test base/config.ins.pas's part `crash_report_blank_lines': the SAU5's
| header is "\n\n\n\r\r\n" where the SAU2's is CR LF (so every field
| below is 4 bytes further on: CRASH_REPORT 0xE1F648, CRASH_STATUS
| 0xE1F65C .. CRASH_USP 0xE1F6B8), and the SAU5's block ends at its
| segment's end (`D E1F300 CRASH_SYSTEM size = 3BC', 0xE1F6BC) with no pad
| word.  The address columns are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): every byte is
| compared with the image.
|
| SAU2 map: "D E1E700 CRASH_SYSTEM size = 2F0", the block 0xE1E97E..
| 0xE1E9EE and the segment's two pad bytes to 0xE1E9F0 (DMA_ follows),
| after FIM_$CRASH's tables (fim/m68k/crash.s).  The map's symbols in it
| are the live fields; the block's own name, CRASH_REPORT, is not the
| map's (tools/asm_compare.py LOCAL_SYMBOLS):
|
|   +0x00  0xE1E97E  CRASH_REPORT   CR LF, "Crash_Status ", 0xFF (a
|                                   32-bit hex field follows)
|   +0x10  0xE1E98E  CRASH_STATUS   the status (CRASH_SYSTEM stores it)
|   +0x14                           "  PC ", 0xFF
|   +0x1A  0xE1E998  CRASH_ECB      the caller's return address
|   +0x1E                           " pid ", 0x00 (a 16-bit field follows)
|   +0x24                           PROC1_$CURRENT
|   +0x26                           '%' (the end of the message), a pad
|   +0x28  0xE1E9A6  CRASH_REGS     D0-D7, A0-A7 (16 longwords)
|   +0x68  0xE1E9E6  CRASH_SP       a longword
|   +0x6C  0xE1E9EA  CRASH_USP      the user stack pointer
|
| The SAU3's block (`D E1D700 CRASH_SYSTEM size = 2F8', 0xE1D97E..) is
| the SAU2's, and in place of the pad word the restart's cells
| (`crash_prom_restart', misc/m68k/crash_system.s): the byte
| CRASH_$OK_TO_REBOOT (0xE1D9EE), a byte 0x74 nothing references, and
| the addresses of DUMP and DUMP_$AUTO_REBOOT (0xE1D9F0, 0xE1D9F4: RELOC
| cells), to the segment's end (0xE1D9F8).
|
| Not on the other SAUs whose crash may restart the node (`crash_reboot',
| base/config.ins.pas): their report holds the restart cells and
| SERVER_$FLAG (the SAU9's misc/sau9/crash_system.s).
|
        .include "base/config.inc"
        .if     !(crash_reboot && !crash_prom_restart)

        .section ".text.CRASH_REPORT","ax",@progbits
        .balign 2

        .globl  CRASH_REPORT
        .globl  CRASH_STATUS
        .globl  CRASH_ECB
        .globl  CRASH_REGS
        .globl  CRASH_SP
        .globl  CRASH_USP

CRASH_REPORT:                           | 0xE1E97E
        .if crash_report_blank_lines
        .byte   0x0A, 0x0A, 0x0A, 0x0D, 0x0D, 0x0A      | sau5 0xE1F648
        .else
        .byte   0x0D, 0x0A
        .endif
        .ascii  "Crash_Status "
        .byte   0xFF
CRASH_STATUS:                           | 0xE1E98E
        .long   0
        .ascii  "  PC "
        .byte   0xFF
CRASH_ECB:                              | 0xE1E998
        .long   0
        .ascii  " pid "
        .byte   0x00
        .word   0                       | 0xE1E9A2: the pid
        .byte   0x25                    | 0xE1E9A4: '%'
        .byte   0
CRASH_REGS:                             | 0xE1E9A6
        .space  16 * 4
CRASH_SP:                               | 0xE1E9E6
        .long   0
CRASH_USP:                              | 0xE1E9EA
        .long   0
        .if crash_prom_restart
        .globl  CRASH_$OK_TO_REBOOT
        .globl  crash_dump
        .globl  crash_auto_reboot
CRASH_$OK_TO_REBOOT:                    | sau3 0xE1D9EE: a boolean byte
        .byte   0
        .byte   0x74                    | sau3 0xE1D9EF: not referenced
crash_dump:                             | sau3 0xE1D9F0
        .long   DUMP
crash_auto_reboot:                      | sau3 0xE1D9F4
        .long   DUMP_$AUTO_REBOOT
        .elseif !crash_report_blank_lines
        .word   0                       | 0xE1E9EE: pad to the segment size
        .endif

        .endif
