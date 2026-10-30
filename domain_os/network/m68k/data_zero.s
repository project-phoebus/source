/*
 * network/m68k/data_zero.s - OS_$DATA_ZERO (m68k / SAU2, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'):
 * encodings identical to the image.
 *
 * The last routine of the hand-written NETWORK_ASM segment (SAU2 map:
 * "I E11EF0 NETWORK_ASM size = B8"), 0x00E11F42..0x00E11FA7, up to
 * PAS_$SET_BUILD (0xE11FA8).
 *
 * Hand assembly (os/os.ins.pas): the zeros are stored from `move.b
 * #0x0,(A1)+' and `move.w #0x0,(A1)+' immediates and from A0 loaded with
 * an unrelocated `movea.l #0x0,A0', forms compiled code does not use.
 * It has a `link #0' frame.
 *
 * The heading Pascal callers use is os/os.ins.pas's
 *   procedure os_$data_zero(out dst: univ os_$data_t; len: integer32);
 *                           val_param;
 * (0x8,A6) the destination's address, (0xC,A6) the byte count by value.
 *
 * What it does: nothing for a zero length; else one byte first if the
 * destination is odd, then (len - 4) div 4 + 1 longwords, with `dbf'
 * when that count fits a word and a `subq.l/bpl' loop otherwise, then a
 * word if bit 1 of the remaining length is set and a byte if bit 0 is.
 * The bits are tested in D1, the length after the odd byte, before the
 * longword count is taken from it.
 *
 * The seven words at 0x00E11F9A..0x00E11FA7 are a byte loop that nothing
 * reaches (no branch targets them; the `bmi.b' and `bra.b' in them lead
 * back to the exit): the image's bytes, kept as code.
 *
 * The `cmpi.l #0xffff,D0' at 0x00E11F6C is gas's own encoding (0c80).
 */

        .section ".text.OS_$DATA_ZERO","ax",@progbits
        .even

        .globl  OS_$DATA_ZERO
OS_$DATA_ZERO:
        link.w  %a6,#0                          /* e11f42  4e56 0000        */
        move.l  (0xc,%a6),%d0                   /* e11f46  202e 000c  len   */
        beq.b   .Lexit                          /* e11f4a  674a             */
        movea.l (0x8,%a6),%a1                   /* e11f4c  226e 0008  dst   */
        movea.l #0,%a0                          /* e11f50  207c 0000 0000   */
        move.l  %a1,%d1                         /* e11f56  2209             */
        btst    #0,%d1                          /* e11f58  0801 0000        */
        beq.b   .Leven                          /* e11f5c  6706             */
        move.b  #0,(%a1)+                       /* e11f5e  12fc 0000        */
        subq.l  #1,%d0                          /* e11f62  5380             */
.Leven:
        move.l  %d0,%d1                         /* e11f64  2200             */
        subq.l  #4,%d0                          /* e11f66  5980             */
        bmi.b   .Ltail                          /* e11f68  6b18             */
        lsr.l   #2,%d0                          /* e11f6a  e488             */
        cmpi.l  #0xffff,%d0                     /* e11f6c  0c80 0000 ffff   */
        bls.b   .Ldbf                           /* e11f72  6308             */
.Lbig:
        move.l  %a0,(%a1)+                      /* e11f74  22c8             */
        subq.l  #1,%d0                          /* e11f76  5380             */
        bpl.b   .Lbig                           /* e11f78  6afa             */
        bra.b   .Ltail                          /* e11f7a  6006             */
.Ldbf:
        move.l  %a0,(%a1)+                      /* e11f7c  22c8             */
        dbf     %d0,.Ldbf                       /* e11f7e  51c8 fffc        */
.Ltail:
        btst    #1,%d1                          /* e11f82  0801 0001        */
        beq.b   .Lnoword                        /* e11f86  6704             */
        move.w  #0,(%a1)+                       /* e11f88  32fc 0000        */
.Lnoword:
        btst    #0,%d1                          /* e11f8c  0801 0000        */
        beq.b   .Lexit                          /* e11f90  6704             */
        move.b  #0,(%a1)+                       /* e11f92  12fc 0000        */
.Lexit:
        unlk    %a6                             /* e11f96  4e5e             */
        rts                                     /* e11f98  4e75             */

/* Unreached (no branch in the image targets 0x00E11F9A). */
        subq.l  #1,%d0                          /* e11f9a  5380             */
        bmi.b   .Lexit                          /* e11f9c  6bf8             */
.Ldead:
        move.b  #0,(%a1)+                       /* e11f9e  12fc 0000        */
        dbf     %d0,.Ldead                      /* e11fa2  51c8 fffa        */
        bra.b   .Lexit                          /* e11fa6  60ee             */
