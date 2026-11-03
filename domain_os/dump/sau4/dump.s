/*
 * dump/sau4/dump.s - the DUMP page (SAU4): the crash-dump code and its cells
 *
 * The SAU4's DUMP page, transcribed from the SAU4 image file (file
 * 0x800..0xC00, physical 0x202000, VA 0xF800800), with the SAU3's names
 * and conventions (dump/sau3/dump.s: one section, A5 = DUMP with the
 * cells at fixed displacements, the <ea>=#imm forms and the DNx60's
 * control registers as `.short').  The SAU4 map:
 *
 *   D23 F800800  DUMP               loaded at 202000, size = 400
 *   D   F800800  DUMP               size = 400
 *       F800800  DUMP
 *       F800A12  DUMP_$AUTO_REBOOT
 *       F800BE4  DUMP_$SMAP_PHADDR
 *       F800BE8  DUMP_$RARS_PHADDR
 *       F800BEC  DUMP_$ADDRS
 *
 * The code runs with the translation off, at the physical addresses the
 * PROM loaded the image to (VA - 0xF800C00 + 0x202400): its stack is
 * physical 0x202E00, and a kernel cell is reached as its VA - OS_PROC +
 * KERNEL_PHYS (CRASH_STATUS, SERVER_$FLAG).  Against the SAU3's:
 *   - DUMP enters with d7 = 1, DUMP + 4 with d7 = 2; the first entry
 *     saves the words at physical 0x9004 and 0x8002 in the frame;
 *   - the request that opens the dump (op 0) carries CRASH_STATUS; with
 *     bit 5 of physical 0x8003 and SERVER_$FLAG set, the reply's flag
 *     byte decides the reboot (bit 6) and whether to dump at all (bit 7);
 *   - the tables sent first are the 512 bytes from physical 0x9000 and,
 *     after a header of two words, either the 32 region registers
 *     (control registers 0x116, 0x115, with bit 0 of physical 0x8002 set)
 *     or the registers the PROM's cells 0x138 and 0x134 read;
 *   - a type-1 device takes at most 0x4D0 pages, and dump_xfer waits for
 *     no reply from one;
 *   - the receive buffer is physical 0x202E22, 0x800 bytes; the packet's
 *     byte before dump_pkt_op is 4, and dump_flags is 0x0078 in the file;
 *   - DUMP_$ADDRS lists one range, physical 0x200000..0x27FC00.
 * Addresses in the comments are the SAU4 image's.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau4 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.
 */

        .section ".text.DUMP","ax",@progbits
        .balign 4

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

        .equ    DUMP_STACK_PHYS,  0x00202E00 /* physical: the dump's stack */
        .equ    KERNEL_PHYS,      0x00202400 /* physical: OS_PROC */
        .equ    DUMP_TABLES_PHYS, 0x00202800 /* physical: the tables' buffer */
        .equ    DUMP_RCV_BUF,     0x00202E22 /* physical: the receive buffer */

DUMP:
        moveq   #1,%d7                          | sau4 f800800  7e01
        bra.s   dump_common                     | sau4 f800802  6002
dump_start_2:
        moveq   #2,%d7                          | sau4 f800804  7e02
dump_common:
        lea     (DUMP:w,%pc),%a5                | sau4 f800806  4bfa fff8
        lea     (DUMP_STACK_PHYS).l,%sp         | sau4 f80080a  4ff9 0020 2e00
        movea.l %sp,%a6                         | sau4 f800810  2c4f
        move.l  #0x400,%d6                      | sau4 f800812  2c3c 0000 0400
        bset    #0,(0x3e2,%a5)                  | sau4 f800818  08ed 0000 03e2
        bne.s   dump_entered                    | sau4 f80081e  6610
        move.w  (0x9004).l,(0xc,%a6)            | sau4 f800820  3d79 0000 9004 000c
        move.w  (0x8002).l,(0xe,%a6)            | sau4 f800828  3d79 0000 8002 000e
dump_entered:
        move.w  %d7,(%a6)                       | sau4 f800830  3c87
        clr.w   (0x2,%a6)                       | sau4 f800832  426e 0002
        move.w  #0,-(%sp)                       | sau4 f800836  3f3c 0000
        pea     (%sp)                           | sau4 f80083a  4857
        move.l  #0x600df1a6,(0x4,%a6)           | sau4 f80083c  2d7c 600d f1a6 0004
        pea     (0x4,%a6)                       | sau4 f800844  486e 0004
        pea     (0x2,%a6)                       | sau4 f800848  486e 0002
        pea     (%a6)                           | sau4 f80084c  4856
        movea.l (0x10c).w,%a0                   | sau4 f80084e  2078 010c
        jsr     (%a0)                           | sau4 f800852  4e90
        adda.w  #0x12,%sp                       | sau4 f800854  defc 0012
        lea     (OS_PROC).l,%a4                 | sau4 f800858  49f9 0f80 0c00
        move.l  #KERNEL_PHYS,%d7                | sau4 f80085e  2e3c 0020 2400
        clr.b   (0x20,%a6)                      | sau4 f800864  422e 0020
        cmpi.w  #2,(%a6)                        | sau4 f800868  0c56 0002
        beq.s   .Lf80087a                       | sau4 f80086c  670c
        cmpi.w  #6,(%a6)                        | sau4 f80086e  0c56 0006
        beq.s   .Lf80087a                       | sau4 f800872  6706
        cmpi.w  #8,(%a6)                        | sau4 f800874  0c56 0008
        bne.s   dump_tables                     | sau4 f800878  6650
.Lf80087a:
        lea     (CRASH_STATUS).l,%a3            | sau4 f80087a  47f9 0f81 fe48
        suba.l  %a4,%a3                         | sau4 f800880  97cc
        adda.l  %d7,%a3                         | sau4 f800882  d7c7
        move.l  (%a3),(0x3a8,%a5)               | sau4 f800884  2b53 03a8
        moveq   #0,%d0                          | sau4 f800888  7000
        bsr.w   dump_send_request               | sau4 f80088a  6100 01b2
        btst    #5,(0x8003).l                   | sau4 f80088e  0839 0005 0000 8003
        beq.s   .Lf8008be                       | sau4 f800896  6726
        lea     (SERVER_$FLAG).l,%a3            | sau4 f800898  47f9 0f81 fe5f
        suba.l  %a4,%a3                         | sau4 f80089e  97cc
        adda.l  %d7,%a3                         | sau4 f8008a0  d7c7
        tst.b   (%a3)                           | sau4 f8008a2  4a13
        beq.s   .Lf8008be                       | sau4 f8008a4  6718
        movea.l (0x1c,%a6),%a1                  | sau4 f8008a6  226e 001c
        btst    #6,(0xa,%a1)                    | sau4 f8008aa  0829 0006 000a
        st      (0x20,%a6)                      | sau4 f8008b0  50ee 0020
        btst    #7,(0xa,%a1)                    | sau4 f8008b4  0829 0007 000a
        beq.w   dump_done                       | sau4 f8008ba  6700 0122
.Lf8008be:
        movea.l (0x1c,%a6),%a1                  | sau4 f8008be  226e 001c
        lea     (0xc,%a1),%a0                   | sau4 f8008c2  41e9 000c
        bsr.w   dump_puts                       | sau4 f8008c6  6100 0282
dump_tables:
        lea     (DUMP_TABLES_PHYS).l,%a4        | sau4 f8008ca  49f9 0020 2800
        move.l  %a4,%d7                         | sau4 f8008d0  2e0c
        lea     (0x9000).l,%a3                  | sau4 f8008d2  47f9 0000 9000
.Lf8008d8:
        move.w  (%a3)+,(%a4)+                   | sau4 f8008d8  38db
        cmpa.l  #0x9200,%a3                     | sau4 f8008da  b7fc 0000 9200
        bne.s   .Lf8008d8                       | sau4 f8008e0  66f6
        move.w  (0xc,%a6),(-0x1fc,%a4)          | sau4 f8008e2  396e 000c fe04
        move.w  #4,(-0x1fe,%a4)                 | sau4 f8008e8  397c 0004 fe02
        btst    #0,(0x8002).l                   | sau4 f8008ee  0839 0000 0000 8002
        bne.s   .Lf80094e                       | sau4 f8008f6  6656
        clr.w   (%a4)+                          | sau4 f8008f8  425c
        move.w  (0xe,%a6),(%a4)+                | sau4 f8008fa  38ee 000e
        movea.l (0x138).w,%a0                   | sau4 f8008fe  2078 0138
        jsr     (%a0)                           | sau4 f800902  4e90
        move.l  %a4,-(%sp)                      | sau4 f800904  2f0c
        move.l  #0x120,-(%sp)                   | sau4 f800906  2f3c 0000 0120
        move.w  #0xe40,-(%sp)                   | sau4 f80090c  3f3c 0e40
        movea.l (0x134).w,%a0                   | sau4 f800910  2078 0134
        moveq   #31,%d5                         | sau4 f800914  7a1f
.Lf800916:
        jsr     (%a0)                           | sau4 f800916  4e90
        addq.w  #4,(0x8,%sp)                    | sau4 f800918  586f 0008
        addq.w  #1,(0x4,%sp)                    | sau4 f80091c  526f 0004
        dbf     %d5,.Lf800916                   | sau4 f800920  51cd fff4
        addq.l  #6,%sp                          | sau4 f800924  5c8f
        move.w  #0xc0c,-(%sp)                   | sau4 f800926  3f3c 0c0c
        jsr     (%a0)                           | sau4 f80092a  4e90
        addq.w  #4,(0x4,%sp)                    | sau4 f80092c  586f 0004
        move.w  #0xc0e,(%sp)                    | sau4 f800930  3ebc 0c0e
        jsr     (%a0)                           | sau4 f800934  4e90
        addq.w  #4,(0x4,%sp)                    | sau4 f800936  586f 0004
        move.w  #0xc04,(%sp)                    | sau4 f80093a  3ebc 0c04
        jsr     (%a0)                           | sau4 f80093e  4e90
        addq.w  #4,(0x4,%sp)                    | sau4 f800940  586f 0004
        move.w  #0x8008,(%sp)                   | sau4 f800944  3ebc 8008
        jsr     (%a0)                           | sau4 f800948  4e90
        addq.l  #6,%sp                          | sau4 f80094a  5c8f
        bra.s   dump_ranges                     | sau4 f80094c  601e
.Lf80094e:
        move.w  #0xff00,(%a4)+                  | sau4 f80094e  38fc ff00
        move.w  (0xe,%a6),(%a4)+                | sau4 f800952  38ee 000e
        movea.l #0x120,%a3                      | sau4 f800956  267c 0000 0120
        .short  0x4e7b, 0xb116                  | sau4 f80095c  4e7b b116  movec %a3,0x116
        moveq   #31,%d5                         | sau4 f800960  7a1f
.Lf800962:
        .short  0x4e7a, 0xb115                  | sau4 f800962  4e7a b115  movec 0x115,%a3
        move.l  %a3,(%a4)+                      | sau4 f800966  28cb
        dbf     %d5,.Lf800962                   | sau4 f800968  51cd fff8
dump_ranges:
        clr.l   (0x3a8,%a5)                     | sau4 f80096c  42ad 03a8
        bsr.w   dump_send_page                  | sau4 f800970  6100 00c2
        moveq   #31,%d5                         | sau4 f800974  7a1f
        move.w  %d5,%d2                         | sau4 f800976  3405
        lea     (DUMP_$ADDRS:w,%pc),%a3         | sau4 f800978  47fa 0272
dump_range_loop:
        move.l  (%a3)+,%d3                      | sau4 f80097c  261b
        beq.s   dump_finish                     | sau4 f80097e  6744
        move.l  (%a3)+,%d4                      | sau4 f800980  281b
dump_page_loop:
        move.l  %d3,%d7                         | sau4 f800982  2e03
        bsr.w   dump_page                       | sau4 f800984  6100 0016
        cmpi.w  #1,(%a6)                        | sau4 f800988  0c56 0001
        bne.s   .Lf800996                       | sau4 f80098c  6608
        cmpi.w  #0x4d0,(0x3aa,%a5)              | sau4 f80098e  0c6d 04d0 03aa
        bge.s   dump_finish                     | sau4 f800994  6c2e
.Lf800996:
        cmp.l   %d3,%d4                         | sau4 f800996  b883
        bge.s   dump_page_loop                  | sau4 f800998  6ce8
        bra.s   dump_range_loop                 | sau4 f80099a  60e0
dump_page:
        addq.l  #1,(0x3a8,%a5)                  | sau4 f80099c  52ad 03a8
        bsr.w   dump_send_page                  | sau4 f8009a0  6100 0092
        dbf     %d5,.Lf8009bc                   | sau4 f8009a4  51cd 0016
        move.b  #0x21,%d1                       | sau4 f8009a8  123c 0021
        bsr.w   dump_putc                       | sau4 f8009ac  6100 01c2
        moveq   #31,%d5                         | sau4 f8009b0  7a1f
        dbf     %d2,.Lf8009bc                   | sau4 f8009b2  51ca 0008
        bsr.w   dump_put_nl                     | sau4 f8009b6  6100 018e
        move.w  %d5,%d2                         | sau4 f8009ba  3405
.Lf8009bc:
        .short  0xd6bc, 0x0000, 0x0400          | sau4 f8009bc  d6bc 0000 0400  add.l   #0x400,%d3
        rts                                     | sau4 f8009c2  4e75
dump_finish:
        lea     (dump_str_done:w,%pc),%a0       | sau4 f8009c4  41fa 0215
        bsr.w   dump_puts_nl                    | sau4 f8009c8  6100 017a
        cmpi.w  #2,(%a6)                        | sau4 f8009cc  0c56 0002
        beq.s   dump_done                       | sau4 f8009d0  670c
        cmpi.w  #6,(%a6)                        | sau4 f8009d2  0c56 0006
        beq.s   dump_done                       | sau4 f8009d6  6706
        cmpi.w  #8,(%a6)                        | sau4 f8009d8  0c56 0008
        bne.s   .Lf8009ea                       | sau4 f8009dc  660c
dump_done:
        moveq   #4,%d0                          | sau4 f8009de  7004
        cmp.b   (dump_pkt_op:w,%pc),%d0         | sau4 f8009e0  b03a 01c5
        beq.s   .Lf8009ea                       | sau4 f8009e4  6704
        bsr.w   dump_send_request               | sau4 f8009e6  6100 0056
.Lf8009ea:
        tst.b   (0x20,%a6)                      | sau4 f8009ea  4a2e 0020
        beq.s   dump_quiet                      | sau4 f8009ee  671c
dump_reboot:
        move.w  #0x7d0,%d0                      | sau4 f8009f0  303c 07d0
dump_reboot_wait:
        mulu.w  #3,%d2                          | sau4 f8009f4  c4fc 0003
        dbf     %d0,dump_reboot_wait            | sau4 f8009f8  51c8 fffa
        reset                                   | sau4 f8009fc  4e70
        movea.l (0x0).w,%sp                     | sau4 f8009fe  2e78 0000
        ori.w   #0x2700,%sr                     | sau4 f800a02  007c 2700
        movea.l (0x4).w,%a0                     | sau4 f800a06  2078 0004
        jmp     (%a0)                           | sau4 f800a0a  4ed0
dump_quiet:
        movea.l (0x11c).w,%a0                   | sau4 f800a0c  2078 011c
        jmp     (%a0)                           | sau4 f800a10  4ed0
DUMP_$AUTO_REBOOT:
        lea     (DUMP:w,%pc),%a5                | sau4 f800a12  4bfa fdec
        lea     (DUMP_STACK_PHYS).l,%sp         | sau4 f800a16  4ff9 0020 2e00
        movea.l %sp,%a6                         | sau4 f800a1c  2c4f
        lea     (dump_str_rebooting:w,%pc),%a0  | sau4 f800a1e  41fa 01ae
        bsr.w   dump_puts_nl                    | sau4 f800a22  6100 0120
        move.w  #0x2000,%d0                     | sau4 f800a26  303c 2000
dump_auto_reboot_wait:
        mulu.w  #3,%d2                          | sau4 f800a2a  c4fc 0003
        dbf     %d0,dump_auto_reboot_wait       | sau4 f800a2e  51c8 fffa
        bra.s   dump_reboot                     | sau4 f800a32  60bc
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | sau4 f800a34  48e7 ff78
        moveq   #2,%d0                          | sau4 f800a38  7002
        move.l  %d6,%d1                         | sau4 f800a3a  2206
        bra.s   dump_xfer                       | sau4 f800a3c  6008
dump_send_request:
        movem.l %d0-%d7/%a1-%a4,-(%sp)          | sau4 f800a3e  48e7 ff78
        clr.w   %d1                             | sau4 f800a42  4241
        move.l  %a5,%d7                         | sau4 f800a44  2e0d
dump_xfer:
        move.w  %d1,(0x394,%a5)                 | sau4 f800a46  3b41 0394
        move.b  %d0,(0x3a7,%a5)                 | sau4 f800a4a  1b40 03a7
        move.l  %d7,%d0                         | sau4 f800a4e  2007
        lsr.l   #8,%d0                          | sau4 f800a50  e088
        lsr.l   #2,%d0                          | sau4 f800a52  e488
        move.w  %d0,(0xa,%a6)                   | sau4 f800a54  3d40 000a
        move.w  #0xa,(0x8,%a6)                  | sau4 f800a58  3d7c 000a 0008
dump_xfer_send:
        pea     (0x4,%a6)                       | sau4 f800a5e  486e 0004
        pea     (dump_peer_id:w,%pc)            | sau4 f800a62  487a 011c
        pea     (0xa,%a6)                       | sau4 f800a66  486e 000a
        pea     (dump_pkt_seq:w,%pc)            | sau4 f800a6a  487a 013c
        movea.l (0x120).w,%a0                   | sau4 f800a6e  2078 0120
        jsr     (%a0)                           | sau4 f800a72  4e90
        adda.w  #0x10,%sp                       | sau4 f800a74  defc 0010
        move.l  (0x4,%a6),%d0                   | sau4 f800a78  202e 0004
        beq.s   dump_xfer_sent                  | sau4 f800a7c  6714
        subq.w  #1,(0x8,%a6)                    | sau4 f800a7e  536e 0008
        bne.s   dump_xfer_send                  | sau4 f800a82  66da
        lea     (dump_str_xbad:w,%pc),%a0       | sau4 f800a84  41fa 0128
        bra.w   dump_xfer_fail                  | sau4 f800a88  6000 00aa
dump_xfer_return:
        movem.l (%sp)+,%d0-%d7/%a1-%a4          | sau4 f800a8c  4cdf 1eff
        rts                                     | sau4 f800a90  4e75
dump_xfer_sent:
        cmpi.w  #1,(%a6)                        | sau4 f800a92  0c56 0001
        beq.s   dump_xfer_return                | sau4 f800a96  67f4
dump_xfer_receive:
        move.w  #3,(0x8,%a6)                    | sau4 f800a98  3d7c 0003 0008
        pea     (0x4,%a6)                       | sau4 f800a9e  486e 0004
        move.l  #DUMP_RCV_BUF,-(%sp)            | sau4 f800aa2  2f3c 0020 2e22
        pea     (dump_rcv_len:w,%pc)            | sau4 f800aa8  487a 0102
        pea     (dump_pkt_seq:w,%pc)            | sau4 f800aac  487a 00fa
        movea.l (0x110).w,%a0                   | sau4 f800ab0  2078 0110
        jsr     (%a0)                           | sau4 f800ab4  4e90
        adda.w  #0x10,%sp                       | sau4 f800ab6  defc 0010
        move.l  (0x4,%a6),%d0                   | sau4 f800aba  202e 0004
        beq.s   dump_xfer_reply                 | sau4 f800abe  670c
        subq.w  #1,(0x8,%a6)                    | sau4 f800ac0  536e 0008
        bne.s   dump_xfer_send                  | sau4 f800ac4  6698
        lea     (dump_str_rbad:w,%pc),%a0       | sau4 f800ac6  41fa 00eb
        bra.s   dump_xfer_fail                  | sau4 f800aca  6068
dump_xfer_reply:
        lea     (0x22,%a6),%a0                  | sau4 f800acc  41ee 0022
        move.l  (dump_peer_id:w,%pc),%d0        | sau4 f800ad0  203a 00ae
        cmp.l   (0x8,%a0),%d0                   | sau4 f800ad4  b0a8 0008
        bne.s   dump_xfer_receive               | sau4 f800ad8  66be
        lea     (0x1e,%a0),%a1                  | sau4 f800ada  43e8 001e
        clr.l   %d0                             | sau4 f800ade  4280
        move.b  (0x18,%a0),%d0                  | sau4 f800ae0  1028 0018
        adda.l  %d0,%a1                         | sau4 f800ae4  d3c0
        move.l  %a1,(0x1c,%a6)                  | sau4 f800ae6  2d49 001c
        cmpi.w  #2,(%a1)                        | sau4 f800aea  0c51 0002
        bne.s   dump_xfer_bad_type              | sau4 f800aee  6614
        cmpi.w  #1,(0x2,%a1)                    | sau4 f800af0  0c69 0001 0002
        bne.s   dump_xfer_bad_type              | sau4 f800af6  660c
        move.b  (0x5,%a1),%d0                   | sau4 f800af8  1029 0005
        subq.l  #1,%d0                          | sau4 f800afc  5380
        cmp.b   (dump_pkt_op:w,%pc),%d0         | sau4 f800afe  b03a 00a7
        beq.s   dump_xfer_check_seq             | sau4 f800b02  6714
dump_xfer_bad_type:
        cmpi.b  #7,(0x5,%a1)                    | sau4 f800b04  0c29 0007 0005
        bne.s   dump_xfer_bad_reply             | sau4 f800b0a  6602
dump_xfer_retry:
        bra.s   dump_xfer_receive               | sau4 f800b0c  608a
dump_xfer_bad_reply:
        lea     (dump_str_bad_rpy:w,%pc),%a0    | sau4 f800b0e  41fa 00a8
        bsr.s   dump_puts                       | sau4 f800b12  6136
dump_xfer_abort:
        bra.w   dump_done                       | sau4 f800b14  6000 fec8
dump_xfer_check_seq:
        .short  0xb03c, 0x0002                  | sau4 f800b18  b03c 0002  cmp.b   #2,%d0
        bne.s   dump_xfer_check_status          | sau4 f800b1c  660a
        move.l  (dump_pkt_seq:w,%pc),%d0        | sau4 f800b1e  203a 0088
        cmp.l   (0xc,%a1),%d0                   | sau4 f800b22  b0a9 000c
        bne.s   dump_xfer_retry                 | sau4 f800b26  66e4
dump_xfer_check_status:
        move.l  (0x6,%a1),%d0                   | sau4 f800b28  2029 0006
        beq.w   dump_xfer_return                | sau4 f800b2c  6700 ff5e
        lea     (dump_str_nm_sad:w,%pc),%a0     | sau4 f800b30  41fa 008e
dump_xfer_fail:
        move.l  %d0,-(%sp)                      | sau4 f800b34  2f00
        bsr.s   dump_puts                       | sau4 f800b36  6112
        lea     (dump_str_st:w,%pc),%a0         | sau4 f800b38  41fa 008d
        bsr.s   dump_puts                       | sau4 f800b3c  610c
        move.l  (%sp)+,%d0                      | sau4 f800b3e  201f
        bsr.s   dump_put_hex_nl                 | sau4 f800b40  6112
        bra.s   dump_xfer_abort                 | sau4 f800b42  60d0
dump_puts_nl:
        bsr.s   dump_puts                       | sau4 f800b44  6104
dump_put_nl:
        lea     (dump_str_nl:w,%pc),%a0         | sau4 f800b46  41fa 0090
dump_puts:
        move.b  (%a0)+,%d1                      | sau4 f800b4a  1218
        beq.s   dump_rts                        | sau4 f800b4c  6730
        bsr.s   dump_putc                       | sau4 f800b4e  6120
        bra.s   dump_puts                       | sau4 f800b50  60f8
        rts                                     | sau4 f800b52  4e75
dump_put_hex_nl:
        moveq   #7,%d2                          | sau4 f800b54  7407
dump_put_hex_digit:
        rol.l   #4,%d0                          | sau4 f800b56  e998
        moveq   #15,%d1                         | sau4 f800b58  720f
        and.b   %d0,%d1                         | sau4 f800b5a  c200
        .short  0xb23c, 0x000a                  | sau4 f800b5c  b23c 000a  cmp.b   #0xa,%d1
        blt.s   dump_put_hex_ascii              | sau4 f800b60  6d02
        addq.b  #7,%d1                          | sau4 f800b62  5e01
dump_put_hex_ascii:
        .short  0xd23c, 0x0030                  | sau4 f800b64  d23c 0030  add.b   #0x30,%d1
        bsr.s   dump_putc                       | sau4 f800b68  6106
        dbf     %d2,dump_put_hex_digit          | sau4 f800b6a  51ca ffea
        bra.s   dump_put_nl                     | sau4 f800b6e  60d6
dump_putc:
        movem.l %d0-%a4,-(%sp)                  | sau4 f800b70  48e7 fff8
        movea.l (0x108).w,%a0                   | sau4 f800b74  2078 0108
        jsr     (%a0)                           | sau4 f800b78  4e90
        movem.l (%sp)+,%d0-%a4                  | sau4 f800b7a  4cdf 1fff
dump_rts:
        rts                                     | sau4 f800b7e  4e75

/*
 * 0xF800B80: the cells, laid out as the SAU3's (dump/sau3/dump.s): the
 * packet the PROM send/receive vectors take (dump_pkt_seq is its first
 * argument) with its length word and op byte just ahead of it; the peer
 * id the reply must carry; the receive length (0x800 here); the messages;
 * the flags; and the map's three public cells.
 */
dump_peer_id:
        .long   0                       /* f800b80 */
        .long   0, 0                    /* f800b84 */
        .byte   0x01, 0x01, 0x00, 0x00  /* f800b8c */
        .byte   0x00, 0x2c, 0x00, 0x0a  /* f800b90 */
dump_pkt_len:
        .short  0x0000                  /* f800b94 */
        .short  0x0000                  /* f800b96 */
        .byte   0x04, 0x01, 0x00, 0x00  /* f800b98 */
        .byte   0x00, 0x00, 0x00, 0x00  /* f800b9c */
        .byte   0x00, 0x03, 0x00, 0x02  /* f800ba0 */
        .byte   0x00, 0x01, 0x04        /* f800ba4 */
dump_pkt_op:
        .byte   0x00                    /* f800ba7 */
dump_pkt_seq:
        .long   0                       /* f800ba8 */
dump_rcv_len:
        .short  0x0800                  /* f800bac */
dump_str_xbad:
        .asciz  "Xbad"                  /* f800bae */
dump_str_rbad:
        .asciz  "Rbad"                  /* f800bb3 */
dump_str_bad_rpy:
        .asciz  "Bad rpy"               /* f800bb8 */
dump_str_nm_sad:
        .asciz  "Nm sad"                /* f800bc0 */
dump_str_st:
        .asciz  " - St="                /* f800bc7 */
dump_str_rebooting:
        .asciz  "REBOOTING"             /* f800bce  DUMP_$AUTO_REBOOT's message */
dump_str_nl:
        .byte   0x0a, 0x0d, 0x00        /* f800bd8 */
dump_str_done:
        .byte   0x0a, 0x0d              /* f800bdb */
        .asciz  "Done"
dump_flags:
        .short  0x0078                  /* f800be2  bit 0: entered before */
DUMP_$SMAP_PHADDR:
        .long   0x00000000                      | sau4 f800be4  00000000
DUMP_$RARS_PHADDR:
        .long   0x00000000                      | sau4 f800be8  00000000
DUMP_$ADDRS:
        .long   0x00200000                      | sau4 f800bec  00200000
        .long   0x0027fc00                      | sau4 f800bf0  0027fc00
        .long   0x00000000                      | sau4 f800bf4  00000000
        .long   0x00000000                      | sau4 f800bf8  00000000
        .long   0x00000000                      | sau4 f800bfc  00000000
