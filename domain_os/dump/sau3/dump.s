/*
 * dump/sau3/dump.s - the DUMP page (SAU3): the crash-dump code and its cells
 *
 * The SAU3's DUMP page, transcribed from the SAU3 image file (file
 * 0x800..0xC00, low 0x101C00, VA 0xE00400) on the SAU2's
 * (dump/sau2/dump.s, whose analysis and conventions this file keeps: one
 * section, A5 = DUMP with the DUMP_OFF_* displacements, every RELOC cell
 * a symbol reference, the <ea>=#imm forms as `.short').  The SAU3 map:
 *
 *   D23  E00400  DUMP               loaded at 101C00, size = 400
 *   D    E00400  DUMP               size = 400
 *        E00400  DUMP
 *        E0060A  DUMP_$AUTO_REBOOT
 *        E007D6  DUMP_$SMAP_PHADDR
 *        E007E8  DUMP_$RARS_PHADDR
 *        E007EC  DUMP_$ADDRS
 *
 * Against the SAU2's:
 *   - DUMP (0xE00400) is two `nop's into dump_start_2: both entries run
 *     with d7 = 2;
 *   - after the network request (op 0) it sets the frame's byte +0x24
 *     (`st', after a `btst #6' of the reply's flag byte whose result
 *     nothing reads), and dumps only when bit 7 of that byte is set: else
 *     it goes straight to "Done";
 *   - no type-1 device limit (0x4D0 pages) and no type-1 tests in
 *     dump_finish and dump_xfer: every transfer waits for a reply;
 *   - the first 0x200 bytes of the page-table pages are every other word
 *     of physical 0x10000..0x10400 (the 1 KB COLD clears,
 *     cold/sau3/cold_start.s 0x10177E), not skipped;
 *   - after "Done", with the frame's byte +0x24 set, it reboots: clears
 *     byte 0 of the trap page, waits, `reset', takes SP from location 0
 *     and jumps to the PROM's 0x400; DUMP_$AUTO_REBOOT (0xE0060A), with
 *     A5 = DUMP and SP = physical 0x100100 (CRASH_$RECORD's page + 0x100,
 *     a literal), prints "REBOOTING", waits longer and does the same
 *     (a second copy of the reboot sequence, 0xE005F0);
 *   - the receive buffer is physical 0x100126, the reply at (0x26,A6);
 *   - the packet's byte before dump_pkt_op is 3 (the SAU2's 2) and
 *     dump_flags is 0 in the file.
 * Addresses in the comments are the SAU3 image's.
 */


        .section ".text.DUMP","ax",@progbits
        .balign 4

        .globl  DUMP
        .globl  DUMP_$AUTO_REBOOT
        .globl  DUMP_$SMAP_PHADDR
        .globl  DUMP_$RARS_PHADDR
        .globl  DUMP_$ADDRS

        .set    DUMP_STACK_TOP, CRASH_$RECORD + 0x100 /* 0xE00100, in the CRASH_RECORD page */
        .set    CRASH_STATUS,   CRASH_REPORT + 0x10   /* 0xE1D98E, crash_report_t.status */

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
        .equ    DUMP_RCV_BUF,   0x00100126  /* physical: the receive buffer (VA 0xE00126) */
        .equ    REBOOT_STACK,   0x00100100  /* physical: CRASH_$RECORD's page + 0x100 */
        .equ    PROM_RESTART,   0x00000400  /* the PROM's restart entry */
        .equ    PBU_SAVE_PHYS,  0x00010000  /* physical: the 1 KB COLD clears */
        .equ    PBU_SAVE_END,   0x00010400

        .equ    DUMP_OFF_PKT_LEN,  0x386    /* 0xE00786 dump_pkt_len */
        .equ    DUMP_OFF_PKT_OP,   0x399    /* 0xE00799 dump_pkt_op */
        .equ    DUMP_OFF_PKT_SEQ,  0x39A    /* 0xE0079A dump_pkt_seq */
        .equ    DUMP_OFF_FLAGS,    0x3D4    /* 0xE007D4 dump_flags */

DUMP:
        nop                             /* e00400 */
        nop                             /* e00402 */
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
        .long   DUMP_PHYS
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
        move.w  %d7,(%fp)               /* e00496  2 */
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
        lea     (0xa,%a1),%a0           /* e004ce  its flag byte */
        btst    #6,(%a0)                /* e004d2 */
        st      (0x24,%fp)              /* e004d6  reboot after the dump */
        btst    #7,(%a0)                /* e004da  dump? */
        beq.w   dump_done               /* e004de */
        movea.l (0x20,%fp),%a1          /* e004e2 */
        lea     (0xc,%a1),%a0           /* e004e6 */
        bsr.w   dump_puts               /* e004ea  the server's name */
dump_ranges:
        move.l  #0x23,(DUMP_OFF_PKT_SEQ,%a5) /* e004ee */
        moveq   #31,%d5                 /* e004f6  a `!' every 32 pages */
        lea     (DUMP_$ADDRS:w,%pc),%a3 /* e004f8 */
dump_range_loop:
        move.l  (%a3)+,%d7              /* e004fc  start (0 ends) */
        beq.s   dump_tables             /* e004fe */
        move.l  (%a3)+,%d4              /* e00500  end */
dump_page_loop:
        bsr.w   dump_send_page          /* e00502 */
        addq.l  #1,(DUMP_OFF_PKT_SEQ,%a5) /* e00506 */
        dbf     %d5,dump_page_next      /* e0050a */
        move.b  #0x21,%d1               /* e0050e  `!' */
        bsr.w   dump_putc               /* e00512 */
        moveq   #31,%d5                 /* e00516 */
dump_page_next:
        add.l   %d6,%d7                 /* e00518 */
        cmp.l   %d7,%d4                 /* e0051a */
        bge.s   dump_page_loop          /* e0051c */
        bra.s   dump_range_loop         /* e0051e */

/*
 * 0xE00520: the page tables as 35 pages built at physical 0x102000: the
 * PTT (one word per 1 KB of the window), the PFT, the saved PFT/PTT words
 * of the dump page and the MMU registers.
 */
dump_tables:
        lea     KERNEL_PHYS,%a4         /* e00520  49f9 abs.l */
        move.l  %a4,%d7                 /* e00526 */
        movem.l (0xc,%fp),%d0-%d3/%d5   /* e00528 */
        lea     PBU_SAVE_PHYS,%a3       /* e0052e  47f9 abs.l */
        move.w  #0,MMU                  /* e00534  a RELOC cell */
dump_copy_pbu:
        move.w  (%a3)+,(%a4)+           /* e0053c  every other word of */
        addq.w  #2,%a3                  /*         0x10000..0x10400 */
        cmpa.l  #PBU_SAVE_END,%a3
        bne.s   dump_copy_pbu
        move.l  (PROM_CELL_100).w,(-0x1fe,%a4) /* e00548 */
        move.w  #2,MMU_CSR_PHYS         /* e0054e */
        lea     PTT,%a3                 /* e00556  a RELOC cell */
        movea.l %a4,%a2                 /* e0055c */
dump_copy_ptt:
        move.w  (%a3),(%a4)+            /* e0055e */
        adda.w  %d6,%a3                 /* e00560 */
        cmpa.l  #PTT + 0x100000,%a3     /* e00562  a RELOC cell (0x800000) */
        bne.s   dump_copy_ptt           /* e00568 */
        lsr.l   #8,%d5                  /* e0056a */
        lsr.l   #1,%d5                  /* e0056c */
        move.w  %d0,(0,%a2,%d5.w)       /* e0056e  the dump page's saved PTT word */
        lea     (PFT_PHYS).w,%a3        /* e00572 */
dump_copy_pft:
        move.w  (%a3)+,(%a4)+           /* e00576 */
        cmpa.l  #PFT_PHYS_END,%a3       /* e00578 */
        bne.s   dump_copy_pft           /* e0057e */
        move.l  %d1,(-0x2ff4,%a4)       /* e00580  saved PFT[0x403] */
        move.l  %d2,(-0x3ff4,%a4)       /* e00584  saved PFT[3] */
        movea.l %a2,%a4                 /* e00588 */
        adda.l  #0x8800,%a4             /* e0058a */
        clr.l   (%a4)+                  /* e00590 */
        move.w  MMU_CSR_PHYS_2,(%a4)+   /* e00592  38f9 abs.l */
        move.w  #1,MMU_CSR_PHYS         /* e00598 */
        clr.l   (DUMP_OFF_PKT_SEQ,%a5)  /* e005a0 */
        moveq   #34,%d5                 /* e005a4  35 pages */
dump_tables_loop:
        bsr.w   dump_send_page          /* e005a6 */
        addq.l  #1,(DUMP_OFF_PKT_SEQ,%a5) /* e005aa */
        add.l   %d6,%d7                 /* e005ae */
        dbf     %d5,dump_tables_loop    /* e005b0 */
dump_finish:
        moveq   #4,%d0                  /* e005b4  op 4 */
        cmp.b   (dump_pkt_op:w,%pc),%d0 /* e005b6 */
        beq.s   dump_done               /* e005ba */
        bsr.s   dump_send_request       /* e005bc */
dump_done:
        lea     (dump_str_done:w,%pc),%a0 /* e005be */
        bsr.w   dump_puts_nl            /* e005c2 */
        tst.b   (0x24,%fp)              /* e005c6  reboot? */
        beq.s   dump_quiet              /* e005ca */
        clr.b   (0).w                   /* e005cc */
        move.w  #0x7d0,%d0              /* e005d0 */
dump_reboot_wait:
        mulu.w  #3,%d2                  /* e005d4 */
        dbf     %d0,dump_reboot_wait    /* e005d8 */
        reset                           /* e005dc */
        movea.l (0).w,%sp               /* e005de */
        ori.w   #0x2700,%sr             /* e005e2 */
        jmp     (PROM_RESTART).w        /* e005e6 */
dump_quiet:
        movea.l (PROM_VEC_QUIET).w,%a0  /* e005ea */
        jmp     (%a0)                   /* e005ee */

/* 0xE005F0: the reboot sequence again, DUMP_$AUTO_REBOOT's. */
dump_reboot:
        move.w  #0x7d0,%d0              /* e005f0 */
dump_reboot_wait_2:
        mulu.w  #3,%d2                  /* e005f4 */
        dbf     %d0,dump_reboot_wait_2  /* e005f8 */
        reset                           /* e005fc */
        movea.l (0).w,%sp               /* e005fe */
        ori.w   #0x2700,%sr             /* e00602 */
        jmp     (PROM_RESTART).w        /* e00606 */

/* DUMP_$AUTO_REBOOT, 0xE0060A: print "REBOOTING", wait, reboot. */
DUMP_$AUTO_REBOOT:
        lea     (DUMP:w,%pc),%a5        /* e0060a */
        lea     REBOOT_STACK,%sp        /* e0060e  4ff9 abs.l */
        movea.l %sp,%fp                 /* e00614 */
        lea     (dump_str_rebooting:w,%pc),%a0 /* e00616 */
        bsr.w   dump_puts_nl            /* e0061a */
        move.w  #0x2000,%d0             /* e0061e */
dump_auto_reboot_wait:
        mulu.w  #3,%d2                  /* e00622 */
        dbf     %d0,dump_auto_reboot_wait /* e00626 */
        bra.s   dump_reboot             /* e0062a */

/*
 * dump_send_page, 0xE0062C: send the page at d7 (op 2,
 * length d6).  dump_send_request, 0xE00636: send op d0
 * with length 0 (the page number is that of DUMP itself, d7 = A5).  Both
 * save d0-d7/a1-a4 and share dump_xfer.
 */
dump_send_page:
        movem.l %d0-%d7/%a1-%a4,-(%sp)  /* e0062c */
        moveq   #2,%d0                  /* e00630 */
        move.l  %d6,%d1                 /* e00632 */
        bra.s   dump_xfer               /* e00634 */
dump_send_request:
        movem.l %d0-%d7/%a1-%a4,-(%sp)  /* e00636 */
        clr.w   %d1                     /* e0063a */
        move.l  %a5,%d7                 /* e0063c */
dump_xfer:
        move.w  %d1,(DUMP_OFF_PKT_LEN,%a5) /* e0063e */
        move.b  %d0,(DUMP_OFF_PKT_OP,%a5)  /* e00642 */
        move.l  %d7,%d0                 /* e00646  the page number */
        lsr.l   #8,%d0                  /* e00648 */
        lsr.l   #2,%d0                  /* e0064a */
        move.w  %d0,(0xa,%fp)           /* e0064c */
        move.w  #10,(8,%fp)             /* e00650  10 tries */
dump_xfer_send:
        pea     (4,%fp)                 /* e00656  status */
        pea     (dump_peer_id:w,%pc)    /* e0065a */
        pea     (0xa,%fp)               /* e0065e */
        pea     (dump_pkt_seq:w,%pc)    /* e00662 */
        movea.l (PROM_VEC_120).w,%a0    /* e00666 */
        jsr     (%a0)                   /* e0066a */
        adda.w  #0x10,%sp               /* e0066c */
        move.l  (4,%fp),%d0             /* e00670 */
        beq.s   dump_xfer_sent          /* e00674 */
        subq.w  #1,(8,%fp)              /* e00676 */
        bne.s   dump_xfer_send          /* e0067a */
        lea     (dump_str_xbad:w,%pc),%a0 /* e0067c */
        bra.w   dump_xfer_fail          /* e00680 */
dump_xfer_return:
        movem.l (%sp)+,%d0-%d7/%a1-%a4  /* e00684 */
        rts                             /* e00688 */
dump_xfer_sent:
dump_xfer_receive:
        move.w  #3,(8,%fp)              /* e0068a  3 tries */
dump_xfer_receive_try:
        pea     (4,%fp)                 /* e00690  status */
        move.l  #DUMP_RCV_BUF,-(%sp)    /* e00694 */
        pea     (dump_rcv_len:w,%pc)    /* e0069a */
        pea     (dump_pkt_seq:w,%pc)    /* e0069e */
        movea.l (PROM_VEC_110).w,%a0    /* e006a2 */
        jsr     (%a0)                   /* e006a6 */
        adda.w  #0x10,%sp               /* e006a8 */
        move.l  (4,%fp),%d0             /* e006ac */
        beq.s   dump_xfer_reply         /* e006b0 */
        subq.w  #1,(8,%fp)              /* e006b2 */
        bne.s   dump_xfer_send          /* e006b6 */
        lea     (dump_str_rbad:w,%pc),%a0 /* e006b8 */
        bra.s   dump_xfer_fail          /* e006bc */
dump_xfer_reply:
        lea     (0x26,%fp),%a0          /* e006be  the reply header */
        move.l  (dump_peer_id:w,%pc),%d0 /* e006c2 */
        cmp.l   (8,%a0),%d0             /* e006c6  from our peer? */
        bne.s   dump_xfer_receive       /* e006ca */
        lea     (0x1e,%a0),%a1          /* e006cc */
        clr.l   %d0                     /* e006d0 */
        move.b  (0x18,%a0),%d0          /* e006d2 */
        adda.l  %d0,%a1                 /* e006d6  the reply body */
        move.l  %a1,(0x20,%fp)          /* e006d8 */
        cmpi.w  #2,(%a1)                /* e006dc */
        bne.s   dump_xfer_bad_type      /* e006e0 */
        cmpi.w  #1,(2,%a1)              /* e006e2 */
        bne.s   dump_xfer_bad_type      /* e006e8 */
        move.b  (5,%a1),%d0             /* e006ea */
        subq.l  #1,%d0                  /* e006ee */
        cmp.b   (dump_pkt_op:w,%pc),%d0 /* e006f0  the reply to our op? */
        beq.s   dump_xfer_check_seq     /* e006f4 */
dump_xfer_bad_type:
        cmpi.b  #7,(5,%a1)              /* e006f6 */
        bne.s   dump_xfer_bad_reply     /* e006fc */
dump_xfer_retry:
        bra.s   dump_xfer_receive       /* e006fe */
dump_xfer_bad_reply:
        lea     (dump_str_bad_rpy:w,%pc),%a0 /* e00700 */
        bsr.s   dump_puts               /* e00704 */
dump_xfer_abort:
        bra.w   dump_finish             /* e00706 */
dump_xfer_check_seq:
        .short  0xb03c, 0x0002          /* e0070a  cmp.b #2,%d0 (<ea>=#imm form) */
        bne.s   dump_xfer_check_status  /* e0070e */
        move.l  (dump_pkt_seq:w,%pc),%d0 /* e00710 */
        cmp.l   (0xc,%a1),%d0           /* e00714 */
        bne.s   dump_xfer_retry         /* e00718 */
dump_xfer_check_status:
        move.l  (6,%a1),%d0             /* e0071a  the server's status */
        beq.w   dump_xfer_return        /* e0071e */
        lea     (dump_str_nm_sad:w,%pc),%a0 /* e00722 */
dump_xfer_fail:
        move.l  %d0,-(%sp)              /* e00726  "<msg> - St=<status>" */
        bsr.s   dump_puts               /* e00728 */
        lea     (dump_str_st:w,%pc),%a0 /* e0072a */
        bsr.s   dump_puts               /* e0072e */
        move.l  (%sp)+,%d0              /* e00730 */
        bsr.s   dump_put_hex_nl         /* e00732 */
        bra.s   dump_xfer_abort         /* e00734 */

/* dump_puts_nl, 0xE00736: print the string at a0, then CR LF. */
dump_puts_nl:
        bsr.s   dump_puts               /* e00736 */
dump_put_nl:
        lea     (dump_str_nl:w,%pc),%a0 /* e00738 */
/* dump_puts, 0xE0073C: print the NUL-terminated string at a0. */
dump_puts:
        move.b  (%a0)+,%d1              /* e0073c */
        beq.s   dump_rts                /* e0073e */
        bsr.s   dump_putc               /* e00740 */
        bra.s   dump_puts               /* e00742 */
        rts                             /* e00744  (unreachable, as in the image) */

/* dump_put_hex_nl, 0xE00746: print d0 as 8 hex digits, then CR LF. */
dump_put_hex_nl:
        moveq   #7,%d2                  /* e00746 */
dump_put_hex_digit:
        rol.l   #4,%d0                  /* e00748 */
        moveq   #15,%d1                 /* e0074a */
        and.b   %d0,%d1                 /* e0074c */
        .short  0xb23c, 0x000a          /* e0074e  cmp.b #10,%d1 (<ea>=#imm form) */
        blt.s   dump_put_hex_ascii      /* e00752 */
        addq.b  #7,%d1                  /* e00754  'A' - '0' - 10 */
dump_put_hex_ascii:
        .short  0xd23c, 0x0030          /* e00756  add.b #'0',%d1 (<ea>=#imm form) */
        bsr.s   dump_putc               /* e0075a */
        dbf     %d2,dump_put_hex_digit  /* e0075c */
        bra.s   dump_put_nl             /* e00760 */

/* dump_putc, 0xE00762: the character in d1 through the PROM, every register kept. */
dump_putc:
        movem.l %d0-%d7/%a0-%a4,-(%sp)  /* e00762 */
        movea.l (PROM_VEC_PUTC).w,%a0   /* e00766 */
        jsr     (%a0)                   /* e0076a */
        movem.l (%sp)+,%d0-%d7/%a0-%a4  /* e0076c */
dump_rts:
        rts                             /* e00770 */

/*
 * 0xE00772: the cells.  The packet the PROM send/receive vectors take
 * (dump_pkt_seq is its first argument) with its length word and op byte
 * just ahead of it; the peer id the reply must carry; the receive length;
 * the messages; the flags; and the map's three public cells.
 */
dump_peer_id:
        .long   0                       /* e00772 */
        .long   0, 0                    /* e00776 */
        .byte   0x01, 0x01, 0x00, 0x00  /* e0077e */
        .byte   0x00, 0x2c, 0x00, 0x0a  /* e00782 */
dump_pkt_len:
        .short  0x0000                  /* e00786 */
        .short  0x0000                  /* e00788 */
        .byte   0x04, 0x01, 0x00, 0x00  /* e0078a */
        .byte   0x00, 0x00, 0x00, 0x00  /* e0078e */
        .byte   0x00, 0x03, 0x00, 0x02  /* e00792 */
        .byte   0x00, 0x01, 0x03        /* e00796 */
dump_pkt_op:
        .byte   0x00                    /* e00799 */
dump_pkt_seq:
        .long   0                       /* e0079a */
dump_rcv_len:
        .short  0x0400                  /* e0079e */
dump_str_xbad:
        .asciz  "Xbad"                  /* e007a0 */
dump_str_rbad:
        .asciz  "Rbad"                  /* e007a5 */
dump_str_bad_rpy:
        .asciz  "Bad rpy"               /* e007aa */
dump_str_nm_sad:
        .asciz  "Nm sad"                /* e007b2 */
dump_str_st:
        .asciz  " - St="                /* e007b9 */
dump_str_rebooting:
        .asciz  "REBOOTING"             /* e007c0  DUMP_$AUTO_REBOOT's message */
dump_str_nl:
        .byte   0x0a, 0x0d, 0x00        /* e007ca */
dump_str_done:
        .byte   0x0a, 0x0d              /* e007cd */
        .asciz  "Done"
dump_flags:
        .short  0x0000                  /* e007d4  bit 0 entered, bit 1 68020 */
DUMP_$SMAP_PHADDR:
        .long   0                       /* e007d6 */
        .space  0x0e                    /* e007da */
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
