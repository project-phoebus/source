/*
 * fim/m68k/spurious_int.s - FIM_$SPURIOUS_INT and its counters
 * (m68k/SAU2, SAU3, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here except the distance
 * from the FIM_WIRED segment's start (A5, below) to the routine: 0x690 on
 * the SAU2, 0x6E4 on the SAU5 (FIM_$TRACE_BIT 0xE22558, FIM_$SPURIOUS_INT
 * 0xE22C3C), the 0x54 bytes the SAU5's `pbu_driver' arms add ahead of it
 * (fim/m68k/bus_err.s: CPU_B_PBU_SWITCH, an alignment word, the PBU fault
 * path).  So the `lea' and the three displacements are written from
 * .Lspur_dist, set by that part.  The address and byte columns below are
 * the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E21F20..0x00E21F83 (map
 * FIM_$SPURIOUS_INT and FIM_$SPUR_CNT to FIM_$PARITY_TRAP, 100 bytes: 90 of
 * code and the three cells it keeps after itself), in one section so
 * tools/gen_layout_ld.py links it at its map position.  FIM_$SPUR_CNT,
 * the map symbol at 0x00E21F7E, is defined here rather than in its own
 * section because the routine reaches the cells off its module base
 * (below).
 *
 * The default handler for an interrupt no device claims (PEB_$DISP_INT_ADDR,
 * peb/m68k/int.s, until SMD_$INTERRUPT_INIT installs its own).  It counts
 * every one in FIM_$SPUR_CNT; within one TIME_$CLOCKH tick it allows 1000,
 * and the 1000th crashes the system through FIM_$CRASH with status
 * "spurious interrupt" (0x00120033) - FIM_$CRASH may return, and then so
 * does this, with rte.  A new tick re-arms the allowance.
 *
 * Module base.  The image loads A5 = 0x00E21890, the start of the FIM_WIRED
 * segment (FIM_$TRACE_BIT), with `lea (-0x696,PC),A5', and reaches its
 * cells as (0x6ea/0x6ee/0x6f2,A5) = 0x00E21F7A / 0x00E21F7E / 0x00E21F82
 * (the SAU5's `lea (-0x6ea,PC),A5', (0x73e/0x742/0x746,A5)).
 * Those cells are in this section and nothing else uses A5 here, so the
 * base is modelled as .Lspur_a5 = FIM_$SPURIOUS_INT - .Lspur_dist, the place
 * the segment start has relative to this routine: the `lea' and every
 * displacement keep the image's bytes and land on this section's cells in
 * our link.  (A5 does not equal our FIM_$TRACE_BIT.)  The byte gate is what
 * pins the three displacements: the section must be byte-identical to the
 * image, so the cells sit at the image's distance from the routine (gas
 * cannot check it with .if across the relaxable PC-relative operands).
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations.
 *
 * The routine reaches its cells off A5 = FIM_$TRACE_BIT, the start of
 * FIM_WIRED, so the distance from there is the SAU's layout: on the SAU9
 * (FIM_$NMI and MMU_$BUS_STATUS ahead of it, `fim_nmi') 0x6EC; on the
 * SAU3 (the PBU arms without the display window's 0x3E bytes,
 * `display_driver' in fim/m68k/bus_err.s) 0x6A8; on the SAU8
 * (`cpu_status_register' with `parity_cpu_status': its own FIM_$BUS_ERR,
 * fim/sau8/bus_err.s, and the FPU routines' longer enable) 0x73C; on the
 * SAU4 (`region_mmu': its MMU's fault handlers, fim/sau4/bus_err.s, and
 * the FP save tables, fim/sau4/fp.s) 0x1384.  Where
 * the bus error status is the CPU status register (`cpu_status_register')
 * the routine also clears it after the `lea', 12 bytes that put its cells
 * 12 further on (.Lspur_pre).
 */

        .include "base/config.inc"

        .section ".text.FIM_$SPURIOUS_INT","ax",@progbits
        .even

        .if cpu_status_register
        .if parity_cpu_status
        .set    .Lspur_dist, 0x73c      /* sau8: 0x3C2380C - 0x3C230D0 */
        .else
        .set    .Lspur_dist, 0xe40      /* sau7: 0x3C427174 - 0x3C426334 */
        .endif
        .set    .Lspur_pre, 12          /* the CPU status register cleared */
        .else
        .set    .Lspur_pre, 0
        .if pbu_driver
        .if region_mmu
        .set    .Lspur_dist, 0x1384     /* sau4: 0xF8241E4 - 0xF822E60 */
        .elseif display_driver
        .set    .Lspur_dist, 0x6e4      /* sau5: 0xE22C3C - 0xE22558 */
        .else
        .set    .Lspur_dist, 0x6a8      /* sau3: 0xE20E70 - 0xE207C8 */
        .endif
        .elseif fim_nmi
        .set    .Lspur_dist, 0x6ec      /* sau9: 0x3C424B8C - 0x3C4244A0 */
        .else
        .set    .Lspur_dist, 0x690      /* 0xE21F20 - 0xE21890 */
        .endif
        .endif
        /* the cells' offsets in this routine: .Lspur_last_tick 0x5A,
         * FIM_$SPUR_CNT 0x5E, .Lspur_allowance 0x62 */

        .extern TIME_$CLOCKH_EC

        .set    TIME_$CLOCKH, TIME_$CLOCKH_EC   /* the eventcount value word, map 0xE2B0D4 (time/time.ins.pas) */
        .extern FIM_$CRASH              /* fim/m68k/crash.s, map 0xE1E864 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */

        .global FIM_$SPURIOUS_INT
FIM_$SPURIOUS_INT:
        .set    .Lspur_a5, FIM_$SPURIOUS_INT - .Lspur_dist
        movem.l %d0/%a5,-(%sp)                  /* e21f20 */
        lea     (.Lspur_a5:w,%pc),%a5        /* e21f24  4bfa f96a: the FIM_WIRED base */
        .if cpu_status_register
        move.l  %a0,-(%sp)                      /* sau8 3c23814  2f08 */
        lea     (MMU).l,%a0                     /* sau8 3c23816  41f9 03ff b400 */
        clr.w   (%a0)                           /* sau8 3c2381c  4250  the CPU status */
        movea.l (%sp)+,%a0                      /* sau8 3c2381e  205f */
        .endif
        addq.l  #1,(.Lspur_dist+.Lspur_pre+0x5e,%a5)       /* e21f28  (0x6ee,A5): FIM_$SPUR_CNT++ */
        move.l  (TIME_$CLOCKH).l,%d0            /* e21f2c  2039 00e2 b0d4 */
        cmp.l   (.Lspur_last_tick,%pc),%d0      /* e21f32  b0ba 0046 */
        bne.b   .Lspur_new_tick                 /* e21f36 */
        subq.w  #1,(.Lspur_dist+.Lspur_pre+0x62,%a5)       /* e21f38  (0x6f2,A5): allowance-- */
        bne.b   .Lspur_exit                     /* e21f3c */
        movem.l (%sp)+,%d0/%a5                  /* e21f3e */
        movem.l %d0-%d7/%a0-%a7,-(%sp)          /* e21f42 */
        pea     (.Lspur_status,%pc)             /* e21f46  &status */
        pea     (0x4,%sp)                       /* e21f4a  &registers */
        pea     (0x48,%sp)                      /* e21f4e  &exception frame */
        jsr     (FIM_$CRASH).l                  /* e21f52  4eb9 00e1 e864 */
        adda.w  #12,%sp                         /* e21f58  defc 000c */
        movem.l (%sp)+,%d0-%d7/%a0-%a6          /* e21f5c */
        addq.w  #4,%sp                          /* e21f60  the saved A7 */
        rte                                     /* e21f62 */
.Lspur_status:
        .long   0x00120033                      /* e21f64  "spurious interrupt" */
.Lspur_new_tick:
        move.w  #1000,(.Lspur_dist+.Lspur_pre+0x62,%a5)    /* e21f68  3b7c 03e8 06f2 */
        move.l  %d0,(.Lspur_dist+.Lspur_pre+0x5a,%a5)      /* e21f6e  2b40 06ea */
.Lspur_exit:
        movem.l (%sp)+,%d0/%a5                  /* e21f72 */
        jmp     (FIM_$EXIT:w,%pc)               /* e21f76  4efa 0944 */

/* The routine's cells (zero in the image except the allowance). */
.Lspur_last_tick:
        .long   0                               /* e21f7a  (0x6ea,A5): TIME_$CLOCKH of the */
                                                /* last spurious interrupt */
        .global FIM_$SPUR_CNT
FIM_$SPUR_CNT:
        .long   0                               /* e21f7e  (0x6ee,A5): spurious interrupts */
.Lspur_allowance:
        .short  1000                            /* e21f82  (0x6f2,A5): left in this tick */
