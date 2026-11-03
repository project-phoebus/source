|
| lpr/sau3/lpr_asm.s - LPR_ASM: the line printer port's interrupt
| routine, the copy into the circular buffer, the interrupt enable bits,
| and the driver's data and buffer
|
| SAU3 map: "D E841E0 LPR_ASM size = 2F4" in .DATA, after LPR_'s block
| (0xE8417C, 0x64 bytes) and before CBUF's (0xE844D4).  Its symbols,
| each defined here at its offset:
|
|   +0x000  LPR_$MOVE_DATA           copy a line into a buffer block
|   +0x02E  LPR_$INT                 the port's interrupt routine
|   +0x0D4  LPR_$DATA_MASK           the data mask (a word, set by
|                                    lpr_set_mode)
|   +0x0D6  LPR_$ENABLE_INT          set the port's interrupt enable
|   +0x0E0  LPR_$DISABLE_INT         clear it
|   +0x0EA  (no name)                the length of the block being sent
|   +0x0EC  LPR_$INT_EXPECTED        whether an interrupt is expected
|   +0x0EE  LPR_$UNEXP_INT_COUNT     a word nothing in the image writes
|   +0x0F0  LPR_$IR_START_COUNT      the count of interrupt starts
|   +0x0F2  LPR_$WRITE_TIMEOUT_FLAG  a word nothing in the image writes
|   +0x0F4  LPR_$BUFFER              the circular buffer, 512 bytes
|
| LPR_$DATA_END (0xE844D7) is not this file's: a mark three bytes into
| CBUF's block, the end of the driver's wired data range.
|
| Hand-written (the `_ASM' segment, code in a data section; the routines
| have no frame and read their arguments off the stack):
|
| - LPR_$MOVE_DATA: three addresses, the source, the destination
|   pointer's and the length's (LPR_$WRITE's call); words when the
|   destination is even, bytes otherwise.
| - LPR_$INT (the level 5 autovector, LPR_VEC): the scratch registers
|   saved, IO_$USE_INT_STACK called at IPL 6.  When the port's status
|   bit 0 differs from the mask's (the port is ready), the next block of
|   LPR_$BCB is sent byte by byte, each XORed with the mask, waiting up
|   to 101 polls of the ready bit for each, then released; with no block
|   the expected flag is cleared and the interrupt disabled.  When the
|   port is not ready, a zero byte is written if its ready bit is set.
|   It leaves through PROC1_$INT_EXIT.
| - LPR_$ENABLE_INT, LPR_$DISABLE_INT: bit 1 of the register at 0x0C.
|
| The SAU4's LPR_ASM is another form (0x2C4 bytes; only LPR_$MOVE_DATA
| is the same code, tools/sau_catalog.py); the other SAUs' LPR_ASM is
| the 4-byte LPR_$RELEASE stub (lpr/m68k/release.s).
|
| Byte check: assembled with `m68k-elf-as -m68000', linked at 0xE841E0
| with the map's addresses for the other symbols, and compared with the
| image's 0x2F4 bytes (the SAU3 build is not linked yet).
|
        .section ".text.LPR_$MOVE_DATA","ax",@progbits
        .even

        .globl  LPR_$MOVE_DATA
        .globl  LPR_$INT
        .globl  LPR_$DATA_MASK
        .globl  LPR_$ENABLE_INT
        .globl  LPR_$DISABLE_INT
        .globl  LPR_$INT_EXPECTED
        .globl  LPR_$UNEXP_INT_COUNT
        .globl  LPR_$IR_START_COUNT
        .globl  LPR_$WRITE_TIMEOUT_FLAG
        .globl  LPR_$BUFFER

LPR_$MOVE_DATA:                         | 0xE841E0
        movea.l (4,%sp),%a0             | e841e0  206f 0004  the source
        movea.l (12,%sp),%a1            | e841e4  226f 000c
        move.w  (%a1),%d0               | e841e8  3011       the length
        movea.l (8,%sp),%a1             | e841ea  226f 0008
        movea.l (%a1),%a1               | e841ee  2251       the destination
        btst    #0,(7,%sp)              | e841f0  082f 0000 0007
        beq.s   .Lwords                 | e841f6  670a
        subq.w  #1,%d0                  | e841f8  5340
.Lbytes:
        move.b  (%a0)+,(%a1)+           | e841fa  12d8
        dbf     %d0,.Lbytes             | e841fc  51c8 fffc
        rts                             | e84200  4e75
.Lwords:
        subq.w  #1,%d0                  | e84202  5340
        lsr.w   #1,%d0                  | e84204  e248
.Lwloop:
        move.w  (%a0)+,(%a1)+           | e84206  32d8
        dbf     %d0,.Lwloop             | e84208  51c8 fffc
        rts                             | e8420c  4e75

LPR_$INT:                               | 0xE8420E
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | e8420e  48e7 c0c0
        move.w  %sr,%d0                 | e84212  40c0
        ori.w   #0x600,%sr              | e84214  007c 0600
        jsr     IO_$USE_INT_STACK       | e84218  4eb9 00e2 d426
        move.w  %d0,%sr                 | e8421e  46c0
        move.l  %d2,-(%sp)              | e84220  2f02
        move.w  (LPR_$DATA_MASK,%pc),%d2  | e84222  343a 0090
        move.b  LPR+0x18,%d0            | e84226  1039 00ff 8018
        eor.w   %d2,%d0                 | e8422c  b540
        btst    #0,%d0                  | e8422e  0800 0000
        bne.s   .Lnot_ready             | e84232  666c
        pea     (.Llen,%pc)             | e84234  487a 0094
        move.l  #LPR_$BCB,-(%sp)        | e84238  2f3c 00e8 41a4
        jsr     CBUF_$READ_NEXT         | e8423e  4eb9 00e6 ecee
        addq.w  #8,%sp                  | e84244  504f
        move.l  %a0,%d0                 | e84246  2008
        beq.s   .Lidle                  | e84248  6746
        move.w  (.Llen,%pc),%d0         | e8424a  303a 007e
        subq.w  #1,%d0                  | e8424e  5340
.Lsend:
        btst    #0,LPR+0x1A             | e84250  0839 0000 00ff 801a
        bne.s   .Lput                   | e84258  6612
        moveq   #100,%d1                | e8425a  7264
.Lpoll:
        btst    #0,LPR+0x1A             | e8425c  0839 0000 00ff 801a
        bne.s   .Lput                   | e84264  6606
        dbf     %d1,.Lpoll              | e84266  51c9 fff4
        bra.s   .Lrelease               | e8426a  600e
.Lput:
        move.b  (%a0)+,%d1              | e8426c  1218
        eor.b   %d2,%d1                 | e8426e  b501
        move.b  %d1,LPR+0x10            | e84270  13c1 00ff 8010
        dbf     %d0,.Lsend              | e84276  51c8 ffd8
.Lrelease:
        move.l  #LPR_$BCB,-(%sp)        | e8427a  2f3c 00e8 41a4
        jsr     CBUF_$RELEASE           | e84280  4eb9 00e6 ed4e
        addq.w  #4,%sp                  | e84286  584f
.Lexit:
        move.l  (%sp)+,%d2              | e84288  241f
        jmp     PROC1_$INT_EXIT         | e8428a  4ef9 00e1 f836
.Lidle:
        lea     (LPR_$INT_EXPECTED,%pc),%a0  | e84290  41fa 003a
        clr.w   (%a0)                   | e84294  4250
        bclr    #1,LPR+0x0C             | e84296  08b9 0001 00ff 800c
        bra.s   .Lexit                  | e8429e  60e8
.Lnot_ready:
        btst    #0,LPR+0x1A             | e842a0  0839 0000 00ff 801a
        beq.s   .Lexit                  | e842a8  67de
        move.b  #0,LPR+0x10             | e842aa  13fc 0000 00ff 8010
        bra.s   .Lexit                  | e842b2  60d4

LPR_$DATA_MASK:                         | 0xE842B4
        .word   0                       | e842b4  0000

LPR_$ENABLE_INT:                        | 0xE842B6
        bset    #1,LPR+0x0C             | e842b6  08f9 0001 00ff 800c
        rts                             | e842be  4e75

LPR_$DISABLE_INT:                       | 0xE842C0
        bclr    #1,LPR+0x0C             | e842c0  08b9 0001 00ff 800c
        rts                             | e842c8  4e75

.Llen:                                  | 0xE842CA
        .word   0
LPR_$INT_EXPECTED:                      | 0xE842CC
        .word   0
LPR_$UNEXP_INT_COUNT:                   | 0xE842CE
        .word   0
LPR_$IR_START_COUNT:                    | 0xE842D0
        .word   0
LPR_$WRITE_TIMEOUT_FLAG:                | 0xE842D2
        .word   0
LPR_$BUFFER:                            | 0xE842D4
        .space  512                     | to 0xE844D4
