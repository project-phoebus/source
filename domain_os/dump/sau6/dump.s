|
| dump/sau6/dump.s - the DUMP page (SAU6): the crash-dump code and its
| cells
|
| The SAU6's DUMP page, transcribed from the SAU6 image file (file
| 0x800..0x1000, VA 0x78000800).  The SAU6 map:
|
|   D2378000800  DUMP               loaded at 101F400, size = 800
|   D  78000800  DUMP               size = 800
|      78000800  DUMP
|      78000BC2  DUMP_$AUTO_REBOOT
|      78000E1E  DUMP_$SMAP_PHADDR
|      78000FE8  DUMP_$RARS_PHADDR
|      78000FEC  DUMP_$ADDRS
|
| The SAU8's form (dump/sau8/dump.s; dump/sau2/dump.s describes the dump
| protocol) for the DN5xxT: entered by the PROM with the MMU off, it runs
| at its physical home and reaches the kernel's cells by physical
| address (dump_kernel_phys: VA - OS_PROC + 0x101FC00, the kernel's
| first page as loaded): CRASH_STATUS, SERVER_$FLAG, WIN_$DT.  Its stack
| is physical 0x1020600 and its packet buffer 0x1020000.  Against the
| SAU8's:
|   - the first entry saves the word at physical 0x8002 in the frame,
|     and with bit 6 of physical 0x8003 and SERVER_$FLAG set the reply's
|     flag byte decides the reboot (bit 6) and the dump (bit 7);
|   - the tables sent first carry the second Winchester board's command
|     blocks when WIN_$DT's bus address is set (8 pages, tagged `IOPB',
|     0x2400 bytes), and no MMU state (the DN5xxT has no MC68851);
|   - the global segment maps walked are DUMP_$SMAP_PHADDR's + 0x400
|     (0x4000 bytes), then the page at physical 0x101E800;
|   - DUMP_$ADDRS lists one range, physical 0x1000000..0x107FC00.
| DUMP_$AUTO_REBOOT is the entry CRASH_SYSTEM's restart hands the PROM;
| DUMP_$SMAP_PHADDR and DUMP_$RARS_PHADDR the tables' physical addresses
| (OS_$INIT).  The strings are the console's messages.
|
| One section; its cells are reached off A5 = DUMP (`lea (d,PC),A5') with
| the image's displacements and PC-relatively.  The labels without a map
| name keep the image address they stand at, but for the SAU8's names.
| The Apollo assembler's <ea>=#imm forms (cmp/add/sub/and #imm,Dn), which
| gas spells cmpi/addi/subi/andi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau6 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU6 image's.
|
        .section ".text.DUMP","ax",@progbits
        .even

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

DUMP:
        move.l  %d0,%d7                         | sau6 78000800  2e00
        bra.s   dump_check_magic                | sau6 78000802  600e
        moveq   #2,%d7                          | sau6 78000804  7e02
        bra.s   dump_start_2_0                  | sau6 78000806  6006
        moveq   #2,%d7                          | sau6 78000808  7e02
        moveq   #1,%d6                          | sau6 7800080a  7c01
        bra.s   dump_common                     | sau6 7800080c  6028
dump_start_2_0:
        moveq   #0,%d6                          | sau6 7800080e  7c00
        bra.s   dump_common                     | sau6 78000810  6024
dump_check_magic:
        swap    %d0                             | sau6 78000812  4840
        .short  0xb07c, 0x0ace                  | sau6 78000814  b07c 0ace  cmp.w   #0xace,%d0
        beq.s   .L7800081c                      | sau6 78000818  6702
        moveq   #5,%d7                          | sau6 7800081a  7e05
.L7800081c:
        moveq   #0,%d6                          | sau6 7800081c  7c00
        swap    %d1                             | sau6 7800081e  4841
        .short  0xb27c, 0x0ace                  | sau6 78000820  b27c 0ace  cmp.w   #0xace,%d1
        bne.s   dump_common                     | sau6 78000824  6610
        clr.w   %d1                             | sau6 78000826  4241
        swap    %d1                             | sau6 78000828  4841
        move.l  %d1,%d6                         | sau6 7800082a  2c01
        btst    #7,%d2                          | sau6 7800082c  0802 0007
        bne.s   dump_common                     | sau6 78000830  6604
        .short  0xcc7c, 0x00ff                  | sau6 78000832  cc7c 00ff  and.w   #0xff,%d6
dump_common:
        lea     (DUMP:w,%pc),%a5                | sau6 78000836  4bfa ffc8
        lea     (0x1020600).l,%sp               | sau6 7800083a  4ff9 0102 0600
        movea.l %sp,%fp                         | sau6 78000840  2c4f
        clr.w   (0x608,%a5)                     | sau6 78000842  426d 0608
        move.b  %d6,(0x609,%a5)                 | sau6 78000846  1b46 0609
        lsr.w   #8,%d6                          | sau6 7800084a  e04e
        move.w  %d6,(0x2,%fp)                   | sau6 7800084c  3d46 0002
        move.l  #0x400,%d6                      | sau6 78000850  2c3c 0000 0400
        bset    #0,(0x5ee,%a5)                  | sau6 78000856  08ed 0000 05ee
        bne.s   .L78000866                      | sau6 7800085c  6608
        move.w  (0x8002).l,(0xe,%fp)            | sau6 7800085e  3d79 0000 8002 000e
.L78000866:
        move.w  %d7,(%fp)                       | sau6 78000866  3c87
        move.w  #0,-(%sp)                       | sau6 78000868  3f3c 0000
        pea     (%sp)                           | sau6 7800086c  4857
        move.l  #0x600df1a6,(0x4,%fp)           | sau6 7800086e  2d7c 600d f1a6 0004
        pea     (0x4,%fp)                       | sau6 78000876  486e 0004
        pea     (0x2,%fp)                       | sau6 7800087a  486e 0002
        pea     (%fp)                           | sau6 7800087e  4856
        movea.l (0x10c).w,%a0                   | sau6 78000880  2078 010c
        jsr     (%a0)                           | sau6 78000884  4e90
        adda.w  #0x12,%sp                       | sau6 78000886  defc 0012
        lea     (0x1020600).l,%fp               | sau6 7800088a  4df9 0102 0600
        clr.b   (0x20,%fp)                      | sau6 78000890  422e 0020
        cmpi.w  #2,(%fp)                        | sau6 78000894  0c56 0002
        beq.s   .L780008a6                      | sau6 78000898  670c
        cmpi.w  #6,(%fp)                        | sau6 7800089a  0c56 0006
        beq.s   .L780008a6                      | sau6 7800089e  6706
        cmpi.w  #8,(%fp)                        | sau6 780008a0  0c56 0008
        bne.s   .L780008f6                      | sau6 780008a4  6650
.L780008a6:
        lea     (CRASH_STATUS).l,%a3            | sau6 780008a6  47f9 7802 0ee2
        bsr.w   dump_kernel_phys                | sau6 780008ac  6100 04c4
        move.l  (%a3),(0x5b4,%a5)               | sau6 780008b0  2b53 05b4
        moveq   #0,%d0                          | sau6 780008b4  7000
        bsr.w   dump_send_page0                 | sau6 780008b6  6100 033a
        btst    #6,(0x8003).l                   | sau6 780008ba  0839 0006 0000 8003
        beq.s   .L780008ea                      | sau6 780008c2  6726
        lea     (SERVER_$FLAG).l,%a3            | sau6 780008c4  47f9 7802 0ef9
        bsr.w   dump_kernel_phys                | sau6 780008ca  6100 04a6
        tst.b   (%a3)                           | sau6 780008ce  4a13
        beq.s   .L780008ea                      | sau6 780008d0  6718
        movea.l (0x1c,%fp),%a1                  | sau6 780008d2  226e 001c
        btst    #6,(0xa,%a1)                    | sau6 780008d6  0829 0006 000a
        st      (0x20,%fp)                      | sau6 780008dc  50ee 0020
        btst    #7,(0xa,%a1)                    | sau6 780008e0  0829 0007 000a
        beq.w   .L78000b92                      | sau6 780008e6  6700 02aa
.L780008ea:
        movea.l (0x1c,%fp),%a1                  | sau6 780008ea  226e 001c
        lea     (0xc,%a1),%a0                   | sau6 780008ee  41e9 000c
        bsr.w   dump_puts                       | sau6 780008f2  6100 0448
.L780008f6:
        lea     (WIN_$DT).l,%a3                 | sau6 780008f6  47f9 7802 fac8
        bsr.w   dump_kernel_phys                | sau6 780008fc  6100 0474
        move.l  (0x4,%a3),(0x90,%fp)            | sau6 78000900  2d6b 0004 0090
        lea     (0x1020000).l,%a4               | sau6 78000906  49f9 0102 0000
        move.l  %a4,%d7                         | sau6 7800090c  2e0c
        move.w  (0xe,%fp),(%a4)+                | sau6 7800090e  38ee 000e
        move.w  #6,(%a4)+                       | sau6 78000912  38fc 0006
        move.l  (0x8004).l,(%a4)+               | sau6 78000916  28f9 0000 8004
        move.w  (0x8012).l,(%a4)+               | sau6 7800091c  38f9 0000 8012
        move.l  (0x8018).l,(%a4)+               | sau6 78000922  28f9 0000 8018
        move.l  (0x801c).l,(%a4)+               | sau6 78000928  28f9 0000 801c
        clr.l   %d0                             | sau6 7800092e  4280
        move.l  #0x400,%d1                      | sau6 78000930  223c 0000 0400
        tst.l   (0x90,%fp)                      | sau6 78000936  4aae 0090
        beq.s   .L78000948                      | sau6 7800093a  670c
        move.l  #0x494f5042,%d0                 | sau6 7800093c  203c 494f 5042
        move.l  #0x2400,%d1                     | sau6 78000942  223c 0000 2400
.L78000948:
        move.l  %d0,(%a4)+                      | sau6 78000948  28c0
        move.l  %d1,(0x616,%a5)                 | sau6 7800094a  2b41 0616
        clr.l   %d0                             | sau6 7800094e  4280
        cmpi.w  #1,(0x608,%a5)                  | sau6 78000950  0c6d 0001 0608
        bne.s   .L7800098a                      | sau6 78000956  6632
        lea     (.L78000def:w,%pc),%a0          | sau6 78000958  41fa 0495
        bsr.w   dump_puts                       | sau6 7800095c  6100 03de
        move.l  #0x47424c42,%d0                 | sau6 78000960  203c 4742 4c42
        move.l  #1,(0x61a,%a5)                  | sau6 78000966  2b7c 0000 0001 061a
        clr.l   (0x60a,%a5)                     | sau6 7800096e  42ad 060a
        clr.l   (0x60e,%a5)                     | sau6 78000972  42ad 060e
        lea     (.L78000a04:w,%pc),%a0          | sau6 78000976  41fa 008c
        bsr.w   dump_walk_tables                | sau6 7800097a  6100 0158
        move.l  (.L78000e0a:w,%pc),(0x4,%a4)    | sau6 7800097e  297a 048a 0004
        move.l  (.L78000e0e:w,%pc),(0x8,%a4)    | sau6 78000984  297a 0488 0008
.L7800098a:
        move.l  %d0,(%a4)                       | sau6 7800098a  2880
        adda.l  #0xc,%a4                        | sau6 7800098c  d9fc 0000 000c
        clr.l   (0x5b4,%a5)                     | sau6 78000992  42ad 05b4
        bsr.w   dump_send_page                  | sau6 78000996  6100 0250
        tst.l   (0x90,%fp)                      | sau6 7800099a  4aae 0090
        beq.s   .L780009c6                      | sau6 7800099e  6726
        movea.l (0x90,%fp),%a2                  | sau6 780009a0  246e 0090
        move.w  #7,%d5                          | sau6 780009a4  3a3c 0007
.L780009a8:
        move.w  #0xff,%d4                       | sau6 780009a8  383c 00ff
        lea     (0x1020000).l,%a4               | sau6 780009ac  49f9 0102 0000
        move.l  %a4,%d7                         | sau6 780009b2  2e0c
.L780009b4:
        move.l  (%a2)+,(%a4)+                   | sau6 780009b4  28da
        dbf     %d4,.L780009b4                  | sau6 780009b6  51cc fffc
        addq.l  #1,(0x5b4,%a5)                  | sau6 780009ba  52ad 05b4
        bsr.w   dump_send_page                  | sau6 780009be  6100 0228
        dbf     %d5,.L780009a8                  | sau6 780009c2  51cd ffe4
.L780009c6:
        moveq   #0x1f,%d5                       | sau6 780009c6  7a1f
        move.w  %d5,%d2                         | sau6 780009c8  3405
        cmpi.w  #1,(0x608,%a5)                  | sau6 780009ca  0c6d 0001 0608
        bne.w   .L78000b3a                      | sau6 780009d0  6600 0168
        lea     (.L78000ac4:w,%pc),%a0          | sau6 780009d4  41fa 00ee
        bsr.w   dump_walk_tables                | sau6 780009d8  6100 00fa
        move.l  #1,(0x61a,%a5)                  | sau6 780009dc  2b7c 0000 0001 061a
        bset    #2,(0x5ee,%a5)                  | sau6 780009e4  08ed 0002 05ee
        lea     (0x1020000).l,%a0               | sau6 780009ea  41f9 0102 0000
        move.l  %a0,(0x612,%a5)                 | sau6 780009f0  2b48 0612
        lea     (.L78000a2a:w,%pc),%a0          | sau6 780009f4  41fa 0034
        bsr.w   dump_walk_tables                | sau6 780009f8  6100 00da
        bsr.w   .L78000aa8                      | sau6 780009fc  6100 00aa
        bra.w   .L78000b78                      | sau6 78000a00  6000 0176
.L78000a04:
        movem.l %d0-%d1,-(%sp)                  | sau6 78000a04  48e7 c000
        addq.l  #1,(0x60a,%a5)                  | sau6 78000a08  52ad 060a
        move.l  %d0,%d1                         | sau6 78000a0c  2200
        .short  0x92bc, 0x0000, 0x0400          | sau6 78000a0e  92bc 0000 0400  sub.l   #0x400,%d1
        cmp.l   (.L78000e1a:w,%pc),%d1          | sau6 78000a14  b2ba 0404
        beq.w   .L78000a20                      | sau6 78000a18  6700 0006
        addq.l  #1,(0x60e,%a5)                  | sau6 78000a1c  52ad 060e
.L78000a20:
        move.l  %d0,(0x61a,%a5)                 | sau6 78000a20  2b40 061a
        movem.l (%sp)+,%d0-%d1                  | sau6 78000a24  4cdf 0003
        rts                                     | sau6 78000a28  4e75
.L78000a2a:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | sau6 78000a2a  48e7 c0c0
        movea.l (.L78000e12:w,%pc),%a0          | sau6 78000a2e  207a 03e2
        move.l  (.L78000e1a:w,%pc),%d1          | sau6 78000a32  223a 03e6
        move.l  %d0,(0x61a,%a5)                 | sau6 78000a36  2b40 061a
        .short  0xd2bc, 0x0000, 0x0400          | sau6 78000a3a  d2bc 0000 0400  add.l   #0x400,%d1
        cmp.l   %d0,%d1                         | sau6 78000a40  b280
        beq.w   .L78000a8c                      | sau6 78000a42  6700 0048
        bclr    #2,(0x5ee,%a5)                  | sau6 78000a46  08ad 0002 05ee
        bne.w   .L78000a6e                      | sau6 78000a4c  6600 0020
        adda.l  #0x10,%a0                       | sau6 78000a50  d1fc 0000 0010
        move.l  %a0,(0x612,%a5)                 | sau6 78000a56  2b48 0612
        move.l  %a0,%d1                         | sau6 78000a5a  2208
        .short  0xc2bc, 0x0000, 0x03ff          | sau6 78000a5c  c2bc 0000 03ff  and.l   #0x3ff,%d1
        bne.w   .L78000a6e                      | sau6 78000a62  6600 000a
        bsr.w   .L78000aa8                      | sau6 78000a66  6100 0040
        movea.l (.L78000e12:w,%pc),%a0          | sau6 78000a6a  207a 03a6
.L78000a6e:
        move.l  (.L78000e16:w,%pc),%d1          | sau6 78000a6e  223a 03a6
        movea.l %a0,%a1                         | sau6 78000a72  2248
        move.l  %d1,(%a1)+                      | sau6 78000a74  22c1
        .short  0xd2bc, 0x0000, 0x03ff          | sau6 78000a76  d2bc 0000 03ff  add.l   #0x3ff,%d1
        move.l  %d1,(%a1)+                      | sau6 78000a7c  22c1
        move.l  %d0,(%a1)+                      | sau6 78000a7e  22c0
        .short  0xd0bc, 0x0000, 0x03ff          | sau6 78000a80  d0bc 0000 03ff  add.l   #0x3ff,%d0
        move.l  %d0,(%a1)                       | sau6 78000a86  2280
        bra.w   .L78000a9a                      | sau6 78000a88  6000 0010
.L78000a8c:
        move.l  #0x400,%d1                      | sau6 78000a8c  223c 0000 0400
        add.l   %d1,(0x4,%a0)                   | sau6 78000a92  d3a8 0004
        add.l   %d1,(0xc,%a0)                   | sau6 78000a96  d3a8 000c
.L78000a9a:
        addi.l  #0x400,(0x616,%a5)              | sau6 78000a9a  06ad 0000 0400 0616
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | sau6 78000aa2  4cdf 0303
        rts                                     | sau6 78000aa6  4e75
.L78000aa8:
        movem.l %d0-%a5,-(%sp)                  | sau6 78000aa8  48e7 fffc
        lea     (0x1020000).l,%a0               | sau6 78000aac  41f9 0102 0000
        move.l  %a0,(0x612,%a5)                 | sau6 78000ab2  2b48 0612
        addq.l  #1,(0x5b4,%a5)                  | sau6 78000ab6  52ad 05b4
        bsr.w   dump_send_page                  | sau6 78000aba  6100 012c
        movem.l (%sp)+,%d0-%a5                  | sau6 78000abe  4cdf 3fff
        rts                                     | sau6 78000ac2  4e75
.L78000ac4:
        movem.l %d1/%d3/%d7-%a2,-(%sp)          | sau6 78000ac4  48e7 51e0
        move.l  %d0,%d7                         | sau6 78000ac8  2e00
        bsr.w   .L78000b50                      | sau6 78000aca  6100 0084
        movem.l (%sp)+,%d1/%d3/%d7-%a2          | sau6 78000ace  4cdf 078a
        rts                                     | sau6 78000ad2  4e75
dump_walk_tables:
        movem.l %d0-%d4/%a0-%a3,-(%sp)          | sau6 78000ad4  48e7 f8f0
        movea.l (DUMP_$SMAP_PHADDR:w,%pc),%a1   | sau6 78000ad8  227a 0344
        adda.l  #0x400,%a1                      | sau6 78000adc  d3fc 0000 0400
        clr.l   %d1                             | sau6 78000ae2  4281
.L78000ae4:
        move.l  (0x0,%a1,%d1.w),%d4             | sau6 78000ae4  2831 1000
        btst    #0x1f,%d4                       | sau6 78000ae8  0804 001f
        beq.s   .L78000b24                      | sau6 78000aec  6736
        movea.l %d4,%a2                         | sau6 78000aee  2444
        clr.l   %d3                             | sau6 78000af0  4283
.L78000af2:
        move.l  (0x0,%a2,%d3.w),%d0             | sau6 78000af2  2032 3000
        btst    #0x1f,%d0                       | sau6 78000af6  0800 001f
        beq.s   .L78000b1c                      | sau6 78000afa  6720
        .short  0xc0bc, 0x0000, 0xffff          | sau6 78000afc  c0bc 0000 ffff  and.l   #0xffff,%d0
        lsl.l   #8,%d0                          | sau6 78000b02  e188
        lsl.l   #2,%d0                          | sau6 78000b04  e588
        lea     (dump_ranges:w,%pc),%a3         | sau6 78000b06  47fa 04dc
.L78000b0a:
        addq.l  #8,%a3                          | sau6 78000b0a  508b
        tst.l   (%a3)                           | sau6 78000b0c  4a93
        beq.s   .L78000b1c                      | sau6 78000b0e  670c
        cmp.l   (%a3),%d0                       | sau6 78000b10  b093
        blt.s   .L78000b0a                      | sau6 78000b12  6df6
        cmp.l   (0x4,%a3),%d0                   | sau6 78000b14  b0ab 0004
        bgt.s   .L78000b0a                      | sau6 78000b18  6ef0
        jsr     (%a0)                           | sau6 78000b1a  4e90
.L78000b1c:
        addq.w  #4,%d3                          | sau6 78000b1c  5843
        .short  0xb67c, 0x0080                  | sau6 78000b1e  b67c 0080  cmp.w   #0x80,%d3
        blt.s   .L78000af2                      | sau6 78000b22  6dce
.L78000b24:
        addq.w  #4,%d1                          | sau6 78000b24  5841
        .short  0xb27c, 0x4000                  | sau6 78000b26  b27c 4000  cmp.w   #0x4000,%d1
        blt.s   .L78000ae4                      | sau6 78000b2a  6db8
        move.l  #0x101e800,%d0                  | sau6 78000b2c  203c 0101 e800
        jsr     (%a0)                           | sau6 78000b32  4e90
        movem.l (%sp)+,%d0-%d4/%a0-%a3          | sau6 78000b34  4cdf 0f1f
        rts                                     | sau6 78000b38  4e75
.L78000b3a:
        lea     (DUMP_$ADDRS:w,%pc),%a3         | sau6 78000b3a  47fa 04b0
.L78000b3e:
        move.l  (%a3)+,%d3                      | sau6 78000b3e  261b
        beq.s   .L78000b78                      | sau6 78000b40  6736
        move.l  (%a3)+,%d4                      | sau6 78000b42  281b
.L78000b44:
        move.l  %d3,%d7                         | sau6 78000b44  2e03
        bsr.w   .L78000b50                      | sau6 78000b46  6100 0008
        cmp.l   %d3,%d4                         | sau6 78000b4a  b883
        bge.s   .L78000b44                      | sau6 78000b4c  6cf6
        bra.s   .L78000b3e                      | sau6 78000b4e  60ee
.L78000b50:
        addq.l  #1,(0x5b4,%a5)                  | sau6 78000b50  52ad 05b4
        bsr.w   dump_send_page                  | sau6 78000b54  6100 0092
        dbf     %d5,.L78000b70                  | sau6 78000b58  51cd 0016
        move.b  #0x21,%d1                       | sau6 78000b5c  123c 0021
        bsr.w   dump_putc                       | sau6 78000b60  6100 0200
        moveq   #0x1f,%d5                       | sau6 78000b64  7a1f
        dbf     %d2,.L78000b70                  | sau6 78000b66  51ca 0008
        bsr.w   dump_crlf                       | sau6 78000b6a  6100 01cc
        move.w  %d5,%d2                         | sau6 78000b6e  3405
.L78000b70:
        .short  0xd6bc, 0x0000, 0x0400          | sau6 78000b70  d6bc 0000 0400  add.l   #0x400,%d3
        rts                                     | sau6 78000b76  4e75
.L78000b78:
        lea     (.L78000de7:w,%pc),%a0          | sau6 78000b78  41fa 026d
        bsr.w   dump_puts_crlf                  | sau6 78000b7c  6100 01b8
        cmpi.w  #2,(%fp)                        | sau6 78000b80  0c56 0002
        beq.s   .L78000b92                      | sau6 78000b84  670c
        cmpi.w  #6,(%fp)                        | sau6 78000b86  0c56 0006
        beq.s   .L78000b92                      | sau6 78000b8a  6706
        cmpi.w  #8,(%fp)                        | sau6 78000b8c  0c56 0008
        bne.s   .L78000b9e                      | sau6 78000b90  660c
.L78000b92:
        moveq   #4,%d0                          | sau6 78000b92  7004
        cmp.b   (.L78000db3:w,%pc),%d0          | sau6 78000b94  b03a 021d
        beq.s   .L78000b9e                      | sau6 78000b98  6704
        bsr.w   dump_send_page0                 | sau6 78000b9a  6100 0056
.L78000b9e:
        cmpi.w  #5,(%fp)                        | sau6 78000b9e  0c56 0005
        bne.s   .L78000ba8                      | sau6 78000ba2  6604
        bsr.s   .L78000bd8                      | sau6 78000ba4  6132
        bsr.s   .L78000bd8                      | sau6 78000ba6  6130
.L78000ba8:
        tst.b   (0x20,%fp)                      | sau6 78000ba8  4a2e 0020
        beq.s   dump_to_prom                    | sau6 78000bac  670e
dump_reset:
        movea.l (0x0).w,%sp                     | sau6 78000bae  2e78 0000
        ori.w   #0x2700,%sr                     | sau6 78000bb2  007c 2700
        movea.l (0x4).w,%a0                     | sau6 78000bb6  2078 0004
        jmp     (%a0)                           | sau6 78000bba  4ed0
dump_to_prom:
        movea.l (0x11c).w,%a0                   | sau6 78000bbc  2078 011c
        jmp     (%a0)                           | sau6 78000bc0  4ed0
DUMP_$AUTO_REBOOT:
        lea     (DUMP:w,%pc),%a5                | sau6 78000bc2  4bfa fc3c
        lea     (0x1020600).l,%sp               | sau6 78000bc6  4ff9 0102 0600
        movea.l %sp,%fp                         | sau6 78000bcc  2c4f
        lea     (.L78000dda:w,%pc),%a0          | sau6 78000bce  41fa 020a
        bsr.w   dump_puts_crlf                  | sau6 78000bd2  6100 0162
        bra.s   dump_reset                      | sau6 78000bd6  60d6
.L78000bd8:
        cmpi.w  #5,(%fp)                        | sau6 78000bd8  0c56 0005
        bne.s   .L78000be6                      | sau6 78000bdc  6608
        moveq   #-1,%d0                         | sau6 78000bde  70ff
        move.l  %d0,(0x5b4,%a5)                 | sau6 78000be0  2b40 05b4
        bsr.s   dump_send_page0                 | sau6 78000be4  610c
.L78000be6:
        rts                                     | sau6 78000be6  4e75
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | sau6 78000be8  48e7 ff78
        moveq   #2,%d0                          | sau6 78000bec  7002
        move.l  %d6,%d1                         | sau6 78000bee  2206
        bra.s   .L78000bfa                      | sau6 78000bf0  6008
dump_send_page0:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | sau6 78000bf2  48e7 ff78
        clr.w   %d1                             | sau6 78000bf6  4241
        move.l  %a5,%d7                         | sau6 78000bf8  2e0d
.L78000bfa:
        move.w  %d1,(0x5a0,%a5)                 | sau6 78000bfa  3b41 05a0
        move.b  %d0,(0x5b3,%a5)                 | sau6 78000bfe  1b40 05b3
        move.l  %d7,%d0                         | sau6 78000c02  2007
        lsr.l   #8,%d0                          | sau6 78000c04  e088
        lsr.l   #2,%d0                          | sau6 78000c06  e488
        move.w  %d0,(0xa,%fp)                   | sau6 78000c08  3d40 000a
        move.w  #0xa,(0x8,%fp)                  | sau6 78000c0c  3d7c 000a 0008
.L78000c12:
        lea     (0x1000000).l,%a0               | sau6 78000c12  41f9 0100 0000
        lea     (dump_pkt:w,%pc),%a1            | sau6 78000c18  43fa 0172
        moveq   #0x2b,%d0                       | sau6 78000c1c  702b
.L78000c1e:
        move.b  (%a1)+,(%a0)+                   | sau6 78000c1e  10d9
        dbf     %d0,.L78000c1e                  | sau6 78000c20  51c8 fffc
        clr.l   %d4                             | sau6 78000c24  4284
.L78000c26:
        pea     (0x4,%fp)                       | sau6 78000c26  486e 0004
        move.l  #0x1000000,-(%sp)               | sau6 78000c2a  2f3c 0100 0000
        cmpi.w  #5,(%fp)                        | sau6 78000c30  0c56 0005
        bne.s   .L78000c3a                      | sau6 78000c34  6604
        move.l  %d7,(%sp)                       | sau6 78000c36  2e87
        add.l   %d4,(%sp)                       | sau6 78000c38  d997
.L78000c3a:
        pea     (0xa,%fp)                       | sau6 78000c3a  486e 000a
        pea     (dump_peer:w,%pc)               | sau6 78000c3e  487a 0174
        movea.l (0x120).w,%a0                   | sau6 78000c42  2078 0120
        jsr     (%a0)                           | sau6 78000c46  4e90
        adda.w  #0x10,%sp                       | sau6 78000c48  defc 0010
        move.l  (0x1000000).l,%d0               | sau6 78000c4c  2039 0100 0000
        move.l  %d0,(0x58c,%a5)                 | sau6 78000c52  2b40 058c
        move.l  (0x4,%fp),%d0                   | sau6 78000c56  202e 0004
        beq.s   .L78000c70                      | sau6 78000c5a  6714
        subq.w  #1,(0x8,%fp)                    | sau6 78000c5c  536e 0008
        bne.s   .L78000c12                      | sau6 78000c60  66b0
        lea     (.L78000dba:w,%pc),%a0          | sau6 78000c62  41fa 0156
        bra.w   .L78000d26                      | sau6 78000c66  6000 00be
.L78000c6a:
        movem.l (%sp)+,%d0-%d7/%a1-%a4          | sau6 78000c6a  4cdf 1eff
        rts                                     | sau6 78000c6e  4e75
.L78000c70:
        cmpi.w  #5,(%fp)                        | sau6 78000c70  0c56 0005
        bne.s   .L78000c86                      | sau6 78000c74  6610
        tst.l   (0x5b4,%a5)                     | sau6 78000c76  4aad 05b4
        blt.s   .L78000c6a                      | sau6 78000c7a  6dee
        tst.l   %d4                             | sau6 78000c7c  4a84
        bne.s   .L78000c6a                      | sau6 78000c7e  66ea
        .short  0xd87c, 0x0200                  | sau6 78000c80  d87c 0200  add.w   #0x200,%d4
        bra.s   .L78000c26                      | sau6 78000c84  60a0
.L78000c86:
        move.w  #3,(0x8,%fp)                    | sau6 78000c86  3d7c 0003 0008
        pea     (0x4,%fp)                       | sau6 78000c8c  486e 0004
        move.l  #0x1000000,-(%sp)               | sau6 78000c90  2f3c 0100 0000
        pea     (.L78000db8:w,%pc)              | sau6 78000c96  487a 0120
        pea     (dump_peer:w,%pc)               | sau6 78000c9a  487a 0118
        movea.l (0x110).w,%a0                   | sau6 78000c9e  2078 0110
        jsr     (%a0)                           | sau6 78000ca2  4e90
        adda.w  #0x10,%sp                       | sau6 78000ca4  defc 0010
        move.l  (0x4,%fp),%d0                   | sau6 78000ca8  202e 0004
        beq.s   .L78000cbc                      | sau6 78000cac  670e
        subq.w  #1,(0x8,%fp)                    | sau6 78000cae  536e 0008
        bne.w   .L78000c12                      | sau6 78000cb2  6600 ff5e
        lea     (.L78000dbf:w,%pc),%a0          | sau6 78000cb6  41fa 0107
        bra.s   .L78000d26                      | sau6 78000cba  606a
.L78000cbc:
        lea     (0x1000000).l,%a0               | sau6 78000cbc  41f9 0100 0000
        move.l  (dump_pkt:w,%pc),%d0            | sau6 78000cc2  203a 00c8
        cmp.l   (0x8,%a0),%d0                   | sau6 78000cc6  b0a8 0008
        bne.s   .L78000c86                      | sau6 78000cca  66ba
        lea     (0x1e,%a0),%a1                  | sau6 78000ccc  43e8 001e
        clr.l   %d0                             | sau6 78000cd0  4280
        move.b  (0x18,%a0),%d0                  | sau6 78000cd2  1028 0018
        adda.l  %d0,%a1                         | sau6 78000cd6  d3c0
        move.l  %a1,(0x1c,%fp)                  | sau6 78000cd8  2d49 001c
        cmpi.w  #2,(%a1)                        | sau6 78000cdc  0c51 0002
        bne.s   .L78000cf6                      | sau6 78000ce0  6614
        cmpi.w  #1,(0x2,%a1)                    | sau6 78000ce2  0c69 0001 0002
        bne.s   .L78000cf6                      | sau6 78000ce8  660c
        move.b  (0x5,%a1),%d0                   | sau6 78000cea  1029 0005
        subq.l  #1,%d0                          | sau6 78000cee  5380
        cmp.b   (.L78000db3:w,%pc),%d0          | sau6 78000cf0  b03a 00c1
        beq.s   .L78000d0a                      | sau6 78000cf4  6714
.L78000cf6:
        cmpi.b  #7,(0x5,%a1)                    | sau6 78000cf6  0c29 0007 0005
        bne.s   .L78000d00                      | sau6 78000cfc  6602
.L78000cfe:
        bra.s   .L78000c86                      | sau6 78000cfe  6086
.L78000d00:
        lea     (.L78000dc4:w,%pc),%a0          | sau6 78000d00  41fa 00c2
        bsr.s   dump_puts                       | sau6 78000d04  6136
.L78000d06:
        bra.w   .L78000b92                      | sau6 78000d06  6000 fe8a
.L78000d0a:
        .short  0xb03c, 0x0002                  | sau6 78000d0a  b03c 0002  cmp.b   #2,%d0
        bne.s   .L78000d1a                      | sau6 78000d0e  660a
        move.l  (dump_peer:w,%pc),%d0           | sau6 78000d10  203a 00a2
        cmp.l   (0xc,%a1),%d0                   | sau6 78000d14  b0a9 000c
        bne.s   .L78000cfe                      | sau6 78000d18  66e4
.L78000d1a:
        move.l  (0x6,%a1),%d0                   | sau6 78000d1a  2029 0006
        beq.w   .L78000c6a                      | sau6 78000d1e  6700 ff4a
        lea     (.L78000dcc:w,%pc),%a0          | sau6 78000d22  41fa 00a8
.L78000d26:
        move.l  %d0,-(%sp)                      | sau6 78000d26  2f00
        bsr.s   dump_puts                       | sau6 78000d28  6112
        lea     (.L78000dd3:w,%pc),%a0          | sau6 78000d2a  41fa 00a7
        bsr.s   dump_puts                       | sau6 78000d2e  610c
        move.l  (%sp)+,%d0                      | sau6 78000d30  201f
        bsr.s   dump_hex8                       | sau6 78000d32  6112
        bra.s   .L78000d06                      | sau6 78000d34  60d0
dump_puts_crlf:
        bsr.s   dump_puts                       | sau6 78000d36  6104
dump_crlf:
        lea     (.L78000de4:w,%pc),%a0          | sau6 78000d38  41fa 00aa
dump_puts:
        move.b  (%a0)+,%d1                      | sau6 78000d3c  1218
        beq.s   .L78000d70                      | sau6 78000d3e  6730
        bsr.s   dump_putc                       | sau6 78000d40  6120
        bra.s   dump_puts                       | sau6 78000d42  60f8
        rts                                     | sau6 78000d44  4e75
dump_hex8:
        moveq   #7,%d2                          | sau6 78000d46  7407
.L78000d48:
        rol.l   #4,%d0                          | sau6 78000d48  e998
        moveq   #0xf,%d1                        | sau6 78000d4a  720f
        and.b   %d0,%d1                         | sau6 78000d4c  c200
        .short  0xb23c, 0x000a                  | sau6 78000d4e  b23c 000a  cmp.b   #0xa,%d1
        blt.s   .L78000d56                      | sau6 78000d52  6d02
        addq.b  #7,%d1                          | sau6 78000d54  5e01
.L78000d56:
        .short  0xd23c, 0x0030                  | sau6 78000d56  d23c 0030  add.b   #0x30,%d1
        bsr.s   dump_putc                       | sau6 78000d5a  6106
        dbf     %d2,.L78000d48                  | sau6 78000d5c  51ca ffea
        bra.s   dump_crlf                       | sau6 78000d60  60d6
dump_putc:
        movem.l %d0-%a4,-(%sp)                  | sau6 78000d62  48e7 fff8
        movea.l (0x108).w,%a0                   | sau6 78000d66  2078 0108
        jsr     (%a0)                           | sau6 78000d6a  4e90
        movem.l (%sp)+,%d0-%a4                  | sau6 78000d6c  4cdf 1fff
.L78000d70:
        rts                                     | sau6 78000d70  4e75
dump_kernel_phys:
        movem.l %d7/%a4,-(%sp)                  | sau6 78000d72  48e7 0108
        lea     (OS_PROC).l,%a4                 | sau6 78000d76  49f9 7800 1000
        move.l  #0x101fc00,%d7                  | sau6 78000d7c  2e3c 0101 fc00
        suba.l  %a4,%a3                         | sau6 78000d82  97cc
        adda.l  %d7,%a3                         | sau6 78000d84  d7c7
        movem.l (%sp)+,%d7/%a4                  | sau6 78000d86  4cdf 1080
        rts                                     | sau6 78000d8a  4e75
dump_pkt:
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78000d8c  0000 0000 0000 0000
        .byte   0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00 | sau6 78000d94  0000 0000 0101 0000
        .byte   0x00, 0x2c, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00 | sau6 78000d9c  002c 000a 0000 0000
        .byte   0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | sau6 78000da4  0401 0000 0000 0000
        .byte   0x00, 0x03, 0x00, 0x02, 0x00, 0x01, 0x06 | sau6 78000dac  0003 0002 0001 06
.L78000db3:
        .byte   0x00                            | sau6 78000db3  00
dump_peer:
        .short  0x0000, 0x0000                  | sau6 78000db4  0000 0000
.L78000db8:
        .short  0x4000                          | sau6 78000db8  4000
.L78000dba:
        .ascii  "Xbad"                          | sau6 78000dba  5862 6164
        .byte   0x00                            | sau6 78000dbe  00
.L78000dbf:
        .ascii  "Rbad"                          | sau6 78000dbf  5262 6164
        .byte   0x00                            | sau6 78000dc3  00
.L78000dc4:
        .ascii  "Bad rpy"                       | sau6 78000dc4  4261 6420 7270 79
        .byte   0x00                            | sau6 78000dcb  00
.L78000dcc:
        .ascii  "Nm sad"                        | sau6 78000dcc  4e6d 2073 6164
        .byte   0x00                            | sau6 78000dd2  00
.L78000dd3:
        .ascii  " - St="                        | sau6 78000dd3  202d 2053 743d
        .byte   0x00                            | sau6 78000dd9  00
.L78000dda:
        .ascii  "REBOOTING"                     | sau6 78000dda  5245 424f 4f54 494e 47
        .byte   0x00                            | sau6 78000de3  00
.L78000de4:
        .byte   0x0a, 0x0d, 0x00                | sau6 78000de4  0a0d 00
.L78000de7:
        .byte   0x0a, 0x0d                      | sau6 78000de7  0a0d
        .ascii  "Done"                          | sau6 78000de9  446f 6e65
        .byte   0x00                            | sau6 78000ded  00
dump_flags:
        .byte   0x00                            | sau6 78000dee  00
.L78000def:
        .ascii  "Dumping global_b only."        | sau6 78000def  4475 6d70 696e 6720 676c 6f62 616c 5f62 206f 6e6c 792e
        .byte   0x0a, 0x0d, 0x00, 0x00, 0x00    | sau6 78000e05  0a0d 0000 00
.L78000e0a:
        .short  0x0000, 0x0000                  | sau6 78000e0a  0000 0000
.L78000e0e:
        .short  0x0000, 0x0000                  | sau6 78000e0e  0000 0000
.L78000e12:
        .short  0x0000, 0x0000                  | sau6 78000e12  0000 0000
.L78000e16:
        .short  0x0000, 0x0000                  | sau6 78000e16  0000 0000
.L78000e1a:
        .short  0x0000, 0x0000                  | sau6 78000e1a  0000 0000
DUMP_$SMAP_PHADDR:
        .space  454                             | sau6 78000e1e
dump_ranges:
        .short  0x0000, 0x0000                  | sau6 78000fe4  0000 0000
DUMP_$RARS_PHADDR:
        .short  0x0000, 0x0000                  | sau6 78000fe8  0000 0000
DUMP_$ADDRS:
        .short  0x0100, 0x0000, 0x0107, 0xfc00, 0x0000, 0x0000, 0x0000, 0x0000 | sau6 78000fec  0100 0000 0107 fc00 0000 0000 0000 0000
        .short  0x0000, 0x0000                  | sau6 78000ffc  0000 0000
