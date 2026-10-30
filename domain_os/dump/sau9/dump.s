|
| dump/sau9/dump.s - the DUMP page (SAU9): the crash-dump code and its
| cells
|
| The SAU9's DUMP page, transcribed from the SAU9 image file (file
| 0x1800..0x2000, loaded at 0x4003C00, VA 0x3C401400; COLD copies it to
| physical 0x4001400).  The SAU9 map:
|
|   D24 3C401400  DUMP               loaded at 4003C00, size = 800
|   D   3C401400  DUMP               size = 800
|       3C401400  DUMP
|       3C401792  DUMP_$AUTO_REBOOT
|       3C401A5E  DUMP_$SMAP_PHADDR
|       3C401BE8  DUMP_$RARS_PHADDR
|       3C401BEC  DUMP_$ADDRS
|
| Another form than the SAU2's (dump/sau2/dump.s, whose description of
| the dump protocol applies): twice the size, the page entered by the
| PROM with the MMU off, so it runs at its physical home (DUMP_PHYS,
| 0x4001400) and reaches the kernel's cells by physical address (VA -
| OS_PROC + 0x4004400, the kernel's first page as loaded): CRASH_STATUS,
| SERVER_$FLAG.  Its stack and buffers are physical 0x4004800..0x4004E00
| (the kernel's second and third pages, which a dump no longer needs);
| DUMP_$AUTO_REBOOT is the entry CRASH_SYSTEM's restart hands the PROM;
| DUMP_$ADDRS the physical range dumped (0x4000000..0x407FC00 in the
| file, as the image; OS_$INIT sets it), DUMP_$SMAP_PHADDR and
| DUMP_$RARS_PHADDR the tables' physical addresses (OS_$INIT).  The
| strings are the console's messages.
|
| One section; the cells are reached off A5 = DUMP (`lea (d,PC),A5') and
| PC-relatively, so every displacement is a difference of two labels of
| the section.  The Apollo assembler's <ea>=#imm forms (cmp/and #imm,Dn),
| which gas spells cmpi/andi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU9 image's.
|

        .section ".text.DUMP","ax",@progbits
        .even

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

DUMP:
        moveq   #0,%d6                          | 3c401400  7c00
        bra.b   L3c401406                       | 3c401402  6002
        moveq   #1,%d6                          | 3c401404  7c01
L3c401406:
        lea     (24,%a0),%a1                    | 3c401406  43e8 0018
        move.b  (%a1),%d6                       | 3c40140a  1c11
        btst    #0,%d6                          | 3c40140c  0806 0000
        beq.b   L3c40141c                       | 3c401410  670a
        .short  0xcc3c, 0x0070                | 3c401412  cc3c 0070  andb #112,%d6
        .short  0xbc3c, 0x0020                | 3c401416  bc3c 0020  cmpb #32,%d6
        bne.b   L3c401420                       | 3c40141a  6604
L3c40141c:
        moveq   #5,%d7                          | 3c40141c  7e05
        bra.b   L3c401436                       | 3c40141e  6016
L3c401420:
        .short  0xbc3c, 0x0030                | 3c401420  bc3c 0030  cmpb #48,%d6
        bne.b   L3c40142a                       | 3c401424  6604
        moveq   #2,%d7                          | 3c401426  7e02
        bra.b   L3c401436                       | 3c401428  600c
L3c40142a:
        lea     (.Ld0604:w,%pc),%a0             | 3c40142a  41fa 05d8
        bsr.w   L3c401974                       | 3c40142e  6100 0544
        bra.w   L3c40178c                       | 3c401432  6000 0358
L3c401436:
        lea     (DUMP,%pc),%a5                  | 3c401436  4bfa ffc8
        lea     (0x4004e00).l,%sp               | 3c40143a  4ff9 0400 4e00
        movea.l %sp,%fp                         | 3c401440  2c4f
        lea     (24,%a0),%a1                    | 3c401442  43e8 0018
        move.l  %a1,(8,%fp)                     | 3c401446  2d49 0008
        move.l  (40,%a0),(4,%fp)                | 3c40144a  2d68 0028 0004
        move.l  %d1,(.Ld05aa-DUMP:w,%a5)                  | 3c401450  2b41 05aa
        clr.w   (.Ld0648-DUMP:w,%a5)                      | 3c401454  426d 0648
        move.b  %d6,(.Ld0649-DUMP:w,%a5)                  | 3c401458  1b46 0649
        lsr.w   #8,%d6                          | 3c40145c  e04e
        move.w  %d6,(2,%fp)                     | 3c40145e  3d46 0002
        move.l  #0x400,%d6                      | 3c401462  2c3c 0000 0400
        bset    #0,(.Ld062e-DUMP:w,%a5)                   | 3c401468  08ed 0000 062e
        bne.b   L3c401474                       | 3c40146e  6604
        clr.w   (36,%fp)                        | 3c401470  426e 0024
L3c401474:
        move.w  %d7,(%fp)                       | 3c401474  3c87
        pea     (16,%fp)                        | 3c401476  486e 0010
        pea     (12,%fp)                        | 3c40147a  486e 000c
        move.l  (8,%fp),-(%sp)                  | 3c40147e  2f2e 0008
        movea.l (4,%fp),%a0                     | 3c401482  206e 0004
        movea.l (68,%a0),%a0                    | 3c401486  2068 0044
        .short  0xbe7c, 0x0005                | 3c40148a  be7c 0005  cmpw #5,%d7
        bne.b   L3c401498                       | 3c40148e  6608
        movea.l (4,%fp),%a0                     | 3c401490  206e 0004
        movea.l (88,%a0),%a0                    | 3c401494  2068 0058
L3c401498:
        jsr     (%a0)                           | 3c401498  4e90
        adda.w  #0xc,%sp                        | 3c40149a  defc 000c
        lea     (OS_PROC).l,%a4           | 3c40149e  49f9 3c40 1c00
        move.l  #0x4004400,%d7                  | 3c4014a4  2e3c 0400 4400
        clr.b   (54,%fp)                        | 3c4014aa  422e 0036
        cmpi.w  #2,(%fp)                        | 3c4014ae  0c56 0002
        beq.b   L3c4014c0                       | 3c4014b2  670c
        cmpi.w  #6,(%fp)                        | 3c4014b4  0c56 0006
        beq.b   L3c4014c0                       | 3c4014b8  6706
        cmpi.w  #8,(%fp)                        | 3c4014ba  0c56 0008
        bne.b   L3c401510                       | 3c4014be  6650
L3c4014c0:
        lea     (CRASH_STATUS).l,%a3            | 3c4014c0  47f9 3c42 1612
        suba.l  %a4,%a3                         | 3c4014c6  97cc
        adda.l  %d7,%a3                         | 3c4014c8  d7c7
        move.l  (%a3),(.Ld05d2-DUMP:w,%a5)                | 3c4014ca  2b53 05d2
        moveq   #0,%d0                          | 3c4014ce  7000
        bsr.w   L3c4017ec                       | 3c4014d0  6100 031a
        btst    #0,(0x202c0).l                  | 3c4014d4  0839 0000 0002 02c0
        beq.b   L3c401504                       | 3c4014dc  6726
        lea     (SERVER_$FLAG).l,%a3            | 3c4014de  47f9 3c42 1629
        suba.l  %a4,%a3                         | 3c4014e4  97cc
        adda.l  %d7,%a3                         | 3c4014e6  d7c7
        tst.b   (%a3)                           | 3c4014e8  4a13
        beq.b   L3c401504                       | 3c4014ea  6718
        movea.l (50,%fp),%a1                    | 3c4014ec  226e 0032
        btst    #6,(10,%a1)                     | 3c4014f0  0829 0006 000a
        st      (54,%fp)                        | 3c4014f6  50ee 0036
        btst    #7,(10,%a1)                     | 3c4014fa  0829 0007 000a
        beq.w   L3c401754                       | 3c401500  6700 0252
L3c401504:
        movea.l (50,%fp),%a1                    | 3c401504  226e 0032
        lea     (12,%a1),%a0                    | 3c401508  41e9 000c
        bsr.w   L3c401974                       | 3c40150c  6100 0466
L3c401510:
        lea     (0x4004800).l,%a4               | 3c401510  49f9 0400 4800
        move.l  %a4,%d7                         | 3c401516  2e0c
        move.w  (36,%fp),(%a4)+                 | 3c401518  38ee 0024
        move.w  #9,(%a4)+                       | 3c40151c  38fc 0009
        move.l  #0x400,(.Ld0656-DUMP:w,%a5)               | 3c401520  2b7c 0000 0400 0656
        pmove   %tc,(%a4)                       | 3c401528  f014 4200
        addq.w  #4,%a4                          | 3c40152c  584c
        move.w  #-1,(%a4)+                      | 3c40152e  38fc ffff
        pmove   %crp,(%a4)                      | 3c401532  f014 4e00
        addq.l  #8,%a4                          | 3c401536  508c
        clr.l   %d0                             | 3c401538  4280
        cmpi.w  #1,(.Ld0648-DUMP:w,%a5)                   | 3c40153a  0c6d 0001 0648
        bne.b   L3c401574                       | 3c401540  6632
        lea     (.Ld062f:w,%pc),%a0             | 3c401542  41fa 04eb
        bsr.w   L3c401974                       | 3c401546  6100 042c
        move.l  #0x47424c42,%d0                 | 3c40154a  203c 4742 4c42
        move.l  #1,(.Ld065a-DUMP:w,%a5)                   | 3c401550  2b7c 0000 0001 065a
        clr.l   (.Ld064a-DUMP:w,%a5)                      | 3c401558  42ad 064a
        clr.l   (.Ld064e-DUMP:w,%a5)                      | 3c40155c  42ad 064e
        lea     (L3c4015c2:w,%pc),%a0             | 3c401560  41fa 0060
        bsr.w   L3c401692                       | 3c401564  6100 012c
        move.l  (.Ld064a:w,%pc),(4,%a4)         | 3c401568  297a 04e0 0004
        move.l  (.Ld064e:w,%pc),(8,%a4)         | 3c40156e  297a 04de 0008
L3c401574:
        move.l  %d0,(%a4)                       | 3c401574  2880
        adda.l  #0xc,%a4                        | 3c401576  d9fc 0000 000c
        clr.l   (.Ld05d2-DUMP:w,%a5)                      | 3c40157c  42ad 05d2
        bsr.w   L3c4017e2                       | 3c401580  6100 0260
        moveq   #0x1f,%d5                       | 3c401584  7a1f
        move.w  %d5,%d2                         | 3c401586  3405
        cmpi.w  #1,(.Ld0648-DUMP:w,%a5)                   | 3c401588  0c6d 0001 0648
        bne.w   L3c4016fc                       | 3c40158e  6600 016c
        lea     (L3c401682:w,%pc),%a0             | 3c401592  41fa 00ee
        bsr.w   L3c401692                       | 3c401596  6100 00fa
        move.l  #1,(.Ld065a-DUMP:w,%a5)                   | 3c40159a  2b7c 0000 0001 065a
        bset    #2,(.Ld062e-DUMP:w,%a5)                   | 3c4015a2  08ed 0002 062e
        lea     (0x4004800).l,%a0               | 3c4015a8  41f9 0400 4800
        move.l  %a0,(.Ld0652-DUMP:w,%a5)                  | 3c4015ae  2b48 0652
        lea     (L3c4015e8:w,%pc),%a0             | 3c4015b2  41fa 0034
        bsr.w   L3c401692                       | 3c4015b6  6100 00da
        bsr.w   L3c401666                       | 3c4015ba  6100 00aa
        bra.w   L3c40173a                       | 3c4015be  6000 017a
L3c4015c2:
        movem.l %d0-%d1,-(%a7)                  | 3c4015c2  48e7 c000
        addq.l  #1,(.Ld064a-DUMP:w,%a5)                   | 3c4015c6  52ad 064a
        move.l  %d0,%d1                         | 3c4015ca  2200
        .short  0x92bc, 0x0000, 0x0400        | 3c4015cc  92bc 0000 0400  subl #1024,%d1
        cmp.l   (.Ld065a:w,%pc),%d1             | 3c4015d2  b2ba 0486
        beq.w   L3c4015de                       | 3c4015d6  6700 0006
        addq.l  #1,(.Ld064e-DUMP:w,%a5)                   | 3c4015da  52ad 064e
L3c4015de:
        move.l  %d0,(.Ld065a-DUMP:w,%a5)                  | 3c4015de  2b40 065a
        movem.l (%a7)+,%d0-%d1                  | 3c4015e2  4cdf 0003
        rts                                     | 3c4015e6  4e75
L3c4015e8:
        movem.l %d0-%d1/%a0-%a1,-(%a7)          | 3c4015e8  48e7 c0c0
        movea.l (.Ld0652:w,%pc),%a0             | 3c4015ec  207a 0464
        move.l  (.Ld065a:w,%pc),%d1             | 3c4015f0  223a 0468
        move.l  %d0,(.Ld065a-DUMP:w,%a5)                  | 3c4015f4  2b40 065a
        .short  0xd2bc, 0x0000, 0x0400        | 3c4015f8  d2bc 0000 0400  addl #1024,%d1
        cmp.l   %d0,%d1                         | 3c4015fe  b280
        beq.w   L3c40164a                       | 3c401600  6700 0048
        bclr    #2,(.Ld062e-DUMP:w,%a5)                   | 3c401604  08ad 0002 062e
        bne.w   L3c40162c                       | 3c40160a  6600 0020
        adda.l  #0x10,%a0                       | 3c40160e  d1fc 0000 0010
        move.l  %a0,(.Ld0652-DUMP:w,%a5)                  | 3c401614  2b48 0652
        move.l  %a0,%d1                         | 3c401618  2208
        .short  0xc2bc, 0x0000, 0x03ff        | 3c40161a  c2bc 0000 03ff  andl #1023,%d1
        bne.w   L3c40162c                       | 3c401620  6600 000a
        bsr.w   L3c401666                       | 3c401624  6100 0040
        movea.l (.Ld0652:w,%pc),%a0             | 3c401628  207a 0428
L3c40162c:
        move.l  (.Ld0656:w,%pc),%d1             | 3c40162c  223a 0428
        movea.l %a0,%a1                         | 3c401630  2248
        move.l  %d1,(%a1)+                      | 3c401632  22c1
        .short  0xd2bc, 0x0000, 0x03ff        | 3c401634  d2bc 0000 03ff  addl #1023,%d1
        move.l  %d1,(%a1)+                      | 3c40163a  22c1
        move.l  %d0,(%a1)+                      | 3c40163c  22c0
        .short  0xd0bc, 0x0000, 0x03ff        | 3c40163e  d0bc 0000 03ff  addl #1023,%d0
        move.l  %d0,(%a1)                       | 3c401644  2280
        bra.w   L3c401658                       | 3c401646  6000 0010
L3c40164a:
        move.l  #0x400,%d1                      | 3c40164a  223c 0000 0400
        add.l   %d1,(4,%a0)                     | 3c401650  d3a8 0004
        add.l   %d1,(12,%a0)                    | 3c401654  d3a8 000c
L3c401658:
        addi.l  #0x400,(.Ld0656-DUMP:w,%a5)               | 3c401658  06ad 0000 0400 0656
        movem.l (%a7)+,%d0-%d1/%a0-%a1          | 3c401660  4cdf 0303
        rts                                     | 3c401664  4e75
L3c401666:
        movem.l %d0-%a5,-(%a7)                  | 3c401666  48e7 fffc
        lea     (0x4004800).l,%a0               | 3c40166a  41f9 0400 4800
        move.l  %a0,(.Ld0652-DUMP:w,%a5)                  | 3c401670  2b48 0652
        addq.l  #1,(.Ld05d2-DUMP:w,%a5)                   | 3c401674  52ad 05d2
        bsr.w   L3c4017e2                       | 3c401678  6100 0168
        movem.l (%a7)+,%d0-%a5                  | 3c40167c  4cdf 3fff
        rts                                     | 3c401680  4e75
L3c401682:
        movem.l %d1/%d3/%d7-%a2,-(%a7)          | 3c401682  48e7 51e0
        move.l  %d0,%d7                         | 3c401686  2e00
        bsr.w   L3c401712                       | 3c401688  6100 0088
        movem.l (%a7)+,%d1/%d3/%d7-%a2          | 3c40168c  4cdf 078a
        rts                                     | 3c401690  4e75
L3c401692:
        movem.l %d0-%d4/%a0-%a3,-(%a7)          | 3c401692  48e7 f8f0
        movea.l (DUMP_$SMAP_PHADDR,%pc),%a1     | 3c401696  227a 03c6
        adda.l  #0x800,%a1                      | 3c40169a  d3fc 0000 0800
        clr.l   %d1                             | 3c4016a0  4281
L3c4016a2:
        move.l  (0,%a1,%d1.w),%d4               | 3c4016a2  2831 1000
        .short  0xc8bc, 0x0000, 0x0003        | 3c4016a6  c8bc 0000 0003  andl #3,%d4
        beq.b   L3c4016ee                       | 3c4016ac  6740
        move.l  (4,%a1,%d1.w),%d4               | 3c4016ae  2831 1004
        .short  0xc8bc, 0xffff, 0xfff0        | 3c4016b2  c8bc ffff fff0  andl #-16,%d4
        movea.l %d4,%a2                         | 3c4016b8  2444
        clr.l   %d3                             | 3c4016ba  4283
L3c4016bc:
        move.l  (0,%a2,%d3.w),%d0               | 3c4016bc  2032 3000
        move.l  %d0,%d4                         | 3c4016c0  2800
        .short  0xc8bc, 0x0000, 0x0003        | 3c4016c2  c8bc 0000 0003  andl #3,%d4
        beq.b   L3c4016e6                       | 3c4016c8  671c
        .short  0xc0bc, 0xffff, 0xfc00        | 3c4016ca  c0bc ffff fc00  andl #-1024,%d0
        lea     (.Ld07e4:w,%pc),%a3             | 3c4016d0  47fa 0512
L3c4016d4:
        addq.l  #8,%a3                          | 3c4016d4  508b
        tst.l   (%a3)                           | 3c4016d6  4a93
        beq.b   L3c4016e6                       | 3c4016d8  670c
        cmp.l   (%a3),%d0                       | 3c4016da  b093
        blt.b   L3c4016d4                       | 3c4016dc  6df6
        cmp.l   (4,%a3),%d0                     | 3c4016de  b0ab 0004
        bgt.b   L3c4016d4                       | 3c4016e2  6ef0
        jsr     (%a0)                           | 3c4016e4  4e90
L3c4016e6:
        addq.w  #4,%d3                          | 3c4016e6  5843
        .short  0xb67c, 0x0080                | 3c4016e8  b67c 0080  cmpw #128,%d3
        blt.b   L3c4016bc                       | 3c4016ec  6dce
L3c4016ee:
        addq.w  #8,%d1                          | 3c4016ee  5041
        .short  0xb27c, 0x4000                | 3c4016f0  b27c 4000  cmpw #16384,%d1
        blt.b   L3c4016a2                       | 3c4016f4  6dac
        movem.l (%a7)+,%d0-%d4/%a0-%a3          | 3c4016f6  4cdf 0f1f
        rts                                     | 3c4016fa  4e75
L3c4016fc:
        lea     (DUMP_$ADDRS,%pc),%a3           | 3c4016fc  47fa 04ee
L3c401700:
        move.l  (%a3)+,%d3                      | 3c401700  261b
        beq.b   L3c40173a                       | 3c401702  6736
        move.l  (%a3)+,%d4                      | 3c401704  281b
L3c401706:
        move.l  %d3,%d7                         | 3c401706  2e03
        bsr.w   L3c401712                       | 3c401708  6100 0008
        cmp.l   %d3,%d4                         | 3c40170c  b883
        bge.b   L3c401706                       | 3c40170e  6cf6
        bra.b   L3c401700                       | 3c401710  60ee
L3c401712:
        addq.l  #1,(.Ld05d2-DUMP:w,%a5)                   | 3c401712  52ad 05d2
        bsr.w   L3c4017e2                       | 3c401716  6100 00ca
        dbf     %d5,L3c401732                   | 3c40171a  51cd 0016
        move.b  #0x21,%d1                       | 3c40171e  123c 0021
        bsr.w   L3c40199a                       | 3c401722  6100 0276
        moveq   #0x1f,%d5                       | 3c401726  7a1f
        dbf     %d2,L3c401732                   | 3c401728  51ca 0008
        bsr.w   L3c401970                       | 3c40172c  6100 0242
        move.w  %d5,%d2                         | 3c401730  3405
L3c401732:
        .short  0xd6bc, 0x0000, 0x0400        | 3c401732  d6bc 0000 0400  addl #1024,%d3
        rts                                     | 3c401738  4e75
L3c40173a:
        lea     (.Ld0627:w,%pc),%a0             | 3c40173a  41fa 02eb
        bsr.w   L3c40196e                       | 3c40173e  6100 022e
        cmpi.w  #2,(%fp)                        | 3c401742  0c56 0002
        beq.b   L3c401754                       | 3c401746  670c
        cmpi.w  #6,(%fp)                        | 3c401748  0c56 0006
        beq.b   L3c401754                       | 3c40174c  6706
        cmpi.w  #8,(%fp)                        | 3c40174e  0c56 0008
        bne.b   L3c401760                       | 3c401752  660c
L3c401754:
        moveq   #4,%d0                          | 3c401754  7004
        cmp.b   (.Ld05d1:w,%pc),%d0             | 3c401756  b03a 0279
        beq.b   L3c401760                       | 3c40175a  6704
        bsr.w   L3c4017ec                       | 3c40175c  6100 008e
L3c401760:
        cmpi.w  #5,(%fp)                        | 3c401760  0c56 0005
        bne.b   L3c40176a                       | 3c401764  6604
        bsr.b   L3c4017b4                       | 3c401766  614c
        bsr.b   L3c4017b4                       | 3c401768  614a
L3c40176a:
        tst.b   (54,%fp)                        | 3c40176a  4a2e 0036
        beq.b   L3c40178c                       | 3c40176e  671c
L3c401770:
        move.w  #0x7d0,%d0                      | 3c401770  303c 07d0
L3c401774:
        mulu.w  #3,%d2                          | 3c401774  c4fc 0003
        dbf     %d0,L3c401774                   | 3c401778  51c8 fffa
        reset                                   | 3c40177c  4e70
        movea.l (0x0).w,%sp                     | 3c40177e  2e78 0000
        ori.w   #0x2700,%sr                     | 3c401782  007c 2700
        movea.l (0x4).w,%a0                     | 3c401786  2078 0004
        jmp     (%a0)                           | 3c40178a  4ed0
L3c40178c:
        movea.l (0x11c).w,%a0                   | 3c40178c  2078 011c
        jmp     (%a0)                           | 3c401790  4ed0
DUMP_$AUTO_REBOOT:
        lea     (DUMP,%pc),%a5                  | 3c401792  4bfa fc6c
        lea     (0x4004e00).l,%sp               | 3c401796  4ff9 0400 4e00
        movea.l %sp,%fp                         | 3c40179c  2c4f
        lea     (.Ld05fa:w,%pc),%a0             | 3c40179e  41fa 025a
        bsr.w   L3c40196e                       | 3c4017a2  6100 01ca
        move.w  #0x2000,%d0                     | 3c4017a6  303c 2000
L3c4017aa:
        mulu.w  #3,%d2                          | 3c4017aa  c4fc 0003
        dbf     %d0,L3c4017aa                   | 3c4017ae  51c8 fffa
        bra.b   L3c401770                       | 3c4017b2  60bc
L3c4017b4:
        cmpi.w  #5,(%fp)                        | 3c4017b4  0c56 0005
        bne.b   L3c4017e0                       | 3c4017b8  6626
        pea     (16,%fp)                        | 3c4017ba  486e 0010
        clr.l   (26,%fp)                        | 3c4017be  42ae 001a
        pea     (12,%fp)                        | 3c4017c2  486e 000c
        pea     (26,%fp)                        | 3c4017c6  486e 001a
        pea     (26,%fp)                        | 3c4017ca  486e 001a
        move.l  (8,%fp),-(%sp)                  | 3c4017ce  2f2e 0008
        movea.l (4,%fp),%a0                     | 3c4017d2  206e 0004
        movea.l (100,%a0),%a0                   | 3c4017d6  2068 0064
        jsr     (%a0)                           | 3c4017da  4e90
        adda.w  #0x14,%sp                       | 3c4017dc  defc 0014
L3c4017e0:
        rts                                     | 3c4017e0  4e75
L3c4017e2:
        movem.l %d0-%d7/%a1-%a4,-(%a7)          | 3c4017e2  48e7 ff78
        moveq   #2,%d0                          | 3c4017e6  7002
        move.l  %d6,%d1                         | 3c4017e8  2206
        bra.b   L3c4017f4                       | 3c4017ea  6008
L3c4017ec:
        movem.l %d0-%d7/%a1-%a4,-(%a7)          | 3c4017ec  48e7 ff78
        clr.w   %d1                             | 3c4017f0  4241
        move.l  %a5,%d7                         | 3c4017f2  2e0d
L3c4017f4:
        move.w  %d1,(.Ld05be-DUMP:w,%a5)                  | 3c4017f4  3b41 05be
        move.b  %d0,(.Ld05d1-DUMP:w,%a5)                  | 3c4017f8  1b40 05d1
        move.l  %d7,(22,%fp)                    | 3c4017fc  2d47 0016
        move.w  #0xa,(20,%fp)                   | 3c401800  3d7c 000a 0014
L3c401806:
        clr.l   %d4                             | 3c401806  4284
        cmpi.w  #5,(%fp)                        | 3c401808  0c56 0005
        bne.b   L3c401864                       | 3c40180c  6656
        move.l  #0x400,(30,%fp)                 | 3c40180e  2d7c 0000 0400 001e
L3c401816:
        move.l  (30,%fp),(26,%fp)               | 3c401816  2d6e 001e 001a
        pea     (16,%fp)                        | 3c40181c  486e 0010
        pea     (12,%fp)                        | 3c401820  486e 000c
        pea     (26,%fp)                        | 3c401824  486e 001a
        pea     (22,%fp)                        | 3c401828  486e 0016
        move.l  (8,%fp),-(%sp)                  | 3c40182c  2f2e 0008
        movea.l (4,%fp),%a0                     | 3c401830  206e 0004
        movea.l (100,%a0),%a0                   | 3c401834  2068 0064
        jsr     (%a0)                           | 3c401838  4e90
        adda.w  #0x14,%sp                       | 3c40183a  defc 0014
        move.l  (16,%fp),%d0                    | 3c40183e  202e 0010
        bne.b   L3c40189c                       | 3c401842  6658
        move.l  (22,%fp),%d0                    | 3c401844  202e 0016
        add.l   (26,%fp),%d0                    | 3c401848  d0ae 001a
        move.l  %d0,(22,%fp)                    | 3c40184c  2d40 0016
        move.l  (30,%fp),%d0                    | 3c401850  202e 001e
        sub.l   (26,%fp),%d0                    | 3c401854  90ae 001a
        move.l  %d0,(30,%fp)                    | 3c401858  2d40 001e
        bgt.b   L3c401816                       | 3c40185c  6eb8
        clr.l   %d0                             | 3c40185e  4280
        bra.w   L3c4018a4                       | 3c401860  6000 0042
L3c401864:
        lea     (.Ld05aa:w,%pc),%a0             | 3c401864  41fa 0144
        move.l  %a0,(26,%fp)                    | 3c401868  2d48 001a
        pea     (16,%fp)                        | 3c40186c  486e 0010
        pea     (12,%fp)                        | 3c401870  486e 000c
        pea     (22,%fp)                        | 3c401874  486e 0016
        pea     (26,%fp)                        | 3c401878  486e 001a
        move.l  (8,%fp),-(%sp)                  | 3c40187c  2f2e 0008
        movea.l (4,%fp),%a0                     | 3c401880  206e 0004
        movea.l (76,%a0),%a0                    | 3c401884  2068 004c
        jsr     (%a0)                           | 3c401888  4e90
        adda.w  #0x14,%sp                       | 3c40188a  defc 0014
        move.l  (16,%fp),%d0                    | 3c40188e  202e 0010
        beq.b   L3c4018aa                       | 3c401892  6716
        subq.w  #1,(20,%fp)                     | 3c401894  536e 0014
        bne.w   L3c401806                       | 3c401898  6600 ff6c
L3c40189c:
        lea     (.Ld05da:w,%pc),%a0             | 3c40189c  41fa 013c
        bra.w   L3c40195e                       | 3c4018a0  6000 00bc
L3c4018a4:
        movem.l (%a7)+,%d0-%d7/%a1-%a4          | 3c4018a4  4cdf 1eff
        rts                                     | 3c4018a8  4e75
L3c4018aa:
        cmpi.w  #5,(%fp)                        | 3c4018aa  0c56 0005
        beq.b   L3c4018a4                       | 3c4018ae  67f4
L3c4018b0:
        move.w  #3,(20,%fp)                     | 3c4018b0  3d7c 0003 0014
        pea     (16,%fp)                        | 3c4018b6  486e 0010
        pea     (12,%fp)                        | 3c4018ba  486e 000c
        pea     (.Ld05d6:w,%pc)                 | 3c4018be  487a 0116
        move.l  #0x4004e38,(26,%fp)             | 3c4018c2  2d7c 0400 4e38 001a
        pea     (26,%fp)                        | 3c4018ca  486e 001a
        move.l  (8,%fp),-(%sp)                  | 3c4018ce  2f2e 0008
        movea.l (4,%fp),%a0                     | 3c4018d2  206e 0004
        movea.l (80,%a0),%a0                    | 3c4018d6  2068 0050
        jsr     (%a0)                           | 3c4018da  4e90
        adda.w  #0x14,%sp                       | 3c4018dc  defc 0014
        move.l  (16,%fp),%d0                    | 3c4018e0  202e 0010
        beq.b   L3c4018f4                       | 3c4018e4  670e
        subq.w  #1,(20,%fp)                     | 3c4018e6  536e 0014
        bne.w   L3c401806                       | 3c4018ea  6600 ff1a
        lea     (.Ld05df:w,%pc),%a0             | 3c4018ee  41fa 00ef
        bra.b   L3c40195e                       | 3c4018f2  606a
L3c4018f4:
        lea     (56,%fp),%a0                    | 3c4018f4  41ee 0038
        move.l  (.Ld05aa:w,%pc),%d0             | 3c4018f8  203a 00b0
        cmp.l   (8,%a0),%d0                     | 3c4018fc  b0a8 0008
        bne.b   L3c4018b0                       | 3c401900  66ae
        lea     (30,%a0),%a1                    | 3c401902  43e8 001e
        clr.l   %d0                             | 3c401906  4280
        move.b  (24,%a0),%d0                    | 3c401908  1028 0018
        adda.l  %d0,%a1                         | 3c40190c  d3c0
        move.l  %a1,(50,%fp)                    | 3c40190e  2d49 0032
        cmpi.w  #2,(%a1)                        | 3c401912  0c51 0002
        bne.b   L3c40192c                       | 3c401916  6614
        cmpi.w  #1,(2,%a1)                      | 3c401918  0c69 0001 0002
        bne.b   L3c40192c                       | 3c40191e  660c
        move.b  (5,%a1),%d0                     | 3c401920  1029 0005
        subq.l  #1,%d0                          | 3c401924  5380
        cmp.b   (.Ld05d1:w,%pc),%d0             | 3c401926  b03a 00a9
        beq.b   L3c401942                       | 3c40192a  6716
L3c40192c:
        cmpi.b  #7,(5,%a1)                      | 3c40192c  0c29 0007 0005
        bne.b   L3c401938                       | 3c401932  6604
L3c401934:
        bra.w   L3c4018b0                       | 3c401934  6000 ff7a
L3c401938:
        lea     (.Ld05e4:w,%pc),%a0             | 3c401938  41fa 00aa
        bsr.b   L3c401974                       | 3c40193c  6136
L3c40193e:
        bra.w   L3c401754                       | 3c40193e  6000 fe14
L3c401942:
        .short  0xb03c, 0x0002                | 3c401942  b03c 0002  cmpb #2,%d0
        bne.b   L3c401952                       | 3c401946  660a
        move.l  (.Ld05d2:w,%pc),%d0             | 3c401948  203a 0088
        cmp.l   (12,%a1),%d0                    | 3c40194c  b0a9 000c
        bne.b   L3c401934                       | 3c401950  66e2
L3c401952:
        move.l  (6,%a1),%d0                     | 3c401952  2029 0006
        beq.w   L3c4018a4                       | 3c401956  6700 ff4c
        lea     (.Ld05ec:w,%pc),%a0             | 3c40195a  41fa 0090
L3c40195e:
        move.l  %d0,-(%sp)                      | 3c40195e  2f00
        bsr.b   L3c401974                       | 3c401960  6112
        lea     (.Ld05f3:w,%pc),%a0             | 3c401962  41fa 008f
        bsr.b   L3c401974                       | 3c401966  610c
        move.l  (%sp)+,%d0                      | 3c401968  201f
        bsr.b   L3c40197e                       | 3c40196a  6112
        bra.b   L3c40193e                       | 3c40196c  60d0
L3c40196e:
        bsr.b   L3c401974                       | 3c40196e  6104
L3c401970:
        lea     (.Ld0624:w,%pc),%a0             | 3c401970  41fa 00b2
L3c401974:
        move.b  (%a0)+,%d1                      | 3c401974  1218
        beq.b   L3c4019a8                       | 3c401976  6730
        bsr.b   L3c40199a                       | 3c401978  6120
        bra.b   L3c401974                       | 3c40197a  60f8
        rts                                     | 3c40197c  4e75
L3c40197e:
        moveq   #7,%d2                          | 3c40197e  7407
L3c401980:
        rol.l   #4,%d0                          | 3c401980  e998
        moveq   #0xf,%d1                        | 3c401982  720f
        and.b   %d0,%d1                         | 3c401984  c200
        .short  0xb23c, 0x000a                | 3c401986  b23c 000a  cmpb #10,%d1
        blt.b   L3c40198e                       | 3c40198a  6d02
        addq.b  #7,%d1                          | 3c40198c  5e01
L3c40198e:
        .short  0xd23c, 0x0030                | 3c40198e  d23c 0030  addb #48,%d1
        bsr.b   L3c40199a                       | 3c401992  6106
        dbf     %d2,L3c401980                   | 3c401994  51ca ffea
        bra.b   L3c401970                       | 3c401998  60d6
L3c40199a:
        movem.l %d0-%a4,-(%a7)                  | 3c40199a  48e7 fff8
        movea.l (0x108).w,%a0                   | 3c40199e  2078 0108
        jsr     (%a0)                           | 3c4019a2  4e90
        movem.l (%a7)+,%d0-%a4                  | 3c4019a4  4cdf 1fff
L3c4019a8:
        rts                                     | 3c4019a8  4e75
.Ld05aa:
        .byte   0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00       | 3c4019aa
        .byte   0x00,0x00,0x00,0x00,0x01,0x01,0x00,0x00       | 3c4019b2
        .byte   0x00,0x2c,0x00,0x0a                           | 3c4019ba
.Ld05be:
        .byte   0x00,0x00,0x00,0x00,0x04,0x01,0x00,0x00       | 3c4019be
        .byte   0x00,0x00,0x00,0x00,0x00,0x03,0x00,0x02       | 3c4019c6
        .byte   0x00,0x01,0x09                                | 3c4019ce
.Ld05d1:
        .byte   0x00                                          | 3c4019d1
.Ld05d2:
        .byte   0x00,0x00,0x00,0x00                           | 3c4019d2
.Ld05d6:
        .byte   0x04,0x00,0x00,0x00                           | 3c4019d6
.Ld05da:
        .byte   0x58,0x62,0x61,0x64,0x00                      | 3c4019da
.Ld05df:
        .byte   0x52,0x62,0x61,0x64,0x00                      | 3c4019df
.Ld05e4:
        .byte   0x42,0x61,0x64,0x20,0x72,0x70,0x79,0x00       | 3c4019e4
.Ld05ec:
        .byte   0x4e,0x6d,0x20,0x73,0x61,0x64,0x00            | 3c4019ec
.Ld05f3:
        .byte   0x20,0x2d,0x20,0x53,0x74,0x3d,0x00            | 3c4019f3
.Ld05fa:
        .byte   0x52,0x45,0x42,0x4f,0x4f,0x54,0x49,0x4e       | 3c4019fa
        .byte   0x47,0x00                                     | 3c401a02
.Ld0604:
        .byte   0x43,0x61,0x6e,0x6e,0x6f,0x74,0x20,0x64       | 3c401a04
        .byte   0x75,0x6d,0x70,0x20,0x74,0x6f,0x20,0x74       | 3c401a0c
        .byte   0x68,0x69,0x73,0x20,0x64,0x65,0x76,0x69       | 3c401a14
        .byte   0x63,0x65,0x20,0x74,0x79,0x70,0x65,0x00       | 3c401a1c
.Ld0624:
        .byte   0x0a,0x0d,0x00                                | 3c401a24
.Ld0627:
        .byte   0x0a,0x0d,0x44,0x6f,0x6e,0x65,0x00            | 3c401a27
.Ld062e:
        .byte   0x00                                          | 3c401a2e
.Ld062f:
        .byte   0x44,0x75,0x6d,0x70,0x69,0x6e,0x67,0x20       | 3c401a2f
        .byte   0x67,0x6c,0x6f,0x62,0x61,0x6c,0x5f,0x62       | 3c401a37
        .byte   0x20,0x6f,0x6e,0x6c,0x79,0x2e,0x0a,0x0d       | 3c401a3f
        .byte   0x00                                          | 3c401a47
.Ld0648:
        .byte   0x00                                          | 3c401a48
.Ld0649:
        .byte   0x00                                          | 3c401a49
.Ld064a:
        .byte   0x00,0x00,0x00,0x00                           | 3c401a4a
.Ld064e:
        .byte   0x00,0x00,0x00,0x00                           | 3c401a4e
.Ld0652:
        .byte   0x00,0x00,0x00,0x00                           | 3c401a52
.Ld0656:
        .byte   0x00,0x00,0x00,0x00                           | 3c401a56
.Ld065a:
        .byte   0x00,0x00,0x00,0x00                           | 3c401a5a
DUMP_$SMAP_PHADDR:
        .space  384                                           | 3c401a5e
        .byte   0x00,0x00,0x00,0x00,0x00,0x00                 | 3c401bde
.Ld07e4:
        .byte   0x00,0x00,0x00,0x00                           | 3c401be4
DUMP_$RARS_PHADDR:
        .byte   0x00,0x00,0x00,0x00                           | 3c401be8
DUMP_$ADDRS:
        .byte   0x04,0x00,0x00,0x00,0x04,0x07,0xfc,0x00       | 3c401bec
        .byte   0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00       | 3c401bf4
        .byte   0x00,0x00,0x00,0x00                           | 3c401bfc
