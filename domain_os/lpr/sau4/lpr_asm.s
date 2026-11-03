|
| lpr/sau4/lpr_asm.s - LPR_ASM: the PNA printer port's device routine,
| the copy into the circular buffer, and the driver's data and buffer
|
| SAU4 map: "D F893858 LPR_ASM size = 2C4" in .DATA, after LPR_'s block
| (0xF893808, 0x50 bytes) and before CBUF's (0xF893B1C).  Its symbols,
| each defined here at its offset:
|
|   +0x000  LPR_$MOVE_DATA           copy a line into a buffer block
|   +0x02E  LPR_$INT                 the PBU unit's device routine
|   +0x0BA  (no name)                the length of the block being sent
|   +0x0BC  LPR_$INT_EXPECTED        whether an interrupt is expected
|   +0x0BE  LPR_$UNEXP_INT_COUNT     a word nothing in the image writes
|   +0x0C0  LPR_$IR_START_COUNT      the count of interrupt starts
|   +0x0C2  LPR_$WRITE_TIMEOUT_FLAG  a word nothing in the image writes
|   +0x0C4  LPR_$BUFFER              the circular buffer, 512 bytes
|
| LPR_$DATA_END (0xF893B1F) is not this file's: a mark three bytes into
| CBUF's block, the end of the driver's wired data range.
|
| Hand-written (the `_ASM' segment, code in a data section; the routines
| have no frame and read their arguments off the stack):
|
| - LPR_$MOVE_DATA: the SAU3's (lpr/sau3/lpr_asm.s).
| - LPR_$INT, the printer's PBU unit's device routine (LPR_$ACQUIRE gives
|   it to PBU_$ACQUIRE_INT; PBU_$INT_COM calls it): with the port ready
|   (bit 5 of PBU_CTL's byte +5) the next block of LPR_$BCB is sent byte
|   by byte to PBU_CTL+1, waiting up to 101 polls of the ready bit 7 for
|   each, a zero byte after the block, then the block released, D0 = 1;
|   with no block the expected flag is cleared, PBU_CTL+7 given 12 and
|   13, and D0 = 0; with the port not ready a zero byte is sent, D0 = 1.
|   The DNx60's PNA (Domain Engineering Handbook, ch. 9-3: the line
|   printer controller on the node peripheral adapter, INT6).
|
| The SAU3's LPR_ASM is the port at LPR on the level 5 autovector, with
| the data mask and the interrupt enable routines; the other SAUs'
| LPR_ASM is the 4-byte LPR_$RELEASE stub (lpr/m68k/release.s).
|
| Byte check: assembled with `m68k-elf-as -m68010', linked at 0xF893858
| with the map's addresses for the other symbols, and compared with the
| image's 0x2C4 bytes.
|
        .section ".text.LPR_$MOVE_DATA","ax",@progbits
        .even

        .globl  LPR_$MOVE_DATA
        .globl  LPR_$INT
        .globl  LPR_$INT_EXPECTED
        .globl  LPR_$UNEXP_INT_COUNT
        .globl  LPR_$IR_START_COUNT
        .globl  LPR_$WRITE_TIMEOUT_FLAG
        .globl  LPR_$BUFFER

LPR_$MOVE_DATA:                         | 0xF893858
        movea.l (4,%sp),%a0             | f893858  206f 0004
        movea.l (12,%sp),%a1            | f89385c  226f 000c
        move.w  (%a1),%d0               | f893860  3011
        movea.l (8,%sp),%a1             | f893862  226f 0008
        movea.l (%a1),%a1               | f893866  2251
        btst    #0,(7,%sp)              | f893868  082f 0000 0007
        beq.s   .Lwords                 | f89386e  670a
        subq.w  #1,%d0                  | f893870  5340
.Lbytes:
        move.b  (%a0)+,(%a1)+           | f893872  12d8
        dbf     %d0,.Lbytes             | f893874  51c8 fffc
        rts                             | f893878  4e75
.Lwords:
        subq.w  #1,%d0                  | f89387a  5340
        lsr.w   #1,%d0                  | f89387c  e248
.Lwloop:
        move.w  (%a0)+,(%a1)+           | f89387e  32d8
        dbf     %d0,.Lwloop             | f893880  51c8 fffc
        rts                             | f893884  4e75

LPR_$INT:                               | 0xF893886
        btst    #5,PBU_CTL+5            | f893886  0839 0005 0ffe fc05
        beq.s   .Lnot_ready             | f89388e  6778
        pea     (.Llen,%pc)             | f893890  487a 0080
        move.l  #LPR_$BCB,-(%sp)        | f893894  2f3c 0f89 3830
        jsr     CBUF_$READ_NEXT         | f89389a  4eb9 0f87 bb2e
        addq.w  #8,%sp                  | f8938a0  504f
        move.l  %a0,%d0                 | f8938a2  2008
        beq.s   .Lidle                  | f8938a4  6748
        move.w  (.Llen,%pc),%d0         | f8938a6  303a 006a
        subq.w  #1,%d0                  | f8938aa  5340
.Lsend:
        btst    #7,PBU_CTL+5            | f8938ac  0839 0007 0ffe fc05
        bne.s   .Lput                   | f8938b4  6612
        moveq   #100,%d1                | f8938b6  7264
.Lpoll:
        btst    #7,PBU_CTL+5            | f8938b8  0839 0007 0ffe fc05
        bne.s   .Lput                   | f8938c0  6606
        dbf     %d1,.Lpoll              | f8938c2  51c9 fff4
        bra.s   .Lrelease               | f8938c6  6012
.Lput:
        move.b  (%a0)+,PBU_CTL+1        | f8938c8  13d8 0ffe fc01
        dbf     %d0,.Lsend              | f8938ce  51c8 ffdc
        move.b  #0,PBU_CTL+1            | f8938d2  13fc 0000 0ffe fc01
.Lrelease:
        move.l  #LPR_$BCB,-(%sp)        | f8938da  2f3c 0f89 3830
        jsr     CBUF_$RELEASE           | f8938e0  4eb9 0f87 bb8e
        addq.w  #4,%sp                  | f8938e6  584f
.Lclaimed:
        move.w  #1,%d0                  | f8938e8  303c 0001
        rts                             | f8938ec  4e75
.Lidle:
        lea     (LPR_$INT_EXPECTED,%pc),%a0 | f8938ee  41fa 0024
        clr.w   (%a0)                   | f8938f2  4250
        move.b  #12,PBU_CTL+7           | f8938f4  13fc 000c 0ffe fc07
        move.b  #13,PBU_CTL+7           | f8938fc  13fc 000d 0ffe fc07
        clr.w   %d0                     | f893904  4240
        rts                             | f893906  4e75
.Lnot_ready:
        move.b  #0,PBU_CTL+1            | f893908  13fc 0000 0ffe fc01
        bra.s   .Lclaimed               | f893910  60d6

.Llen:
        .word   0
LPR_$INT_EXPECTED:                      | 0xF893914
        .word   0
LPR_$UNEXP_INT_COUNT:                   | 0xF893916
        .word   0
LPR_$IR_START_COUNT:                    | 0xF893918
        .word   0
LPR_$WRITE_TIMEOUT_FLAG:                | 0xF89391A
        .word   0
LPR_$BUFFER:                            | 0xF89391C
        .space  512
