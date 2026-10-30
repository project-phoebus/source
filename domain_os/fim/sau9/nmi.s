/*
 * fim/sau9/nmi.s - NMI_$CNT and FIM_$NMI, the level 7 interrupt (SAU9)
 *
 * SAU9 map, in "D 3C4244A0 FIM_WIRED size = 10A4":
 *   0x3C4246C2  NMI_$CNT   a word: the level 7 interrupts taken
 *   0x3C4246C4  FIM_$NMI   to 0x3C424713: the handler and its two status
 *                          longwords
 * and, with no map name, the handler's fault path after FIM_$SPUR_CNT's
 * cells (0x3C424BF0..0x3C424C37, before PARITY_$INFO), where the SAU2 has
 * FIM_$PARITY_TRAP.  Vector 31 is FIM_$NMI on the SAUs with `fim_nmi'
 * (base/config.ins.pas; os/init.pas): the SAU2's FIM_$PARITY_TRAP
 * (fim/m68k/parity_trap.s) with the SAU9's MMU in front:
 *   - NMI_$CNT counted, the pending memory error cleared (MMU_CCR bit 4);
 *   - a bus time-out being fielded (BUS_ERROR_SWITCH armed) crashes with
 *     "unexpected virtual timeout" and returns through FIM_$EXIT;
 *   - else PARITY_$CHK classifies the error, PARITY_$INFO's in-progress
 *     word is cleared, and an error that is not the process's is
 *     dismissed through PROC1_$INT_EXIT; the process's is turned into a
 *     format-8 frame and a "memory parity error" fault for FIM_$COM, as
 *     on the SAU2.
 * "write buffer timeout" (0x0007000B) is not referenced.
 *
 * Two sections: .text.NMI_$CNT (keyed by NMI_$CNT) and the fault path,
 * .text.fim_$nmi_fault, which tools/gen_layout_ld.py's ANCHORS place
 * after FIM_$SPURIOUS_INT's section.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU9 image's.
 */

        .section ".text.NMI_$CNT","ax",@progbits
        .even

        .globl  NMI_$CNT
        .globl  FIM_$NMI
        .globl  fim_$nmi_fault

        .extern MMU_CCR                 /* arch/m68k/sau9/iodefs.s */

        /* PARITY_$INFO (fim/m68k/wired_data.s; parity/parity.ins.pas) */
        .set    PARITY_CHK_FLAG,   PARITY_$INFO + 0x02
        .set    PARITY_ERR_VA,     PARITY_$INFO + 0x0C
        .set    PARITY_ERR_STATUS, PARITY_$INFO + 0x10
        .set    PARITY_ERR_DATA,   PARITY_$INFO + 0x12

NMI_$CNT:                                       | 3c4246c2
        .word   0

FIM_$NMI:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c4246c4  48e7 c0c0
        addq.w  #1,(NMI_$CNT).l                 | 3c4246c8  5279 3c42 46c2
        bclr    #4,MMU_CCR                      | 3c4246ce  08b9 0004 3ff9 f2d0  clear the error
        tst.l   BUS_ERROR_SWITCH                | 3c4246d6  4ab9 3c42 44dc  a probe running?
        beq.b   .Lparity                        | 3c4246dc  6706
        pea     (.Lsts_virtual_timeout,%pc)     | 3c4246de  487a 0030
        bra.b   .Lcrash                         | 3c4246e2  6018
.Lparity:
        jsr     PARITY_$CHK                     | 3c4246e4  4eb9 3c40 cd04
        lea     (PARITY_CHK_FLAG:w,%pc),%a0     | 3c4246ea  41fa 054e
        clr.w   (%a0)                           | 3c4246ee  4250
        tst.b   %d0                             | 3c4246f0  4a00
        bmi.w   fim_$nmi_fault                  | 3c4246f2  6b00 04fc  the process's error
        jmp     PROC1_$INT_EXIT                 | 3c4246f6  4ef9 3c42 34fa
.Lcrash:
        jsr     CRASH_SYSTEM                    | 3c4246fc  4eb9 3c42 1300
        addq.w  #4,%sp                          | 3c424702  584f
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c424704  4cdf 0303
        jmp     (FIM_$EXIT:w,%pc)               | 3c424708  4efa 0df0
        .long   0x0007000B                      | 3c42470c  "write buffer timeout"
.Lsts_virtual_timeout:
        .long   0x0007000A                      | 3c424710  "unexpected virtual timeout"

/* The fault path (0x3C424BF0): the SAU2's FIM_$PARITY_TRAP from its
   0x00E21F9E. */
        .section ".text.fim_$nmi_fault","ax",@progbits
        .even
fim_$nmi_fault:
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c424bf0  4cdf 0303
        suba.w  #0x3a,%sp                       | 3c424bf4  9efc 003a
        move.w  (0x3a,%sp),(%sp)                | 3c424bf8  3eaf 003a  SR
        move.l  (0x3c,%sp),(0x2,%sp)            | 3c424bfc  2f6f 003c 0002  PC
        move.b  #0x80,(0x6,%sp)                 | 3c424c02  1f7c 0080 0006  format 8
        move.l  (PARITY_ERR_VA:w,%pc),(0xa,%sp)     | 3c424c08  2f7a 003a 000a
        move.w  (PARITY_ERR_STATUS:w,%pc),(0x8,%sp) | 3c424c0e  3f7a 0038 0008
        move.w  (PARITY_ERR_DATA:w,%pc),(0x18,%sp)  | 3c424c14  3f7a 0034 0018
        move.w  #0x3000,-(%sp)                  | 3c424c1a  3f3c 3000  fault class
        move.w  #0x13,-(%sp)                    | 3c424c1e  3f3c 0013  signal number
        move.l  #0x0012001E,-(%sp)              | 3c424c22  2f3c 0012 001e  "memory parity error"
        andi.w  #0xf8ff,%sr                     | 3c424c28  027c f8ff  IPL 0
        pea     (%sp)                           | 3c424c2c  4857  &descriptor
        pea     (0xc,%sp)                       | 3c424c2e  486f 000c  &frame
        jmp     FIM_COM                         | 3c424c32  4ef9 3c42 3fb4
