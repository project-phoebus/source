/*
 * fim/m68k/deliver_trace_fault.s - FIM_$DELIVER_TRACE_FAULT (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E22866..0x00E2288F (map
 * FIM_$DELIVER_TRACE_FAULT to FIM_$CLEAR_TRACE_FAULT, 42 bytes), in its
 * own section.
 *
 *   void FIM_$DELIVER_TRACE_FAULT(int16_t asid)     asid at 0x4(SP)
 *
 * With interrupts masked (SR saved and restored): sets bit 7 of
 * FIM_$TRACE_BIT[asid]; if it was clear, counts the address space in
 * PENDING_TRACE_FAULTS and patches the first word of FIM_$EXIT from rte to
 * nop (0x4E71), so every exception return falls into FIM_$EXIT's trace arm,
 * then clears the instruction cache.
 *
 * Module base.  The image loads A1 = 0x00E21890 (FIM_$TRACE_BIT, the
 * FIM_WIRED segment start) with `lea (-0xfd8,PC),A1' and reaches the
 * other two cells as (0x76e,A1) = PENDING_TRACE_FAULTS (0x00E21FFE) and
 * (0x102c,A1) = FIM_$EXIT (0x00E228BC).  Here A1 is our FIM_$TRACE_BIT
 * (R_68K_PC16, needed for the indexed bset), and the two other cells are
 * named: in our link they are not at the image's distance from it.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations, except the two widened operands marked below ((d16,A1) ->
 * (xxx).l, A1 = 0x00E21890 in REGISTER_BASES).
 */

        .section ".text.FIM_$DELIVER_TRACE_FAULT","ax",@progbits
        .even

        .extern FIM_$TRACE_BIT          /* fim/m68k/trace_bit.s, map 0xE21890 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */
        .extern CACHE_$CLEAR            /* cache/m68k/clear.s, map 0xE242D4 */

        .extern PENDING_TRACE_FAULTS    /* fim/m68k/wired_data.s, map 0xE21FFE */

        .global FIM_$DELIVER_TRACE_FAULT
FIM_$DELIVER_TRACE_FAULT:
        lea     (FIM_$TRACE_BIT:w,%pc),%a1      /* e22866  43fa f028 */
        move.w  (0x4,%sp),%d0                   /* e2286a  asid */
        move.w  %sr,-(%sp)                      /* e2286e */
        ori.w   #0x0700,%sr                     /* e22870 */
        bset.b  #7,(0,%a1,%d0.w)                /* e22874  08f1 0007 0000 */
        bne.b   .Ldtf_done                      /* e2287a  already pending */
        /* widened: image (0x76e,A1) = 0x00E21FFE */
        addq.l  #1,(PENDING_TRACE_FAULTS).l    /* e2287c  52a9 076e */
        /* widened: image (0x102c,A1) = 0x00E228BC */
        move.w  #0x4e71,(FIM_$EXIT).l           /* e22880  337c 4e71 102c: nop */
        jsr     (CACHE_$CLEAR).l                /* e22886  4eb9 00e2 42d4 */
.Ldtf_done:
        move.w  (%sp)+,%sr                      /* e2288c */
        rts                                     /* e2288e */
