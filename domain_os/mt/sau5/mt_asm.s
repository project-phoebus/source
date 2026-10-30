|
| mt/sau5/mt_asm.s - MT_ASM: the MT page's hand-written routines and the
| magnetic tape controller's block (MT_$SCB)
|
| SAU5 map: "D39 E90C00 MT_PAGE loaded at 192400, size = C00" and in it
| "D E90C00 MT_ASM size = C00": the whole MT page, 0xC00 bytes, which
| MT_$ACQUIRE wires (MT_$PAGE_START .. MT_$PAGE_END, three pages) and
| maps for the controller.  Its symbols, each defined here at its
| offset:
|
|   +0x000  MT_$PAGE_START   the page's first byte (a marker)
|   +0x000  MT_$INT          the routine MT_$ACQUIRE gives
|                            PBU_$ACQUIRE_INT for the controller
|   +0x01A  MT_$MT_BUSY      test and set the controller's busy member
|   +0x026  MT_$PB_WIRED     test and clear a request block's unwire
|                            member
|   +0x032  MT_$ENQ          append a request block to a queue
|   +0x054  MT_$DEQ          take a queue's first block
|   +0x070  MT_$GETIOVA      an I/O map entry's form back to its I/O
|                            address
|   +0x07C  MT_$PUTIOVA      an I/O address into a request block's form
|   +0x08E  MT_$SCB          the controller's block (mt/mt.ins.pas
|                            mt_$scb_t)
|   +0xBFF  MT_$PAGE_END     the page's last byte (a marker)
|
| Hand-written (the `_ASM' segment, code in a data section: the routines
| have no frame and read their arguments off the stack).  The
| conventions:
|
| - MT_$INT is called by PBU_$INT_COM as the unit's device routine
|   (pbu/sau5/pbu_asm.s), with its argument on the stack.  It calls
|   MT_$SIO with nil (the cell after it), so that MT_$SIO finishes the
|   controller's current request, replaces its own argument with
|   MT_$SCB's cur_dcte (the DCTE of the unit MT_$SIO last finished) and
|   returns MT_$SIO's answer in D0 (bit 0: the interrupt is claimed, bit
|   1: the DCTE's eventcount is advanced).
| - MT_$MT_BUSY: `bset' of the busy member (bit 13) of MT_$SCB's flags
|   word, D0's low byte 0xFF when it was set; MT_$PB_WIRED the same with
|   `bclr' of member 15 of the block's flags (its address the argument),
|   sharing MT_$MT_BUSY's tail.
| - MT_$ENQ (the queue's address, then the address of a block pointer)
|   and MT_$DEQ (the queue's address; the block, or nil, in A0 and D0)
|   change the queue with the interrupts masked (IPL 7); a queue is the
|   first block and the address of the last block's link (of the head
|   when it is empty).  MT_$DEQ shares MT_$ENQ's tail.
| - MT_$GETIOVA and MT_$PUTIOVA take a longword by value (MT_$PUTIOVA
|   then the address it writes to) and exchange the page number between
|   the low 12 bits of the high word and the high 4 bits of the low
|   word.
|
| The SAU5's: the SAU3, SAU4 and SAU6 maps have their own MT_ASM; the
| SAU2 and SAU7..SAU9 none.  The Makefile assembles */$(TARGET_SAU)/*.s,
| so only a SAU5 build takes this file.  Every byte was checked against
| the image by assembling and linking the file at the segment's address
| with the map's addresses for the other symbols
| (../tmp/sau5/verify_sau5_asm.py).
|
        .section ".text.MT_$PAGE_START","ax",@progbits
        .even

        .globl  MT_$PAGE_START
        .globl  MT_$INT
        .globl  MT_$MT_BUSY
        .globl  MT_$PB_WIRED
        .globl  MT_$ENQ
        .globl  MT_$DEQ
        .globl  MT_$GETIOVA
        .globl  MT_$PUTIOVA
        .globl  MT_$SCB
        .globl  MT_$PAGE_END

MT_$PAGE_START:                         | 0xE90C00
MT_$INT:                                | 0xE90C00
        pea     (mt_int_nil,%pc)        | e90c00  MT_$SIO's argument: nil
        lea     MT_$SIO,%a0             | e90c04
        jsr     (%a0)                   | e90c0a
        addq.w  #4,%sp                  | e90c0c
        move.l  (MT_$SCB+0x38,%pc),(4,%sp)  | e90c0e  cur_dcte: the argument
        rts                             | e90c14
mt_int_nil:
        .long   0                       | e90c16

MT_$MT_BUSY:                            | 0xE90C1A
        lea     (MT_$SCB+0x32,%pc),%a0  | e90c1a  MT_$SCB's flags
        bset.b  #5,(%a0)                | e90c1e  bit 13: busy
mt_busy_tail:
        sne     %d0                     | e90c22  0xFF when it was set
        rts                             | e90c24

MT_$PB_WIRED:                           | 0xE90C26
        movea.l (4,%sp),%a0             | e90c26  the block
        bclr.b  #7,(4,%a0)              | e90c2a  flags bit 15: unwire
        bra.s   mt_busy_tail            | e90c30

MT_$ENQ:                                | 0xE90C32
        movea.l (4,%sp),%a1             | e90c32  the queue
        movea.l (8,%sp),%a0             | e90c36  the block pointer's address
        movea.l (%a0),%a0               | e90c3a  the block
        clr.l   (%a0)                   | e90c3c  its link
        move.l  %a0,%d0                 | e90c3e
        move.w  %sr,%d1                 | e90c40
        ori.w   #0x700,%sr              | e90c42  IPL 7
        movea.l (4,%a1),%a0             | e90c46  the tail: the last link
        move.l  %d0,(%a0)               | e90c4a
        move.l  %d0,(4,%a1)             | e90c4c  the block is the tail
mt_enq_tail:
        move.w  %d1,%sr                 | e90c50
        rts                             | e90c52

MT_$DEQ:                                | 0xE90C54
        movea.l (4,%sp),%a1             | e90c54  the queue
        move.w  %sr,%d1                 | e90c58
        ori.w   #0x700,%sr              | e90c5a  IPL 7
        movea.l (%a1),%a0               | e90c5e  the head
        move.l  %a0,%d0                 | e90c60
        beq.s   mt_enq_tail             | e90c62  empty: nil
        move.l  (%a0),(%a1)             | e90c64  the next block is the head
        bne.s   mt_deq_clear            | e90c66
        move.l  %a1,(4,%a1)             | e90c68  emptied: the tail is the head
mt_deq_clear:
        clr.l   (%a0)                   | e90c6c  the block's link
        bra.s   mt_enq_tail             | e90c6e

MT_$GETIOVA:                            | 0xE90C70
        move.l  (4,%sp),%d0             | e90c70
        lsr.w   #8,%d0                  | e90c74
        lsr.w   #4,%d0                  | e90c76
        swap    %d0                     | e90c78
        rts                             | e90c7a

MT_$PUTIOVA:                            | 0xE90C7C
        move.l  (4,%sp),%d0             | e90c7c
        swap    %d0                     | e90c80
        lsl.w   #8,%d0                  | e90c82
        lsl.w   #4,%d0                  | e90c84
        movea.l (8,%sp),%a0             | e90c86  the result's address
        move.l  %d0,(%a0)               | e90c8a
        rts                             | e90c8c

| The controller's block, as mt/mt.ins.pas declares it: zero but for the
| first word, the free queue's head (the pool's first block), the
| request blocks' size, the ring of the two units (the cursor at unit 0,
| each unit's `next' the other) with their empty queues (the tail the
| head's address) and PBU units (3 and 7), the unit count and the new
| units' mode bits.  MT_$ACQUIRE rebuilds the pool and the free queue.
MT_$SCB:                                | 0xE90C8E
        .word   0x0300                  | +0x00
        .space  0x10                    | +0x02  ctl_iova, ctl_word, cmd_iova, current
        .long   MT_$SCB+0x98            | +0x12  free_q.head: the pool
        .space  0x12                    | +0x16  free_q.tail, cfg_iova, cfg_pages
        .word   0x006C                  | +0x28  pb_size
        .long   MT_$SCB+0x3C            | +0x2A  cursor: unit 0
        .word   2                       | +0x2E  n_units
        .word   0                       | +0x30  n_acquired
        .word   0                       | +0x32  flags
        .word   0x8220                  | +0x34  default_mode
        .space  6                       | +0x36  n_spurious, cur_dcte
| unit 0, +0x3C
        .long   0                       | +0x3C  queue.head
        .long   MT_$SCB+0x3C            | +0x40  queue.tail: the head
        .word   0                       | +0x44  flags
        .word   3                       | +0x46  pbu_unit
        .space  0x1E                    | +0x48
        .long   MT_$SCB+0x6A            | +0x66  next: unit 1
| unit 1, +0x6A
        .long   0                       | +0x6A  queue.head
        .long   MT_$SCB+0x6A            | +0x6E  queue.tail: the head
        .word   0                       | +0x72  flags
        .word   7                       | +0x74  pbu_unit
        .space  0x1E                    | +0x76
        .long   MT_$SCB+0x3C            | +0x94  next: unit 0
| the request block pool, +0x98 (0xE90D26) to the page's end, zero
        .space  0xAD9                   | +0x98
MT_$PAGE_END:                           | 0xE917FF
        .byte   0
