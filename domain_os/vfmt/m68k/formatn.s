/*
 * vfmt/m68k/formatn.s - VFMT_$FORMATN, the "format" procedure-variable thunk
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image.
 *
 * SAU2 map: "I E6B074 VFMT_$FORMATN size = 30" (.TEXT), 0x00E6B074..
 * 0x00E6B0A3: the thunk, 0x2E bytes, and a zero word to the segment's end;
 * VFMT_$WRITEN (vfmt/m68k/writen.s) follows at 0xE6B0A4.
 *
 * The format family's descriptor (vfmt/m68k/descriptors.s; map "D E825E4
 * VFMT_$FORMATN size = 10", VFMT_$FORMAT10 and five other names) is
 * `lea (-0x2,PC),A0; jmp VFMT_$FORMATN', then the installed routine,
 * VFMT_$MAIN (0xE6AB2A), at +0xA.  A caller `jsr's the descriptor, which
 * hands its own address to this thunk in A0.  The thunk calls the
 * installed routine with the caller's four arguments (format, buffer,
 * max length, out length) and the address of the fifth, the argument
 * list VFMT_$MAIN walks.
 *
 * Hand assembly (vfmt/README.md): the descriptor in A0,
 * `movea.l A0,A5' with A5 saved by a `move.l' rather than in a frame,
 * the call through (0xa,A5), and `adda.l #0x14,SP'.
 *
 *   00e6b074  4e56 0000       link.w A6,#0
 *   00e6b078  2f0d            move.l A5,-(SP)
 *   00e6b07a  2a48            movea.l A0,A5         A5 = the descriptor
 *   00e6b07c  486e 0018       pea (0x18,A6)         &args (arg 5 on)
 *   00e6b080  2f2e 0014       move.l (0x14,A6),-(SP)  arg 4
 *   00e6b084  2f2e 0010       move.l (0x10,A6),-(SP)  arg 3
 *   00e6b088  2f2e 000c       move.l (0xc,A6),-(SP)   arg 2
 *   00e6b08c  2f2e 0008       move.l (0x8,A6),-(SP)   arg 1
 *   00e6b090  206d 000a       movea.l (0xa,A5),A0   the installed routine
 *   00e6b094  4e90            jsr (A0)
 *   00e6b096  dffc 0000 0014  adda.l #0x14,SP
 *   00e6b09c  2a5f            movea.l (SP)+,A5
 *   00e6b09e  4e5e            unlk A6
 *   00e6b0a0  4e75            rts
 *   00e6b0a2  0000            (to the segment's end)
 *
 * `adda.l #0x14,SP' is the long-immediate form gas emits for that spelling
 * (dffc), as in the image.
 */

        .section ".text.VFMT_$FORMATN","ax",@progbits
        .even

        .globl  VFMT_$FORMATN
VFMT_$FORMATN:
        link.w  %a6,#0                          /* e6b074  4e56 0000       */
        move.l  %a5,-(%sp)                      /* e6b078  2f0d            */
        movea.l %a0,%a5                         /* e6b07a  2a48            */
        pea     (0x18,%a6)                      /* e6b07c  486e 0018       */
        move.l  (0x14,%a6),-(%sp)               /* e6b080  2f2e 0014       */
        move.l  (0x10,%a6),-(%sp)               /* e6b084  2f2e 0010       */
        move.l  (0xc,%a6),-(%sp)                /* e6b088  2f2e 000c       */
        move.l  (0x8,%a6),-(%sp)                /* e6b08c  2f2e 0008       */
        movea.l (0xa,%a5),%a0                   /* e6b090  206d 000a       */
        jsr     (%a0)                           /* e6b094  4e90            */
        adda.l  #0x14,%sp                       /* e6b096  dffc 0000 0014  */
        movea.l (%sp)+,%a5                      /* e6b09c  2a5f            */
        unlk    %a6                             /* e6b09e  4e5e            */
        rts                                     /* e6b0a0  4e75            */
        .word   0                               /* e6b0a2: to the segment's end */
