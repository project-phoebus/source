/*
 * ring/m68k/ring_asm.s - RING_ASM: RING_$RB_FROM and RING_$RB_TO, the
 * ring controller's buffer copies (SAU7, SAU8, SAU9)
 *
 * The SAU7, SAU8 and SAU9 images have the same bytes here; the address and
 * byte columns below are the SAU9 image's (map: "D 3C49F6B0 RING_ASM size
 * = 98" in RING_DATA, RING_$RB_FROM 0x3C49F6B0, RING_$RB_TO 0x3C49F6FA).
 * Only the SAUs whose ring controller keeps its own packet buffers have
 * them (`ring8_controller', base/config.ins.pas).
 *
 * RING_$RB_FROM(csr, addr, buf, count) / RING_$RB_TO(csr, addr, buf,
 * count): the arguments by value off SP (no frame): 4(SP) the
 * controller's CSR page, 8(SP) a word, the buffer address in the
 * controller's memory, 10(SP) the host buffer, 14(SP) the word count.
 * The controller's buffer port is at CSR + 0x1000: the address goes to
 * +6, byte-swapped (`rol.w #8'), and the words move through the data
 * port at +0x406, four a turn with an entry by the count's remainder.
 * RING_$RB_FROM reads the data port once before the copy (the first read
 * after the address is set returns nothing new); RING_$RB_TO refuses a
 * count over 0x400 words.  A count of 0 does nothing.
 *
 * Hand-written: no frame, the arguments read off SP, an unrolled copy.
 * The Apollo assembler's `cmp.w #imm,Dn' (<ea>=#imm, 0xB07C), which gas
 * spells cmpi, is written as `.short'.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
 * the image's bytes.
 */

        .include "base/config.inc"
        .if     ring8_controller

        .section ".text.RING_$RB_FROM","ax",@progbits
        .even

        .globl  RING_$RB_FROM
        .globl  RING_$RB_TO

RING_$RB_FROM:
        movea.l (4,%sp),%a0                     | 3c49f6b0  206f 0004  the CSR page
        lea     (0x1000,%a0),%a0                | 3c49f6b4  41e8 1000  the buffer port
        tst.w   (14,%sp)                        | 3c49f6b8  4a6f 000e  no words?
        beq.b   .Lfrom_done                     | 3c49f6bc  673a
        move.w  (8,%sp),%d0                     | 3c49f6be  302f 0008  the address,
        rol.w   #8,%d0                          | 3c49f6c2  e158       byte-swapped
        move.w  %d0,(6,%a0)                     | 3c49f6c4  3140 0006
        move.w  (0x406,%a0),%d1                 | 3c49f6c8  3228 0406  a dummy read
        move.w  (14,%sp),%d1                    | 3c49f6cc  322f 000e  the count
        movea.l (10,%sp),%a1                    | 3c49f6d0  226f 000a  the host buffer
        lea     (0x406,%a0),%a0                 | 3c49f6d4  41e8 0406  the data port
        moveq   #3,%d0                          | 3c49f6d8  7003
        and.w   %d1,%d0                         | 3c49f6da  c041  count mod 4
        lsr.w   #2,%d1                          | 3c49f6dc  e449  count div 4
        tst.w   %d0                             | 3c49f6de  4a40
        beq.b   .Lfrom_next                     | 3c49f6e0  6712
        .short  0xb07c, 0x0002                  | 3c49f6e2  b07c 0002  cmp.w #2,%d0
        blt.b   .Lfrom_1                        | 3c49f6e6  6d0a
        beq.b   .Lfrom_2                        | 3c49f6e8  6706
        bra.b   .Lfrom_3                        | 3c49f6ea  6002
.Lfrom_4:
        move.w  (%a0),(%a1)+                    | 3c49f6ec  32d0
.Lfrom_3:
        move.w  (%a0),(%a1)+                    | 3c49f6ee  32d0
.Lfrom_2:
        move.w  (%a0),(%a1)+                    | 3c49f6f0  32d0
.Lfrom_1:
        move.w  (%a0),(%a1)+                    | 3c49f6f2  32d0
.Lfrom_next:
        dbf     %d1,.Lfrom_4                    | 3c49f6f4  51c9 fff6
.Lfrom_done:
        rts                                     | 3c49f6f8  4e75

RING_$RB_TO:
        movea.l (4,%sp),%a0                     | 3c49f6fa  206f 0004
        lea     (0x1000,%a0),%a0                | 3c49f6fe  41e8 1000
        tst.w   (14,%sp)                        | 3c49f702  4a6f 000e
        beq.b   .Lto_done                       | 3c49f706  673e
        cmpi.w  #0x400,(14,%sp)                 | 3c49f708  0c6f 0400 000e  over 0x400 words?
        bhi.b   .Lto_done                       | 3c49f70e  6236
        move.w  (8,%sp),%d0                     | 3c49f710  302f 0008
        rol.w   #8,%d0                          | 3c49f714  e158
        move.w  %d0,(6,%a0)                     | 3c49f716  3140 0006
        move.w  (14,%sp),%d1                    | 3c49f71a  322f 000e
        movea.l (10,%sp),%a1                    | 3c49f71e  226f 000a
        lea     (0x406,%a0),%a0                 | 3c49f722  41e8 0406
        moveq   #3,%d0                          | 3c49f726  7003
        and.w   %d1,%d0                         | 3c49f728  c041
        lsr.w   #2,%d1                          | 3c49f72a  e449
        tst.w   %d0                             | 3c49f72c  4a40
        beq.b   .Lto_next                       | 3c49f72e  6712
        .short  0xb07c, 0x0002                  | 3c49f730  b07c 0002  cmp.w #2,%d0
        blt.b   .Lto_1                          | 3c49f734  6d0a
        beq.b   .Lto_2                          | 3c49f736  6706
        bra.b   .Lto_3                          | 3c49f738  6002
.Lto_4:
        move.w  (%a1)+,(%a0)                    | 3c49f73a  3099
.Lto_3:
        move.w  (%a1)+,(%a0)                    | 3c49f73c  3099
.Lto_2:
        move.w  (%a1)+,(%a0)                    | 3c49f73e  3099
.Lto_1:
        move.w  (%a1)+,(%a0)                    | 3c49f740  3099
.Lto_next:
        dbf     %d1,.Lto_4                      | 3c49f742  51c9 fff6
.Lto_done:
        rts                                     | 3c49f746  4e75

        .endif
