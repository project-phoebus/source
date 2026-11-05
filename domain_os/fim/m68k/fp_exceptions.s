/*
 * fim/m68k/fp_exceptions.s - the 68881 exception vector stubs FIM_$FP_BSUN
 * .. FIM_$FP_SIG_NAN (m68k/SAU2, SAU5)
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E214B0..0x00E2152F (128 bytes), part
 * of the map segment `D E213A0 FIM_UNWIRED size = 4F0', one section per map
 * symbol:
 *
 *   .text.FIM_$FP_BSUN       0x00E214B0..0x00E214BF  16 bytes  vector 48
 *   .text.FIM_$FP_INEXACT    0x00E214C0..0x00E214CF  16 bytes  vector 49
 *   .text.FIM_$FP_DIV_ZERO   0x00E214D0..0x00E214DF  16 bytes  vector 50
 *   .text.FIM_$FP_UNDFLO     0x00E214E0..0x00E214EF  16 bytes  vector 51
 *   .text.FIM_$FP_OP_ERR     0x00E214F0..0x00E214FF  16 bytes  vector 52
 *   .text.FIM_$FP_OVRFLO     0x00E21500..0x00E2150F  16 bytes  vector 53
 *   .text.FIM_$FP_SIG_NAN    0x00E21510..0x00E2152F  32 bytes  vector 54,
 *                            then the shared helper fim_fp_frame_pc
 *                            (0x00E2151E, no map symbol) and a word pad
 *
 * (vectors from the image's BOOT_INFO_TABLE descriptor 0x00300007 at
 * 0x00E35354.)
 *
 * Image bytes (gsk read 0xE214B0 0x80):
 *   e214b0  616c 6100 feec 0012 002e 0013 a004 0000
 *   e214c0  615c 6100 fedc 0012 0022 0008 a004 0000
 *   e214d0  614c 6100 fecc 0012 0023 0008 a004 0000
 *   e214e0  613c 6100 febc 0012 0024 0008 a004 0000
 *   e214f0  612c 6100 feac 0012 0025 0008 a004 0000
 *   e21500  611c 6100 fe9c 0012 0026 0008 a004 0000
 *   e21510  610c 6100 fe8c 0012 002f 0008 a004 0c2f
 *   e21520  0090 000a 6606 2f6f 000c 0006 4e75 0000
 *
 * Each stub first calls fim_fp_frame_pc, then calls FIM_COMMON_FAULT
 * (fim/m68k/com.s), which never returns and reads the fault descriptor that
 * follows the call (status, signal, class 0xA004).
 *
 * fim_fp_frame_pc: called with the exception frame at 4(SP).  When the
 * frame's format/vector word (0xA,SP) has format 9 in its top nibble
 * (cmpi.b #0x90 on the high byte: the 68020 coprocessor mid-instruction
 * frame), the frame's instruction address longword (0xC,SP) is copied over
 * its PC (6,SP), so the fault is reported at the floating-point instruction
 * rather than the instruction after it.  It is module-local (no map
 * symbol); tools/asm_compare.py knows its image address.
 *
 * Statuses (stcode.db.10.2): 0x0012002E FP branch/set on unordered,
 * 0x00120022 inexact result, 0x00120023 divide by zero, 0x00120024
 * underflow, 0x00120025 operand error, 0x00120026 overflow, 0x0012002F
 * signalling not-a-number.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations (R_68K_PC8 against fim_fp_frame_pc, R_68K_PC16 against
 * FIM_COMMON_FAULT).
 *
 * The SAU4's vector table installs the five exceptions INEXACT..OVRFLO
 * only (`fp_five_exceptions', base/config.ins.pas): its FIM_UNWIRED has
 * no FIM_$FP_BSUN or FIM_$FP_SIG_NAN, and fim_fp_frame_pc is a return in
 * the place of FIM_$FP_OVRFLO's pad (sau4 0xF822AFE), the floating-point
 * registers being the CPU's own (no coprocessor mid-instruction frame);
 * its five stubs are the SAU2's bytes at 0xF822AB0..0xF822AFF.
 */

        .include "base/config.inc"

        .extern FIM_COMMON_FAULT        /* fim/m68k/com.s, image 0xE213A0 */

        .if !fp_five_exceptions
        .section ".text.FIM_$FP_BSUN","ax",@progbits
        .even
        .global FIM_$FP_BSUN
FIM_$FP_BSUN:
        bsr.s   fim_fp_frame_pc                 /* e214b0  616c */
        bsr.w   FIM_COMMON_FAULT                /* e214b2  6100 feec */
        .long   0x0012002E                      /* e214b6  status "FP branch/set on unordered condition" */
        .short  0x0013                          /* e214ba  signal 0x13 */
        .short  0xA004                          /* e214bc  class */
        .short  0x0000                          /* e214be  pad */
        .endif

        .section ".text.FIM_$FP_INEXACT","ax",@progbits
        .even
        .global FIM_$FP_INEXACT
FIM_$FP_INEXACT:
        bsr.s   fim_fp_frame_pc                 /* e214c0  615c */
        bsr.w   FIM_COMMON_FAULT                /* e214c2  6100 fedc */
        .long   0x00120022                      /* e214c6  status "FP inexact result" */
        .short  0x0008                          /* e214ca  signal 8 */
        .short  0xA004                          /* e214cc  class */
        .short  0x0000                          /* e214ce  pad */

        .section ".text.FIM_$FP_DIV_ZERO","ax",@progbits
        .even
        .global FIM_$FP_DIV_ZERO
FIM_$FP_DIV_ZERO:
        bsr.s   fim_fp_frame_pc                 /* e214d0  614c */
        bsr.w   FIM_COMMON_FAULT                /* e214d2  6100 fecc */
        .long   0x00120023                      /* e214d6  status "FP divide by zero" */
        .short  0x0008                          /* e214da  signal 8 */
        .short  0xA004                          /* e214dc  class */
        .short  0x0000                          /* e214de  pad */

        .section ".text.FIM_$FP_UNDFLO","ax",@progbits
        .even
        .global FIM_$FP_UNDFLO
FIM_$FP_UNDFLO:
        bsr.s   fim_fp_frame_pc                 /* e214e0  613c */
        bsr.w   FIM_COMMON_FAULT                /* e214e2  6100 febc */
        .long   0x00120024                      /* e214e6  status "FP underflow" */
        .short  0x0008                          /* e214ea  signal 8 */
        .short  0xA004                          /* e214ec  class */
        .short  0x0000                          /* e214ee  pad */

        .section ".text.FIM_$FP_OP_ERR","ax",@progbits
        .even
        .global FIM_$FP_OP_ERR
FIM_$FP_OP_ERR:
        bsr.s   fim_fp_frame_pc                 /* e214f0  612c */
        bsr.w   FIM_COMMON_FAULT                /* e214f2  6100 feac */
        .long   0x00120025                      /* e214f6  status "FP operand error" */
        .short  0x0008                          /* e214fa  signal 8 */
        .short  0xA004                          /* e214fc  class */
        .short  0x0000                          /* e214fe  pad */

        .section ".text.FIM_$FP_OVRFLO","ax",@progbits
        .even
        .global FIM_$FP_OVRFLO
FIM_$FP_OVRFLO:
        bsr.s   fim_fp_frame_pc                 /* e21500  611c */
        bsr.w   FIM_COMMON_FAULT                /* e21502  6100 fe9c */
        .long   0x00120026                      /* e21506  status "FP overflow" */
        .short  0x0008                          /* e2150a  signal 8 */
        .short  0xA004                          /* e2150c  class */
        .if fp_five_exceptions
        .global fim_fp_frame_pc
fim_fp_frame_pc:
        rts                                     /* sau4 f822afe  4e75 */
        .else
        .short  0x0000                          /* e2150e  pad */
        .endif

        .if !fp_five_exceptions
        .section ".text.FIM_$FP_SIG_NAN","ax",@progbits
        .even
        .global FIM_$FP_SIG_NAN
        .global fim_fp_frame_pc
FIM_$FP_SIG_NAN:
        bsr.s   fim_fp_frame_pc                 /* e21510  610c */
        bsr.w   FIM_COMMON_FAULT                /* e21512  6100 fe8c */
        .long   0x0012002F                      /* e21516  status "FP signalling not-a-number" */
        .short  0x0008                          /* e2151a  signal 8 */
        .short  0xA004                          /* e2151c  class */

        .if fpu_enable_mmu_9
fim_fp_frame_pc:
        rts                                     /* sau6 78023abe  4e75 */

/* The SAU6's two more stubs (`fpu_enable_mmu_9'): FIM_$FP_PARITY, and
   FIM_$FP_VEC_EXCEPTION, the FPU interface's exception, whose status the
   interface's register 16#FFFFFC84 selects from the table after it
   (its low byte: 16#30..16#36 the six exceptions above, 16#7F and any
   other "fpx parity error", 16#00120038) before FIM_$SOFT_FAULT's tail
   delivers it.  The longword after the table is "unknown fpa
   exception", 16#00120039, which nothing reads. */
        .section ".text.FIM_$FP_PARITY","ax",@progbits
        .even
        .global FIM_$FP_PARITY
        .global FIM_$FP_VEC_EXCEPTION
        .extern FIM_SOFT_FAULT_PUSH             /* fim/m68k/soft_fault.s */
FIM_$FP_PARITY:
        bsr.w   FIM_COMMON_FAULT                /* sau6 78023ac0  6100 fe7e */
        .long   0x00120038                      /* sau6 78023ac4  status "fpx parity error" */
        .short  0x0008                          /* sau6 78023ac8  signal 8 */
        .short  0xA004                          /* sau6 78023aca  class */
FIM_$FP_VEC_EXCEPTION:
        move.w  #0xa004,-(%sp)                  /* sau6 78023acc  3f3c a004  class */
        move.w  #8,-(%sp)                       /* sau6 78023ad0  3f3c 0008  signal 8 */
        subq.w  #4,%sp                          /* sau6 78023ad4  594f  the status */
        movem.l %d0-%d1/%a0,-(%sp)              /* sau6 78023ad6  48e7 c080 */
        move.w  (0xfc84).w,%d0                  /* sau6 78023ada  3038 fc84 */
        .short  0xc07c, 0x00ff                  /* sau6 78023ade  c07c 00ff  and.w #0xff,%d0, the <ea>=#imm form */
        move.w  #7,%d1                          /* sau6 78023ae2  323c 0007 */
        lea     (.Lfp_vec_table,%pc),%a0        /* sau6 78023ae6  41fa 0016 */
.Lfp_vec_find:
        cmp.w   (%a0)+,%d0                      /* sau6 78023aea  b058 */
        addq.w  #4,%a0                          /* sau6 78023aec  5848 */
        dbeq    %d1,.Lfp_vec_find               /* sau6 78023aee  57c9 fffa */
        move.l  -(%a0),(12,%sp)                 /* sau6 78023af2  2f60 000c */
        movem.l (%sp)+,%d0-%d1/%a0              /* sau6 78023af6  4cdf 0103 */
        bra.w   FIM_SOFT_FAULT_PUSH             /* sau6 78023afa  6000 ff06 */
.Lfp_vec_table:
        .short  0x0030                          /* sau6 78023afe */
        .long   0x0012002E                      /*   FP branch/set on unordered */
        .short  0x0031
        .long   0x00120022                      /*   inexact result */
        .short  0x0032
        .long   0x00120023                      /*   divide by zero */
        .short  0x0033
        .long   0x00120024                      /*   underflow */
        .short  0x0034
        .long   0x00120025                      /*   operand error */
        .short  0x0035
        .long   0x00120026                      /*   overflow */
        .short  0x0036
        .long   0x0012002F                      /*   signalling not-a-number */
        .short  0x007F
        .long   0x00120038                      /*   fpx parity error, and no match */
        .long   0x00120039                      /* sau6 78023b2e  "unknown fpa exception" */
        .short  0x0000                          /* sau6 78023b32  pad; FIM_$PRIV_VIOL is at 0x78023B34 */
        .else
fim_fp_frame_pc:
        cmpi.b  #0x90,(0xa,%sp)                 /* e2151e  0c2f 0090 000a: format 9 frame? */
        bne.b   .Lfp_frame_pc_done              /* e21524  6606 */
        move.l  (0xc,%sp),(6,%sp)               /* e21526  2f6f 000c 0006: PC = instruction address */
.Lfp_frame_pc_done:
        rts                                     /* e2152c */
        .short  0x0000                          /* e2152e  pad; FIM_$PRIV_VIOL is at 0xE21530 */
        .endif
        .endif
