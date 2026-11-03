|
| misc/sau4/crash_system.s - the CRASH_SYSTEM module of the SAU4: CRASH_SYSTEM,
| the restart through the PROM, the crash console, REMAP_DISPLAY,
| FIM_$CRASH, the crash report and CRASH_CHK_CACHES
|
| SAU4 map: "D F81FAF8 CRASH_SYSTEM size = 4F8" (WIRED_DATA),
| 0x0F81FAF8..0x0F81FFEF, hand-written code and data, one section (the
| cells are reached off A5 = CRASH_SYSTEM, `lea (d,PC),A5', and
| PC-relatively, so the displacements stay those of the image as long as
| the segment is one piece):
|
|   0xF81FAF8  CRASH_PAUSE, CRASH_SYSTEM
|   0xF81FC26  the SR stash (no map name)
|   0xF81FC28  CRASH: restart through the PROM with a code at DUMP + 4
|   0xF81FC32  the call of the PROM's restart cell 0x128 (no map name)
|   0xF81FC44  CRASH_SHOW_STRING, then the string writer, the PROM putc
|              (cell 0x108) and the font reload (cell 0x114)
|   0xF81FCB6  DISP2_PRESENT (OS_$INIT's second-display probe sets it)
|   0xF81FCB8  REMAP_DISPLAY: at IPL 7, maps the color board's control
|              store and DISP2_MEM when DISP2_PRESENT, else DISP1_MEM
|   0xF81FD30  FIM_$CRASH and its report template (0xF81FDBA..)
|   0xF81FE38  the crash report: CRASH_STATUS, CRASH_ECB, SERVER_$FLAG,
|              CRASH_REGS, CRASH_SP, CRASH_USP, CRASH_$OK_TO_REBOOT, then
|              DUMP's and DUMP_$AUTO_REBOOT's addresses
|   0xF81FEB2  the restart check (no map name): after MMU_$NORMAL_MODE,
|              0 = no restart, 1 = restart, -1 = a server's shutdown
|   0xF81FEFA  CRASH_CHK_CACHES: with control register 0x10F set, reads
|              the data cache's RAM failure log (control registers 0x116,
|              0x115, up to 63 entries), prints "Fatal Hardware Error -
|              Dcache Ram Failures:" and each failing address and data,
|              and sets the cell at A5 + 0x4AA
|
| CRASH_SYSTEM is the SAU2's (misc/m68k/crash_system.s) with the restart
| of the SAU3 (`crash_prom_restart': codes 0xF1 and 0xFF through the
| PROM's cell 0x128, at DUMP_$AUTO_REBOOT's physical address or DUMP + 4)
| and of the SAU9 (the restart check, KBD_$RESET, KBD_$CRASH_INIT), and
| the cache check first (`crash_cache_check', base/config.ins.pas).  The
| physical addresses 0x200C00 and 0x200C04 are DUMP's page where COLD
| left it.  The other SAUs' modules are misc/m68k/crash_system.s,
| crash_report.s, fim/m68k/crash.s and misc/m68k/crash_system_restart.s.
|
| The DNx60's control registers 0x10F, 0x115 and 0x116 and the Apollo
| assembler's <ea>=#imm forms (cmp/add/and #imm,Dn), which gas spells
| otherwise, are written as words with the instruction in the comment.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau4 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.
|
        .include "base/config.inc"

        .section ".text.CRASH_SYSTEM","ax",@progbits
        .even

        .globl  CRASH_PAUSE
        .globl  CRASH_SYSTEM
        .globl  CRASH
        .globl  CRASH_SHOW_STRING
        .globl  DISP2_PRESENT
        .globl  REMAP_DISPLAY
        .globl  FIM_$CRASH
        .globl  CRASH_STATUS
        .globl  CRASH_ECB
        .globl  SERVER_$FLAG
        .globl  CRASH_REGS
        .globl  CRASH_SP
        .globl  CRASH_USP
        .globl  CRASH_$OK_TO_REBOOT
        .globl  CRASH_CHK_CACHES
        .globl  CRASH_REPORT

CRASH_PAUSE:
CRASH_SYSTEM:
        move.w  %sr,-(%sp)                      | sau4 f81faf8  40e7
        ori.w   #0x700,%sr                      | sau4 f81fafa  007c 0700
        movem.l %d0-%a7,-(%sp)                  | sau4 f81fafe  48e7 ffff
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau4 f81fb02  4bfa fff4
        bsr.w   CRASH_CHK_CACHES                | sau4 f81fb06  6100 03f2
        bne.s   .Lf81fb10                       | sau4 f81fb0a  6604
        clr.b   (0x4aa,%a5)                     | sau4 f81fb0c  422d 04aa
.Lf81fb10:
        movea.l (0x46,%sp),%a0                  | sau4 f81fb10  206f 0046
        move.l  (%a0),(0x350,%a5)               | sau4 f81fb14  2b50 0350
        beq.s   .Lf81fb3a                       | sau4 f81fb18  6720
        cmpi.l  #0x1b0008,(0x350,%a5)           | sau4 f81fb1a  0cad 001b 0008 0350
        beq.s   .Lf81fb3a                       | sau4 f81fb22  6716
        move.l  (0x42,%sp),(0x35a,%a5)          | sau4 f81fb24  2b6f 0042 035a
        move.w  (PROC1_$CURRENT).l,(0x364,%a5)  | sau4 f81fb2a  3b79 0f82 1c18 0364
        lea     (CRASH_REPORT:w,%pc),%a0        | sau4 f81fb32  41fa 0304
        bsr.w   crash_puts_string               | sau4 f81fb36  6100 011c
.Lf81fb3a:
        lea     (CRASH_$RECORD).l,%a1           | sau4 f81fb3a  43f9 0f80 0000
        clr.l   (%a1)                           | sau4 f81fb40  4291
        tst.l   (0x350,%a5)                     | sau4 f81fb42  4aad 0350
        beq.s   .Lf81fb62                       | sau4 f81fb46  671a
        cmpi.l  #0x1b0008,(0x350,%a5)           | sau4 f81fb48  0cad 001b 0008 0350
        beq.s   .Lf81fb62                       | sau4 f81fb50  6710
        move.l  #0xabcdef01,(%a1)+              | sau4 f81fb52  22fc abcd ef01
        move.l  (TIME_$CLOCKH_EC).l,(%a1)+      | sau4 f81fb58  22f9 0f82 d788
        move.l  (CRASH_STATUS:w,%pc),(%a1)      | sau4 f81fb5e  22ba 02e8
.Lf81fb62:
        lea     (%sp),%a0                       | sau4 f81fb62  41d7
        lea     (CRASH_REGS:w,%pc),%a1          | sau4 f81fb64  43fa 02fa
        moveq   #15,%d0                         | sau4 f81fb68  700f
.Lf81fb6a:
        move.l  (%a0)+,(%a1)+                   | sau4 f81fb6a  22d8
        dbf     %d0,.Lf81fb6a                   | sau4 f81fb6c  51c8 fffc
        movec   %usp,%d0                        | sau4 f81fb70  4e7a 0800
        move.l  %d0,(0x3ac,%a5)                 | sau4 f81fb74  2b40 03ac
        jsr     (KBD_$RESET).l                  | sau4 f81fb78  4eb9 0f81 bd3c
        lea     (CRASH_STATUS:w,%pc),%a0        | sau4 f81fb7e  41fa 02c8
        bsr.w   crash_reboot_check              | sau4 f81fb82  6100 032e
        tst.w   %d0                             | sau4 f81fb86  4a40
        bmi.s   .Lf81fbac                       | sau4 f81fb88  6b22
        cmpi.l  #0x1b0008,(%a0)                 | sau4 f81fb8a  0c90 001b 0008
        bne.s   .Lf81fb94                       | sau4 f81fb90  6602
        clr.l   (%a0)                           | sau4 f81fb92  4290
.Lf81fb94:
        tst.w   %d0                             | sau4 f81fb94  4a40
        bne.s   .Lf81fbec                       | sau4 f81fb96  6654
.Lf81fb98:
        move.l  (crash_auto_reboot:w,%pc),%d0   | sau4 f81fb98  203a 0314
        sub.l   (crash_dump:w,%pc),%d0          | sau4 f81fb9c  90ba 030c
        .short  0xd0bc, 0x0020, 0x0c00          | sau4 f81fba0  d0bc 0020 0c00  add.l   #0x200c00,%d0
        move.w  #0xf1,%d1                       | sau4 f81fba6  323c 00f1
        bra.s   .Lf81fbd8                       | sau4 f81fbaa  602c
.Lf81fbac:
        lea     (CRASH_STATUS:w,%pc),%a0        | sau4 f81fbac  41fa 029a
        tst.l   (%a0)                           | sau4 f81fbb0  4a90
        beq.s   .Lf81fbc0                       | sau4 f81fbb2  670c
        cmpi.l  #0x1b0008,(%a0)                 | sau4 f81fbb4  0c90 001b 0008
        bne.s   .Lf81fbc8                       | sau4 f81fbba  660c
        clr.l   (%a0)                           | sau4 f81fbbc  4290
        bra.s   .Lf81fb98                       | sau4 f81fbbe  60d8
.Lf81fbc0:
        clr.l   %d0                             | sau4 f81fbc0  4280
        move.w  #0xff,%d1                       | sau4 f81fbc2  323c 00ff
        bra.s   .Lf81fbd8                       | sau4 f81fbc6  6010
.Lf81fbc8:
        tst.b   (0x4aa,%a5)                     | sau4 f81fbc8  4a2d 04aa
        bne.s   .Lf81fbc0                       | sau4 f81fbcc  66f2
        move.l  #0x200c04,%d0                   | sau4 f81fbce  203c 0020 0c04
        move.w  #0xf1,%d1                       | sau4 f81fbd4  323c 00f1
.Lf81fbd8:
        move.l  %d0,-(%sp)                      | sau4 f81fbd8  2f00
        move.w  %d1,-(%sp)                      | sau4 f81fbda  3f01
        bsr.s   crash_call_prom_restart         | sau4 f81fbdc  6154
        addq.w  #6,%sp                          | sau4 f81fbde  5c4f
        move.w  (0x40,%sp),(0x12e,%a5)          | sau4 f81fbe0  3b6f 0040 012e
        movem.l (%sp)+,%d0-%a7                  | sau4 f81fbe6  4cdf ffff
        addq.w  #2,%sp                          | sau4 f81fbea  544f
.Lf81fbec:
        tst.l   (0x350,%a5)                     | sau4 f81fbec  4aad 0350
        bne.s   .Lf81fbf8                       | sau4 f81fbf0  6606
        movea.l (0x11c).w,%a0                   | sau4 f81fbf2  2078 011c
        jmp     (%a0)                           | sau4 f81fbf6  4ed0
.Lf81fbf8:
        move.w  (0x40,%sp),(0x12e,%a5)          | sau4 f81fbf8  3b6f 0040 012e
        movem.l (%sp)+,%d0-%a7                  | sau4 f81fbfe  4cdf ffff
        addq.w  #2,%sp                          | sau4 f81fc02  544f
        trap    #0xf                            | sau4 f81fc04  4e4f
        jsr     (KBD_$CRASH_INIT).l             | sau4 f81fc06  4eb9 0f81 e0a8
        movem.l %d0/%a0,-(%sp)                  | sau4 f81fc0c  48e7 8080
        lea     (CRASH_REGS:w,%pc),%a0          | sau4 f81fc10  41fa 024e
        moveq   #15,%d0                         | sau4 f81fc14  700f
.Lf81fc16:
        clr.l   (%a0)+                          | sau4 f81fc16  4298
        dbf     %d0,.Lf81fc16                   | sau4 f81fc18  51c8 fffc
        movem.l (%sp)+,%d0/%a0                  | sau4 f81fc1c  4cdf 0101
        move.w  (CRASH_SAVED_SR:w,%pc),%sr      | sau4 f81fc20  46fa 0004
        rts                                     | sau4 f81fc24  4e75
CRASH_SAVED_SR:
        .short  0x0000                          | sau4 f81fc26
CRASH:
        movea.l #0x200c04,%a0                   | sau4 f81fc28  207c 0020 0c04
        move.l  %a0,(0x6,%sp)                   | sau4 f81fc2e  2f48 0006
crash_call_prom_restart:
        movea.l (0x128).w,%a0                   | sau4 f81fc32  2078 0128
        move.l  (0x6,%sp),-(%sp)                | sau4 f81fc36  2f2f 0006
        move.w  (0x8,%sp),-(%sp)                | sau4 f81fc3a  3f2f 0008
        jsr     (%a0)                           | sau4 f81fc3e  4e90
        addq.l  #6,%sp                          | sau4 f81fc40  5c8f
        rts                                     | sau4 f81fc42  4e75
CRASH_SHOW_STRING:
        movem.l %d0-%a7,-(%sp)                  | sau4 f81fc44  48e7 ffff
        movea.l (0x44,%sp),%a0                  | sau4 f81fc48  206f 0044
        bsr.s   crash_puts_string               | sau4 f81fc4c  6106
        movem.l (%sp)+,%d0-%a7                  | sau4 f81fc4e  4cdf ffff
        rts                                     | sau4 f81fc52  4e75
crash_puts_string:
        move.l  %a0,-(%sp)                      | sau4 f81fc54  2f08
        bsr.w   REMAP_DISPLAY                   | sau4 f81fc56  6100 0060
        bsr.s   call_prom_reload_font           | sau4 f81fc5a  6152
        movea.l (%sp)+,%a0                      | sau4 f81fc5c  205f
.Lf81fc5e:
        move.b  (%a0)+,%d1                      | sau4 f81fc5e  1218
        ble.s   .Lf81fc76                       | sau4 f81fc60  6f14
        .short  0xb23c, 0x0025                  | sau4 f81fc62  b23c 0025  cmp.b   #0x25,%d1
        beq.s   .Lf81fc6c                       | sau4 f81fc66  6704
        bsr.s   call_prom_putc                  | sau4 f81fc68  6134
        bra.s   .Lf81fc5e                       | sau4 f81fc6a  60f2
.Lf81fc6c:
        moveq   #13,%d1                         | sau4 f81fc6c  720d
        bsr.s   call_prom_putc                  | sau4 f81fc6e  612e
        moveq   #10,%d1                         | sau4 f81fc70  720a
        bsr.s   call_prom_putc                  | sau4 f81fc72  612a
        rts                                     | sau4 f81fc74  4e75
.Lf81fc76:
        blt.s   .Lf81fc80                       | sau4 f81fc76  6d08
        move.w  (%a0)+,%d2                      | sau4 f81fc78  3418
        swap    %d2                             | sau4 f81fc7a  4842
        moveq   #3,%d0                          | sau4 f81fc7c  7003
        bra.s   .Lf81fc84                       | sau4 f81fc7e  6004
.Lf81fc80:
        move.l  (%a0)+,%d2                      | sau4 f81fc80  2418
        moveq   #7,%d0                          | sau4 f81fc82  7007
.Lf81fc84:
        rol.l   #4,%d2                          | sau4 f81fc84  e99a
        moveq   #15,%d1                         | sau4 f81fc86  720f
        and.b   %d2,%d1                         | sau4 f81fc88  c202
        .short  0xb23c, 0x000a                  | sau4 f81fc8a  b23c 000a  cmp.b   #0xa,%d1
        blt.s   .Lf81fc92                       | sau4 f81fc8e  6d02
        addq.b  #7,%d1                          | sau4 f81fc90  5e01
.Lf81fc92:
        .short  0xd23c, 0x0030                  | sau4 f81fc92  d23c 0030  add.b   #0x30,%d1
        bsr.s   call_prom_putc                  | sau4 f81fc96  6106
        dbf     %d0,.Lf81fc84                   | sau4 f81fc98  51c8 ffea
        bra.s   .Lf81fc5e                       | sau4 f81fc9c  60c0
call_prom_putc:
        movem.l %d0-%d2/%a0,-(%sp)              | sau4 f81fc9e  48e7 e080
        movea.l (0x108).w,%a0                   | sau4 f81fca2  2078 0108
        jsr     (%a0)                           | sau4 f81fca6  4e90
        movem.l (%sp)+,%d0-%d2/%a0              | sau4 f81fca8  4cdf 0107
        rts                                     | sau4 f81fcac  4e75
call_prom_reload_font:
        movea.l (0x114).w,%a1                   | sau4 f81fcae  2278 0114
        jmp     (%a1)                           | sau4 f81fcb2  4ed1
        rts                                     | sau4 f81fcb4  4e75
DISP2_PRESENT:
        .short  0x0000                          | sau4 f81fcb6
REMAP_DISPLAY:
        move.w  %sr,-(%sp)                      | sau4 f81fcb8  40e7
        ori.w   #0x700,%sr                      | sau4 f81fcba  007c 0700
        move.w  #0x26,-(%sp)                    | sau4 f81fcbe  3f3c 0026
        clr.w   -(%sp)                          | sau4 f81fcc2  4267
        tst.b   (DISP2_PRESENT).l               | sau4 f81fcc4  4a39 0f81 fcb6
        beq.s   .Lf81fcf2                       | sau4 f81fcca  6726
        lea     (COLOR_CSTORE).l,%a0            | sau4 f81fccc  41f9 0fff 6800
        move.l  %a0,-(%sp)                      | sau4 f81fcd2  2f08
        move.l  #0x3a,-(%sp)                    | sau4 f81fcd4  2f3c 0000 003a
        jsr     (MMU_$INSTALL).l                | sau4 f81fcda  4eb9 0f82 633a
        addq.l  #8,%sp                          | sau4 f81fce0  508f
        lea     (DISP2_MEM).l,%a0               | sau4 f81fce2  41f9 0ffa 0000
        move.l  %a0,-(%sp)                      | sau4 f81fce8  2f08
        move.l  #0x100,-(%sp)                   | sau4 f81fcea  2f3c 0000 0100
        bra.s   .Lf81fcfe                       | sau4 f81fcf0  600c
.Lf81fcf2:
        move.l  #DISP1_MEM,-(%sp)               | sau4 f81fcf2  2f3c 0ffc 0000
        move.l  #0x80,-(%sp)                    | sau4 f81fcf8  2f3c 0000 0080
.Lf81fcfe:
        jsr     (MMU_$INSTALL).l                | sau4 f81fcfe  4eb9 0f82 633a
        addq.l  #1,(%sp)                        | sau4 f81fd04  5297
        cmpi.l  #0x180,(%sp)                    | sau4 f81fd06  0c97 0000 0180
        bne.s   .Lf81fd16                       | sau4 f81fd0c  6608
        move.l  #0x80,(%sp)                     | sau4 f81fd0e  2ebc 0000 0080
        bra.s   .Lf81fd1e                       | sau4 f81fd14  6008
.Lf81fd16:
        cmpi.l  #0x100,(%sp)                    | sau4 f81fd16  0c97 0000 0100
        beq.s   .Lf81fd28                       | sau4 f81fd1c  670a
.Lf81fd1e:
        addi.l  #0x400,(0x4,%sp)                | sau4 f81fd1e  06af 0000 0400 0004
        bra.s   .Lf81fcfe                       | sau4 f81fd26  60d6
.Lf81fd28:
        adda.w  #0xc,%sp                        | sau4 f81fd28  defc 000c
        move.w  (%sp)+,%sr                      | sau4 f81fd2c  46df
        rts                                     | sau4 f81fd2e  4e75
FIM_$CRASH:
        move.w  %sr,-(%sp)                      | sau4 f81fd30  40e7
        ori.w   #0x700,%sr                      | sau4 f81fd32  007c 0700
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau4 f81fd36  4bfa fdc0
        movea.l (0x6,%sp),%a2                   | sau4 f81fd3a  246f 0006
        move.l  %a2,(0x2dc,%a5)                 | sau4 f81fd3e  2b4a 02dc
        move.w  (%a2),(0x2e6,%a5)               | sau4 f81fd42  3b52 02e6
        move.l  (0x2,%a2),(0x2ee,%a5)           | sau4 f81fd46  2b6a 0002 02ee
        move.w  (0x6,%a2),%d0                   | sau4 f81fd4c  302a 0006
        move.w  %d0,(0x2f8,%a5)                 | sau4 f81fd50  3b40 02f8
        lsr.w   #2,%d0                          | sau4 f81fd54  e448
        lea     (.Lf81fe22:w,%pc),%a0           | sau4 f81fd56  41fa 00ca
        .short  0xb03c, 0x0020                  | sau4 f81fd5a  b03c 0020  cmp.b   #0x20,%d0
        blt.s   .Lf81fd66                       | sau4 f81fd5e  6d06
        .short  0xb03c, 0x0030                  | sau4 f81fd60  b03c 0030  cmp.b   #0x30,%d0
        blt.s   .Lf81fd72                       | sau4 f81fd64  6d0c
.Lf81fd66:
        lea     (.Lf81fe09:w,%pc),%a0           | sau4 f81fd66  41fa 00a1
.Lf81fd6a:
        move.b  (%a0)+,%d1                      | sau4 f81fd6a  1218
        beq.s   .Lf81fd72                       | sau4 f81fd6c  6704
        cmp.b   %d0,%d1                         | sau4 f81fd6e  b200
        bne.s   .Lf81fd6a                       | sau4 f81fd70  66f8
.Lf81fd72:
        move.b  (%a0),(0x2fc,%a5)               | sau4 f81fd72  1b50 02fc
        moveq   #37,%d4                         | sau4 f81fd76  7825
        .short  0xb03c, 0x0003                  | sau4 f81fd78  b03c 0003  cmp.b   #3,%d0
        bgt.s   .Lf81fd8c                       | sau4 f81fd7c  6e0e
        moveq   #32,%d4                         | sau4 f81fd7e  7820
        move.w  (0x8,%a2),(0x30e,%a5)           | sau4 f81fd80  3b6a 0008 030e
        move.l  (0xa,%a2),(0x304,%a5)           | sau4 f81fd86  2b6a 000a 0304
.Lf81fd8c:
        move.b  %d4,(0x2fe,%a5)                 | sau4 f81fd8c  1b44 02fe
        lea     (fim_crash_msg:w,%pc),%a0       | sau4 f81fd90  41fa 0028
        bsr.w   crash_puts_string               | sau4 f81fd94  6100 febe
        movea.l (0xa,%sp),%a0                   | sau4 f81fd98  206f 000a
        move.l  (0x3c,%a0),(0x3a8,%a5)          | sau4 f81fd9c  2b68 003c 03a8
        move.l  (0x20,%a0),-(%sp)               | sau4 f81fda2  2f28 0020
        movem.l (%a0)+,%d0-%a6                  | sau4 f81fda6  4cd8 7fff
        movea.l (%sp)+,%a0                      | sau4 f81fdaa  205f
        move.l  (0xe,%sp),-(%sp)                | sau4 f81fdac  2f2f 000e
        jsr     (CRASH_SYSTEM:w,%pc)            | sau4 f81fdb0  4eba fd46
        addq.w  #4,%sp                          | sau4 f81fdb4  584f
        move.w  (%sp)+,%sr                      | sau4 f81fdb6  46df
        rts                                     | sau4 f81fdb8  4e75
fim_crash_msg:
        .byte   0x0d, 0x0a, 0x0d, 0x0a, 0x46, 0x41, 0x55, 0x4c | sau4 f81fdba  "....FAUL"
        .byte   0x54, 0x20, 0x49, 0x4e, 0x20, 0x44, 0x4f, 0x4d | sau4 f81fdc2  "T IN DOM"
        .byte   0x41, 0x49, 0x4e, 0x2f, 0x4f, 0x53, 0x3a, 0x0d | sau4 f81fdca  "AIN/OS:."
        .byte   0x0a, 0xff, 0x00, 0x00, 0x00, 0x00, 0x3a, 0x20 | sau4 f81fdd2  "......: "
        .byte   0x53, 0x52, 0x3a, 0x00, 0x00, 0x00, 0x20, 0x20 | sau4 f81fdda  "SR:...  "
        .byte   0x50, 0x43, 0x3a, 0xff, 0x00, 0x00, 0x00, 0x00 | sau4 f81fde2  "PC:....."
        .byte   0x20, 0x20, 0x46, 0x46, 0x3a, 0x00, 0x00, 0x00 | sau4 f81fdea  "  FF:..."
        .byte   0x20, 0x28, 0x20, 0x29, 0x25, 0x20, 0x46, 0x41 | sau4 f81fdf2  " ( )% FA"
        .byte   0x3a, 0xff, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20 | sau4 f81fdfa  ":.....  "
        .byte   0x53, 0x57, 0x3a, 0x00, 0x00, 0x00, 0x25 | sau4 f81fe02  "SW:...%"
.Lf81fe09:
        .byte   0x02, 0x42, 0x03, 0x41, 0x04, 0x55, 0x05, 0x5a | sau4 f81fe09  ".B.A.U.Z"
        .byte   0x06, 0x43, 0x07, 0x54, 0x08, 0x4d, 0x09, 0x54 | sau4 f81fe11  ".C.T.M.T"
        .byte   0x0a, 0x55, 0x0b, 0x55, 0x0e, 0x46, 0x18, 0x4a | sau4 f81fe19  ".U.U.F.J"
        .byte   0x20                            | sau4 f81fe21  " "
.Lf81fe22:
        .byte   0x53, 0x31, 0x4f, 0x32, 0x4f, 0x33, 0x4f, 0x34 | sau4 f81fe22  "S1O2O3O4"
        .byte   0x4f, 0x35, 0x4f, 0x80, 0x57, 0x81, 0x58, 0x82 | sau4 f81fe2a  "O5O.W.X."
        .byte   0x59, 0x83, 0x56, 0x00, 0x49, 0x00 | sau4 f81fe32  "Y.V.I."
CRASH_REPORT:
        .byte   0x0d, 0x0a, 0x43, 0x72, 0x61, 0x73, 0x68, 0x5f | sau4 f81fe38  "..Crash_"
        .byte   0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x20, 0xff | sau4 f81fe40  "Status ."
CRASH_STATUS:
        .byte   0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x50, 0x43 | sau4 f81fe48  "....  PC"
        .byte   0x20, 0xff                      | sau4 f81fe50  " ."
CRASH_ECB:
        .byte   0x00, 0x00, 0x00, 0x00, 0x20, 0x70, 0x69, 0x64 | sau4 f81fe52  ".... pid"
        .byte   0x20, 0x00, 0x00, 0x00, 0x25    | sau4 f81fe5a  " ...%"
SERVER_$FLAG:
        .byte   0x00                            | sau4 f81fe5f  "."
CRASH_REGS:
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe60  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe68  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe70  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe78  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe80  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe88  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe90  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau4 f81fe98  "........"
CRASH_SP:
        .byte   0x00, 0x00, 0x00, 0x00          | sau4 f81fea0  "...."
CRASH_USP:
        .byte   0x00, 0x00, 0x00, 0x00          | sau4 f81fea4  "...."
CRASH_$OK_TO_REBOOT:
        .byte   0x00, 0x74                      | sau4 f81fea8  ".t"
crash_dump:
        .long   DUMP                            | sau4 f81feaa  0f800800
crash_auto_reboot:
        .long   DUMP_$AUTO_REBOOT               | sau4 f81feae  0f800a12
crash_reboot_check:
        movem.l %a0/%a5,-(%sp)                  | sau4 f81feb2  48e7 0084
        jsr     (MMU_$NORMAL_MODE).l            | sau4 f81feb6  4eb9 0f82 6528
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau4 f81febc  4bfa fc3a
        tst.b   %d0                             | sau4 f81fec0  4a00
        beq.s   .Lf81fef2                       | sau4 f81fec2  672e
        tst.b   (SERVER_$FLAG).l                | sau4 f81fec4  4a39 0f81 fe5f
        bne.s   .Lf81fef6                       | sau4 f81feca  662a
        tst.b   (CRASH_$OK_TO_REBOOT).l         | sau4 f81fecc  4a39 0f81 fea8
        beq.s   .Lf81fef2                       | sau4 f81fed2  671e
        movea.l (%sp),%a0                       | sau4 f81fed4  2057
        tst.l   (%a0)                           | sau4 f81fed6  4a90
        beq.s   .Lf81fef2                       | sau4 f81fed8  6718
        cmpi.l  #0x10002,(%a0)                  | sau4 f81feda  0c90 0001 0002
        beq.s   .Lf81fef2                       | sau4 f81fee0  6710
        cmpi.l  #0xb0008,(%a0)                  | sau4 f81fee2  0c90 000b 0008
        beq.s   .Lf81fef2                       | sau4 f81fee8  6708
        clr.w   %d0                             | sau4 f81feea  4240
.Lf81feec:
        movem.l (%sp)+,%a0/%a5                  | sau4 f81feec  4cdf 2100
        rts                                     | sau4 f81fef0  4e75
.Lf81fef2:
        moveq   #1,%d0                          | sau4 f81fef2  7001
        bra.s   .Lf81feec                       | sau4 f81fef4  60f6
.Lf81fef6:
        moveq   #-1,%d0                         | sau4 f81fef6  70ff
        bra.s   .Lf81feec                       | sau4 f81fef8  60f2
CRASH_CHK_CACHES:
        .short  0x4e7a, 0x810f                  | sau4 f81fefa  4e7a 810f  movec 0x10f,%a0
        beq.w   .Lf81ff7a                       | sau4 f81fefe  6700 007a
        movem.l %d0-%d6/%a5,-(%sp)              | sau4 f81ff02  48e7 fe04
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau4 f81ff06  4bfa fbf0
        move.w  %sr,-(%sp)                      | sau4 f81ff0a  40e7
        ori.w   #0x700,%sr                      | sau4 f81ff0c  007c 0700
        movea.l #0x40,%a0                       | sau4 f81ff10  207c 0000 0040
        .short  0x4e7b, 0x8116                  | sau4 f81ff16  4e7b 8116  movec %a0,0x116
        .short  0x4e7a, 0x3115                  | sau4 f81ff1a  4e7a 3115  movec 0x115,%d3
        .short  0xc67c, 0x0fff                  | sau4 f81ff1e  c67c 0fff  and.w   #0xfff,%d3
        .short  0xb67c, 0x003f                  | sau4 f81ff22  b67c 003f  cmp.w   #0x3f,%d3
        ble.s   .Lf81ff2a                       | sau4 f81ff26  6f02
        moveq   #63,%d3                         | sau4 f81ff28  763f
.Lf81ff2a:
        tst.w   %d3                             | sau4 f81ff2a  4a43
        beq.s   .Lf81ff6e                       | sau4 f81ff2c  6740
        clr.l   %d4                             | sau4 f81ff2e  4284
        subq.l  #1,%d3                          | sau4 f81ff30  5383
        .short  0x4e7a, 0x2115                  | sau4 f81ff32  4e7a 2115  movec 0x115,%d2
.Lf81ff36:
        .short  0x4e7a, 0x2115                  | sau4 f81ff36  4e7a 2115  movec 0x115,%d2
        move.l  %d2,(0x4ea,%a5)                 | sau4 f81ff3a  2b42 04ea
        bsr.s   .Lf81ff82                       | sau4 f81ff3e  6142
        beq.s   .Lf81ff7c                       | sau4 f81ff40  673a
        tst.w   %d4                             | sau4 f81ff42  4a44
        bne.s   .Lf81ff4e                       | sau4 f81ff44  6608
        lea     (.Lf81ffa3:w,%pc),%a0           | sau4 f81ff46  41fa 005b
        bsr.w   crash_puts_string               | sau4 f81ff4a  6100 fd08
.Lf81ff4e:
        addq.l  #1,%d4                          | sau4 f81ff4e  5284
        .short  0x4e7a, 0x2115                  | sau4 f81ff50  4e7a 2115  movec 0x115,%d2
        move.l  %d2,(0x4f2,%a5)                 | sau4 f81ff54  2b42 04f2
        lea     (.Lf81ffe0:w,%pc),%a0           | sau4 f81ff58  41fa 0086
        bsr.w   crash_puts_string               | sau4 f81ff5c  6100 fcf6
.Lf81ff60:
        movea.l (0x118).w,%a0                   | sau4 f81ff60  2078 0118
        jsr     (%a0)                           | sau4 f81ff64  4e90
        tst.b   %d1                             | sau4 f81ff66  4a01
        bpl.s   .Lf81ff6e                       | sau4 f81ff68  6a04
        dbf     %d3,.Lf81ff36                   | sau4 f81ff6a  51cb ffca
.Lf81ff6e:
        move.w  (%sp)+,%sr                      | sau4 f81ff6e  46df
        move.b  #0xff,(0x4aa,%a5)               | sau4 f81ff70  1b7c 00ff 04aa
        movem.l (%sp)+,%d0-%d6/%a5              | sau4 f81ff76  4cdf 207f
.Lf81ff7a:
        rts                                     | sau4 f81ff7a  4e75
.Lf81ff7c:
        .short  0x4e7a, 0x2115                  | sau4 f81ff7c  4e7a 2115  movec 0x115,%d2
        bra.s   .Lf81ff60                       | sau4 f81ff80  60de
.Lf81ff82:
        move.l  %d2,%d1                         | sau4 f81ff82  2202
        lsr.l   #8,%d1                          | sau4 f81ff84  e089
        lsr.l   #2,%d1                          | sau4 f81ff86  e489
        lea     (IOMAP).l,%a0                   | sau4 f81ff88  41f9 0fff f800
        move.l  #0xff,%d5                       | sau4 f81ff8e  2a3c 0000 00ff
.Lf81ff94:
        move.w  #0xfff,%d6                      | sau4 f81ff94  3c3c 0fff
        and.w   (%a0)+,%d6                      | sau4 f81ff98  cc58
        cmp.w   %d6,%d1                         | sau4 f81ff9a  b246
        dbeq    %d5,.Lf81ff94                   | sau4 f81ff9c  57cd fff6
        rts                                     | sau4 f81ffa0  4e75
        .byte   0x00                            | sau4 f81ffa2  "."
.Lf81ffa3:
        .byte   0x46, 0x61, 0x74, 0x61, 0x6c, 0x20, 0x48, 0x61 | sau4 f81ffa3  "Fatal Ha"
        .byte   0x72, 0x64, 0x77, 0x61, 0x72, 0x65, 0x20, 0x45 | sau4 f81ffab  "rdware E"
        .byte   0x72, 0x72, 0x6f, 0x72, 0x20, 0x2d, 0x20, 0x44 | sau4 f81ffb3  "rror - D"
        .byte   0x63, 0x61, 0x63, 0x68, 0x65, 0x20, 0x52, 0x61 | sau4 f81ffbb  "cache Ra"
        .byte   0x6d, 0x20, 0x46, 0x61, 0x69, 0x6c, 0x75, 0x72 | sau4 f81ffc3  "m Failur"
        .byte   0x65, 0x73, 0x3a, 0x20, 0x28, 0x61, 0x64, 0x64 | sau4 f81ffcb  "es: (add"
        .byte   0x72, 0x20, 0x20, 0x78, 0x6f, 0x72, 0x2d, 0x64 | sau4 f81ffd3  "r  xor-d"
        .byte   0x61, 0x74, 0x61, 0x29, 0x25    | sau4 f81ffdb  "ata)%"
.Lf81ffe0:
        .byte   0x20, 0xff, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20 | sau4 f81ffe0  " .....  "
        .byte   0x20, 0xff, 0x00, 0x00, 0x00, 0x00, 0x25, 0x00 | sau4 f81ffe8  " .....%."
