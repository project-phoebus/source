/*
 * fim/m68k/get_user_sr_ptr.s - FIM_$GET_USER_SR_PTR (m68k/SAU2, SAU5,
 * SAU8, SAU9)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.  The SAU9's (0x3C4253CE,
 * 0xD6 bytes) tries no 68010 frames (format 8: only the SAUs that run
 * on an MC68010, `pft_mmu', base/config.ins.pas) and takes PROT
 * 0x3BFC0000 as the user limit (`large_address_space').  The SAU8's
 * (0x3C24074) is the SAU9's but for the limit, PROT itself, a fixup-table
 * cell (`run_time_layout').
 *
 * The SAU4's (0xF8249FA, 0xAA bytes) knows the DNx60's frames
 * (`fault_frame_addr'): after format 0 it tries top - 8 - 8 as the long
 * fault frame, format 4 vector 2, and as format 8 vector 3, and nothing
 * else; its SR test lets bits 7 and 6 through (SR & 0x3F20,
 * `sr_user_bits_76'), and its limit is its PROT, 0xF7C0000
 * (`vm_8192_segs').  Those lines carry the SAU4 image's addresses.
 *
 * Transcribed from the SAU2 image, 0x00E2277C..0x00E22865 (map
 * FIM_$GET_USER_SR_PTR to FIM_$DELIVER_TRACE_FAULT, 234 bytes: 118 of the
 * routine and its 116-byte frame checker at 0x00E227F2), in its own
 * section.
 *
 *   void *FIM_$GET_USER_SR_PTR(uint16_t pid)     pid at 0x4(SP); result D0
 *
 * Finds the exception frame through which process pid entered the kernel
 * from user mode, at the top of its OS stack (OS_STACK_BASE[pid]): the
 * candidate frames end at the stack top, so each is tried at top - 8
 * (format 0), top - 8 - 0x32 (format 8, vector 2 or 3), - 0x54 (format B,
 * vector 2 or 3), - 0x18 (format A), - 0x4 (format 2) and - 0xC (format 9),
 * and the first that .Lcheck_frame accepts is returned; failing all, top -
 * 8 is.  proc1/m68k/misc.s calls it.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations; the CMP/AND #imm,Dn instructions are the <ea>=#imm form in
 * the image (b07c, b0bc, c07c), CMPI/ANDI in ours (recognised by the gate).
 */

        .include "base/config.inc"

        .section ".text.FIM_$GET_USER_SR_PTR","ax",@progbits
        .even

        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */

        /* OS stack top per PROC1 process: OS_STACK_BASE[pid], map
         * 0x00E25C18, +0x730 of PROC1_'s block (proc1/proc1.pas defines
         * it). */
        .extern OS_STACK_BASE

        /* Lowest PC accepted from user mode below the kernel: the SAU2
         * user/kernel VA limit. */
        .if large_address_space
        .equ    USER_VA_LIMIT, 0x3BFC0000       /* sau9: the map's PROT */
        .elseif vm_8192_segs
        .equ    USER_VA_LIMIT, 0x0F7C0000       /* sau4: the map's PROT (f824a86) */
        .elseif run_time_layout
        /* sau8: PROT itself, a fixup-table cell (3c2412c), which COLD
           moves with the MC68851's layout (svc/m68k/svc_macros.inc) */
        .equ    USER_VA_LIMIT, PROT
        .else
        .equ    USER_VA_LIMIT, 0x00CC0000
        .endif

        .global FIM_$GET_USER_SR_PTR
FIM_$GET_USER_SR_PTR:
        move.w  (0x4,%sp),%d0                   /* e2277c  pid */
        lsl.w   #2,%d0                          /* e22780 */
        lea     (OS_STACK_BASE).l,%a0           /* e22782  41f9 00e2 5c18 */
        move.l  (0,%a0,%d0.w),%d0               /* e22788 */
        subq.l  #8,%d0                          /* e2278c */
        movea.l %d0,%a0                         /* e2278e  A0 = top - 8 */
        clr.w   %d1                             /* e22790  format 0 */
        bsr.b   .Lcheck_frame                   /* e22792 */
        beq.b   .Lgusp_found                    /* e22794 */
        movea.l %a0,%a1                         /* e22796  A1 = top - 8 */
        .if fault_frame_addr
        lea     (-0x8,%a1),%a0                  /* sau4 f824a16  41e9 fff8 */
        move.w  #0x4008,%d1                     /* sau4 f824a1a  format 4, vector 2 */
        bsr.b   .Lcheck_frame                   /* sau4 f824a1e */
        beq.b   .Lgusp_found                    /* sau4 f824a20 */
        move.w  #0x800c,%d1                     /* sau4 f824a22  format 8, vector 3 */
        bsr.b   .Lcheck_frame                   /* sau4 f824a26 */
        beq.b   .Lgusp_found                    /* sau4 f824a28 */
        .else
        .if pft_mmu
        lea     (-0x32,%a1),%a0                 /* e22798 */
        move.w  #0x8008,%d1                     /* e2279c  format 8, vector 2 */
        bsr.b   .Lcheck_frame                   /* e227a0 */
        beq.b   .Lgusp_found                    /* e227a2 */
        move.w  #0x800c,%d1                     /* e227a4  format 8, vector 3 */
        bsr.b   .Lcheck_frame                   /* e227a8 */
        beq.b   .Lgusp_found                    /* e227aa */
        .endif
        lea     (-0x54,%a1),%a0                 /* e227ac */
        move.w  #0xb008,%d1                     /* e227b0  format B */
        bsr.b   .Lcheck_frame                   /* e227b4 */
        beq.b   .Lgusp_found                    /* e227b6 */
        move.w  #0xb00c,%d1                     /* e227b8 */
        bsr.b   .Lcheck_frame                   /* e227bc */
        beq.b   .Lgusp_found                    /* e227be */
        lea     (-0x18,%a1),%a0                 /* e227c0 */
        move.w  #0xa008,%d1                     /* e227c4  format A */
        bsr.b   .Lcheck_frame                   /* e227c8 */
        beq.b   .Lgusp_found                    /* e227ca */
        move.w  #0xa00c,%d1                     /* e227cc */
        bsr.b   .Lcheck_frame                   /* e227d0 */
        beq.b   .Lgusp_found                    /* e227d2 */
        lea     (-0x4,%a1),%a0                  /* e227d4 */
        move.w  #0x2000,%d1                     /* e227d8  format 2, any vector */
        bsr.b   .Lcheck_frame                   /* e227dc */
        beq.b   .Lgusp_found                    /* e227de */
        lea     (-0xc,%a1),%a0                  /* e227e0 */
        move.w  #0x9000,%d1                     /* e227e4  format 9, any vector */
        bsr.b   .Lcheck_frame                   /* e227e8 */
        beq.b   .Lgusp_found                    /* e227ea */
        .endif
        movea.l %a1,%a0                         /* e227ec  none: top - 8 */
.Lgusp_found:
        move.l  %a0,%d0                         /* e227ee */
        rts                                     /* e227f0 */

/* --------------------------------------------------------------------
 * .Lcheck_frame - 0x00E227F2 (module-local)
 *
 * A0 = candidate frame, D1 = expected format/vector word: 0 = format 0
 * with any valid vector offset; a word whose low 12 bits are zero =
 * that format with any valid vector offset (0x010..0x3FC, a multiple of
 * 4); otherwise an exact match.  The frame is accepted (Z set, via
 * `cmp.w D0,D0') if, in addition, its SR is a user-mode SR at IPL 0 with
 * nothing but T1, T0 and CCR bits (SR & 0x3FE0 == 0) and its PC is even,
 * above 0x8000, and either below USER_VA_LIMIT or FIM_$EXIT itself.
 * Rejection returns Z clear (`cmp.l A5,D0'; a supervisor-mode SR returns
 * with the Z of its `btst'), so the caller's beq tests the result.
 * Clobbers D0, D1.
 * -------------------------------------------------------------------- */
.Lcheck_frame:
        move.w  (0x6,%a0),%d0                   /* e227f2  format/vector word */
        tst.w   %d1                             /* e227f6 */
        beq.b   .Lcf_format0                    /* e227f8 */
        cmp.w   %d0,%d1                         /* e227fa  exact match? */
        beq.b   .Lcf_check_sr                   /* e227fc */
        lsl.l   #4,%d1                          /* e227fe */
        tst.w   %d1                             /* e22800  low 12 bits zero? */
        bne.b   .Lcf_reject                     /* e22802 */
        lsr.l   #4,%d1                          /* e22804 */
        and.w   %d1,%d0                         /* e22806 */
        cmp.w   %d1,%d0                         /* e22808  format matches? */
        bne.b   .Lcf_reject                     /* e2280a */
        bra.b   .Lcf_check_vector               /* e2280c */
.Lcf_format0:
        and.w   #0xf000,%d0                     /* e2280e  c07c f000 */
        bne.b   .Lcf_reject                     /* e22812 */
.Lcf_check_vector:
        move.w  (0x6,%a0),%d0                   /* e22814 */
        and.w   #0x0fff,%d0                     /* e22818  c07c 0fff */
        cmp.w   #0x03fc,%d0                     /* e2281c  b07c 03fc */
        bgt.b   .Lcf_reject                     /* e22820 */
        cmp.w   #0x0010,%d0                     /* e22822  b07c 0010 */
        blt.b   .Lcf_reject                     /* e22826 */
        and.w   #0x0003,%d0                     /* e22828  c07c 0003 */
        bne.b   .Lcf_reject                     /* e2282c */
.Lcf_check_sr:
        move.w  (%a0),%d0                       /* e2282e  SR */
        btst.l  #13,%d0                         /* e22830  supervisor mode? */
        bne.b   .Lcf_return                     /* e22834  Z clear: rejected */
        .if sr_user_bits_76
        and.w   #0x3f20,%d0                     /* sau4 f824a74  c07c 3f20 */
        .else
        and.w   #0x3fe0,%d0                     /* e22836  c07c 3fe0 */
        .endif
        bne.b   .Lcf_reject                     /* e2283a */
        move.l  (0x2,%a0),%d0                   /* e2283c  PC */
        btst.l  #0,%d0                          /* e22840 */
        bne.b   .Lcf_reject                     /* e22844  odd */
        cmp.l   #USER_VA_LIMIT,%d0              /* e22846  b0bc 00cc 0000 */
        bcs.b   .Lcf_check_low                  /* e2284c */
        cmp.l   #FIM_$EXIT,%d0                  /* e2284e  b0bc 00e2 28bc */
        bne.b   .Lcf_reject                     /* e22854 */
.Lcf_check_low:
        cmp.l   #0x00008000,%d0                 /* e22856  b0bc 0000 8000 */
        bls.b   .Lcf_reject                     /* e2285c */
        cmp.w   %d0,%d0                         /* e2285e  Z set: accepted */
.Lcf_return:
        rts                                     /* e22860 */
.Lcf_reject:
        cmp.l   %a5,%d0                         /* e22862  b08d: Z clear */
        rts                                     /* e22864 */
