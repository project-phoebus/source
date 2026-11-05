|
| dump/sau7/dump.s - the DUMP page (SAU7): the crash-dump code and its
| cells
|
| The SAU7's DUMP page, transcribed from the SAU7 image file (file
| 0x1800..0x2000, VA 0x3C400C00; COLD copies it to physical 0x1000C00,
| `cold_ram_16mb').  The SAU7 map:
|
|   D26 3C400C00  DUMP               loaded at 1003400, size = 800
|       3C400C00  DUMP
|       3C40101E  DUMP_$AUTO_REBOOT
|       3C40124C  DUMP_$SMAP_PHADDR
|       3C4013E8  DUMP_$RARS_PHADDR
|       3C4013EC  DUMP_$ADDRS
|
| The SAU8's form (dump/sau8/dump.s; dump/sau2/dump.s describes the dump
| protocol) for the SAU7's memory, which starts at 16 MB: entered by the
| PROM with the MMU off, it runs at its physical home and reaches the
| kernel's cells by physical address (VA - OS_PROC + 0x1003C00, the
| kernel's first page as loaded): CRASH_STATUS, SERVER_$FLAG.  Its stack
| is physical 0x1004600 and its packet buffer 0x1004000.  The PROM's
| vectors (0x104 .. 0x120 of the trap page, absolute words) send and
| receive the packets.  Against the SAU8's:
| - the MMU's state is always saved with `pmove tc' and `pmove crp' (the
|   MC68030's and the MC68851's), after a word of 0x7A when bit 3 of the
|   PROM's machine id's low byte (0x103) is set, else of 7; the same bit
|   picks the size recorded at (0x644,A5): 0x10C00, else 0x2C00;
| - after the header page it sends 2 KB from physical 0x17000 and then
|   8 KB from 0x12000 (64 KB from 0x4000000 with that bit), 1 KB at a
|   time through the packet buffer;
| - the segment table walk starts at the global segments' descriptors
|   (DUMP_$SMAP_PHADDR + 0x800) and covers 0x800 of them.
| DUMP_$AUTO_REBOOT is the entry CRASH_SYSTEM's restart hands the PROM;
| DUMP_$ADDRS the physical ranges dumped (0x1000000..0x107FC00 in the
| file, as the image; OS_$INIT sets them); DUMP_$SMAP_PHADDR and
| DUMP_$RARS_PHADDR the tables' physical addresses (OS_$INIT).  The
| strings are the console's messages.
|
| One section; its cells are reached off A5 = DUMP (`lea (d,PC),A5') with
| the image's displacements and PC-relatively.  Three cells are kernel
| addresses (OS_PROC, CRASH_STATUS, SERVER_$FLAG).  The labels without a
| map name keep the image address they stand at.  The Apollo assembler's
| <ea>=#imm forms (cmp/add/sub/and #imm,Dn), which gas spells
| cmpi/addi/subi/andi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau7 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU7 image's.
|

        .section ".text.DUMP","ax",@progbits
        .even

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

DUMP:
        move.l  %d0,%d7                         | 3c400c00  2e00
        bra.s   dump_check_magic                | 3c400c02  600e
        moveq   #2,%d7                          | 3c400c04  7e02
        bra.s   dump_start_2_0                  | 3c400c06  6006
        moveq   #2,%d7                          | 3c400c08  7e02
        moveq   #1,%d6                          | 3c400c0a  7c01
        bra.s   dump_common                     | 3c400c0c  6028
dump_start_2_0:
        moveq   #0,%d6                          | 3c400c0e  7c00
        bra.s   dump_common                     | 3c400c10  6024
dump_check_magic:
        swap    %d0                             | 3c400c12  4840
        .short  0xb07c, 0x0ace                  | 3c400c14  b07c 0ace  cmp.w #0xace,%d0 (<ea>=#imm form)
        beq.s   .L3c400c1c                      | 3c400c18  6702
        moveq   #1,%d7                          | 3c400c1a  7e01
.L3c400c1c:
        moveq   #0,%d6                          | 3c400c1c  7c00
        swap    %d1                             | 3c400c1e  4841
        .short  0xb27c, 0x0ace                  | 3c400c20  b27c 0ace  cmp.w #0xace,%d1 (<ea>=#imm form)
        bne.s   dump_common                     | 3c400c24  6610
        clr.w   %d1                             | 3c400c26  4241
        swap    %d1                             | 3c400c28  4841
        move.l  %d1,%d6                         | 3c400c2a  2c01
        btst    #7,%d2                          | 3c400c2c  0802 0007
        bne.s   dump_common                     | 3c400c30  6604
        .short  0xcc7c, 0x00ff                  | 3c400c32  cc7c 00ff  and.w #0xff,%d6 (<ea>=#imm form)
dump_common:
        lea     (DUMP,%pc),%a5                  | 3c400c36  4bfa ffc8
        lea     (0x1004600).l,%sp               | 3c400c3a  4ff9 0100 4600
        movea.l %sp,%fp                         | 3c400c40  2c4f
        clr.w   (0x636,%a5)                     | 3c400c42  426d 0636
        move.b  %d6,(0x637,%a5)                 | 3c400c46  1b46 0637
        lsr.w   #8,%d6                          | 3c400c4a  e04e
        move.w  %d6,(0x2,%fp)                   | 3c400c4c  3d46 0002
        move.l  #0x400,%d6                      | 3c400c50  2c3c 0000 0400
        bset    #0,(0x61c,%a5)                  | 3c400c56  08ed 0000 061c
        bne.s   .L3c400c6e                      | 3c400c5c  6610
        move.w  (0x17004).l,(0xc,%fp)           | 3c400c5e  3d79 0001 7004 000c
        move.w  (0x10000).l,(0xe,%fp)           | 3c400c66  3d79 0001 0000 000e
.L3c400c6e:
        move.w  %d7,(%fp)                       | 3c400c6e  3c87
        move.w  #0,-(%sp)                       | 3c400c70  3f3c 0000
        pea     (%sp)                           | 3c400c74  4857
        move.l  #0x600df1a6,(0x4,%fp)           | 3c400c76  2d7c 600d f1a6 0004
        pea     (0x4,%fp)                       | 3c400c7e  486e 0004
        pea     (0x2,%fp)                       | 3c400c82  486e 0002
        pea     (%fp)                           | 3c400c86  4856
        movea.l (0x10c).w,%a0                   | 3c400c88  2078 010c
        jsr     (%a0)                           | 3c400c8c  4e90
        adda.w  #0x12,%sp                       | 3c400c8e  defc 0012
        lea     (OS_PROC).l,%a4                 | 3c400c92  49f9 3c40 1400
        move.l  #0x1003c00,%d7                  | 3c400c98  2e3c 0100 3c00
        clr.b   (0x20,%fp)                      | 3c400c9e  422e 0020
        cmpi.w  #2,(%fp)                        | 3c400ca2  0c56 0002
        beq.s   .L3c400cb4                      | 3c400ca6  670c
        cmpi.w  #6,(%fp)                        | 3c400ca8  0c56 0006
        beq.s   .L3c400cb4                      | 3c400cac  6706
        cmpi.w  #8,(%fp)                        | 3c400cae  0c56 0008
        bne.s   .L3c400d04                      | 3c400cb2  6650
.L3c400cb4:
        lea     (CRASH_STATUS).l,%a3            | 3c400cb4  47f9 3c42 2e90
        suba.l  %a4,%a3                         | 3c400cba  97cc
        adda.l  %d7,%a3                         | 3c400cbc  d7c7
        move.l  (%a3),(0x5d6,%a5)               | 3c400cbe  2b53 05d6
        moveq   #0,%d0                          | 3c400cc2  7000
        bsr.w   dump_send_page0                 | 3c400cc4  6100 0382
        btst    #0,(0x10001).l                  | 3c400cc8  0839 0000 0001 0001
        beq.s   .L3c400cf8                      | 3c400cd0  6726
        lea     (SERVER_$FLAG).l,%a3            | 3c400cd2  47f9 3c42 2ea7
        suba.l  %a4,%a3                         | 3c400cd8  97cc
        adda.l  %d7,%a3                         | 3c400cda  d7c7
        tst.b   (%a3)                           | 3c400cdc  4a13
        beq.s   .L3c400cf8                      | 3c400cde  6718
        movea.l (0x1c,%fp),%a1                  | 3c400ce0  226e 001c
        btst    #6,(0xa,%a1)                    | 3c400ce4  0829 0006 000a
        st      (0x20,%fp)                      | 3c400cea  50ee 0020
        btst    #7,(0xa,%a1)                    | 3c400cee  0829 0007 000a
        beq.w   .L3c400fec                      | 3c400cf4  6700 02f6
.L3c400cf8:
        movea.l (0x1c,%fp),%a1                  | 3c400cf8  226e 001c
        lea     (0xc,%a1),%a0                   | 3c400cfc  41e9 000c
        bsr.w   dump_puts                       | 3c400d00  6100 0476
.L3c400d04:
        lea     (0x1004000).l,%a4               | 3c400d04  49f9 0100 4000
        move.l  %a4,%d7                         | 3c400d0a  2e0c
        move.w  (0xe,%fp),(%a4)+                | 3c400d0c  38ee 000e
        btst    #3,(0x103).w                    | 3c400d10  0838 0003 0103
        bne.s   .L3c400d26                      | 3c400d16  660e
        move.w  #7,(%a4)+                       | 3c400d18  38fc 0007
        move.l  #0x2c00,(0x644,%a5)             | 3c400d1c  2b7c 0000 2c00 0644
        bra.s   .L3c400d32                      | 3c400d24  600c
.L3c400d26:
        move.w  #0x7a,(%a4)+                    | 3c400d26  38fc 007a
        move.l  #0x10c00,(0x644,%a5)            | 3c400d2a  2b7c 0001 0c00 0644
.L3c400d32:
        pmove   %tc,(%a4)                       | 3c400d32  f014 4200
        addq.w  #4,%a4                          | 3c400d36  584c
        move.w  #-0x1,(%a4)+                    | 3c400d38  38fc ffff
        pmove   %crp,(%a4)                      | 3c400d3c  f014 4e00
        addq.l  #8,%a4                          | 3c400d40  508c
        clr.l   %d0                             | 3c400d42  4280
        cmpi.w  #1,(0x636,%a5)                  | 3c400d44  0c6d 0001 0636
        bne.s   .L3c400d7e                      | 3c400d4a  6632
        lea     (.L3c40121d,%pc),%a0            | 3c400d4c  41fa 04cf
        bsr.w   dump_puts                       | 3c400d50  6100 0426
        move.l  #0x47424c42,%d0                 | 3c400d54  203c 4742 4c42
        move.l  #1,(0x648,%a5)                  | 3c400d5a  2b7c 0000 0001 0648
        clr.l   (0x638,%a5)                     | 3c400d62  42ad 0638
        clr.l   (0x63c,%a5)                     | 3c400d66  42ad 063c
        lea     (.L3c400e1a,%pc),%a0            | 3c400d6a  41fa 00ae
        bsr.w   dump_walk_tables                | 3c400d6e  6100 017a
        move.l  (.L3c401238,%pc),(0x4,%a4)      | 3c400d72  297a 04c4 0004
        move.l  (.L3c40123c,%pc),(0x8,%a4)      | 3c400d78  297a 04c2 0008
.L3c400d7e:
        move.l  %d0,(%a4)                       | 3c400d7e  2880
        adda.l  #0xc,%a4                        | 3c400d80  d9fc 0000 000c
        clr.l   (0x5d6,%a5)                     | 3c400d86  42ad 05d6
        bsr.w   dump_send_page                  | 3c400d8a  6100 02b2
        move.w  #1,%d3                          | 3c400d8e  363c 0001
        movea.l #0x17000,%a2                    | 3c400d92  247c 0001 7000
        move.w  #1,%d5                          | 3c400d98  3a3c 0001
.L3c400d9c:
        move.w  #0xff,%d4                       | 3c400d9c  383c 00ff
        lea     (0x1004000).l,%a4               | 3c400da0  49f9 0100 4000
        move.l  %a4,%d7                         | 3c400da6  2e0c
.L3c400da8:
        move.l  (%a2)+,(%a4)+                   | 3c400da8  28da
        dbf     %d4,.L3c400da8                  | 3c400daa  51cc fffc
        addq.l  #1,(0x5d6,%a5)                  | 3c400dae  52ad 05d6
        bsr.w   dump_send_page                  | 3c400db2  6100 028a
        dbf     %d5,.L3c400d9c                  | 3c400db6  51cd ffe4
        btst    #3,(0x103).w                    | 3c400dba  0838 0003 0103
        bne.s   .L3c400dce                      | 3c400dc0  660c
        movea.l #0x12000,%a2                    | 3c400dc2  247c 0001 2000
        move.w  #7,%d5                          | 3c400dc8  3a3c 0007
        bra.s   .L3c400dd8                      | 3c400dcc  600a
.L3c400dce:
        movea.l #0x4000000,%a2                  | 3c400dce  247c 0400 0000
        move.w  #0x3f,%d5                       | 3c400dd4  3a3c 003f
.L3c400dd8:
        dbf     %d3,.L3c400d9c                  | 3c400dd8  51cb ffc2
        moveq   #0x1f,%d5                       | 3c400ddc  7a1f
        move.w  %d5,%d2                         | 3c400dde  3405
        cmpi.w  #1,(0x636,%a5)                  | 3c400de0  0c6d 0001 0636
        bne.w   .L3c400f54                      | 3c400de6  6600 016c
        lea     (.L3c400eda,%pc),%a0            | 3c400dea  41fa 00ee
        bsr.w   dump_walk_tables                | 3c400dee  6100 00fa
        move.l  #1,(0x648,%a5)                  | 3c400df2  2b7c 0000 0001 0648
        bset    #2,(0x61c,%a5)                  | 3c400dfa  08ed 0002 061c
        lea     (0x1004000).l,%a0               | 3c400e00  41f9 0100 4000
        move.l  %a0,(0x640,%a5)                 | 3c400e06  2b48 0640
        lea     (.L3c400e40,%pc),%a0            | 3c400e0a  41fa 0034
        bsr.w   dump_walk_tables                | 3c400e0e  6100 00da
        bsr.w   .L3c400ebe                      | 3c400e12  6100 00aa
        bra.w   .L3c400fd2                      | 3c400e16  6000 01ba
.L3c400e1a:
        movem.l %d0-%d1,-(%sp)                  | 3c400e1a  48e7 c000
        addq.l  #1,(0x638,%a5)                  | 3c400e1e  52ad 0638
        move.l  %d0,%d1                         | 3c400e22  2200
        .short  0x92bc, 0x0000, 0x0400          | 3c400e24  92bc 0000 0400  sub.l #0x400,%d1 (<ea>=#imm form)
        cmp.l   (.L3c401248,%pc),%d1            | 3c400e2a  b2ba 041c
        beq.w   .L3c400e36                      | 3c400e2e  6700 0006
        addq.l  #1,(0x63c,%a5)                  | 3c400e32  52ad 063c
.L3c400e36:
        move.l  %d0,(0x648,%a5)                 | 3c400e36  2b40 0648
        movem.l (%sp)+,%d0-%d1                  | 3c400e3a  4cdf 0003
        rts                                     | 3c400e3e  4e75
.L3c400e40:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c400e40  48e7 c0c0
        movea.l (.L3c401240,%pc),%a0            | 3c400e44  207a 03fa
        move.l  (.L3c401248,%pc),%d1            | 3c400e48  223a 03fe
        move.l  %d0,(0x648,%a5)                 | 3c400e4c  2b40 0648
        .short  0xd2bc, 0x0000, 0x0400          | 3c400e50  d2bc 0000 0400  add.l #0x400,%d1 (<ea>=#imm form)
        cmp.l   %d0,%d1                         | 3c400e56  b280
        beq.w   .L3c400ea2                      | 3c400e58  6700 0048
        bclr    #2,(0x61c,%a5)                  | 3c400e5c  08ad 0002 061c
        bne.w   .L3c400e84                      | 3c400e62  6600 0020
        adda.l  #0x10,%a0                       | 3c400e66  d1fc 0000 0010
        move.l  %a0,(0x640,%a5)                 | 3c400e6c  2b48 0640
        move.l  %a0,%d1                         | 3c400e70  2208
        .short  0xc2bc, 0x0000, 0x03ff          | 3c400e72  c2bc 0000 03ff  and.l #0x3ff,%d1 (<ea>=#imm form)
        bne.w   .L3c400e84                      | 3c400e78  6600 000a
        bsr.w   .L3c400ebe                      | 3c400e7c  6100 0040
        movea.l (.L3c401240,%pc),%a0            | 3c400e80  207a 03be
.L3c400e84:
        move.l  (.L3c401244,%pc),%d1            | 3c400e84  223a 03be
        movea.l %a0,%a1                         | 3c400e88  2248
        move.l  %d1,(%a1)+                      | 3c400e8a  22c1
        .short  0xd2bc, 0x0000, 0x03ff          | 3c400e8c  d2bc 0000 03ff  add.l #0x3ff,%d1 (<ea>=#imm form)
        move.l  %d1,(%a1)+                      | 3c400e92  22c1
        move.l  %d0,(%a1)+                      | 3c400e94  22c0
        .short  0xd0bc, 0x0000, 0x03ff          | 3c400e96  d0bc 0000 03ff  add.l #0x3ff,%d0 (<ea>=#imm form)
        move.l  %d0,(%a1)                       | 3c400e9c  2280
        bra.w   .L3c400eb0                      | 3c400e9e  6000 0010
.L3c400ea2:
        move.l  #0x400,%d1                      | 3c400ea2  223c 0000 0400
        add.l   %d1,(0x4,%a0)                   | 3c400ea8  d3a8 0004
        add.l   %d1,(0xc,%a0)                   | 3c400eac  d3a8 000c
.L3c400eb0:
        addi.l  #0x400,(0x644,%a5)              | 3c400eb0  06ad 0000 0400 0644
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c400eb8  4cdf 0303
        rts                                     | 3c400ebc  4e75
.L3c400ebe:
        movem.l %d0-%a5,-(%sp)                  | 3c400ebe  48e7 fffc
        lea     (0x1004000).l,%a0               | 3c400ec2  41f9 0100 4000
        move.l  %a0,(0x640,%a5)                 | 3c400ec8  2b48 0640
        addq.l  #1,(0x5d6,%a5)                  | 3c400ecc  52ad 05d6
        bsr.w   dump_send_page                  | 3c400ed0  6100 016c
        movem.l (%sp)+,%d0-%a5                  | 3c400ed4  4cdf 3fff
        rts                                     | 3c400ed8  4e75
.L3c400eda:
        movem.l %d1/%d3/%d7-%a2,-(%sp)          | 3c400eda  48e7 51e0
        move.l  %d0,%d7                         | 3c400ede  2e00
        bsr.w   .L3c400f6a                      | 3c400ee0  6100 0088
        movem.l (%sp)+,%d1/%d3/%d7-%a2          | 3c400ee4  4cdf 078a
        rts                                     | 3c400ee8  4e75
dump_walk_tables:
        movem.l %d0-%d4/%a0-%a3,-(%sp)          | 3c400eea  48e7 f8f0
        movea.l (DUMP_$SMAP_PHADDR,%pc),%a1     | 3c400eee  227a 035c
        adda.l  #0x800,%a1                      | 3c400ef2  d3fc 0000 0800
        clr.l   %d1                             | 3c400ef8  4281
.L3c400efa:
        move.l  (0x0,%a1,%d1.w),%d4             | 3c400efa  2831 1000
        .short  0xc8bc, 0x0000, 0x0003          | 3c400efe  c8bc 0000 0003  and.l #3,%d4 (<ea>=#imm form)
        beq.s   .L3c400f46                      | 3c400f04  6740
        move.l  (0x4,%a1,%d1.w),%d4             | 3c400f06  2831 1004
        .short  0xc8bc, 0xffff, 0xfff0          | 3c400f0a  c8bc ffff fff0  and.l #-0x10,%d4 (<ea>=#imm form)
        movea.l %d4,%a2                         | 3c400f10  2444
        clr.l   %d3                             | 3c400f12  4283
.L3c400f14:
        move.l  (0x0,%a2,%d3.w),%d0             | 3c400f14  2032 3000
        move.l  %d0,%d4                         | 3c400f18  2800
        .short  0xc8bc, 0x0000, 0x0003          | 3c400f1a  c8bc 0000 0003  and.l #3,%d4 (<ea>=#imm form)
        beq.s   .L3c400f3e                      | 3c400f20  671c
        .short  0xc0bc, 0xffff, 0xfc00          | 3c400f22  c0bc ffff fc00  and.l #-0x400,%d0 (<ea>=#imm form)
        lea     (dump_ranges,%pc),%a3           | 3c400f28  47fa 04ba
.L3c400f2c:
        addq.l  #8,%a3                          | 3c400f2c  508b
        tst.l   (%a3)                           | 3c400f2e  4a93
        beq.s   .L3c400f3e                      | 3c400f30  670c
        cmp.l   (%a3),%d0                       | 3c400f32  b093
        blt.s   .L3c400f2c                      | 3c400f34  6df6
        cmp.l   (0x4,%a3),%d0                   | 3c400f36  b0ab 0004
        bgt.s   .L3c400f2c                      | 3c400f3a  6ef0
        jsr     (%a0)                           | 3c400f3c  4e90
.L3c400f3e:
        addq.w  #4,%d3                          | 3c400f3e  5843
        .short  0xb67c, 0x0080                  | 3c400f40  b67c 0080  cmp.w #0x80,%d3 (<ea>=#imm form)
        blt.s   .L3c400f14                      | 3c400f44  6dce
.L3c400f46:
        addq.w  #8,%d1                          | 3c400f46  5041
        .short  0xb27c, 0x4000                  | 3c400f48  b27c 4000  cmp.w #0x4000,%d1 (<ea>=#imm form)
        blt.s   .L3c400efa                      | 3c400f4c  6dac
        movem.l (%sp)+,%d0-%d4/%a0-%a3          | 3c400f4e  4cdf 0f1f
        rts                                     | 3c400f52  4e75
.L3c400f54:
        lea     (DUMP_$ADDRS,%pc),%a3           | 3c400f54  47fa 0496
.L3c400f58:
        move.l  (%a3)+,%d3                      | 3c400f58  261b
        beq.s   .L3c400fd2                      | 3c400f5a  6776
        move.l  (%a3)+,%d4                      | 3c400f5c  281b
.L3c400f5e:
        move.l  %d3,%d7                         | 3c400f5e  2e03
        bsr.w   .L3c400f6a                      | 3c400f60  6100 0008
        cmp.l   %d3,%d4                         | 3c400f64  b883
        bge.s   .L3c400f5e                      | 3c400f66  6cf6
        bra.s   .L3c400f58                      | 3c400f68  60ee
.L3c400f6a:
        addq.l  #1,(0x5d6,%a5)                  | 3c400f6a  52ad 05d6
        bsr.w   dump_send_page                  | 3c400f6e  6100 00ce
        cmpi.w  #1,(%fp)                        | 3c400f72  0c56 0001
        bne.s   .L3c400fb2                      | 3c400f76  663a
        cmpi.w  #0x4cf,(0x5d8,%a5)              | 3c400f78  0c6d 04cf 05d8
        blt.s   .L3c400fb2                      | 3c400f7e  6d32
        move.l  #-0x1,(0x5d6,%a5)               | 3c400f80  2b7c ffff ffff 05d6
        movem.l %d0-%a0,-(%sp)                  | 3c400f88  48e7 ff80
        bsr.w   dump_crlf                       | 3c400f8c  6100 01e6
        movea.l (0x118).w,%a0                   | 3c400f90  2078 0118
.L3c400f94:
        jsr     (%a0)                           | 3c400f94  4e90
        .short  0xb23c, 0x00ff                  | 3c400f96  b23c 00ff  cmp.b #0xff,%d1 (<ea>=#imm form)
        bne.s   .L3c400f94                      | 3c400f9a  66f8
        lea     (.L3c4011fc,%pc),%a0            | 3c400f9c  41fa 025e
        bsr.w   dump_puts                       | 3c400fa0  6100 01d6
        movea.l (0x104).w,%a0                   | 3c400fa4  2078 0104
        jsr     (%a0)                           | 3c400fa8  4e90
        bsr.w   dump_crlf                       | 3c400faa  6100 01c8
        movem.l (%sp)+,%d0-%a0                  | 3c400fae  4cdf 01ff
.L3c400fb2:
        dbf     %d5,.L3c400fca                  | 3c400fb2  51cd 0016
        move.b  #0x21,%d1                       | 3c400fb6  123c 0021
        bsr.w   dump_putc                       | 3c400fba  6100 01e2
        moveq   #0x1f,%d5                       | 3c400fbe  7a1f
        dbf     %d2,.L3c400fca                  | 3c400fc0  51ca 0008
        bsr.w   dump_crlf                       | 3c400fc4  6100 01ae
        move.w  %d5,%d2                         | 3c400fc8  3405
.L3c400fca:
        .short  0xd6bc, 0x0000, 0x0400          | 3c400fca  d6bc 0000 0400  add.l #0x400,%d3 (<ea>=#imm form)
        rts                                     | 3c400fd0  4e75
.L3c400fd2:
        lea     (.L3c401215,%pc),%a0            | 3c400fd2  41fa 0241
        bsr.w   dump_puts_crlf                  | 3c400fd6  6100 019a
        cmpi.w  #2,(%fp)                        | 3c400fda  0c56 0002
        beq.s   .L3c400fec                      | 3c400fde  670c
        cmpi.w  #6,(%fp)                        | 3c400fe0  0c56 0006
        beq.s   .L3c400fec                      | 3c400fe4  6706
        cmpi.w  #8,(%fp)                        | 3c400fe6  0c56 0008
        bne.s   .L3c400ff8                      | 3c400fea  660c
.L3c400fec:
        moveq   #4,%d0                          | 3c400fec  7004
        cmp.b   (.L3c4011d5,%pc),%d0            | 3c400fee  b03a 01e5
        beq.s   .L3c400ff8                      | 3c400ff2  6704
        bsr.w   dump_send_page0                 | 3c400ff4  6100 0052
.L3c400ff8:
        cmpi.w  #5,(%fp)                        | 3c400ff8  0c56 0005
        bne.s   .L3c401002                      | 3c400ffc  6604
        bsr.s   .L3c401034                      | 3c400ffe  6134
        bsr.s   .L3c401034                      | 3c401000  6132
.L3c401002:
        tst.b   (0x20,%fp)                      | 3c401002  4a2e 0020
        beq.s   dump_to_prom                    | 3c401006  6710
        reset                                   | 3c401008  4e70
dump_reset:
        movea.l (0).w,%sp                       | 3c40100a  2e78 0000
        ori.w   #0x2700,%sr                     | 3c40100e  007c 2700
        movea.l (0x4).w,%a0                     | 3c401012  2078 0004
        jmp     (%a0)                           | 3c401016  4ed0
dump_to_prom:
        movea.l (0x11c).w,%a0                   | 3c401018  2078 011c
        jmp     (%a0)                           | 3c40101c  4ed0
DUMP_$AUTO_REBOOT:
        lea     (DUMP,%pc),%a5                  | 3c40101e  4bfa fbe0
        lea     (0x1004600).l,%sp               | 3c401022  4ff9 0100 4600
        movea.l %sp,%fp                         | 3c401028  2c4f
        lea     (.L3c401208,%pc),%a0            | 3c40102a  41fa 01dc
        bsr.w   dump_puts_crlf                  | 3c40102e  6100 0142
        bra.s   dump_reset                      | 3c401032  60d6
.L3c401034:
        moveq   #-0x1,%d0                       | 3c401034  70ff
        move.l  %d0,(0x5d6,%a5)                 | 3c401036  2b40 05d6
        bsr.s   dump_send_page0                 | 3c40103a  610c
        rts                                     | 3c40103c  4e75
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | 3c40103e  48e7 ff78
        moveq   #2,%d0                          | 3c401042  7002
        move.l  %d6,%d1                         | 3c401044  2206
        bra.s   .L3c401050                      | 3c401046  6008
dump_send_page0:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | 3c401048  48e7 ff78
        clr.w   %d1                             | 3c40104c  4241
        move.l  %a5,%d7                         | 3c40104e  2e0d
.L3c401050:
        move.w  %d1,(0x5c2,%a5)                 | 3c401050  3b41 05c2
        move.b  %d0,(0x5d5,%a5)                 | 3c401054  1b40 05d5
        move.l  %d7,%d0                         | 3c401058  2007
        lsr.l   #8,%d0                          | 3c40105a  e088
        lsr.l   #2,%d0                          | 3c40105c  e488
        move.w  %d0,(0xa,%fp)                   | 3c40105e  3d40 000a
        move.w  #0xa,(0x8,%fp)                  | 3c401062  3d7c 000a 0008
.L3c401068:
        clr.l   %d4                             | 3c401068  4284
.L3c40106a:
        pea     (0x4,%fp)                       | 3c40106a  486e 0004
        pea     (dump_pkt,%pc)                  | 3c40106e  487a 013e
        cmpi.w  #5,(%fp)                        | 3c401072  0c56 0005
        bne.s   .L3c40107c                      | 3c401076  6604
        move.l  %d7,(%sp)                       | 3c401078  2e87
        add.l   %d4,(%sp)                       | 3c40107a  d997
.L3c40107c:
        pea     (0xa,%fp)                       | 3c40107c  486e 000a
        pea     (dump_peer,%pc)                 | 3c401080  487a 0154
        movea.l (0x120).w,%a0                   | 3c401084  2078 0120
        jsr     (%a0)                           | 3c401088  4e90
        adda.w  #0x10,%sp                       | 3c40108a  defc 0010
        move.l  (0x4,%fp),%d0                   | 3c40108e  202e 0004
        beq.s   .L3c4010a8                      | 3c401092  6714
        subq.w  #1,(0x8,%fp)                    | 3c401094  536e 0008
        bne.s   .L3c401068                      | 3c401098  66ce
        lea     (.L3c4011dc,%pc),%a0            | 3c40109a  41fa 0140
        bra.w   .L3c401162                      | 3c40109e  6000 00c2
.L3c4010a2:
        movem.l (%sp)+,%d0-%d7/%a1-%a4          | 3c4010a2  4cdf 1eff
        rts                                     | 3c4010a6  4e75
.L3c4010a8:
        cmpi.w  #1,(%fp)                        | 3c4010a8  0c56 0001
        beq.s   .L3c4010a2                      | 3c4010ac  67f4
        cmpi.w  #5,(%fp)                        | 3c4010ae  0c56 0005
        bne.s   .L3c4010c4                      | 3c4010b2  6610
        tst.l   (0x5d6,%a5)                     | 3c4010b4  4aad 05d6
        blt.s   .L3c4010a2                      | 3c4010b8  6de8
        tst.l   %d4                             | 3c4010ba  4a84
        bne.s   .L3c4010a2                      | 3c4010bc  66e4
        .short  0xd87c, 0x0200                  | 3c4010be  d87c 0200  add.w #0x200,%d4 (<ea>=#imm form)
        bra.s   .L3c40106a                      | 3c4010c2  60a6
.L3c4010c4:
        move.w  #3,(0x8,%fp)                    | 3c4010c4  3d7c 0003 0008
        pea     (0x4,%fp)                       | 3c4010ca  486e 0004
        move.l  #0x1004622,-(%sp)               | 3c4010ce  2f3c 0100 4622
        pea     (.L3c4011da,%pc)                | 3c4010d4  487a 0104
        pea     (dump_peer,%pc)                 | 3c4010d8  487a 00fc
        movea.l (0x110).w,%a0                   | 3c4010dc  2078 0110
        jsr     (%a0)                           | 3c4010e0  4e90
        adda.w  #0x10,%sp                       | 3c4010e2  defc 0010
        move.l  (0x4,%fp),%d0                   | 3c4010e6  202e 0004
        beq.s   .L3c4010fa                      | 3c4010ea  670e
        subq.w  #1,(0x8,%fp)                    | 3c4010ec  536e 0008
        bne.w   .L3c401068                      | 3c4010f0  6600 ff76
        lea     (.L3c4011e1,%pc),%a0            | 3c4010f4  41fa 00eb
        bra.s   .L3c401162                      | 3c4010f8  6068
.L3c4010fa:
        lea     (0x22,%fp),%a0                  | 3c4010fa  41ee 0022
        move.l  (dump_pkt,%pc),%d0              | 3c4010fe  203a 00ae
        cmp.l   (0x8,%a0),%d0                   | 3c401102  b0a8 0008
        bne.s   .L3c4010c4                      | 3c401106  66bc
        lea     (0x1e,%a0),%a1                  | 3c401108  43e8 001e
        clr.l   %d0                             | 3c40110c  4280
        move.b  (0x18,%a0),%d0                  | 3c40110e  1028 0018
        adda.l  %d0,%a1                         | 3c401112  d3c0
        move.l  %a1,(0x1c,%fp)                  | 3c401114  2d49 001c
        cmpi.w  #2,(%a1)                        | 3c401118  0c51 0002
        bne.s   .L3c401132                      | 3c40111c  6614
        cmpi.w  #1,(0x2,%a1)                    | 3c40111e  0c69 0001 0002
        bne.s   .L3c401132                      | 3c401124  660c
        move.b  (0x5,%a1),%d0                   | 3c401126  1029 0005
        subq.l  #1,%d0                          | 3c40112a  5380
        cmp.b   (.L3c4011d5,%pc),%d0            | 3c40112c  b03a 00a7
        beq.s   .L3c401146                      | 3c401130  6714
.L3c401132:
        cmpi.b  #7,(0x5,%a1)                    | 3c401132  0c29 0007 0005
        bne.s   .L3c40113c                      | 3c401138  6602
.L3c40113a:
        bra.s   .L3c4010c4                      | 3c40113a  6088
.L3c40113c:
        lea     (.L3c4011e6,%pc),%a0            | 3c40113c  41fa 00a8
        bsr.s   dump_puts                       | 3c401140  6136
.L3c401142:
        bra.w   .L3c400fec                      | 3c401142  6000 fea8
.L3c401146:
        .short  0xb03c, 0x0002                  | 3c401146  b03c 0002  cmp.b #2,%d0 (<ea>=#imm form)
        bne.s   .L3c401156                      | 3c40114a  660a
        move.l  (dump_peer,%pc),%d0             | 3c40114c  203a 0088
        cmp.l   (0xc,%a1),%d0                   | 3c401150  b0a9 000c
        bne.s   .L3c40113a                      | 3c401154  66e4
.L3c401156:
        move.l  (0x6,%a1),%d0                   | 3c401156  2029 0006
        beq.w   .L3c4010a2                      | 3c40115a  6700 ff46
        lea     (.L3c4011ee,%pc),%a0            | 3c40115e  41fa 008e
.L3c401162:
        move.l  %d0,-(%sp)                      | 3c401162  2f00
        bsr.s   dump_puts                       | 3c401164  6112
        lea     (.L3c4011f5,%pc),%a0            | 3c401166  41fa 008d
        bsr.s   dump_puts                       | 3c40116a  610c
        move.l  (%sp)+,%d0                      | 3c40116c  201f
        bsr.s   dump_hex8                       | 3c40116e  6112
        bra.s   .L3c401142                      | 3c401170  60d0
dump_puts_crlf:
        bsr.s   dump_puts                       | 3c401172  6104
dump_crlf:
        lea     (.L3c401212,%pc),%a0            | 3c401174  41fa 009c
dump_puts:
        move.b  (%a0)+,%d1                      | 3c401178  1218
        beq.s   .L3c4011ac                      | 3c40117a  6730
        bsr.s   dump_putc                       | 3c40117c  6120
        bra.s   dump_puts                       | 3c40117e  60f8
        rts                                     | 3c401180  4e75
dump_hex8:
        moveq   #7,%d2                          | 3c401182  7407
.L3c401184:
        rol.l   #4,%d0                          | 3c401184  e998
        moveq   #0xf,%d1                        | 3c401186  720f
        and.b   %d0,%d1                         | 3c401188  c200
        .short  0xb23c, 0x000a                  | 3c40118a  b23c 000a  cmp.b #0xa,%d1 (<ea>=#imm form)
        blt.s   .L3c401192                      | 3c40118e  6d02
        addq.b  #7,%d1                          | 3c401190  5e01
.L3c401192:
        .short  0xd23c, 0x0030                  | 3c401192  d23c 0030  add.b #0x30,%d1 (<ea>=#imm form)
        bsr.s   dump_putc                       | 3c401196  6106
        dbf     %d2,.L3c401184                  | 3c401198  51ca ffea
        bra.s   dump_crlf                       | 3c40119c  60d6
dump_putc:
        movem.l %d0-%a4,-(%sp)                  | 3c40119e  48e7 fff8
        movea.l (0x108).w,%a0                   | 3c4011a2  2078 0108
        jsr     (%a0)                           | 3c4011a6  4e90
        movem.l (%sp)+,%d0-%a4                  | 3c4011a8  4cdf 1fff
.L3c4011ac:
        rts                                     | 3c4011ac  4e75
dump_pkt:
        .byte   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | 3c4011ae  0000 0000 0000 0000
        .byte   0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00 | 3c4011b6  0000 0000 0101 0000
        .byte   0x00, 0x2c, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00 | 3c4011be  002c 000a 0000 0000
        .byte   0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 | 3c4011c6  0401 0000 0000 0000
        .byte   0x00, 0x03, 0x00, 0x02, 0x00, 0x01, 0x07 | 3c4011ce  0003 0002 0001 07
.L3c4011d5:
        .byte   0x00                            | 3c4011d5  00
dump_peer:
        .short  0x0000, 0x0000                  | 3c4011d6  0000 0000
.L3c4011da:
        .short  0x4000                          | 3c4011da  4000
.L3c4011dc:
        .ascii  "Xbad"                          | 3c4011dc  5862 6164
        .byte   0x00                            | 3c4011e0  00
.L3c4011e1:
        .ascii  "Rbad"                          | 3c4011e1  5262 6164
        .byte   0x00                            | 3c4011e5  00
.L3c4011e6:
        .ascii  "Bad rpy"                       | 3c4011e6  4261 6420 7270 79
        .byte   0x00                            | 3c4011ed  00
.L3c4011ee:
        .ascii  "Nm sad"                        | 3c4011ee  4e6d 2073 6164
        .byte   0x00                            | 3c4011f4  00
.L3c4011f5:
        .ascii  " - St="                        | 3c4011f5  202d 2053 743d
        .byte   0x00                            | 3c4011fb  00
.L3c4011fc:
        .ascii  "Nxt flp<CR>"                   | 3c4011fc  4e78 7420 666c 703c 4352 3e
        .byte   0x00                            | 3c401207  00
.L3c401208:
        .ascii  "REBOOTING"                     | 3c401208  5245 424f 4f54 494e 47
        .byte   0x00                            | 3c401211  00
.L3c401212:
        .byte   0x0a, 0x0d, 0x00                | 3c401212  0a0d 00
.L3c401215:
        .byte   0x0a, 0x0d                      | 3c401215  0a0d
        .ascii  "Done"                          | 3c401217  446f 6e65
        .byte   0x00                            | 3c40121b  00
dump_flags:
        .byte   0x00                            | 3c40121c  00
.L3c40121d:
        .ascii  "Dumping global_b only."        | 3c40121d  4475 6d70 696e 6720 676c 6f62 616c 5f62 206f 6e6c 792e
        .byte   0x0a, 0x0d, 0x00, 0x00, 0x00    | 3c401233  0a0d 0000 00
.L3c401238:
        .short  0x0000, 0x0000                  | 3c401238  0000 0000
.L3c40123c:
        .short  0x0000, 0x0000                  | 3c40123c  0000 0000
.L3c401240:
        .short  0x0000, 0x0000                  | 3c401240  0000 0000
.L3c401244:
        .short  0x0000, 0x0000                  | 3c401244  0000 0000
.L3c401248:
        .short  0x0000, 0x0000                  | 3c401248  0000 0000
DUMP_$SMAP_PHADDR:
        .space  408                             | 3c40124c
dump_ranges:
        .short  0x0000, 0x0000                  | 3c4013e4  0000 0000
DUMP_$RARS_PHADDR:
        .short  0x0000, 0x0000                  | 3c4013e8  0000 0000
DUMP_$ADDRS:
        .short  0x0100, 0x0000, 0x0107, 0xfc00, 0x0000, 0x0000, 0x0000, 0x0000 | 3c4013ec  0100 0000 0107 fc00 0000 0000 0000 0000
        .short  0x0000, 0x0000                  | 3c4013fc  0000 0000
