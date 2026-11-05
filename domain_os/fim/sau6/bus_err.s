/*
 * fim/sau6/bus_err.s - the SAU6's bus error and NMI handlers, with the
 * memory boards' error handler and the cells before them (SAU6)
 *
 * SAU6 map, in "D 78023E94 FIM_WIRED size = 131C":
 *   0x78023EF6  MCSR_CONFIG      the memory boards present, bit 0 the
 *                                first, bit 1 the second (MEM_$INIT adds
 *                                them; mem/mem.ins.pas)
 *   0x78023EF8  MMU_$BUS_STATUS  the last bus error's MMU status word
 *   0x78023EFA  MEM_$MCSR1, MEM_$MEAR1, MEM_$MCSR2, MEM_$MEAR2
 *                                the two boards' status and error address
 *                                registers as the error handler last read
 *                                them (and two bytes before FIM_$BUS_ERR)
 *   0x78023F0C  FIM_$BUS_ERR     the bus error (vector 2) handler
 *   0x78024158  (no map name)    the memory boards' error handler
 *   0x780241FC  FIM_$NMI         the level 7 interrupt
 * to 0x780242CE (FIM_$FLINE's FPU entry, fim/sau6/fp.s, follows).  One
 * section, keyed by MCSR_CONFIG: the handlers branch into one another
 * and reach one another's status cells.  CPU_B_PBU_SWITCH, JMP_TO_BUS_ERR
 * and BUS_ERROR_SWITCH before it are fim/m68k/bus_err.s's (`fim_vme_ack'),
 * FP_$SAVEP and FP_$OWNER fp/m68k/savep.s's.
 *
 * The DN5xxT's (`mmu_status_bit_6', `ecc6_memory', `fim_vme_ack',
 * base/config.ins.pas):
 *   - FIM_$BUS_ERR, at IPL 7, reads the MMU's word at +0xE (and drops
 *     it), keeps the status word at +2 in MMU_$BUS_STATUS and writes it
 *     back with bit 6 clear.  In a PBU's user interrupt routine
 *     (CPU_B_PBU_SWITCH set): signal 19, "illegal page fault in user
 *     gpio interrupt routine".  Status bit 7: an FPU access, delivered
 *     as FIM_$FP_VEC_EXCEPTION unless the FPU is enabled (MMU + 9 bit
 *     7), then FIM_$FLINE's owner switch or, with no save area, the
 *     crash of status bit 8 below.  Otherwise the faulting address from the
 *     frame (format A or B, from the special status word), then by the
 *     status's bits 13..11: none of them, bit 9 an access violation
 *     (SIGSEGV), bit 15 an FPU coprocessor's address (16#FFFFFC10: the
 *     FPU's saved state tested for a pending exception, then
 *     FIM_$FP_VEC_EXCEPTION) or a CPU-space access (16#FFFFFC00 or
 *     16#FFFFFE00 pages: "reference to illegal address", SIGSEGV, else
 *     a crash, "unexpected virtual timeout"), bit 14 a memory error (the
 *     boards' handler; with none to report, a bus time-out to
 *     BUS_ERROR_SWITCH when one is armed and the VME adapter shows none,
 *     else SIGBUS, "bus time-out", after VME_$SAVE_VME), bit 8 a crash,
 *     "unknown mmu status",
 *     after a type-7 log entry with no data; of bits 13..11, bit 14
 *     set as well a crash, "mmu timeout"; bit 13 "reference to
 *     illegal address" (SIGSEGV); else MST_$TOUCH, the guard fault as on
 *     the SAU2, any other status SIGSEGV.  A signal goes through FIM_$COM
 *     as the SAU2's do, after the VME adapter is acknowledged (VME_CTL +
 *     8 ORed with 16#440) where the path says so.
 *   - the boards' handler (bsr, Z clear when it served a board): each
 *     board present (MCSR_CONFIG) whose status has any of its bits
 *     15..13: bit 14 set, its registers to MEM_$ECCC6_LOG (the status's
 *     high word written back); bit 14 clear, a crash, "uncorrectable
 *     memory error detected".  Board 1's registers at MEM, board 2's at
 *     MEM + 16#80; their status and error address are kept in MEM_$MCSR1
 *     .. MEM_$MEAR2.
 *   - FIM_$NMI: the MMU's word at +0x18 (after VME_$SAVE_VME): bit 7 "ac
 *     power failure", bit 6 "data cache parity error", bit 5 "mmu parity
 *     error", each a crash; bit 3 the VME bus (VME_CTL + 9 bit 7 "VME
 *     bus error on bus error", a crash), else the boards' handler, and
 *     with none to report a VME bus error: to BUS_ERROR_SWITCH when one
 *     is armed, after CACHE_$CLEAR, else a crash, "vme bus error"; the
 *     adapter is acknowledged (16#444) on the way out through FIM_$EXIT.
 *
 * Byte gate (the SAU6 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68020 -m68881' and compared with the image at the map's
 * addresses, modulo relocations.  The Apollo assembler's <ea>=#imm forms
 * of CMP/AND (gas's CMPI/ANDI) and the byte immediates with a zero high
 * byte are `.short' words.  The address and byte columns are the SAU6
 * image's.
 */

        .include "base/config.inc"
        .if mmu_status_bit_6

        .extern CPU_B_PBU_SWITCH        /* fim/m68k/bus_err.s */
        .extern JMP_TO_BUS_ERR          /* fim/m68k/bus_err.s */
        .extern BUS_ERROR_SWITCH        /* fim/m68k/bus_err.s */
        .extern FP_$SAVEP               /* fp/m68k/savep.s */
        .extern fim_fline_fault_entry   /* fim/sau6/fp.s */
        .extern FIM_$FP_VEC_EXCEPTION   /* fim/m68k/fp_exceptions.s */
        .extern FIM_$COM                /* fim/m68k/com.s */
        .extern FIM_$EXIT               /* fim/m68k/exit.s */
        .extern FIM_$DELIVER_TRACE_FAULT /* fim/m68k/deliver_trace_fault.s */
        .extern FIM_$TRACE_STS          /* fim/m68k/wired_data.s */
        .extern MST_$TOUCH
        .extern MEM_$ECCC6_LOG          /* mem/eccc6_log.pas */
        .extern LOG_$ADD
        .extern CRASH_SYSTEM
        .extern CACHE_$CLEAR
        .extern VME_$SAVE_VME
        .extern PROC1_$AS_ID
        .extern M68881_EXISTS
        .extern MMU                     /* I/O definitions */
        .extern MEM
        .extern VME_CTL

        .section ".text.MCSR_CONFIG","ax",@progbits
        .even

        .global MCSR_CONFIG
        .global MMU_$BUS_STATUS
        .global MEM_$MCSR1
        .global MEM_$MEAR1
        .global MEM_$MCSR2
        .global MEM_$MEAR2
        .global FIM_$BUS_ERR
        .global FIM_$NMI

MCSR_CONFIG:
        .short  0                       /* sau6 78023ef6 */
MMU_$BUS_STATUS:
        .short  0                       /* sau6 78023ef8 */
MEM_$MCSR1:
        .long   0                       /* sau6 78023efa */
MEM_$MEAR1:
        .long   0                       /* sau6 78023efe */
MEM_$MCSR2:
        .long   0                       /* sau6 78023f02 */
MEM_$MEAR2:
        .long   0                       /* sau6 78023f06 */
        .short  0                       /* sau6 78023f0a, before FIM_$BUS_ERR */
FIM_$BUS_ERR:
        ori.w   #1792,%sr                        /* sau6 78023f0c  007c 0700 */
        subq.w  #8,%sp                           /* sau6 78023f10  514f */
        movem.l %d0-%d2/%a0-%a1,-(%sp)           /* sau6 78023f12  48e7 e0c0 */
        move.w  (MMU+0xe).l,%d0                  /* sau6 78023f16  3039 7fff b40e */
        move.w  (MMU+0x2).l,%d1                  /* sau6 78023f1c  3239 7fff b402 */
        move.w  %d1,(MMU_$BUS_STATUS).l          /* sau6 78023f22  33c1 7802 3ef8 */
        bclr    #6,%d1                           /* sau6 78023f28  0881 0006 */
        move.w  %d1,(MMU+0x2).l                  /* sau6 78023f2c  33c1 7fff b402 */
        tst.b   (CPU_B_PBU_SWITCH).l             /* sau6 78023f32  4a39 7802 3ece */
        bne.w   .L780240e4                       /* sau6 78023f38  6600 01aa */
        btst    #7,%d1                           /* sau6 78023f3c  0801 0007 */
        bne.w   .L780240f2                       /* sau6 78023f40  6600 01b0 */
        move.w  (38,%sp),%d0                     /* sau6 78023f44  302f 0026 */
        btst    #8,%d0                           /* sau6 78023f48  0800 0008 */
        beq.s   .L78023f54                       /* sau6 78023f4c  6706 */
        move.l  (44,%sp),%d2                     /* sau6 78023f4e  242f 002c */
        bra.s   .L78023f78                       /* sau6 78023f52  6024 */
.L78023f54:
        .short  0x0c2f, 0x00a0, 0x0022  /* cmpib #-96,%sp@(34) */ /* sau6 78023f54  0c2f 00a0 0022 */
        bne.s   .L78023f6c                       /* sau6 78023f5a  6610 */
        move.l  (30,%sp),%d2                     /* sau6 78023f5c  242f 001e */
        addq.l  #2,%d2                           /* sau6 78023f60  5482 */
        btst    #14,%d0                          /* sau6 78023f62  0800 000e */
        beq.s   .L78023f78                       /* sau6 78023f66  6710 */
        addq.l  #2,%d2                           /* sau6 78023f68  5482 */
        bra.s   .L78023f78                       /* sau6 78023f6a  600c */
.L78023f6c:
        move.l  (64,%sp),%d2                     /* sau6 78023f6c  242f 0040 */
        btst    #15,%d0                          /* sau6 78023f70  0800 000f */
        beq.s   .L78023f78                       /* sau6 78023f74  6702 */
        subq.l  #2,%d2                           /* sau6 78023f76  5582 */
.L78023f78:
        move.w  #14336,%d0                       /* sau6 78023f78  303c 3800 */
        and.w   %d1,%d0                          /* sau6 78023f7c  c041 */
        beq.w   .L7802402a                       /* sau6 78023f7e  6700 00aa */
        btst    #14,%d1                          /* sau6 78023f82  0801 000e */
        bne.s   .L78023fec                       /* sau6 78023f86  6664 */
        andi.w  #-1793,%sr                       /* sau6 78023f88  027c f8ff */
        btst    #13,%d1                          /* sau6 78023f8c  0801 000d */
        bne.s   .L78023ff4                       /* sau6 78023f90  6662 */
        move.l  #0,-(%sp)                        /* sau6 78023f92  2f3c 0000 0000 */
        pea     (24,%sp)                         /* sau6 78023f98  486f 0018 */
        move.l  %d2,-(%sp)                       /* sau6 78023f9c  2f02 */
        andi.w  #-1793,%sr                       /* sau6 78023f9e  027c f8ff */
        jsr     (MST_$TOUCH).l                   /* sau6 78023fa2  4eb9 7800 e4ac */
        adda.l  #12,%sp                          /* sau6 78023fa8  dffc 0000 000c */
        move.l  (20,%sp),%d0                     /* sau6 78023fae  202f 0014 */
        bne.s   .L78023fbe                       /* sau6 78023fb2  660a */
.L78023fb4:
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 78023fb4  4cdf 0307 */
        addq.w  #8,%sp                           /* sau6 78023fb8  504f */
        jmp     (FIM_$EXIT:w,%pc)                  /* sau6 78023fba  4efa 11aa */
.L78023fbe:
        move.w  #11,%d1                          /* sau6 78023fbe  323c 000b */
        .short  0xb0bc, 0x0004, 0x000a  /* cmpl #0x4000a,%d0 */ /* sau6 78023fc2  b0bc 0004 000a */
        bne.s   .L7802400c                       /* sau6 78023fc8  6642 */
        move.w  (PROC1_$AS_ID).l,-(%sp)          /* sau6 78023fca  3f39 7802 2baa */
        bsr.w   FIM_$DELIVER_TRACE_FAULT         /* sau6 78023fd0  6100 113e */
        addq.l  #2,%sp                           /* sau6 78023fd4  548f */
        move.w  (PROC1_$AS_ID).l,%d0             /* sau6 78023fd6  3039 7802 2baa */
        lsl.w   #2,%d0                           /* sau6 78023fdc  e548 */
        lea     (FIM_$TRACE_STS:w,%pc),%a0         /* sau6 78023fde  41fa 0c80 */
        move.l  #0x4000a,(0,%a0,%d0.w)            /* sau6 78023fe2  21bc 0004 000a 0000 */
        bra.s   .L78023fb4                       /* sau6 78023fea  60c8 */
.L78023fec:
        pea     (.L78024154,%pc)                 /* sau6 78023fec  487a 0166 */
        bra.w   .L78024134                       /* sau6 78023ff0  6000 0142 */
.L78023ff4:
        move.l  #0x40004,%d0                      /* sau6 78023ff4  203c 0004 0004 */
        move.w  #11,%d1                          /* sau6 78023ffa  323c 000b */
        bra.s   .L7802400c                       /* sau6 78023ffe  600c */
.L78024000:
        ori.w   #1088,(VME_CTL+0x8).l            /* sau6 78024000  0079 0440 7fff 9408 */
.L78024008:
        andi.w  #-1793,%sr                       /* sau6 78024008  027c f8ff */
.L7802400c:
        move.l  %d0,(20,%sp)                     /* sau6 7802400c  2f40 0014 */
        move.w  %d1,(24,%sp)                     /* sau6 78024010  3f41 0018 */
        move.w  #12288,(26,%sp)                  /* sau6 78024014  3f7c 3000 001a */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 7802401a  4cdf 0307 */
        pea     (%sp)                            /* sau6 7802401e  4857 */
        pea     (12,%sp)                         /* sau6 78024020  486f 000c */
        jmp     (FIM_$COM).l                     /* sau6 78024024  4ef9 7802 3944 */
.L7802402a:
        btst    #9,%d1                           /* sau6 7802402a  0801 0009 */
        beq.s   .L7802403c                       /* sau6 7802402e  670c */
        move.l  #0x120011,%d0                     /* sau6 78024030  203c 0012 0011 */
        move.w  #11,%d1                          /* sau6 78024036  323c 000b */
        bra.s   .L78024008                       /* sau6 7802403a  60cc */
.L7802403c:
        btst    #15,%d1                          /* sau6 7802403c  0801 000f */
        beq.s   .L780240a0                       /* sau6 78024040  675e */
        .short  0xb4bc, 0xffff, 0xfc10  /* cmpl #-1008,%d2 */ /* sau6 78024042  b4bc ffff fc10 */
        bne.s   .L78024076                       /* sau6 78024048  662c */
        movea.l %sp,%a0                          /* sau6 7802404a  204f */
        fsave   -(%sp)                           /* sau6 7802404c  f327 */
        tst.w   (M68881_EXISTS).l                /* sau6 7802404e  4a79 7809 bee6 */
        bne.w   .L7802405e                       /* sau6 78024054  6600 0008 */
        move.w  #17470,(0xfc0a).w                /* sau6 78024058  31fc 443e fc0a */
.L7802405e:
        move.w  (-2,%a0),%d0                     /* sau6 7802405e  3028 fffe */
        movea.l %a0,%sp                          /* sau6 78024062  2e48 */
        btst    #11,%d0                          /* sau6 78024064  0800 000b */
        beq.s   .L78024076                       /* sau6 78024068  670c */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 7802406a  4cdf 0307 */
        addq.w  #8,%sp                           /* sau6 7802406e  504f */
        jmp     (FIM_$FP_VEC_EXCEPTION).l        /* sau6 78024070  4ef9 7802 3acc */
.L78024076:
        .short  0xc47c, 0xfe00  /* andw #-512,%d2 */ /* sau6 78024076  c47c fe00 */
        .short  0xb4bc, 0xffff, 0xfe00  /* cmpl #-512,%d2 */ /* sau6 7802407a  b4bc ffff fe00 */
        beq.s   .L7802408a                       /* sau6 78024080  6708 */
        .short  0xb4bc, 0xffff, 0xfc00  /* cmpl #-1024,%d2 */ /* sau6 78024082  b4bc ffff fc00 */
        bne.s   .L78024098                       /* sau6 78024088  660e */
.L7802408a:
        move.l  #0x40004,%d0                      /* sau6 7802408a  203c 0004 0004 */
        move.w  #11,%d1                          /* sau6 78024090  323c 000b */
        bra.w   .L78024008                       /* sau6 78024094  6000 ff72 */
.L78024098:
        pea     (.L78024150,%pc)                 /* sau6 78024098  487a 00b6 */
        bra.w   .L78024134                       /* sau6 7802409c  6000 0096 */
.L780240a0:
        btst    #14,%d1                          /* sau6 780240a0  0801 000e */
        beq.w   .L7802411a                       /* sau6 780240a4  6700 0074 */
        bsr.w   .L78024158                       /* sau6 780240a8  6100 00ae */
        bne.w   .L7802413c                       /* sau6 780240ac  6600 008e */
        btst    #7,(VME_CTL+0x80).l              /* sau6 780240b0  0839 0007 7fff 9480 */
        bne.s   .L780240d0                       /* sau6 780240b8  6616 */
        tst.l   (BUS_ERROR_SWITCH).l             /* sau6 780240ba  4ab9 7802 3eda */
        beq.s   .L780240d0                       /* sau6 780240c0  670e */
        jsr     (CACHE_$CLEAR).l                 /* sau6 780240c2  4eb9 7802 6e24 */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 780240c8  4cdf 0307 */
        bra.w   JMP_TO_BUS_ERR             /* sau6 780240cc  6000 fe02 */
.L780240d0:
        jsr     (VME_$SAVE_VME).l                /* sau6 780240d0  4eb9 7802 51b0 */
        move.l  #0x12000c,%d0                     /* sau6 780240d6  203c 0012 000c */
        move.w  #10,%d1                          /* sau6 780240dc  323c 000a */
        bra.w   .L78024000                       /* sau6 780240e0  6000 ff1e */
.L780240e4:
        move.l  #0x120031,%d0                     /* sau6 780240e4  203c 0012 0031 */
        move.w  #19,%d1                          /* sau6 780240ea  323c 0013 */
        bra.w   .L78024000                       /* sau6 780240ee  6000 ff10 */
.L780240f2:
        btst    #7,(MMU+0x9).l                   /* sau6 780240f2  0839 0007 7fff b409 */
        bne.s   .L78024108                       /* sau6 780240fa  660c */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 780240fc  4cdf 0307 */
        addq.w  #8,%sp                           /* sau6 78024100  504f */
        jmp     (FIM_$FP_VEC_EXCEPTION).l        /* sau6 78024102  4ef9 7802 3acc */
.L78024108:
        tst.l   (FP_$SAVEP).l                    /* sau6 78024108  4ab9 7802 3ede */
        beq.s   .L78024120                       /* sau6 7802410e  6710 */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 78024110  4cdf 0307 */
        addq.w  #8,%sp                           /* sau6 78024114  504f */
        bra.w   fim_fline_fault_entry                    /* sau6 78024116  6000 01b6 */
.L7802411a:
        btst    #8,%d1                           /* sau6 7802411a  0801 0008 */
        beq.s   .L7802413c                       /* sau6 7802411e  671c */
.L78024120:
        clr.w   -(%sp)                           /* sau6 78024120  4267 */
        clr.l   -(%sp)                           /* sau6 78024122  42a7 */
        move.w  #7,-(%sp)                        /* sau6 78024124  3f3c 0007 */
        jsr     (LOG_$ADD).l                     /* sau6 78024128  4eb9 7801 8112 */
        addq.w  #8,%sp                           /* sau6 7802412e  504f */
        pea     (.L7802414c,%pc)                 /* sau6 78024130  487a 001a */
.L78024134:
        jsr     (CRASH_SYSTEM).l                  /* sau6 78024134  4eb9 7802 0af8 */
        addq.w  #4,%sp                           /* sau6 7802413a  584f */
.L7802413c:
        ori.w   #1088,(VME_CTL+0x8).l            /* sau6 7802413c  0079 0440 7fff 9408 */
        bra.w   .L78023fb4                       /* sau6 78024144  6000 fe6e */
.L78024148:
        .short  0x0027, 0x0002                   /* sau6 78024148  0027 0002 */
.L7802414c:
        .short  0x0007, 0x0007                   /* sau6 7802414c  0007 0007 */
.L78024150:
        .short  0x0007, 0x000a                   /* sau6 78024150  0007 000a */
.L78024154:
        .short  0x0007, 0x0006                   /* sau6 78024154  0007 0006 */
.L78024158:
        movea.l #MEM,%a0                         /* sau6 78024158  207c 7fff 9800 */
        move.l  (4,%a0),(MEM_$MEAR1).l           /* sau6 7802415e  23e8 0004 7802 3efe */
        move.l  (%a0),%d0                        /* sau6 78024166  2010 */
        move.l  %d0,(MEM_$MCSR1).l               /* sau6 78024168  23c0 7802 3efa */
        swap    %d0                              /* sau6 7802416e  4840 */
        .short  0xc07c, 0xe000  /* andw #-8192,%d0 */ /* sau6 78024170  c07c e000 */
        beq.s   .L7802418e                       /* sau6 78024174  6718 */
        btst    #14,%d0                          /* sau6 78024176  0800 000e */
        beq.s   .L780241d8                       /* sau6 7802417a  675c */
        move.l  (%a0),-(%sp)                     /* sau6 7802417c  2f10 */
        move.l  (4,%a0),-(%sp)                   /* sau6 7802417e  2f28 0004 */
        move.w  (8,%a0),-(%sp)                   /* sau6 78024182  3f28 0008 */
        move.w  %d0,(%a0)                        /* sau6 78024186  3080 */
        move.w  #1,-(%sp)                        /* sau6 78024188  3f3c 0001 */
        bra.s   .L780241ca                       /* sau6 7802418c  603c */
.L7802418e:
        btst    #1,(MCSR_CONFIG+1:w,%pc)              /* sau6 7802418e  083a 0001 fd65 */
        beq.s   .L780241d6                       /* sau6 78024194  6740 */
        move.l  (132,%a0),(MEM_$MEAR2).l         /* sau6 78024196  23e8 0084 7802 3f06 */
        move.l  (128,%a0),%d0                    /* sau6 7802419e  2028 0080 */
        move.l  %d0,(MEM_$MCSR2).l               /* sau6 780241a2  23c0 7802 3f02 */
        swap    %d0                              /* sau6 780241a8  4840 */
        .short  0xc07c, 0xe000  /* andw #-8192,%d0 */ /* sau6 780241aa  c07c e000 */
        beq.s   .L780241d6                       /* sau6 780241ae  6726 */
        btst    #14,%d0                          /* sau6 780241b0  0800 000e */
        beq.s   .L780241d8                       /* sau6 780241b4  6722 */
        move.l  (128,%a0),-(%sp)                 /* sau6 780241b6  2f28 0080 */
        move.l  (132,%a0),-(%sp)                 /* sau6 780241ba  2f28 0084 */
        move.w  (136,%a0),-(%sp)                 /* sau6 780241be  3f28 0088 */
        move.w  %d0,(128,%a0)                    /* sau6 780241c2  3140 0080 */
        move.w  #2,-(%sp)                        /* sau6 780241c6  3f3c 0002 */
.L780241ca:
        jsr     (MEM_$ECCC6_LOG).l               /* sau6 780241ca  4eb9 7800 b8f4 */
        adda.w  #12,%sp                          /* sau6 780241d0  defc 000c */
.L780241d4:
        moveq   #-1,%d0                          /* sau6 780241d4  70ff */
.L780241d6:
        rts                                      /* sau6 780241d6  4e75 */
.L780241d8:
        pea     (.L780242c6,%pc)                 /* sau6 780241d8  487a 00ec */
        jsr     (CRASH_SYSTEM).l                  /* sau6 780241dc  4eb9 7802 0af8 */
        addq.w  #4,%sp                           /* sau6 780241e2  584f */
        move.w  (%a0),%d0                        /* sau6 780241e4  3010 */
        move.w  %d0,(%a0)                        /* sau6 780241e6  3080 */
        btst    #1,(MCSR_CONFIG+1:w,%pc)              /* sau6 780241e8  083a 0001 fd0b */
        beq.s   .L780241d4                       /* sau6 780241ee  67e4 */
        move.w  (128,%a0),%d0                    /* sau6 780241f0  3028 0080 */
        move.w  %d0,(128,%a0)                    /* sau6 780241f4  3140 0080 */
        bra.s   .L780241d4                       /* sau6 780241f8  60da */
        .short  0x0000                           /* sau6 780241fa  0000 */
FIM_$NMI:
        movem.l %d0-%d2/%a0-%a1,-(%sp)           /* sau6 780241fc  48e7 e0c0 */
        move.w  (MMU+0x18).l,%d2                 /* sau6 78024200  3439 7fff b418 */
        jsr     (VME_$SAVE_VME).l                /* sau6 78024206  4eb9 7802 51b0 */
        btst    #7,%d2                           /* sau6 7802420c  0802 0007 */
        beq.s   .L7802421a                       /* sau6 78024210  6708 */
        pea     (.L780242b6,%pc)                 /* sau6 78024212  487a 00a2 */
        bra.w   .L7802429e                       /* sau6 78024216  6000 0086 */
.L7802421a:
        btst    #6,%d2                           /* sau6 7802421a  0802 0006 */
        beq.s   .L78024226                       /* sau6 7802421e  6706 */
        pea     (.L780242ba,%pc)                 /* sau6 78024220  487a 0098 */
        bra.s   .L7802429e                       /* sau6 78024224  6078 */
.L78024226:
        btst    #5,%d2                           /* sau6 78024226  0802 0005 */
        beq.s   .L78024232                       /* sau6 7802422a  6706 */
        pea     (.L780242be,%pc)                 /* sau6 7802422c  487a 0090 */
        bra.s   .L7802429e                       /* sau6 78024230  606c */
.L78024232:
        btst    #3,%d2                           /* sau6 78024232  0802 0003 */
        beq.s   .L780242a6                       /* sau6 78024236  676e */
        btst    #7,(VME_CTL+0x9).l               /* sau6 78024238  0839 0007 7fff 9409 */
        beq.s   .L78024248                       /* sau6 78024240  6706 */
        pea     (.L780242c2,%pc)                 /* sau6 78024242  487a 007e */
        bra.s   .L7802429e                       /* sau6 78024246  6056 */
.L78024248:
        bsr.w   .L78024158                       /* sau6 78024248  6100 ff0e */
        bne.s   .L780242a6                       /* sau6 7802424c  6658 */
        btst    #7,(VME_CTL+0x80).l              /* sau6 7802424e  0839 0007 7fff 9480 */
        bne.s   .L7802429a                       /* sau6 78024256  6642 */
        tst.l   (BUS_ERROR_SWITCH).l             /* sau6 78024258  4ab9 7802 3eda */
        beq.s   .L78024276                       /* sau6 7802425e  6716 */
        jsr     (CACHE_$CLEAR).l                 /* sau6 78024260  4eb9 7802 6e24 */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 78024266  4cdf 0307 */
        ori.w   #4,(VME_CTL+0x8).l               /* sau6 7802426a  0079 0004 7fff 9408 */
        bra.w   JMP_TO_BUS_ERR             /* sau6 78024272  6000 fc5c */
.L78024276:
        ori.w   #1092,(VME_CTL+0x8).l            /* sau6 78024276  0079 0444 7fff 9408 */
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 7802427e  4cdf 0307 */
        move.w  #8192,-(%sp)                     /* sau6 78024282  3f3c 2000 */
        move.w  #10,-(%sp)                       /* sau6 78024286  3f3c 000a */
        move.l  #0x270002,-(%sp)                  /* sau6 7802428a  2f3c 0027 0002 */
        pea     (%sp)                            /* sau6 78024290  4857 */
        pea     (12,%sp)                         /* sau6 78024292  486f 000c */
        andi.w  #-1793,%sr                       /* sau6 78024296  027c f8ff */
.L7802429a:
        pea     (.L78024148,%pc)                 /* sau6 7802429a  487a feac */
.L7802429e:
        jsr     (CRASH_SYSTEM).l                  /* sau6 7802429e  4eb9 7802 0af8 */
        addq.w  #4,%sp                           /* sau6 780242a4  584f */
.L780242a6:
        movem.l (%sp)+,%d0-%d2/%a0-%a1           /* sau6 780242a6  4cdf 0307 */
        ori.w   #1092,(VME_CTL+0x8).l            /* sau6 780242aa  0079 0444 7fff 9408 */
        jmp     (FIM_$EXIT:w,%pc)                  /* sau6 780242b2  4efa 0eb2 */
.L780242b6:
        .short  0x0012, 0x0037                   /* sau6 780242b6  0012 0037 */
.L780242ba:
        .short  0x0007, 0x0009                   /* sau6 780242ba  0007 0009 */
.L780242be:
        .short  0x0007, 0x0008                   /* sau6 780242be  0007 0008 */
.L780242c2:
        .short  0x0012, 0x003a                   /* sau6 780242c2  0012 003a */
.L780242c6:
        .short  0x0012, 0x000f                   /* sau6 780242c6  0012 000f */
        .short  0x0012, 0x000e                   /* sau6 780242ca  0012 000e */
        .endif
