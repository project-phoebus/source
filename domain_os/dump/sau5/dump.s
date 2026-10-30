/*
 * dump/sau5/dump.s - the DUMP page (SAU5): the crash-dump code and its cells
 *
 * The SAU5's DUMP page, transcribed from the SAU5 image file (file
 * 0x800..0xC00, low 0x101C00, VA 0xE00400) on the SAU2's
 * (dump/sau2/dump.s, whose analysis and conventions this file keeps: one
 * section, A5 = DUMP with the DUMP_OFF_* displacements, every RELOC cell
 * a symbol reference, the <ea>=#imm forms as `.short').  The SAU5 map:
 *
 *   D23  E00400  DUMP               loaded at 101C00, size = 400
 *   D    E00400  DUMP               size = 400
 *        E00400  DUMP
 *        E007DA  DUMP_$SMAP_PHADDR
 *        E007E8  DUMP_$RARS_PHADDR
 *        E007EC  DUMP_$ADDRS
 *
 * A file of its own rather than `.if' arms in a shared one: 685 of the
 * 1024 bytes differ from the SAU2's; of the SAU2 code's 260 instructions
 * 176 are the same text here, and the SAU5 adds 45 in 10 places and drops
 * 5.  Against the SAU2's:
 *   - DUMP enters with d7 = 5 (the SAU2's 1), the device word the PROM's
 *     vector 0x10C starts from; the device-1 limit of 0x4D0 pages is gone;
 *   - device 5 (a tape dump: the boot device of the `tape_boot' SAUs)
 *     gets an end-of-dump request (sequence -1) after the ranges and two
 *     at the end (dump_end_tape), sends each page from its own physical
 *     address and, after a page has been written, sends 0x200 bytes more
 *     once (d4), and expects no reply;
 *   - the packet header (dump_peer_id .., 44 bytes) is copied to VA
 *     0xE00000 (the CRASH_RECORD page) before every send, sent from there,
 *     and its first longword copied back after; the reply is read there
 *     too (the SAU2's from the frame), and the receive buffer is physical
 *     0x100000 (the SAU2's 0x100124);
 *   - the page tables' dump copies the I/O map (IOMAP, 0x200 words read
 *     from physical 0x10002 every other word) when it can be read, the
 *     MMU control register cleared either way;
 *   - the packet's byte before the op is 5 (the SAU2's 2), dump_flags'
 *     initial word 0x00AD (the SAU2's 0x000C), and the gap between
 *     DUMP_$SMAP_PHADDR and DUMP_$RARS_PHADDR 0xE bytes (the SAU2's 0x86).
 * The RFC fixup table lists 12 cells here (the SAU2's 6).  Addresses in
 * the comments are the SAU5 image's.  What the page does is described
 * in dump/sau2/dump.s; the comments below are that file's where the
 * code is the same.
 */

        .section ".text.DUMP","ax",@progbits
        .balign 4

        .globl  DUMP
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

        .set    DUMP_STACK_TOP, CRASH_$RECORD + 0x100 /* 0xE00100, in the CRASH_RECORD page */
        .extern CRASH_STATUS                          /* 0xE1F65C, misc/m68k/crash_report.s */
        .set    DUMP_PKT_BUF,   CRASH_$RECORD         /* 0xE00000: the packet's copy, in the CRASH_RECORD page */

        .equ    PROM_MACHINE_ID_LO, 0x00000103  /* low byte of PROM_$MACHINE_ID (0x100); bit 1 = 68020 */
        .equ    PROM_VEC_PUTC,  0x00000108  /* PROM putc vector (d1 = the char) */
        .equ    PROM_VEC_10C,   0x0000010C  /* PROM vector: the dump device (3 var args) */
        .equ    PROM_VEC_110,   0x00000110  /* PROM vector: receive (4 var args) */
        .equ    PROM_VEC_QUIET, 0x0000011C  /* PROM_$QUIET_RET_ADDR: back to the PROM */
        .equ    PROM_VEC_120,   0x00000120  /* PROM vector: send (4 var args) */
        .equ    PROM_CELL_100,  0x00000100  /* PROM_$MACHINE_ID */
        .equ    MMU_CSR_PHYS,   0x00008000  /* the MMU control register, physical */
        .equ    MMU_CSR_PHYS_2, 0x00008002  /* the word after it */
        .equ    PFT_PHYS,       0x00004000  /* the page frame table, physical */
        .equ    PFT_PHYS_END,   0x00008000
        .equ    PFT_DUMP,       0x0000400C  /* PFT[3]: the PFT entry of PPN 3 */
        .equ    PFT_DUMP_PAGE,  0x0000500C  /* PFT[0x403]: the dump page's own entry */
        .equ    PFT_DUMP_PAGE_HI, 0x00005010
        .equ    DUMP_PHYS,      0x00100C00  /* PPN 0x403 */
        .equ    KERNEL_PHYS,    0x00102000  /* PPN 0x408: the kernel's first page, scratch here */
        .equ    DUMP_RCV_BUF,   0x00100000  /* physical: the receive buffer (VA 0xE00000) */
        .equ    IOMAP_SAVE_PHYS, 0x00010000 /* physical: the I/O map's copy the dump sends */
        .equ    IOMAP_SAVE_END, 0x00010400
        .equ    BUS_ERROR_VEC_OFF, 0x8      /* vector 2 */

        .equ    DUMP_OFF_PEER_ID,  0x380    /* 0xE00780 dump_peer_id */
        .equ    DUMP_OFF_PKT_LEN,  0x394    /* 0xE00794 dump_pkt_len */
        .equ    DUMP_OFF_PKT_OP,   0x3A7    /* 0xE007A7 dump_pkt_op */
        .equ    DUMP_OFF_PKT_SEQ,  0x3A8    /* 0xE007A8 dump_pkt_seq */
        .equ    DUMP_OFF_FLAGS,    0x3D8    /* 0xE007D8 dump_flags */

DUMP:
        moveq   #5,%d7                  /* e00400 */
        bra.s   dump_common             /* e00402 */
dump_start_2:
        moveq   #2,%d7                  /* e00404 */
dump_common:
        lea     (DUMP:w,%pc),%a5        /* e00406  A5 = DUMP */
        lea     DUMP_STACK_TOP,%sp      /* e0040a  a RELOC cell */
        movea.l %sp,%fp                 /* e00410  the frame */
        move.l  #0x400,%d6              /* e00412  the page size */
        bset    #0,(DUMP_OFF_FLAGS,%a5) /* e00418  entered before? */
        bne.s   dump_mmu_on             /* e0041e */
        move.w  #2,MMU_CSR_PHYS         /* e00420  CSR = 2 (PTT access) */
        move.l  #0x01711003,%d4         /* e00428  PFT entry for PPN 0x403 */
        move.l  #0x000fff00,%d5         /* e0042e  PTT index mask */
        btst    #1,(PROM_MACHINE_ID_LO).w /* e00434 */
        beq.s   dump_map_self           /* e0043a */
        bset    #1,(DUMP_OFF_FLAGS,%a5) /* e0043c  68020 */
        bclr    #16,%d4                 /* e00442 */
        lsl.l   #2,%d5                  /* e00446 */
dump_map_self:
        .short  0xcabc                  /* e00448  and.l #DUMP_PHYS,%d5 (<ea>=#imm form) */
        .long   DUMP_PHYS               /* e0044a */
        movea.l #PTT,%a4                /* e0044e  a RELOC cell */
        move.w  (0,%a4,%d5.l),%d0       /* e00454  save the PTT slot, */
        move.l  (PFT_DUMP_PAGE).w,%d1   /* e00458      PFT[0x403] */
        move.l  (PFT_DUMP).w,%d2        /* e0045c      and PFT[3] */
        move.w  #0x403,(0,%a4,%d5.l)    /* e00460 */
        move.l  %d4,(PFT_DUMP_PAGE).w   /* e00466 */
        move.l  #0x00709403,(PFT_DUMP).w /* e0046a */
        move.w  #0x160,(PFT_DUMP_PAGE_HI).w /* e00472 */
        move.w  #1,MMU_CSR_PHYS         /* e00478  the MMU on */
        movem.l %d0-%d3/%d5,(0xc,%fp)   /* e00480  the saved words */
        bra.s   dump_mmu_done           /* e00486 */
dump_mmu_on:
        move.w  #1,MMU_CSR_PHYS         /* e00488 */
dump_mmu_done:
        move.b  #0xff,(0).w             /* e00490 */
        move.w  %d7,(%fp)               /* e00496  entry 1 or 2 */
        clr.w   (2,%fp)                 /* e00498 */
        pea     (4,%fp)                 /* e0049c */
        pea     (2,%fp)                 /* e004a0 */
        pea     (%fp)                   /* e004a4 */
        movea.l (PROM_VEC_10C).w,%a0    /* e004a6 */
        jsr     (%a0)                   /* e004aa */
        adda.w  #0xc,%sp                /* e004ac */
        cmpi.w  #2,(%fp)                /* e004b0  device 2 or 6: a network dump */
        beq.s   dump_net_open           /* e004b4 */
        cmpi.w  #6,(%fp)                /* e004b6 */
        bne.s   dump_ranges             /* e004ba */
dump_net_open:
        move.l  CRASH_STATUS,(DUMP_OFF_PKT_SEQ,%a5) /* e004bc  a RELOC cell */
        moveq   #0,%d0                  /* e004c4  op 0 */
        bsr.w   dump_send_request       /* e004c6 */
        movea.l (0x20,%fp),%a1          /* e004ca  the reply */
        lea     (0xc,%a1),%a0           /* e004ce */
        bsr.w   dump_puts               /* e004d2  the server's name */
dump_ranges:
        move.l  #0x23,(DUMP_OFF_PKT_SEQ,%a5) /* e004d6 */
        moveq   #31,%d5                 /* e004de  a `!' every 32 pages */
        lea     (DUMP_$ADDRS:w,%pc),%a3 /* e004e0 */
dump_range_loop:
        move.l  (%a3)+,%d7              /* e004e4  start (0 ends) */
        beq.s   dump_tables             /* e004e6 */
        move.l  (%a3)+,%d4              /* e004e8  end */
dump_page_loop:
        bsr.w   dump_send_page          /* e004ea */
        addq.l  #1,(DUMP_OFF_PKT_SEQ,%a5) /* e004ee */
        dbf     %d5,dump_page_next      /* e004f2 */
        move.b  #0x21,%d1               /* e004f6  `!' */
        bsr.w   dump_putc               /* e004fa */
        moveq   #31,%d5                 /* e004fe */
dump_page_next:
        add.l   %d6,%d7                 /* e00500 */
        cmp.l   %d7,%d4                 /* e00502 */
        bge.s   dump_page_loop          /* e00504 */
        bra.s   dump_range_loop         /* e00506 */

/*
 * 0xE00508: the page tables as 35 pages built at physical 0x102000: the
 * PTT (one word per 1 KB of the window), the PFT, the saved PFT/PTT words
 * of the dump page and the MMU registers.
 */
dump_tables:
        bsr.w   dump_end_tape           /* e00508  end of the ranges (device 5) */
        lea     KERNEL_PHYS,%a4         /* e0050c  49f9 abs.l */
        move.l  %a4,%d7                 /* e00512 */
        movem.l (0xc,%fp),%d0-%d3/%d5   /* e00514 */
        lea     IOMAP_SAVE_PHYS,%a3     /* e0051a  47f9 abs.l */
        lea     (dump_iomap_unreadable:w,%pc),%a2 /* e00520  a bus error: no I/O map */
        move.l  %a2,(BUS_ERROR_VEC_OFF).w /* e00524 */
        movea.l %sp,%a2                 /* e00528 */
        tst.w   IOMAP                   /* e0052a  a RELOC cell */
        move.w  #0,MMU                  /* e00530  a RELOC cell */
        bra.s   dump_copy_iomap         /* e00538 */
dump_iomap_unreadable:
        movea.l %a2,%sp                 /* e0053a */
        lea     (0x200,%a4),%a4         /* e0053c */
        move.w  #0,MMU                  /* e00540  a RELOC cell */
        bra.s   dump_iomap_done         /* e00548 */
dump_copy_iomap:
        addq.w  #2,%a3                  /* e0054a  every other word of the copy */
        move.w  (%a3)+,(%a4)+           /* e0054c */
        cmpa.l  #IOMAP_SAVE_END,%a3     /* e0054e */
        bne.s   dump_copy_iomap         /* e00554 */
dump_iomap_done:
        move.l  (PROM_CELL_100).w,(-0x1fe,%a4) /* e00556 */
        move.w  #2,MMU_CSR_PHYS         /* e0055c */
        lea     PTT,%a3                 /* e00564  a RELOC cell */
        movea.l %a4,%a2                 /* e0056a */
dump_copy_ptt:
        move.w  (%a3),(%a4)+            /* e0056c */
        adda.w  %d6,%a3                 /* e0056e */
        cmpa.l  #PTT + 0x100000,%a3     /* e00570  a RELOC cell (0x800000) */
        bne.s   dump_copy_ptt           /* e00576 */
        lsr.l   #8,%d5                  /* e00578 */
        lsr.l   #1,%d5                  /* e0057a */
        move.w  %d0,(0,%a2,%d5.w)       /* e0057c  the dump page's saved PTT word */
        lea     (PFT_PHYS).w,%a3        /* e00580 */
dump_copy_pft:
        move.w  (%a3)+,(%a4)+           /* e00584 */
        cmpa.l  #PFT_PHYS_END,%a3       /* e00586 */
        bne.s   dump_copy_pft           /* e0058c */
        move.l  %d1,(-0x2ff4,%a4)       /* e0058e  saved PFT[0x403] */
        move.l  %d2,(-0x3ff4,%a4)       /* e00592  saved PFT[3] */
        movea.l %a2,%a4                 /* e00596 */
        adda.l  #0x8800,%a4             /* e00598 */
        clr.l   (%a4)+                  /* e0059e */
        move.w  MMU_CSR_PHYS_2,(%a4)+   /* e005a0  38f9 abs.l */
        move.w  #1,MMU_CSR_PHYS         /* e005a6 */
        clr.l   (DUMP_OFF_PKT_SEQ,%a5)  /* e005ae */
        moveq   #34,%d5                 /* e005b2  35 pages */
dump_tables_loop:
        bsr.w   dump_send_page          /* e005b4 */
        addq.l  #1,(DUMP_OFF_PKT_SEQ,%a5) /* e005b8 */
        add.l   %d6,%d7                 /* e005bc */
        dbf     %d5,dump_tables_loop    /* e005be */
dump_finish:
        cmpi.w  #5,(%fp)                /* e005c2  a tape dump: */
        bne.s   dump_finish_net         /* e005c6 */
        bsr.s   dump_end_tape           /* e005c8  two ends */
        bsr.s   dump_end_tape           /* e005ca */
        bra.s   dump_done               /* e005cc */
dump_finish_net:
        moveq   #4,%d0                  /* e005ce  op 4 */
        cmp.b   (dump_pkt_op:w,%pc),%d0 /* e005d0 */
        beq.s   dump_done               /* e005d4 */
        bsr.s   dump_send_request       /* e005d6 */
dump_done:
        lea     (dump_str_done:w,%pc),%a0 /* e005d8 */
        bsr.w   dump_puts_nl            /* e005dc */
        movea.l (PROM_VEC_QUIET).w,%a0  /* e005e0 */
        jmp     (%a0)                   /* e005e4 */

/* dump_end_tape: on a tape dump (device 5), send a request with sequence
   -1. */
dump_end_tape:
        cmpi.w  #5,(%fp)                /* e005e6 */
        bne.s   dump_end_tape_rts       /* e005ea */
        moveq   #-1,%d0                 /* e005ec */
        move.l  %d0,(DUMP_OFF_PKT_SEQ,%a5) /* e005ee */
        bsr.s   dump_send_request       /* e005f2 */
dump_end_tape_rts:
        rts                             /* e005f4 */

/*
 * dump_send_page, 0xE005F6 (the SAU2's FUN_00e005bc): send the page at d7 (op 2,
 * length d6).  dump_send_request, 0xE00600 (the SAU2's FUN_00e005c6): send op d0
 * with length 0 (the page number is that of DUMP itself, d7 = A5).  Both
 * save d0-d7/a1-a4 and share dump_xfer.
 */
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)  /* e005f6 */
        moveq   #2,%d0                  /* e005fa */
        move.l  %d6,%d1                 /* e005fc */
        bra.s   dump_xfer               /* e005fe */
dump_send_request:
        movem.l %d0-%d7/%a1-%a4,-(%sp)  /* e00600 */
        clr.w   %d1                     /* e00604 */
        move.l  %a5,%d7                 /* e00606 */
dump_xfer:
        move.w  %d1,(DUMP_OFF_PKT_LEN,%a5) /* e00608 */
        move.b  %d0,(DUMP_OFF_PKT_OP,%a5)  /* e0060c */
        move.l  %d7,%d0                 /* e00610  the page number */
        lsr.l   #8,%d0                  /* e00612 */
        lsr.l   #2,%d0                  /* e00614 */
        move.w  %d0,(0xa,%fp)           /* e00616 */
        move.w  #10,(8,%fp)             /* e0061a  10 tries */
dump_xfer_copy:
        lea     DUMP_PKT_BUF,%a0        /* e00620  a RELOC cell */
        lea     (dump_peer_id:w,%pc),%a1 /* e00626  the packet header, 44 bytes */
        moveq   #43,%d0                 /* e0062a */
dump_xfer_copy_loop:
        move.b  (%a1)+,(%a0)+           /* e0062c */
        dbf     %d0,dump_xfer_copy_loop /* e0062e */
        clr.l   %d4                     /* e00632 */
dump_xfer_send:
        pea     (4,%fp)                 /* e00634  status */
        move.l  #DUMP_PKT_BUF,-(%sp)    /* e00638  a RELOC cell */
        cmpi.w  #5,(%fp)                /* e0063e  a tape dump: */
        bne.s   dump_xfer_send_args     /* e00642 */
        move.l  %d7,(%sp)               /* e00644  the page itself, */
        add.l   %d4,(%sp)               /* e00646  then the 0x200 after */
dump_xfer_send_args:
        pea     (0xa,%fp)               /* e00648 */
        pea     (dump_pkt_seq:w,%pc)    /* e0064c */
        movea.l (PROM_VEC_120).w,%a0    /* e00650 */
        jsr     (%a0)                   /* e00654 */
        adda.w  #0x10,%sp               /* e00656 */
        move.l  DUMP_PKT_BUF,%d0        /* e0065a  a RELOC cell: the peer id back */
        move.l  %d0,(DUMP_OFF_PEER_ID,%a5) /* e00660 */
        move.l  (4,%fp),%d0             /* e00664 */
        beq.s   dump_xfer_sent          /* e00668 */
        subq.w  #1,(8,%fp)              /* e0066a */
        bne.s   dump_xfer_copy          /* e0066e */
        lea     (dump_str_xbad:w,%pc),%a0 /* e00670 */
        bra.w   dump_xfer_fail          /* e00674 */
dump_xfer_return:
        movem.l (%sp)+,%d0-%d7/%a1-%a4  /* e00678 */
        rts                             /* e0067c */
dump_xfer_sent:
        cmpi.w  #5,(%fp)                /* e0067e  a tape dump: no reply; */
        bne.s   dump_xfer_receive       /* e00682 */
        tst.l   (DUMP_OFF_PKT_SEQ,%a5)  /* e00684  an end request, */
        blt.s   dump_xfer_return        /* e00688 */
        tst.l   %d4                     /* e0068a  or the second half sent: */
        bne.s   dump_xfer_return        /* e0068c  done */
        .short  0xd87c, 0x0200          /* e0068e  add.w #0x200,%d4 (<ea>=#imm form) */
        bra.s   dump_xfer_send          /* e00692 */
dump_xfer_receive:
        move.w  #3,(8,%fp)              /* e00694  3 tries */
dump_xfer_receive_try:
        pea     (4,%fp)                 /* e0069a  status */
        move.l  #DUMP_RCV_BUF,-(%sp)    /* e0069e */
        pea     (dump_rcv_len:w,%pc)    /* e006a4 */
        pea     (dump_pkt_seq:w,%pc)    /* e006a8 */
        movea.l (PROM_VEC_110).w,%a0    /* e006ac */
        jsr     (%a0)                   /* e006b0 */
        adda.w  #0x10,%sp               /* e006b2 */
        move.l  (4,%fp),%d0             /* e006b6 */
        beq.s   dump_xfer_reply         /* e006ba */
        subq.w  #1,(8,%fp)              /* e006bc */
        bne.w   dump_xfer_copy          /* e006c0 */
        lea     (dump_str_rbad:w,%pc),%a0 /* e006c4 */
        bra.s   dump_xfer_fail          /* e006c8 */
dump_xfer_reply:
        lea     DUMP_PKT_BUF,%a0        /* e006ca  the reply header; a RELOC cell */
        move.l  (dump_peer_id:w,%pc),%d0 /* e006d0 */
        cmp.l   (8,%a0),%d0             /* e006d4  from our peer? */
        bne.s   dump_xfer_receive       /* e006d8 */
        lea     (0x1e,%a0),%a1          /* e006da */
        clr.l   %d0                     /* e006de */
        move.b  (0x18,%a0),%d0          /* e006e0 */
        adda.l  %d0,%a1                 /* e006e4  the reply body */
        move.l  %a1,(0x20,%fp)          /* e006e6 */
        cmpi.w  #2,(%a1)                /* e006ea */
        bne.s   dump_xfer_bad_type      /* e006ee */
        cmpi.w  #1,(2,%a1)              /* e006f0 */
        bne.s   dump_xfer_bad_type      /* e006f6 */
        move.b  (5,%a1),%d0             /* e006f8 */
        subq.l  #1,%d0                  /* e006fc */
        cmp.b   (dump_pkt_op:w,%pc),%d0 /* e006fe  the reply to our op? */
        beq.s   dump_xfer_check_seq     /* e00702 */
dump_xfer_bad_type:
        cmpi.b  #7,(5,%a1)              /* e00704 */
        bne.s   dump_xfer_bad_reply     /* e0070a */
dump_xfer_retry:
        bra.s   dump_xfer_receive       /* e0070c */
dump_xfer_bad_reply:
        lea     (dump_str_bad_rpy:w,%pc),%a0 /* e0070e */
        bsr.s   dump_puts               /* e00712 */
dump_xfer_abort:
        bra.w   dump_finish             /* e00714 */
dump_xfer_check_seq:
        .short  0xb03c, 0x0002          /* e00718  cmp.b #2,%d0 (<ea>=#imm form) */
        bne.s   dump_xfer_check_status  /* e0071c */
        move.l  (dump_pkt_seq:w,%pc),%d0 /* e0071e */
        cmp.l   (0xc,%a1),%d0           /* e00722 */
        bne.s   dump_xfer_retry         /* e00726 */
dump_xfer_check_status:
        move.l  (6,%a1),%d0             /* e00728  the server's status */
        beq.w   dump_xfer_return        /* e0072c */
        lea     (dump_str_nm_sad:w,%pc),%a0 /* e00730 */
dump_xfer_fail:
        move.l  %d0,-(%sp)              /* e00734  "<msg> - St=<status>" */
        bsr.s   dump_puts               /* e00736 */
        lea     (dump_str_st:w,%pc),%a0 /* e00738 */
        bsr.s   dump_puts               /* e0073c */
        move.l  (%sp)+,%d0              /* e0073e */
        bsr.s   dump_put_hex_nl         /* e00740 */
        bra.s   dump_xfer_abort         /* e00742 */

/* dump_puts_nl, 0xE00744: print the string at a0, then CR LF. */
dump_puts_nl:
        bsr.s   dump_puts               /* e00744 */
dump_put_nl:
        lea     (dump_str_nl:w,%pc),%a0 /* e00746 */
/* dump_puts, 0xE0074A: print the NUL-terminated string at a0. */
dump_puts:
        move.b  (%a0)+,%d1              /* e0074a */
        beq.s   dump_rts                /* e0074c */
        bsr.s   dump_putc               /* e0074e */
        bra.s   dump_puts               /* e00750 */
        rts                             /* e00752  (unreachable, as in the image) */

/* dump_put_hex_nl, 0xE00754: print d0 as 8 hex digits, then CR LF. */
dump_put_hex_nl:
        moveq   #7,%d2                  /* e00754 */
dump_put_hex_digit:
        rol.l   #4,%d0                  /* e00756 */
        moveq   #15,%d1                 /* e00758 */
        and.b   %d0,%d1                 /* e0075a */
        .short  0xb23c, 0x000a          /* e0075c  cmp.b #10,%d1 (<ea>=#imm form) */
        blt.s   dump_put_hex_ascii      /* e00760 */
        addq.b  #7,%d1                  /* e00762  'A' - '0' - 10 */
dump_put_hex_ascii:
        .short  0xd23c, 0x0030          /* e00764  add.b #'0',%d1 (<ea>=#imm form) */
        bsr.s   dump_putc               /* e00768 */
        dbf     %d2,dump_put_hex_digit  /* e0076a */
        bra.s   dump_put_nl             /* e0076e */

/* dump_putc, 0xE00770: the character in d1 through the PROM, every register kept. */
dump_putc:
        movem.l %d0-%d7/%a0-%a4,-(%sp)  /* e00770 */
        movea.l (PROM_VEC_PUTC).w,%a0   /* e00774 */
        jsr     (%a0)                   /* e00778 */
        movem.l (%sp)+,%d0-%d7/%a0-%a4  /* e0077a */
dump_rts:
        rts                             /* e0077e */

/*
 * 0xE00780: the cells.  The packet the PROM send/receive vectors take
 * (dump_pkt_seq is its first argument) with its length word and op byte
 * just ahead of it; the peer id the reply must carry; the receive length;
 * the messages; the flags; and the map's three public cells.
 */
dump_peer_id:
        .long   0                       /* e00780 */
        .long   0, 0                    /* e00784 */
        .byte   0x01, 0x01, 0x00, 0x00  /* e0078c */
        .byte   0x00, 0x2c, 0x00, 0x0a  /* e00790 */
dump_pkt_len:
        .short  0x0000                  /* e00794 */
        .short  0x0000                  /* e00796 */
        .byte   0x04, 0x01, 0x00, 0x00  /* e00798 */
        .byte   0x00, 0x00, 0x00, 0x00  /* e0079c */
        .byte   0x00, 0x03, 0x00, 0x02  /* e007a0 */
        .byte   0x00, 0x01, 0x05        /* e007a4 */
dump_pkt_op:
        .byte   0x00                    /* e007a7 */
dump_pkt_seq:
        .long   0                       /* e007a8 */
dump_rcv_len:
        .short  0x0400                  /* e007ac */
dump_str_xbad:
        .asciz  "Xbad"                  /* e007ae */
dump_str_rbad:
        .asciz  "Rbad"                  /* e007b3 */
dump_str_bad_rpy:
        .asciz  "Bad rpy"               /* e007b8 */
dump_str_nm_sad:
        .asciz  "Nm sad"                /* e007c0 */
dump_str_st:
        .asciz  " - St="                /* e007c7 */
dump_str_nl:
        .byte   0x0a, 0x0d, 0x00        /* e007ce */
dump_str_done:
        .byte   0x0a, 0x0d              /* e007d1 */
        .asciz  "Done"                  /* e007d3 */
dump_flags:
        .short  0x00ad                  /* e007d8  bit 0 entered, bit 1 68020 */
DUMP_$SMAP_PHADDR:
        .long   0                       /* e007da */
        .space  0xa                     /* e007de */
DUMP_$RARS_PHADDR:
        .long   0                       /* e007e8 */
DUMP_$ADDRS:
        .long   0x00100000, 0x0017fc00  /* e007ec  range 0 (MMAP_$INIT rewrites both) */
        .long   0, 0                    /* e007f4  range 1 */
        .long   0                       /* e007fc  (no reference) */

/*
 * The page is exactly 0x400 bytes with DUMP_$ADDRS at +0x3EC; gas cannot
 * check label differences across relaxable operands, so the byte gate
 * (tools/asm_compare.py, the whole page against the image) proves it.
 */

        .size   DUMP, . - DUMP
