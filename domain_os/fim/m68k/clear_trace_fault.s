/*
 * fim/m68k/clear_trace_fault.s - FIM_$CLEAR_TRACE_FAULT (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E22890..0x00E228BB (map
 * FIM_$CLEAR_TRACE_FAULT to FIM_$EXIT, 44 bytes), in its own section.
 *
 *   void FIM_$CLEAR_TRACE_FAULT(int16_t asid)       asid at 0x4(SP)
 *
 * With interrupts masked: clears bit 7 of FIM_$TRACE_BIT[asid]; if it was
 * set, uncounts it from PENDING_TRACE_FAULTS, and when that reaches zero
 * restores rte (0x4E73) as FIM_$EXIT's first word and clears the
 * instruction cache.  Exits with the IPL forced to 0 (`andi #0xf8ff,SR'),
 * not restored.
 *
 * Module base: as in FIM_$DELIVER_TRACE_FAULT (fim/sau2/
 * deliver_trace_fault.s): A1 = FIM_$TRACE_BIT (`lea (-0x1002,PC),A1'), and
 * the image's (0x76e,A1) / (0x102c,A1) are named.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations, except the two widened operands marked below ((d16,A1) ->
 * (xxx).l, A1 = 0x00E21890 in REGISTER_BASES).
 *
 * Without a CACR (`cache_clear_stub', base/config.ins.pas: the
 * SAU4) there is no CACHE_$CLEAR call after FIM_$EXIT's first
 * word is patched.
 */

        .include "base/config.inc"
        .section ".text.FIM_$CLEAR_TRACE_FAULT","ax",@progbits
        .even

        .extern FIM_$TRACE_BIT          /* fim/m68k/trace_bit.s, map 0xE21890 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */
        .extern CACHE_$CLEAR            /* cache/m68k/clear.s, map 0xE242D4 */

        .extern PENDING_TRACE_FAULTS    /* fim/m68k/wired_data.s, map 0xE21FFE */

        .global FIM_$CLEAR_TRACE_FAULT
FIM_$CLEAR_TRACE_FAULT:
        lea     (FIM_$TRACE_BIT:w,%pc),%a1      /* e22890  43fa effe */
        move.w  (0x4,%sp),%d0                   /* e22894  asid */
        ori.w   #0x0700,%sr                     /* e22898 */
        bclr.b  #7,(0,%a1,%d0.w)                /* e2289c  08b1 0007 0000 */
        beq.b   .Lctf_done                      /* e228a2  was not pending */
        /* widened: image (0x76e,A1) = 0x00E21FFE */
        subq.l  #1,(PENDING_TRACE_FAULTS).l    /* e228a4  53a9 076e */
        bne.b   .Lctf_done                      /* e228a8  others still pending */
        /* widened: image (0x102c,A1) = 0x00E228BC */
        move.w  #0x4e73,(FIM_$EXIT).l           /* e228aa  337c 4e73 102c: rte */
        .if !cache_clear_stub
        jsr     (CACHE_$CLEAR).l                /* e228b0 */
        .endif
.Lctf_done:
        andi.w  #0xf8ff,%sr                     /* e228b6  IPL 0 */
        rts                                     /* e228ba */
