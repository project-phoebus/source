|
| dump/sau8/dump.s - the DUMP page (SAU8): the crash-dump code and its
| cells
|
| The SAU8's DUMP page, transcribed from the SAU8 image file (file
| 0xC00..0x1400, VA 0x3C00400; COLD copies it to physical 0x100C00, PPN
| 0x403, as on the SAU2).  The SAU8 map:
|
|   D   3C00400  DUMP               size = 800
|       3C00400  DUMP
|       3C00820  DUMP_$AUTO_REBOOT
|       3C00A4E  DUMP_$SMAP_PHADDR
|       3C00BE8  DUMP_$RARS_PHADDR
|       3C00BEC  DUMP_$ADDRS
|
| The SAU7's form (twice the SAU2's size; dump/sau2/dump.s describes the
| dump protocol) for the DN3000's memory: entered by the PROM with the
| MMU off, it runs at its physical home and reaches the kernel's cells by
| physical address (VA - OS_PROC + 0x103000, the kernel's first page as
| loaded): CRASH_STATUS, SERVER_$FLAG.  Its stack is physical 0x103A00
| and its packet buffer 0x103400 (the kernel's pages a dump no longer
| needs).  The PROM's vectors (0x104 .. 0x120 of the trap page, absolute
| words) send and receive the packets; the MMU's state is saved from
| the MC68851 (`pmove tc', `pmove crp') when one is fitted (the line-F
| vector pointed past it while it tries), else from the MMU's registers
| through the function-code space (`moves').  DUMP_$AUTO_REBOOT is the
| entry CRASH_SYSTEM's restart hands the PROM; DUMP_$ADDRS the physical
| ranges dumped (0x100000..0x17FC00 in the file, as the image; OS_$INIT
| sets them); DUMP_$SMAP_PHADDR and DUMP_$RARS_PHADDR the tables'
| physical addresses (OS_$INIT).  The strings are the console's messages.
|
| One section; its cells are reached off A5 = DUMP (`lea (d,PC),A5') with
| the image's displacements and PC-relatively.  The RFC fixup table lists
| three cells here (OS_PROC, CRASH_STATUS, SERVER_$FLAG).  The labels
| without a map name keep the image address they stand at.  The Apollo
| assembler's <ea>=#imm forms (cmp/add/sub/and #imm,Dn), which gas spells
| cmpi/addi/subi/andi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau8 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU8 image's.
|

        .section ".text.DUMP","ax",@progbits
        .even

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

DUMP:
        move.l  %d0,%d7                         | 3c00400  2e00
        bra.s   dump_check_magic                       | 3c00402  600e
        moveq   #2,%d7                          | 3c00404  7e02
        bra.s   dump_start_2_0                       | 3c00406  6006
        moveq   #2,%d7                          | 3c00408  7e02
        moveq   #1,%d6                          | 3c0040a  7c01
        bra.s   dump_common                       | 3c0040c  6028
dump_start_2_0:
        moveq   #0,%d6                          | 3c0040e  7c00
        bra.s   dump_common                       | 3c00410  6024
dump_check_magic:
        swap    %d0                             | 3c00412  4840
        .short  0xb07c, 0x0ace                  | 3c00414  b07c 0ace  cmp.w #0xace,%d0 (<ea>=#imm form)
        beq.s   .L3c0041c                       | 3c00418  6702
        moveq   #1,%d7                          | 3c0041a  7e01
.L3c0041c:
        moveq   #0,%d6                          | 3c0041c  7c00
        swap    %d1                             | 3c0041e  4841
        .short  0xb27c, 0x0ace                  | 3c00420  b27c 0ace  cmp.w #0xace,%d1 (<ea>=#imm form)
        bne.s   dump_common                       | 3c00424  6610
        clr.w   %d1                             | 3c00426  4241
        swap    %d1                             | 3c00428  4841
        move.l  %d1,%d6                         | 3c0042a  2c01
        btst    #7,%d2                          | 3c0042c  0802 0007
        bne.s   dump_common                       | 3c00430  6604
        .short  0xcc7c, 0x00ff                  | 3c00432  cc7c 00ff  and.w #0xff,%d6 (<ea>=#imm form)
dump_common:
        lea     (DUMP,%pc),%a5                  | 3c00436  4bfa ffc8
        lea     (0x103a00).l,%sp                | 3c0043a  4ff9 0010 3a00
        movea.l %sp,%fp                         | 3c00440  2c4f
        clr.w   (0x638,%a5)                     | 3c00442  426d 0638
        move.b  %d6,(0x639,%a5)                 | 3c00446  1b46 0639
        lsr.w   #8,%d6                          | 3c0044a  e04e
        move.w  %d6,(2,%fp)                     | 3c0044c  3d46 0002
        move.l  #0x400,%d6                      | 3c00450  2c3c 0000 0400
        bset    #0,(0x61e,%a5)                  | 3c00456  08ed 0000 061e
        bne.s   .L3c00466                       | 3c0045c  6608
        move.w  (0x8000).l,(0xe,%fp)            | 3c0045e  3d79 0000 8000 000e
.L3c00466:
        move.w  %d7,(%fp)                       | 3c00466  3c87
        move.w  #0,-(%sp)                       | 3c00468  3f3c 0000
        pea     (%sp)                           | 3c0046c  4857
        move.l  #0x600df1a6,(4,%fp)             | 3c0046e  2d7c 600d f1a6 0004
        pea     (4,%fp)                         | 3c00476  486e 0004
        pea     (2,%fp)                         | 3c0047a  486e 0002
        pea     (%fp)                           | 3c0047e  4856
        movea.l (0x10c).w,%a0                   | 3c00480  2078 010c
        jsr     (%a0)                           | 3c00484  4e90
        adda.w  #0x12,%sp                       | 3c00486  defc 0012
        lea     (OS_PROC).l,%a4           | 3c0048a  49f9 03c0 0c00
        move.l  #0x103000,%d7                   | 3c00490  2e3c 0010 3000
        clr.b   (0x20,%fp)                      | 3c00496  422e 0020
        cmpi.w  #2,(%fp)                        | 3c0049a  0c56 0002
        beq.s   .L3c004ac                       | 3c0049e  670c
        cmpi.w  #6,(%fp)                        | 3c004a0  0c56 0006
        beq.s   .L3c004ac                       | 3c004a4  6706
        cmpi.w  #8,(%fp)                        | 3c004a6  0c56 0008
        bne.s   .L3c004fc                       | 3c004aa  6650
.L3c004ac:
        lea     (CRASH_STATUS).l,%a3            | 3c004ac  47f9 03c2 0234
        suba.l  %a4,%a3                         | 3c004b2  97cc
        adda.l  %d7,%a3                         | 3c004b4  d7c7
        move.l  (%a3),(0x5d8,%a5)               | 3c004b6  2b53 05d8
        moveq   #0,%d0                          | 3c004ba  7000
        bsr.w   dump_send_page0                       | 3c004bc  6100 038c
        btst    #0,(0x8001).l                   | 3c004c0  0839 0000 0000 8001
        beq.s   .L3c004f0                       | 3c004c8  6726
        lea     (SERVER_$FLAG).l,%a3            | 3c004ca  47f9 03c2 024b
        suba.l  %a4,%a3                         | 3c004d0  97cc
        adda.l  %d7,%a3                         | 3c004d2  d7c7
        tst.b   (%a3)                           | 3c004d4  4a13
        beq.s   .L3c004f0                       | 3c004d6  6718
        movea.l (0x1c,%fp),%a1                  | 3c004d8  226e 001c
        btst    #6,(0xa,%a1)                    | 3c004dc  0829 0006 000a
        st      (0x20,%fp)                      | 3c004e2  50ee 0020
        btst    #7,(0xa,%a1)                    | 3c004e6  0829 0007 000a
        beq.w   .L3c007ee                       | 3c004ec  6700 0300
.L3c004f0:
        movea.l (0x1c,%fp),%a1                  | 3c004f0  226e 001c
        lea     (0xc,%a1),%a0                   | 3c004f4  41e9 000c
        bsr.w   dump_puts                       | 3c004f8  6100 0480
.L3c004fc:
        lea     (0x103400).l,%a4                | 3c004fc  49f9 0010 3400
        move.l  %a4,%d7                         | 3c00502  2e0c
        move.w  (0xe,%fp),(%a4)+                | 3c00504  38ee 000e
        move.w  #8,(%a4)+                       | 3c00508  38fc 0008
        bclr    #3,(0x61e,%a5)                  | 3c0050c  08ad 0003 061e
        move.l  #0x101800,%d0                   | 3c00512  203c 0010 1800
        movec   %d0,%vbr                        | 3c00518  4e7b 0801
        movea.l #0x10182c,%a0                   | 3c0051c  207c 0010 182c
        move.l  (%a0),%d1                       | 3c00522  2210
        lea     (.L3c00540,%pc),%a3             | 3c00524  47fa 001a
        move.l  %a3,(%a0)                       | 3c00528  208b
        pmove   %tc,(%a4)                       | 3c0052a  f014 4200
        addq.w  #4,%a4                          | 3c0052e  584c
        move.w  #-2,(%a4)+                      | 3c00530  38fc fffe
        bset    #3,(0x61e,%a5)                  | 3c00534  08ed 0003 061e
        pmove   %crp,(%a4)                      | 3c0053a  f014 4e00
        bra.s   .L3c0055c                       | 3c0053e  601c
.L3c00540:
        moveq   #3,%d0                          | 3c00540  7003
        movec   %d0,%sfc                        | 3c00542  4e7b 0000
        moves.l (0xc000000).l,%d0               | 3c00546  0eb9 0000 0c00 0000
        move.l  %d0,(%a4)+                      | 3c0054e  28c0
        move.w  #1,(%a4)+                       | 3c00550  38fc 0001
        moves.l (0x0).w,%d0                     | 3c00554  0eb8 0000 0000
        move.l  %d0,(%a4)                       | 3c0055a  2880
.L3c0055c:
        addq.l  #8,%a4                          | 3c0055c  508c
        move.l  %d1,(%a0)                       | 3c0055e  2081
        move.l  #0x400,(0x646,%a5)              | 3c00560  2b7c 0000 0400 0646
        clr.l   %d0                             | 3c00568  4280
        cmpi.w  #1,(0x638,%a5)                  | 3c0056a  0c6d 0001 0638
        bne.s   .L3c005a4                       | 3c00570  6632
        lea     (.L3c00a1f,%pc),%a0             | 3c00572  41fa 04ab
        bsr.w   dump_puts                       | 3c00576  6100 0402
        move.l  #0x47424c42,%d0                 | 3c0057a  203c 4742 4c42
        move.l  #1,(0x64a,%a5)                  | 3c00580  2b7c 0000 0001 064a
        clr.l   (0x63a,%a5)                     | 3c00588  42ad 063a
        clr.l   (0x63e,%a5)                     | 3c0058c  42ad 063e
        lea     (.L3c005f2,%pc),%a0             | 3c00590  41fa 0060
        bsr.w   dump_walk_tables                       | 3c00594  6100 012c
        move.l  (.L3c00a3a,%pc),(4,%a4)         | 3c00598  297a 04a0 0004
        move.l  (.L3c00a3e,%pc),(8,%a4)         | 3c0059e  297a 049e 0008
.L3c005a4:
        move.l  %d0,(%a4)                       | 3c005a4  2880
        adda.l  #0xc,%a4                        | 3c005a6  d9fc 0000 000c
        clr.l   (0x5d8,%a5)                     | 3c005ac  42ad 05d8
        bsr.w   dump_send_page                       | 3c005b0  6100 028e
        moveq   #0x1f,%d5                       | 3c005b4  7a1f
        move.w  %d5,%d2                         | 3c005b6  3405
        cmpi.w  #1,(0x638,%a5)                  | 3c005b8  0c6d 0001 0638
        bne.w   .L3c00756                       | 3c005be  6600 0196
        lea     (.L3c006b2,%pc),%a0             | 3c005c2  41fa 00ee
        bsr.w   dump_walk_tables                       | 3c005c6  6100 00fa
        move.l  #1,(0x64a,%a5)                  | 3c005ca  2b7c 0000 0001 064a
        bset    #2,(0x61e,%a5)                  | 3c005d2  08ed 0002 061e
        lea     (0x103400).l,%a0                | 3c005d8  41f9 0010 3400
        move.l  %a0,(0x642,%a5)                 | 3c005de  2b48 0642
        lea     (.L3c00618,%pc),%a0             | 3c005e2  41fa 0034
        bsr.w   dump_walk_tables                       | 3c005e6  6100 00da
        bsr.w   .L3c00696                       | 3c005ea  6100 00aa
        bra.w   .L3c007d4                       | 3c005ee  6000 01e4
.L3c005f2:
        movem.l %d0-%d1,-(%sp)                  | 3c005f2  48e7 c000
        addq.l  #1,(0x63a,%a5)                  | 3c005f6  52ad 063a
        move.l  %d0,%d1                         | 3c005fa  2200
        .short  0x92bc, 0x0000, 0x0400          | 3c005fc  92bc 0000 0400  sub.l #0x400,%d1 (<ea>=#imm form)
        cmp.l   (.L3c00a4a,%pc),%d1             | 3c00602  b2ba 0446
        beq.w   .L3c0060e                       | 3c00606  6700 0006
        addq.l  #1,(0x63e,%a5)                  | 3c0060a  52ad 063e
.L3c0060e:
        move.l  %d0,(0x64a,%a5)                 | 3c0060e  2b40 064a
        movem.l (%sp)+,%d0-%d1                  | 3c00612  4cdf 0003
        rts                                     | 3c00616  4e75
.L3c00618:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c00618  48e7 c0c0
        movea.l (.L3c00a42,%pc),%a0             | 3c0061c  207a 0424
        move.l  (.L3c00a4a,%pc),%d1             | 3c00620  223a 0428
        move.l  %d0,(0x64a,%a5)                 | 3c00624  2b40 064a
        .short  0xd2bc, 0x0000, 0x0400          | 3c00628  d2bc 0000 0400  add.l #0x400,%d1 (<ea>=#imm form)
        cmp.l   %d0,%d1                         | 3c0062e  b280
        beq.w   .L3c0067a                       | 3c00630  6700 0048
        bclr    #2,(0x61e,%a5)                  | 3c00634  08ad 0002 061e
        bne.w   .L3c0065c                       | 3c0063a  6600 0020
        adda.l  #0x10,%a0                       | 3c0063e  d1fc 0000 0010
        move.l  %a0,(0x642,%a5)                 | 3c00644  2b48 0642
        move.l  %a0,%d1                         | 3c00648  2208
        .short  0xc2bc, 0x0000, 0x03ff          | 3c0064a  c2bc 0000 03ff  and.l #0x3ff,%d1 (<ea>=#imm form)
        bne.w   .L3c0065c                       | 3c00650  6600 000a
        bsr.w   .L3c00696                       | 3c00654  6100 0040
        movea.l (.L3c00a42,%pc),%a0             | 3c00658  207a 03e8
.L3c0065c:
        move.l  (.L3c00a46,%pc),%d1             | 3c0065c  223a 03e8
        movea.l %a0,%a1                         | 3c00660  2248
        move.l  %d1,(%a1)+                      | 3c00662  22c1
        .short  0xd2bc, 0x0000, 0x03ff          | 3c00664  d2bc 0000 03ff  add.l #0x3ff,%d1 (<ea>=#imm form)
        move.l  %d1,(%a1)+                      | 3c0066a  22c1
        move.l  %d0,(%a1)+                      | 3c0066c  22c0
        .short  0xd0bc, 0x0000, 0x03ff          | 3c0066e  d0bc 0000 03ff  add.l #0x3ff,%d0 (<ea>=#imm form)
        move.l  %d0,(%a1)                       | 3c00674  2280
        bra.w   .L3c00688                       | 3c00676  6000 0010
.L3c0067a:
        move.l  #0x400,%d1                      | 3c0067a  223c 0000 0400
        add.l   %d1,(4,%a0)                     | 3c00680  d3a8 0004
        add.l   %d1,(0xc,%a0)                   | 3c00684  d3a8 000c
.L3c00688:
        addi.l  #0x400,(0x646,%a5)              | 3c00688  06ad 0000 0400 0646
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c00690  4cdf 0303
        rts                                     | 3c00694  4e75
.L3c00696:
        movem.l %d0-%a5,-(%sp)                  | 3c00696  48e7 fffc
        lea     (0x103400).l,%a0                | 3c0069a  41f9 0010 3400
        move.l  %a0,(0x642,%a5)                 | 3c006a0  2b48 0642
        addq.l  #1,(0x5d8,%a5)                  | 3c006a4  52ad 05d8
        bsr.w   dump_send_page                       | 3c006a8  6100 0196
        movem.l (%sp)+,%d0-%a5                  | 3c006ac  4cdf 3fff
        rts                                     | 3c006b0  4e75
.L3c006b2:
        movem.l %d1/%d3/%d7-%a2,-(%sp)          | 3c006b2  48e7 51e0
        move.l  %d0,%d7                         | 3c006b6  2e00
        bsr.w   .L3c0076c                       | 3c006b8  6100 00b2
        movem.l (%sp)+,%d1/%d3/%d7-%a2          | 3c006bc  4cdf 078a
        rts                                     | 3c006c0  4e75
dump_walk_tables:
        movem.l %d0-%d4/%a0-%a3,-(%sp)          | 3c006c2  48e7 f8f0
        movea.l (DUMP_$SMAP_PHADDR,%pc),%a1     | 3c006c6  227a 0386
        btst    #3,(dump_flags,%pc)              | 3c006ca  083a 0003 0350
        beq.w   .L3c006dc                       | 3c006d0  6700 000a
        adda.l  #0x800,%a1                      | 3c006d4  d3fc 0000 0800
        bra.s   .L3c006e2                       | 3c006da  6006
.L3c006dc:
        adda.l  #0x600,%a1                      | 3c006dc  d3fc 0000 0600
.L3c006e2:
        clr.l   %d1                             | 3c006e2  4281
.L3c006e4:
        move.l  (0,%a1,%d1.w),%d4               | 3c006e4  2831 1000
        .short  0xc8bc, 0x0000, 0x0003          | 3c006e8  c8bc 0000 0003  and.l #3,%d4 (<ea>=#imm form)
        beq.s   .L3c00730                       | 3c006ee  6740
        move.l  (4,%a1,%d1.w),%d4               | 3c006f0  2831 1004
        .short  0xc8bc, 0xffff, 0xfff0          | 3c006f4  c8bc ffff fff0  and.l #-0x10,%d4 (<ea>=#imm form)
        movea.l %d4,%a2                         | 3c006fa  2444
        clr.l   %d3                             | 3c006fc  4283
.L3c006fe:
        move.l  (0,%a2,%d3.w),%d0               | 3c006fe  2032 3000
        move.l  %d0,%d4                         | 3c00702  2800
        .short  0xc8bc, 0x0000, 0x0003          | 3c00704  c8bc 0000 0003  and.l #3,%d4 (<ea>=#imm form)
        beq.s   .L3c00728                       | 3c0070a  671c
        .short  0xc0bc, 0xffff, 0xfc00          | 3c0070c  c0bc ffff fc00  and.l #-0x400,%d0 (<ea>=#imm form)
        lea     (dump_ranges,%pc),%a3             | 3c00712  47fa 04d0
.L3c00716:
        addq.l  #8,%a3                          | 3c00716  508b
        tst.l   (%a3)                           | 3c00718  4a93
        beq.s   .L3c00728                       | 3c0071a  670c
        cmp.l   (%a3),%d0                       | 3c0071c  b093
        blt.s   .L3c00716                       | 3c0071e  6df6
        cmp.l   (4,%a3),%d0                     | 3c00720  b0ab 0004
        bgt.s   .L3c00716                       | 3c00724  6ef0
        jsr     (%a0)                           | 3c00726  4e90
.L3c00728:
        addq.w  #4,%d3                          | 3c00728  5843
        .short  0xb67c, 0x0080                  | 3c0072a  b67c 0080  cmp.w #0x80,%d3 (<ea>=#imm form)
        blt.s   .L3c006fe                       | 3c0072e  6dce
.L3c00730:
        addq.w  #8,%d1                          | 3c00730  5041
        btst    #3,(dump_flags,%pc)              | 3c00732  083a 0003 02e8
        beq.w   .L3c00742                       | 3c00738  6700 0008
        .short  0xb27c, 0x1000                  | 3c0073c  b27c 1000  cmp.w #0x1000,%d1 (<ea>=#imm form)
        bra.s   .L3c00746                       | 3c00740  6004
.L3c00742:
        .short  0xb27c, 0x0600                  | 3c00742  b27c 0600  cmp.w #0x600,%d1 (<ea>=#imm form)
.L3c00746:
        blt.s   .L3c006e4                       | 3c00746  6d9c
        move.l  #0x101800,%d0                   | 3c00748  203c 0010 1800
        jsr     (%a0)                           | 3c0074e  4e90
        movem.l (%sp)+,%d0-%d4/%a0-%a3          | 3c00750  4cdf 0f1f
        rts                                     | 3c00754  4e75
.L3c00756:
        lea     (DUMP_$ADDRS,%pc),%a3           | 3c00756  47fa 0494
.L3c0075a:
        move.l  (%a3)+,%d3                      | 3c0075a  261b
        beq.s   .L3c007d4                       | 3c0075c  6776
        move.l  (%a3)+,%d4                      | 3c0075e  281b
.L3c00760:
        move.l  %d3,%d7                         | 3c00760  2e03
        bsr.w   .L3c0076c                       | 3c00762  6100 0008
        cmp.l   %d3,%d4                         | 3c00766  b883
        bge.s   .L3c00760                       | 3c00768  6cf6
        bra.s   .L3c0075a                       | 3c0076a  60ee
.L3c0076c:
        addq.l  #1,(0x5d8,%a5)                  | 3c0076c  52ad 05d8
        bsr.w   dump_send_page                       | 3c00770  6100 00ce
        cmpi.w  #1,(%fp)                        | 3c00774  0c56 0001
        bne.s   .L3c007b4                       | 3c00778  663a
        cmpi.w  #0x4cf,(0x5da,%a5)              | 3c0077a  0c6d 04cf 05da
        blt.s   .L3c007b4                       | 3c00780  6d32
        move.l  #-1,(0x5d8,%a5)                 | 3c00782  2b7c ffff ffff 05d8
        movem.l %d0-%a0,-(%sp)                  | 3c0078a  48e7 ff80
        bsr.w   dump_crlf                       | 3c0078e  6100 01e6
        movea.l (0x118).w,%a0                   | 3c00792  2078 0118
.L3c00796:
        jsr     (%a0)                           | 3c00796  4e90
        .short  0xb23c, 0x00ff                  | 3c00798  b23c 00ff  cmp.b #-1,%d1 (<ea>=#imm form)
        bne.s   .L3c00796                       | 3c0079c  66f8
        lea     (.L3c009fe,%pc),%a0             | 3c0079e  41fa 025e
        bsr.w   dump_puts                       | 3c007a2  6100 01d6
        movea.l (0x104).w,%a0                   | 3c007a6  2078 0104
        jsr     (%a0)                           | 3c007aa  4e90
        bsr.w   dump_crlf                       | 3c007ac  6100 01c8
        movem.l (%sp)+,%d0-%a0                  | 3c007b0  4cdf 01ff
.L3c007b4:
        dbf     %d5,.L3c007cc                   | 3c007b4  51cd 0016
        move.b  #0x21,%d1                       | 3c007b8  123c 0021
        bsr.w   dump_putc                       | 3c007bc  6100 01e2
        moveq   #0x1f,%d5                       | 3c007c0  7a1f
        dbf     %d2,.L3c007cc                   | 3c007c2  51ca 0008
        bsr.w   dump_crlf                       | 3c007c6  6100 01ae
        move.w  %d5,%d2                         | 3c007ca  3405
.L3c007cc:
        .short  0xd6bc, 0x0000, 0x0400          | 3c007cc  d6bc 0000 0400  add.l #0x400,%d3 (<ea>=#imm form)
        rts                                     | 3c007d2  4e75
.L3c007d4:
        lea     (.L3c00a17,%pc),%a0             | 3c007d4  41fa 0241
        bsr.w   dump_puts_crlf                       | 3c007d8  6100 019a
        cmpi.w  #2,(%fp)                        | 3c007dc  0c56 0002
        beq.s   .L3c007ee                       | 3c007e0  670c
        cmpi.w  #6,(%fp)                        | 3c007e2  0c56 0006
        beq.s   .L3c007ee                       | 3c007e6  6706
        cmpi.w  #8,(%fp)                        | 3c007e8  0c56 0008
        bne.s   .L3c007fa                       | 3c007ec  660c
.L3c007ee:
        moveq   #4,%d0                          | 3c007ee  7004
        cmp.b   (.L3c009d7,%pc),%d0             | 3c007f0  b03a 01e5
        beq.s   .L3c007fa                       | 3c007f4  6704
        bsr.w   dump_send_page0                       | 3c007f6  6100 0052
.L3c007fa:
        cmpi.w  #5,(%fp)                        | 3c007fa  0c56 0005
        bne.s   .L3c00804                       | 3c007fe  6604
        bsr.s   .L3c00836                       | 3c00800  6134
        bsr.s   .L3c00836                       | 3c00802  6132
.L3c00804:
        tst.b   (0x20,%fp)                      | 3c00804  4a2e 0020
        beq.s   dump_to_prom                       | 3c00808  6710
        reset                                   | 3c0080a  4e70
dump_reset:
        movea.l (0x0).w,%sp                     | 3c0080c  2e78 0000
        ori.w   #0x2700,%sr                     | 3c00810  007c 2700
        movea.l (0x4).w,%a0                     | 3c00814  2078 0004
        jmp     (%a0)                           | 3c00818  4ed0
dump_to_prom:
        movea.l (0x11c).w,%a0                   | 3c0081a  2078 011c
        jmp     (%a0)                           | 3c0081e  4ed0
DUMP_$AUTO_REBOOT:
        lea     (DUMP,%pc),%a5                  | 3c00820  4bfa fbde
        lea     (0x103a00).l,%sp                | 3c00824  4ff9 0010 3a00
        movea.l %sp,%fp                         | 3c0082a  2c4f
        lea     (.L3c00a0a,%pc),%a0             | 3c0082c  41fa 01dc
        bsr.w   dump_puts_crlf                       | 3c00830  6100 0142
        bra.s   dump_reset                       | 3c00834  60d6
.L3c00836:
        moveq   #-1,%d0                         | 3c00836  70ff
        move.l  %d0,(0x5d8,%a5)                 | 3c00838  2b40 05d8
        bsr.s   dump_send_page0                       | 3c0083c  610c
        rts                                     | 3c0083e  4e75
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | 3c00840  48e7 ff78
        moveq   #2,%d0                          | 3c00844  7002
        move.l  %d6,%d1                         | 3c00846  2206
        bra.s   .L3c00852                       | 3c00848  6008
dump_send_page0:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | 3c0084a  48e7 ff78
        clr.w   %d1                             | 3c0084e  4241
        move.l  %a5,%d7                         | 3c00850  2e0d
.L3c00852:
        move.w  %d1,(0x5c4,%a5)                 | 3c00852  3b41 05c4
        move.b  %d0,(0x5d7,%a5)                 | 3c00856  1b40 05d7
        move.l  %d7,%d0                         | 3c0085a  2007
        lsr.l   #8,%d0                          | 3c0085c  e088
        lsr.l   #2,%d0                          | 3c0085e  e488
        move.w  %d0,(0xa,%fp)                   | 3c00860  3d40 000a
        move.w  #0xa,(8,%fp)                    | 3c00864  3d7c 000a 0008
.L3c0086a:
        clr.l   %d4                             | 3c0086a  4284
.L3c0086c:
        pea     (4,%fp)                         | 3c0086c  486e 0004
        pea     (dump_pkt,%pc)                 | 3c00870  487a 013e
        cmpi.w  #5,(%fp)                        | 3c00874  0c56 0005
        bne.s   .L3c0087e                       | 3c00878  6604
        move.l  %d7,(%sp)                       | 3c0087a  2e87
        add.l   %d4,(%sp)                       | 3c0087c  d997
.L3c0087e:
        pea     (0xa,%fp)                       | 3c0087e  486e 000a
        pea     (dump_peer,%pc)                 | 3c00882  487a 0154
        movea.l (0x120).w,%a0                   | 3c00886  2078 0120
        jsr     (%a0)                           | 3c0088a  4e90
        adda.w  #0x10,%sp                       | 3c0088c  defc 0010
        move.l  (4,%fp),%d0                     | 3c00890  202e 0004
        beq.s   .L3c008aa                       | 3c00894  6714
        subq.w  #1,(8,%fp)                      | 3c00896  536e 0008
        bne.s   .L3c0086a                       | 3c0089a  66ce
        lea     (.L3c009de,%pc),%a0             | 3c0089c  41fa 0140
        bra.w   .L3c00964                       | 3c008a0  6000 00c2
.L3c008a4:
        movem.l (%sp)+,%d0-%d7/%a1-%a4          | 3c008a4  4cdf 1eff
        rts                                     | 3c008a8  4e75
.L3c008aa:
        cmpi.w  #1,(%fp)                        | 3c008aa  0c56 0001
        beq.s   .L3c008a4                       | 3c008ae  67f4
        cmpi.w  #5,(%fp)                        | 3c008b0  0c56 0005
        bne.s   .L3c008c6                       | 3c008b4  6610
        tst.l   (0x5d8,%a5)                     | 3c008b6  4aad 05d8
        blt.s   .L3c008a4                       | 3c008ba  6de8
        tst.l   %d4                             | 3c008bc  4a84
        bne.s   .L3c008a4                       | 3c008be  66e4
        .short  0xd87c, 0x0200                  | 3c008c0  d87c 0200  add.w #0x200,%d4 (<ea>=#imm form)
        bra.s   .L3c0086c                       | 3c008c4  60a6
.L3c008c6:
        move.w  #3,(8,%fp)                      | 3c008c6  3d7c 0003 0008
        pea     (4,%fp)                         | 3c008cc  486e 0004
        move.l  #0x103a22,-(%sp)                | 3c008d0  2f3c 0010 3a22
        pea     (.L3c009dc,%pc)                 | 3c008d6  487a 0104
        pea     (dump_peer,%pc)                 | 3c008da  487a 00fc
        movea.l (0x110).w,%a0                   | 3c008de  2078 0110
        jsr     (%a0)                           | 3c008e2  4e90
        adda.w  #0x10,%sp                       | 3c008e4  defc 0010
        move.l  (4,%fp),%d0                     | 3c008e8  202e 0004
        beq.s   .L3c008fc                       | 3c008ec  670e
        subq.w  #1,(8,%fp)                      | 3c008ee  536e 0008
        bne.w   .L3c0086a                       | 3c008f2  6600 ff76
        lea     (.L3c009e3,%pc),%a0             | 3c008f6  41fa 00eb
        bra.s   .L3c00964                       | 3c008fa  6068
.L3c008fc:
        lea     (0x22,%fp),%a0                  | 3c008fc  41ee 0022
        move.l  (dump_pkt,%pc),%d0             | 3c00900  203a 00ae
        cmp.l   (8,%a0),%d0                     | 3c00904  b0a8 0008
        bne.s   .L3c008c6                       | 3c00908  66bc
        lea     (0x1e,%a0),%a1                  | 3c0090a  43e8 001e
        clr.l   %d0                             | 3c0090e  4280
        move.b  (0x18,%a0),%d0                  | 3c00910  1028 0018
        adda.l  %d0,%a1                         | 3c00914  d3c0
        move.l  %a1,(0x1c,%fp)                  | 3c00916  2d49 001c
        cmpi.w  #2,(%a1)                        | 3c0091a  0c51 0002
        bne.s   .L3c00934                       | 3c0091e  6614
        cmpi.w  #1,(2,%a1)                      | 3c00920  0c69 0001 0002
        bne.s   .L3c00934                       | 3c00926  660c
        move.b  (5,%a1),%d0                     | 3c00928  1029 0005
        subq.l  #1,%d0                          | 3c0092c  5380
        cmp.b   (.L3c009d7,%pc),%d0             | 3c0092e  b03a 00a7
        beq.s   .L3c00948                       | 3c00932  6714
.L3c00934:
        cmpi.b  #7,(5,%a1)                      | 3c00934  0c29 0007 0005
        bne.s   .L3c0093e                       | 3c0093a  6602
.L3c0093c:
        bra.s   .L3c008c6                       | 3c0093c  6088
.L3c0093e:
        lea     (.L3c009e8,%pc),%a0             | 3c0093e  41fa 00a8
        bsr.s   dump_puts                       | 3c00942  6136
.L3c00944:
        bra.w   .L3c007ee                       | 3c00944  6000 fea8
.L3c00948:
        .short  0xb03c, 0x0002                  | 3c00948  b03c 0002  cmp.b #2,%d0 (<ea>=#imm form)
        bne.s   .L3c00958                       | 3c0094c  660a
        move.l  (dump_peer,%pc),%d0             | 3c0094e  203a 0088
        cmp.l   (0xc,%a1),%d0                   | 3c00952  b0a9 000c
        bne.s   .L3c0093c                       | 3c00956  66e4
.L3c00958:
        move.l  (6,%a1),%d0                     | 3c00958  2029 0006
        beq.w   .L3c008a4                       | 3c0095c  6700 ff46
        lea     (.L3c009f0,%pc),%a0             | 3c00960  41fa 008e
.L3c00964:
        move.l  %d0,-(%sp)                      | 3c00964  2f00
        bsr.s   dump_puts                       | 3c00966  6112
        lea     (.L3c009f7,%pc),%a0             | 3c00968  41fa 008d
        bsr.s   dump_puts                       | 3c0096c  610c
        move.l  (%sp)+,%d0                      | 3c0096e  201f
        bsr.s   dump_hex8                       | 3c00970  6112
        bra.s   .L3c00944                       | 3c00972  60d0
dump_puts_crlf:
        bsr.s   dump_puts                       | 3c00974  6104
dump_crlf:
        lea     (.L3c00a14,%pc),%a0             | 3c00976  41fa 009c
dump_puts:
        move.b  (%a0)+,%d1                      | 3c0097a  1218
        beq.s   .L3c009ae                       | 3c0097c  6730
        bsr.s   dump_putc                       | 3c0097e  6120
        bra.s   dump_puts                       | 3c00980  60f8
        rts                                     | 3c00982  4e75
dump_hex8:
        moveq   #7,%d2                          | 3c00984  7407
.L3c00986:
        rol.l   #4,%d0                          | 3c00986  e998
        moveq   #0xf,%d1                        | 3c00988  720f
        and.b   %d0,%d1                         | 3c0098a  c200
        .short  0xb23c, 0x000a                  | 3c0098c  b23c 000a  cmp.b #0xa,%d1 (<ea>=#imm form)
        blt.s   .L3c00994                       | 3c00990  6d02
        addq.b  #7,%d1                          | 3c00992  5e01
.L3c00994:
        .short  0xd23c, 0x0030                  | 3c00994  d23c 0030  add.b #0x30,%d1 (<ea>=#imm form)
        bsr.s   dump_putc                       | 3c00998  6106
        dbf     %d2,.L3c00986                   | 3c0099a  51ca ffea
        bra.s   dump_crlf                       | 3c0099e  60d6
dump_putc:
        movem.l %d0-%a4,-(%sp)                  | 3c009a0  48e7 fff8
        movea.l (0x108).w,%a0                   | 3c009a4  2078 0108
        jsr     (%a0)                           | 3c009a8  4e90
        movem.l (%sp)+,%d0-%a4                  | 3c009aa  4cdf 1fff
.L3c009ae:
        rts                                     | 3c009ae  4e75
dump_pkt:
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | 3c009b0  0000 0000 0000 0000
        .byte   0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00 | 3c009b8  0000 0000 0101 0000
        .byte   0x00, 0x2c, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00 | 3c009c0  002c 000a 0000 0000
        .byte   0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | 3c009c8  0401 0000 0000 0000
        .byte   0x00, 0x03, 0x00, 0x02, 0x00, 0x01, 0x08 | 3c009d0  0003 0002 0001 08
.L3c009d7:
        .byte   0x00                            | 3c009d7  00
dump_peer:
        .short  0x0000, 0x0000                  | 3c009d8  0000 0000
.L3c009dc:
        .short  0x0400                          | 3c009dc  0400
.L3c009de:
        .ascii  "Xbad"                          | 3c009de  5862 6164
        .byte   0x00                            | 3c009e2  00
.L3c009e3:
        .ascii  "Rbad"                          | 3c009e3  5262 6164
        .byte   0x00                            | 3c009e7  00
.L3c009e8:
        .ascii  "Bad rpy"                       | 3c009e8  4261 6420 7270 79
        .byte   0x00                            | 3c009ef  00
.L3c009f0:
        .ascii  "Nm sad"                        | 3c009f0  4e6d 2073 6164
        .byte   0x00                            | 3c009f6  00
.L3c009f7:
        .ascii  " - St="                        | 3c009f7  202d 2053 743d
        .byte   0x00                            | 3c009fd  00
.L3c009fe:
        .ascii  "Nxt flp<CR>"                   | 3c009fe  4e78 7420 666c 703c 4352 3e
        .byte   0x00                            | 3c00a09  00
.L3c00a0a:
        .ascii  "REBOOTING"                     | 3c00a0a  5245 424f 4f54 494e 47
        .byte   0x00                            | 3c00a13  00
.L3c00a14:
        .byte   0x0a, 0x0d, 0x00                | 3c00a14  0a0d 00
.L3c00a17:
        .byte   0x0a, 0x0d                      | 3c00a17  0a0d
        .ascii  "Done"                          | 3c00a19  446f 6e65
        .byte   0x00                            | 3c00a1d  00
dump_flags:
        .byte   0x00                            | 3c00a1e  00
.L3c00a1f:
        .ascii  "Dumping global_b only."        | 3c00a1f  4475 6d70 696e 6720 676c 6f62 616c 5f62 206f 6e6c 792e
        .byte   0x0a, 0x0d, 0x00, 0x00, 0x00    | 3c00a35  0a0d 0000 00
.L3c00a3a:
        .short  0x0000, 0x0000                  | 3c00a3a  0000 0000
.L3c00a3e:
        .short  0x0000, 0x0000                  | 3c00a3e  0000 0000
.L3c00a42:
        .short  0x0000, 0x0000                  | 3c00a42  0000 0000
.L3c00a46:
        .short  0x0000, 0x0000                  | 3c00a46  0000 0000
.L3c00a4a:
        .short  0x0000, 0x0000                  | 3c00a4a  0000 0000
DUMP_$SMAP_PHADDR:
        .space  406                             | 3c00a4e
dump_ranges:
        .short  0x0000, 0x0000                  | 3c00be4  0000 0000
DUMP_$RARS_PHADDR:
        .short  0x0000, 0x0000                  | 3c00be8  0000 0000
DUMP_$ADDRS:
        .short  0x0010, 0x0000, 0x0017, 0xfc00, 0x0000, 0x0000, 0x0000, 0x0000 | 3c00bec  0010 0000 0017 fc00 0000 0000 0000 0000
        .short  0x0000, 0x0000                  | 3c00bfc  0000 0000
