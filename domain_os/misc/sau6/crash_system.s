|
| misc/sau6/crash_system.s - the CRASH_SYSTEM module of the SAU6: CRASH_SYSTEM,
| the restart through the PROM, the crash console, REMAP_DISPLAY,
| FIM_$CRASH and the crash report
|
| SAU6 map: "D 78020AF8 CRASH_SYSTEM size = 49C" (WIRED_DATA),
| 0x78020AF8..0x78020F93, hand-written code and data, one section (the
| cells are reached off A5 = CRASH_SYSTEM, `lea (d,PC),A5', and
| PC-relatively, so the displacements stay those of the image as long as
| the segment is one piece):
|
|   0x78020AF8  CRASH_PAUSE, CRASH_SYSTEM
|   0x78020C3C  the SR stash (no map name)
|   0x78020C3E  CRASH: restart through the PROM with a code at DUMP + 4
|   0x78020C48  the call of the PROM's restart cell 0x128 (no map name)
|   0x78020C5A  CRASH_SHOW_STRING, then the string writer, the PROM putc
|               (cell 0x108) and the font reload (cell 0x114)
|   0x78020CCC  DISP2_PRESENT (OS_$INIT's second-display probe sets it)
|   0x78020CCE  REMAP_DISPLAY: at IPL 7, stops the graphics processor's
|               page faults for a held GPU, maps the color board's
|               registers and frame buffer for the graphic devices 1 and
|               2, then the color board's control store and DISP2_MEM
|               when DISP2_PRESENT, else DISP1_MEM
|   0x78020DCE  FIM_$CRASH and its report template (0x78020E58..)
|   0x78020ED2  the crash report: CRASH_STATUS, CRASH_ECB, SERVER_$FLAG,
|               CRASH_REGS, CRASH_SP, CRASH_USP, CRASH_$OK_TO_REBOOT, then
|               DUMP's and DUMP_$AUTO_REBOOT's addresses
|   0x78020F4C  the restart check (no map name): after MMU_$NORMAL_MODE,
|               0 = no restart, 1 = restart, -1 = a server's shutdown
|
| The SAU4's module (misc/sau4/crash_system.s) without CRASH_CHK_CACHES,
| with the SAU5's REMAP_DISPLAY (misc/m68k/crash_system.s, `gpu_driver'),
| and first, when the second Winchester board's command blocks are set
| up (WIN_$DT's first longword, win/win6_cinit.pas), a copy of the eight
| longwords at their +0x1FC0 to +0x1F40 (`crash_win6_save',
| base/config.ins.pas).  The physical addresses 0x1000C00 and 0x1000C04
| are DUMP's page where COLD left it.  The other SAUs' modules are
| misc/m68k/crash_system.s, crash_report.s, fim/m68k/crash.s,
| misc/m68k/crash_system_restart.s and misc/sau4/crash_system.s.
|
| The Apollo assembler's <ea>=#imm forms (cmp/add #imm,Dn), which gas
| spells otherwise, are written as words with the instruction
| in the comment.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau6 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU6 image's.
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
        .globl  CRASH_REPORT

CRASH_PAUSE:
CRASH_SYSTEM:
        move.w  %sr,-(%sp)                      | sau6 78020af8  40e7
        ori.w   #0x700,%sr                      | sau6 78020afa  007c 0700
        movem.l %d0-%a7,-(%sp)                  | sau6 78020afe  48e7 ffff
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau6 78020b02  4bfa fff4
        tst.l   (WIN_$DT).l                     | sau6 78020b06  4ab9 7802 fac8
        beq.s   .L78020b2c                      | sau6 78020b0c  671e
        movea.l (WIN_$DT).l,%a0                 | sau6 78020b0e  2079 7802 fac8
        movea.l %a0,%a1                         | sau6 78020b14  2248
        adda.l  #0x1fc0,%a0                     | sau6 78020b16  d1fc 0000 1fc0
        adda.l  #0x1f40,%a1                     | sau6 78020b1c  d3fc 0000 1f40
        move.w  #7,%d0                          | sau6 78020b22  303c 0007
.L78020b26:
        move.l  (%a0)+,(%a1)+                   | sau6 78020b26  22d8
        dbf     %d0,.L78020b26                  | sau6 78020b28  51c8 fffc
.L78020b2c:
        movea.l (0x46,%sp),%a0                  | sau6 78020b2c  206f 0046
        move.l  (%a0),(0x3ea,%a5)               | sau6 78020b30  2b50 03ea  CRASH_STATUS
        beq.s   .L78020b56                      | sau6 78020b34  6720
        cmpi.l  #0x1b0008,(0x3ea,%a5)           | sau6 78020b36  0cad 001b 0008 03ea
        beq.s   .L78020b56                      | sau6 78020b3e  6716
        move.l  (0x42,%sp),(0x3f4,%a5)          | sau6 78020b40  2b6f 0042 03f4  CRASH_ECB
        move.w  (PROC1_$CURRENT).l,(0x3fe,%a5)  | sau6 78020b46  3b79 7802 2ba8 03fe  the pid
        lea     (CRASH_REPORT:w,%pc),%a0        | sau6 78020b4e  41fa 0382
        bsr.w   crash_puts_string               | sau6 78020b52  6100 0116
.L78020b56:
        lea     (CRASH_$RECORD).l,%a1           | sau6 78020b56  43f9 7800 0000
        clr.l   (%a1)                           | sau6 78020b5c  4291
        tst.l   (0x3ea,%a5)                     | sau6 78020b5e  4aad 03ea
        beq.s   .L78020b7e                      | sau6 78020b62  671a
        cmpi.l  #0x1b0008,(0x3ea,%a5)           | sau6 78020b64  0cad 001b 0008 03ea
        beq.s   .L78020b7e                      | sau6 78020b6c  6710
        move.l  #0xabcdef01,(%a1)+              | sau6 78020b6e  22fc abcd ef01
        move.l  (TIME_$CLOCKH_EC).l,(%a1)+      | sau6 78020b74  22f9 7802 e5d2
        move.l  (CRASH_STATUS:w,%pc),(%a1)      | sau6 78020b7a  22ba 0366
.L78020b7e:
        lea     (%sp),%a0                       | sau6 78020b7e  41d7
        lea     (CRASH_REGS:w,%pc),%a1          | sau6 78020b80  43fa 0378
        moveq   #15,%d0                         | sau6 78020b84  700f
.L78020b86:
        move.l  (%a0)+,(%a1)+                   | sau6 78020b86  22d8
        dbf     %d0,.L78020b86                  | sau6 78020b88  51c8 fffc
        movec   %usp,%d0                        | sau6 78020b8c  4e7a 0800
        move.l  %d0,(0x446,%a5)                 | sau6 78020b90  2b40 0446  CRASH_USP
        jsr     (KBD_$RESET).l                  | sau6 78020b94  4eb9 7801 c9f4
        lea     (CRASH_STATUS:w,%pc),%a0        | sau6 78020b9a  41fa 0346
        bsr.w   crash_reboot_check              | sau6 78020b9e  6100 03ac
        tst.w   %d0                             | sau6 78020ba2  4a40
        bmi.s   .L78020bc8                      | sau6 78020ba4  6b22
        cmpi.l  #0x1b0008,(%a0)                 | sau6 78020ba6  0c90 001b 0008
        bne.s   .L78020bb0                      | sau6 78020bac  6602
        clr.l   (%a0)                           | sau6 78020bae  4290
.L78020bb0:
        tst.w   %d0                             | sau6 78020bb0  4a40
        bne.s   .L78020c02                      | sau6 78020bb2  664e
.L78020bb4:
        move.l  (crash_auto_reboot:w,%pc),%d0   | sau6 78020bb4  203a 0392
        sub.l   (crash_dump:w,%pc),%d0          | sau6 78020bb8  90ba 038a
        .short  0xd0bc, 0x0100, 0x0c00          | sau6 78020bbc  d0bc 0100 0c00  add.l   #0x1000c00,%d0
        move.w  #0xf1,%d1                       | sau6 78020bc2  323c 00f1
        bra.s   .L78020bee                      | sau6 78020bc6  6026
.L78020bc8:
        lea     (CRASH_STATUS:w,%pc),%a0        | sau6 78020bc8  41fa 0318
        tst.l   (%a0)                           | sau6 78020bcc  4a90
        beq.s   .L78020bdc                      | sau6 78020bce  670c
        cmpi.l  #0x1b0008,(%a0)                 | sau6 78020bd0  0c90 001b 0008
        bne.s   .L78020be4                      | sau6 78020bd6  660c
        clr.l   (%a0)                           | sau6 78020bd8  4290
        bra.s   .L78020bb4                      | sau6 78020bda  60d8
.L78020bdc:
        clr.l   %d0                             | sau6 78020bdc  4280
        move.w  #0xff,%d1                       | sau6 78020bde  323c 00ff
        bra.s   .L78020bee                      | sau6 78020be2  600a
.L78020be4:
        move.l  #0x1000c04,%d0                  | sau6 78020be4  203c 0100 0c04
        move.w  #0xf1,%d1                       | sau6 78020bea  323c 00f1
.L78020bee:
        move.l  %d0,-(%sp)                      | sau6 78020bee  2f00
        move.w  %d1,-(%sp)                      | sau6 78020bf0  3f01
        bsr.s   crash_call_prom_restart         | sau6 78020bf2  6154
        addq.w  #6,%sp                          | sau6 78020bf4  5c4f
        move.w  (0x40,%sp),(0x144,%a5)          | sau6 78020bf6  3b6f 0040 0144  CRASH_SAVED_SR
        movem.l (%sp)+,%d0-%a7                  | sau6 78020bfc  4cdf ffff
        addq.w  #2,%sp                          | sau6 78020c00  544f
.L78020c02:
        tst.l   (0x3ea,%a5)                     | sau6 78020c02  4aad 03ea
        bne.s   .L78020c0e                      | sau6 78020c06  6606
        movea.l (0x11c).w,%a0                   | sau6 78020c08  2078 011c
        jmp     (%a0)                           | sau6 78020c0c  4ed0
.L78020c0e:
        move.w  (0x40,%sp),(0x144,%a5)          | sau6 78020c0e  3b6f 0040 0144
        movem.l (%sp)+,%d0-%a7                  | sau6 78020c14  4cdf ffff
        addq.w  #2,%sp                          | sau6 78020c18  544f
        trap    #0xf                            | sau6 78020c1a  4e4f
        jsr     (KBD_$CRASH_INIT).l             | sau6 78020c1c  4eb9 7801 ef66
        movem.l %d0/%a0,-(%sp)                  | sau6 78020c22  48e7 8080
        lea     (CRASH_REGS:w,%pc),%a0          | sau6 78020c26  41fa 02d2
        moveq   #15,%d0                         | sau6 78020c2a  700f
.L78020c2c:
        clr.l   (%a0)+                          | sau6 78020c2c  4298
        dbf     %d0,.L78020c2c                  | sau6 78020c2e  51c8 fffc
        movem.l (%sp)+,%d0/%a0                  | sau6 78020c32  4cdf 0101
        move.w  (CRASH_SAVED_SR:w,%pc),%sr      | sau6 78020c36  46fa 0004
        rts                                     | sau6 78020c3a  4e75
CRASH_SAVED_SR:
        .short  0x0000                          | sau6 78020c3c
CRASH:
        movea.l #0x1000c04,%a0                  | sau6 78020c3e  207c 0100 0c04
        move.l  %a0,(0x6,%sp)                   | sau6 78020c44  2f48 0006
crash_call_prom_restart:
        movea.l (0x128).w,%a0                   | sau6 78020c48  2078 0128
        move.l  (0x6,%sp),-(%sp)                | sau6 78020c4c  2f2f 0006
        move.w  (0x8,%sp),-(%sp)                | sau6 78020c50  3f2f 0008
        jsr     (%a0)                           | sau6 78020c54  4e90
        addq.l  #6,%sp                          | sau6 78020c56  5c8f
        rts                                     | sau6 78020c58  4e75
CRASH_SHOW_STRING:
        movem.l %d0-%a7,-(%sp)                  | sau6 78020c5a  48e7 ffff
        movea.l (0x44,%sp),%a0                  | sau6 78020c5e  206f 0044
        bsr.s   crash_puts_string               | sau6 78020c62  6106
        movem.l (%sp)+,%d0-%a7                  | sau6 78020c64  4cdf ffff
        rts                                     | sau6 78020c68  4e75
crash_puts_string:
        move.l  %a0,-(%sp)                      | sau6 78020c6a  2f08
        bsr.w   REMAP_DISPLAY                   | sau6 78020c6c  6100 0060
        bsr.s   call_prom_reload_font           | sau6 78020c70  6152
        movea.l (%sp)+,%a0                      | sau6 78020c72  205f
.L78020c74:
        move.b  (%a0)+,%d1                      | sau6 78020c74  1218
        ble.s   .L78020c8c                      | sau6 78020c76  6f14
        .short  0xb23c, 0x0025                  | sau6 78020c78  b23c 0025  cmp.b   #0x25,%d1
        beq.s   .L78020c82                      | sau6 78020c7c  6704
        bsr.s   call_prom_putc                  | sau6 78020c7e  6134
        bra.s   .L78020c74                      | sau6 78020c80  60f2
.L78020c82:
        moveq   #13,%d1                         | sau6 78020c82  720d
        bsr.s   call_prom_putc                  | sau6 78020c84  612e
        moveq   #10,%d1                         | sau6 78020c86  720a
        bsr.s   call_prom_putc                  | sau6 78020c88  612a
        rts                                     | sau6 78020c8a  4e75
.L78020c8c:
        blt.s   .L78020c96                      | sau6 78020c8c  6d08
        move.w  (%a0)+,%d2                      | sau6 78020c8e  3418
        swap    %d2                             | sau6 78020c90  4842
        moveq   #3,%d0                          | sau6 78020c92  7003
        bra.s   .L78020c9a                      | sau6 78020c94  6004
.L78020c96:
        move.l  (%a0)+,%d2                      | sau6 78020c96  2418
        moveq   #7,%d0                          | sau6 78020c98  7007
.L78020c9a:
        rol.l   #4,%d2                          | sau6 78020c9a  e99a
        moveq   #15,%d1                         | sau6 78020c9c  720f
        and.b   %d2,%d1                         | sau6 78020c9e  c202
        .short  0xb23c, 0x000a                  | sau6 78020ca0  b23c 000a  cmp.b   #0xa,%d1
        blt.s   .L78020ca8                      | sau6 78020ca4  6d02
        addq.b  #7,%d1                          | sau6 78020ca6  5e01
.L78020ca8:
        .short  0xd23c, 0x0030                  | sau6 78020ca8  d23c 0030  add.b   #0x30,%d1
        bsr.s   call_prom_putc                  | sau6 78020cac  6106
        dbf     %d0,.L78020c9a                  | sau6 78020cae  51c8 ffea
        bra.s   .L78020c74                      | sau6 78020cb2  60c0
call_prom_putc:
        movem.l %d0-%d2/%a0,-(%sp)              | sau6 78020cb4  48e7 e080
        movea.l (0x108).w,%a0                   | sau6 78020cb8  2078 0108
        jsr     (%a0)                           | sau6 78020cbc  4e90
        movem.l (%sp)+,%d0-%d2/%a0              | sau6 78020cbe  4cdf 0107
        rts                                     | sau6 78020cc2  4e75
call_prom_reload_font:
        movea.l (0x114).w,%a1                   | sau6 78020cc4  2278 0114
        jmp     (%a1)                           | sau6 78020cc8  4ed1
        rts                                     | sau6 78020cca  4e75
DISP2_PRESENT:
        .short  0x0000                          | sau6 78020ccc
REMAP_DISPLAY:
        move.w  %sr,-(%sp)                      | sau6 78020cce  40e7
        ori.w   #0x700,%sr                      | sau6 78020cd0  007c 0700
        move.w  #0x26,-(%sp)                    | sau6 78020cd4  3f3c 0026
        clr.w   -(%sp)                          | sau6 78020cd8  4267
        tst.w   (GPU_$PRESENT).l                | sau6 78020cda  4a79 7802 aa12
        beq.s   .L78020d04                      | sau6 78020ce0  6722
        tst.w   (GPU_$USER_PID).l               | sau6 78020ce2  4a79 7802 aa10  a process holds it
        beq.s   .L78020d04                      | sau6 78020ce8  671a
        lea     (GPU).l,%a0                     | sau6 78020cea  41f9 7ffe 8000
        move.w  (0x2,%a0),%d0                   | sau6 78020cf0  3028 0002
        andi.w  #0x25,%d0                       | sau6 78020cf4  0240 0025
        cmpi.w  #0x20,%d0                       | sau6 78020cf8  0c40 0020
        beq.s   .L78020d04                      | sau6 78020cfc  6706
        move.w  #0,(0x6,%a0)                    | sau6 78020cfe  317c 0000 0006
.L78020d04:
        cmpi.w  #2,(SMD_$GRAPHIC_DEVICE_ID).l   | sau6 78020d04  0c79 0002 7802 a5bc
        beq.s   .L78020d18                      | sau6 78020d0c  670a
        cmpi.w  #1,(SMD_$GRAPHIC_DEVICE_ID).l   | sau6 78020d0e  0c79 0001 7802 a5bc
        bne.s   .L78020d62                      | sau6 78020d16  664a
.L78020d18:
        move.l  #KOLOR_CTL,-(%sp)               | sau6 78020d18  2f3c 7ff9 0000
        move.l  #0x180,-(%sp)                   | sau6 78020d1e  2f3c 0000 0180
.L78020d24:
        jsr     (MMU_$INSTALL).l                | sau6 78020d24  4eb9 7802 6b26
        addq.l  #1,(%sp)                        | sau6 78020d2a  5297
        cmpi.l  #0x1c0,(%sp)                    | sau6 78020d2c  0c97 0000 01c0
        beq.s   .L78020d48                      | sau6 78020d32  6714
        cmpi.l  #0x180,(%sp)                    | sau6 78020d34  0c97 0000 0180
        beq.w   .L78020dc6                      | sau6 78020d3a  6700 008a
        addi.l  #0x400,(0x4,%sp)                | sau6 78020d3e  06af 0000 0400 0004
        bra.s   .L78020d24                      | sau6 78020d46  60dc
.L78020d48:
        addq.w  #8,%sp                          | sau6 78020d48  504f
        cmpi.w  #2,(SMD_$GRAPHIC_DEVICE_ID).l   | sau6 78020d4a  0c79 0002 7802 a5bc
        bne.s   .L78020d62                      | sau6 78020d52  660e
        move.l  #DISP_MEM_2KX1K,-(%sp)          | sau6 78020d54  2f3c 7ffa 0000
        move.l  #0x80,-(%sp)                    | sau6 78020d5a  2f3c 0000 0080
        bra.s   .L78020d24                      | sau6 78020d60  60c2
.L78020d62:
        tst.b   (DISP2_PRESENT).l               | sau6 78020d62  4a39 7802 0ccc
        beq.s   .L78020d90                      | sau6 78020d68  6726
        lea     (COLOR_CSTORE).l,%a0            | sau6 78020d6a  41f9 7fff 6800
        move.l  %a0,-(%sp)                      | sau6 78020d70  2f08
        move.l  #0x3a,-(%sp)                    | sau6 78020d72  2f3c 0000 003a
        jsr     (MMU_$INSTALL).l                | sau6 78020d78  4eb9 7802 6b26
        addq.l  #8,%sp                          | sau6 78020d7e  508f
        lea     (DISP2_MEM).l,%a0               | sau6 78020d80  41f9 7ffa 0000
        move.l  %a0,-(%sp)                      | sau6 78020d86  2f08
        move.l  #0x100,-(%sp)                   | sau6 78020d88  2f3c 0000 0100
        bra.s   .L78020d9c                      | sau6 78020d8e  600c
.L78020d90:
        move.l  #DISP1_MEM,-(%sp)               | sau6 78020d90  2f3c 7ffc 0000
        move.l  #0x80,-(%sp)                    | sau6 78020d96  2f3c 0000 0080
.L78020d9c:
        jsr     (MMU_$INSTALL).l                | sau6 78020d9c  4eb9 7802 6b26
        addq.l  #1,(%sp)                        | sau6 78020da2  5297
        cmpi.l  #0x180,(%sp)                    | sau6 78020da4  0c97 0000 0180
        bne.s   .L78020db4                      | sau6 78020daa  6608
        move.l  #0x80,(%sp)                     | sau6 78020dac  2ebc 0000 0080
        bra.s   .L78020dbc                      | sau6 78020db2  6008
.L78020db4:
        cmpi.l  #0x100,(%sp)                    | sau6 78020db4  0c97 0000 0100
        beq.s   .L78020dc6                      | sau6 78020dba  670a
.L78020dbc:
        addi.l  #0x400,(0x4,%sp)                | sau6 78020dbc  06af 0000 0400 0004
        bra.s   .L78020d9c                      | sau6 78020dc4  60d6
.L78020dc6:
        adda.w  #0xc,%sp                        | sau6 78020dc6  defc 000c
        move.w  (%sp)+,%sr                      | sau6 78020dca  46df
        rts                                     | sau6 78020dcc  4e75
FIM_$CRASH:
        move.w  %sr,-(%sp)                      | sau6 78020dce  40e7
        ori.w   #0x700,%sr                      | sau6 78020dd0  007c 0700
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau6 78020dd4  4bfa fd22
        movea.l (0x6,%sp),%a2                   | sau6 78020dd8  246f 0006
        move.l  %a2,(0x37a,%a5)                 | sau6 78020ddc  2b4a 037a
        move.w  (%a2),(0x384,%a5)               | sau6 78020de0  3b52 0384
        move.l  (0x2,%a2),(0x38c,%a5)           | sau6 78020de4  2b6a 0002 038c
        move.w  (0x6,%a2),%d0                   | sau6 78020dea  302a 0006
        move.w  %d0,(0x396,%a5)                 | sau6 78020dee  3b40 0396
        lsr.w   #2,%d0                          | sau6 78020df2  e448
        lea     (.L78020ec0:w,%pc),%a0          | sau6 78020df4  41fa 00ca
        .short  0xb03c, 0x0020                  | sau6 78020df8  b03c 0020  cmp.b   #0x20,%d0
        blt.s   .L78020e04                      | sau6 78020dfc  6d06
        .short  0xb03c, 0x0030                  | sau6 78020dfe  b03c 0030  cmp.b   #0x30,%d0
        blt.s   .L78020e10                      | sau6 78020e02  6d0c
.L78020e04:
        lea     (.L78020ea7:w,%pc),%a0          | sau6 78020e04  41fa 00a1
.L78020e08:
        move.b  (%a0)+,%d1                      | sau6 78020e08  1218
        beq.s   .L78020e10                      | sau6 78020e0a  6704
        cmp.b   %d0,%d1                         | sau6 78020e0c  b200
        bne.s   .L78020e08                      | sau6 78020e0e  66f8
.L78020e10:
        move.b  (%a0),(0x39a,%a5)               | sau6 78020e10  1b50 039a
        moveq   #37,%d4                         | sau6 78020e14  7825
        .short  0xb03c, 0x0003                  | sau6 78020e16  b03c 0003  cmp.b   #3,%d0
        bgt.s   .L78020e2a                      | sau6 78020e1a  6e0e
        moveq   #32,%d4                         | sau6 78020e1c  7820
        move.w  (0xa,%a2),(0x3ac,%a5)           | sau6 78020e1e  3b6a 000a 03ac
        move.l  (0x10,%a2),(0x3a2,%a5)          | sau6 78020e24  2b6a 0010 03a2
.L78020e2a:
        move.b  %d4,(0x39c,%a5)                 | sau6 78020e2a  1b44 039c
        lea     (fim_crash_msg:w,%pc),%a0       | sau6 78020e2e  41fa 0028
        bsr.w   crash_puts_string               | sau6 78020e32  6100 fe36
        movea.l (0xa,%sp),%a0                   | sau6 78020e36  206f 000a
        move.l  (0x3c,%a0),(0x442,%a5)          | sau6 78020e3a  2b68 003c 0442  CRASH_SP
        move.l  (0x20,%a0),-(%sp)               | sau6 78020e40  2f28 0020
        movem.l (%a0)+,%d0-%a6                  | sau6 78020e44  4cd8 7fff
        movea.l (%sp)+,%a0                      | sau6 78020e48  205f
        move.l  (0xe,%sp),-(%sp)                | sau6 78020e4a  2f2f 000e
        jsr     (CRASH_SYSTEM:w,%pc)            | sau6 78020e4e  4eba fca8
        addq.w  #4,%sp                          | sau6 78020e52  584f
        move.w  (%sp)+,%sr                      | sau6 78020e54  46df
        rts                                     | sau6 78020e56  4e75
fim_crash_msg:
        .byte   0x0d, 0x0a, 0x0d, 0x0a, 0x46, 0x41, 0x55, 0x4c | sau6 78020e58  "....FAUL"
        .byte   0x54, 0x20, 0x49, 0x4e, 0x20, 0x44, 0x4f, 0x4d | sau6 78020e60  "T IN DOM"
        .byte   0x41, 0x49, 0x4e, 0x2f, 0x4f, 0x53, 0x3a, 0x0d | sau6 78020e68  "AIN/OS:."
        .byte   0x0a, 0xff, 0x00, 0x00, 0x00, 0x00, 0x3a, 0x20 | sau6 78020e70  "......: "
        .byte   0x53, 0x52, 0x3a, 0x00, 0x00, 0x00, 0x20, 0x20 | sau6 78020e78  "SR:...  "
        .byte   0x50, 0x43, 0x3a, 0xff, 0x00, 0x00, 0x00, 0x00 | sau6 78020e80  "PC:....."
        .byte   0x20, 0x20, 0x46, 0x46, 0x3a, 0x00, 0x00, 0x00 | sau6 78020e88  "  FF:..."
        .byte   0x20, 0x28, 0x20, 0x29, 0x25, 0x20, 0x46, 0x41 | sau6 78020e90  " ( )% FA"
        .byte   0x3a, 0xff, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20 | sau6 78020e98  ":.....  "
        .byte   0x53, 0x57, 0x3a, 0x00, 0x00, 0x00, 0x25 | sau6 78020ea0  "SW:...%"
.L78020ea7:
        .byte   0x02, 0x42, 0x03, 0x41, 0x04, 0x55, 0x05, 0x5a | sau6 78020ea7  ".B.A.U.Z"
        .byte   0x06, 0x43, 0x07, 0x54, 0x08, 0x4d, 0x09, 0x54 | sau6 78020eaf  ".C.T.M.T"
        .byte   0x0a, 0x55, 0x0b, 0x55, 0x0e, 0x46, 0x18, 0x4a | sau6 78020eb7  ".U.U.F.J"
        .byte   0x20                            | sau6 78020ebf  " "
.L78020ec0:
        .byte   0x53, 0x30, 0x4f, 0x31, 0x4f, 0x32, 0x4f, 0x33 | sau6 78020ec0  "S0O1O2O3"
        .byte   0x4f, 0x34, 0x4f, 0x35, 0x4f, 0x36, 0x4f, 0x00 | sau6 78020ec8  "O4O5O6O."
        .byte   0x49, 0x00                      | sau6 78020ed0  "I."
CRASH_REPORT:
        .byte   0x0d, 0x0a, 0x43, 0x72, 0x61, 0x73, 0x68, 0x5f | sau6 78020ed2  "..Crash_"
        .byte   0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x20, 0xff | sau6 78020eda  "Status ."
CRASH_STATUS:
        .byte   0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x50, 0x43 | sau6 78020ee2  "....  PC"
        .byte   0x20, 0xff                      | sau6 78020eea  " ."
CRASH_ECB:
        .byte   0x00, 0x00, 0x00, 0x00, 0x20, 0x70, 0x69, 0x64 | sau6 78020eec  ".... pid"
        .byte   0x20, 0x00, 0x00, 0x00, 0x25    | sau6 78020ef4  " ...%"
SERVER_$FLAG:
        .byte   0x00                            | sau6 78020ef9  "."
CRASH_REGS:
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020efa  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f02  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f0a  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f12  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f1a  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f22  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f2a  "........"
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78020f32  "........"
CRASH_SP:
        .byte   0x00, 0x00, 0x00, 0x00          | sau6 78020f3a  "...."
CRASH_USP:
        .byte   0x00, 0x00, 0x00, 0x00          | sau6 78020f3e  "...."
CRASH_$OK_TO_REBOOT:
        .byte   0x00, 0x74                      | sau6 78020f42  ".t"
crash_dump:
        .long   DUMP                            | sau6 78020f44  7800 0800
crash_auto_reboot:
        .long   DUMP_$AUTO_REBOOT               | sau6 78020f48  7800 0bc2
crash_reboot_check:
        movem.l %a0/%a5,-(%sp)                  | sau6 78020f4c  48e7 0084
        jsr     (MMU_$NORMAL_MODE).l            | sau6 78020f50  4eb9 7802 6dda
        lea     (CRASH_SYSTEM:w,%pc),%a5        | sau6 78020f56  4bfa fba0
        tst.b   %d0                             | sau6 78020f5a  4a00
        beq.s   .L78020f8c                      | sau6 78020f5c  672e
        tst.b   (SERVER_$FLAG).l                | sau6 78020f5e  4a39 7802 0ef9
        bne.s   .L78020f90                      | sau6 78020f64  662a
        tst.b   (CRASH_$OK_TO_REBOOT).l         | sau6 78020f66  4a39 7802 0f42
        beq.s   .L78020f8c                      | sau6 78020f6c  671e
        movea.l (%sp),%a0                       | sau6 78020f6e  2057
        tst.l   (%a0)                           | sau6 78020f70  4a90
        beq.s   .L78020f8c                      | sau6 78020f72  6718
        cmpi.l  #0x10002,(%a0)                  | sau6 78020f74  0c90 0001 0002
        beq.s   .L78020f8c                      | sau6 78020f7a  6710
        cmpi.l  #0xb0008,(%a0)                  | sau6 78020f7c  0c90 000b 0008
        beq.s   .L78020f8c                      | sau6 78020f82  6708
        clr.w   %d0                             | sau6 78020f84  4240
.L78020f86:
        movem.l (%sp)+,%a0/%a5                  | sau6 78020f86  4cdf 2100
        rts                                     | sau6 78020f8a  4e75
.L78020f8c:
        moveq   #1,%d0                          | sau6 78020f8c  7001
        bra.s   .L78020f86                      | sau6 78020f8e  60f6
.L78020f90:
        moveq   #-1,%d0                         | sau6 78020f90  70ff
        bra.s   .L78020f86                      | sau6 78020f92  60f2
