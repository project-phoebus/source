/*
 * fim/sau7/nmi.s - NMI_$CNT and FIM_$NMI, the level 7 interrupt (SAU7)
 *
 * SAU7 map, in "D 3C426334 FIM_WIRED size = 1804":
 *   0x3C4265CC  NMI_$CNT   a word: the level 7 interrupts taken (and a
 *                          zero word)
 *   0x3C4265D0  FIM_$NMI   to 0x3C426641: the handler and its two status
 *                          longwords
 * and, with no map name, the handler's fault path after FIM_$SPUR_CNT's
 * cells (0x3C4271E4..0x3C42722B, before PARITY_$INFO), as on the SAU9.
 * The SAU9's handler (fim/sau9/nmi.s, whose fault path this is) with the
 * SAU7's registers in front, where the SAU9 clears its MMU's
 * pending memory error:
 *   - when the CPU is not an MC68030 (M68030 clear), bit 6 of the
 *     physical cache's register word (MMU + 16#200) crashes the system
 *     with "write buffer timeout", and bit 12 of the CPU status register
 *     (MMU) with "mmu timeout" (FIM_$BUS_ERR's status longword,
 *     fim/sau7/bus_err.s);
 *   - a bus time-out being fielded (BUS_ERROR_SWITCH armed) crashes with
 *     "unexpected virtual timeout"; each crash returns through FIM_$EXIT;
 *   - else PARITY_$CHK, as on the SAU9.
 *
 * Two sections: .text.NMI_$CNT (keyed by NMI_$CNT) and the fault path,
 * .text.fim_$nmi_fault, after FIM_$SPURIOUS_INT's section.
 *
 * Byte gate (the SAU7 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68030 -m68881' and compared with the image at the map's
 * addresses by tools/asm_compare.py's rules, modulo relocations.  The
 * address and byte columns are the SAU7 image's.
 */

        .include "base/config.inc"
        .if fpa_board

        .section ".text.NMI_$CNT","ax",@progbits
        .even

        .globl  NMI_$CNT
        .globl  FIM_$NMI
        .globl  fim_$nmi_fault

        .extern MMU                     /* the CPU status register; + 0x200 the physical cache's */
        .extern M68030                  /* mmu/mmu.ins.pas: the CPU is an MC68030 */
        .extern fim_$sts_mmu_timeout    /* fim/sau7/bus_err.s */

        /* PARITY_$INFO (fim/m68k/wired_data.s; parity/parity.ins.pas) */
        .set    PARITY_CHK_FLAG,   PARITY_$INFO + 0x02
        .set    PARITY_ERR_VA,     PARITY_$INFO + 0x0C
        .set    PARITY_ERR_STATUS, PARITY_$INFO + 0x10
        .set    PARITY_ERR_DATA,   PARITY_$INFO + 0x12

NMI_$CNT:                                       | 3c4265cc
        .word   0
        .word   0                               | 3c4265ce

FIM_$NMI:
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3c4265d0  48e7 c0c0
        addq.w  #1,(NMI_$CNT).l                 | 3c4265d4  5279 3c42 65cc
        tst.b   (M68030).l                      | 3c4265da  4a39 3c42 90ea
        bne.s   .Lparity                        | 3c4265e0  6630
        btst    #6,(MMU+0x200).l                | 3c4265e2  0839 0006 3fff b600
        beq.s   .Lnot_wb                        | 3c4265ea  6706
        pea     (.Lsts_write_buffer,%pc)        | 3c4265ec  487a 004c
        bra.s   .Lcrash                         | 3c4265f0  6038
.Lnot_wb:
        move.w  (MMU).l,%d1                     | 3c4265f2  3239 3fff b400  the CPU status
        btst    #12,%d1                         | 3c4265f8  0801 000c
        beq.s   .Lnot_mmu                       | 3c4265fc  6706
        pea     (fim_$sts_mmu_timeout:w,%pc)    | 3c4265fe  487a ff40
        bra.s   .Lcrash                         | 3c426602  6026
.Lnot_mmu:
        tst.l   (BUS_ERROR_SWITCH).l            | 3c426604  4ab9 3c42 6372  a probe running?
        beq.s   .Lparity                        | 3c42660a  6706
        pea     (.Lsts_virtual_timeout,%pc)     | 3c42660c  487a 0030
        bra.s   .Lcrash                         | 3c426610  6018
.Lparity:
        jsr     (PARITY_$CHK).l                 | 3c426612  4eb9 3c40 c880
        lea     (PARITY_CHK_FLAG:w,%pc),%a0     | 3c426618  41fa 0c14
        clr.w   (%a0)                           | 3c42661c  4250
        tst.b   %d0                             | 3c42661e  4a00
        bmi.w   fim_$nmi_fault                  | 3c426620  6b00 0bc2  the process's error
        jmp     (PROC1_$INT_EXIT).l             | 3c426624  4ef9 3c42 4d96
.Lcrash:
        jsr     (CRASH_SYSTEM).l                | 3c42662a  4eb9 3c42 2b00
        addq.w  #4,%sp                          | 3c426630  584f
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c426632  4cdf 0303
        jmp     (FIM_$EXIT:w,%pc)               | 3c426636  4efa 14b8
.Lsts_write_buffer:
        .long   0x0007000B                      | 3c42663a  "write buffer timeout"
.Lsts_virtual_timeout:
        .long   0x0007000A                      | 3c42663e  "unexpected virtual timeout"

/* The fault path (0x3C4271E4): the SAU2's FIM_$PARITY_TRAP from its
   0x00E21F9E. */
        .section ".text.fim_$nmi_fault","ax",@progbits
        .even
fim_$nmi_fault:
        movem.l (%sp)+,%d0-%d1/%a0-%a1          | 3c4271e4  4cdf 0303
        suba.w  #0x3a,%sp                       | 3c4271e8  9efc 003a
        move.w  (0x3a,%sp),(%sp)                | 3c4271ec  3eaf 003a  SR
        move.l  (0x3c,%sp),(0x2,%sp)            | 3c4271f0  2f6f 003c 0002  PC
        move.b  #0x80,(0x6,%sp)                 | 3c4271f6  1f7c 0080 0006  format 8
        move.l  (PARITY_ERR_VA:w,%pc),(0xa,%sp)     | 3c4271fc  2f7a 003a 000a
        move.w  (PARITY_ERR_STATUS:w,%pc),(0x8,%sp) | 3c427202  3f7a 0038 0008
        move.w  (PARITY_ERR_DATA:w,%pc),(0x18,%sp)  | 3c427208  3f7a 0034 0018
        move.w  #0x3000,-(%sp)                  | 3c42720e  3f3c 3000  fault class
        move.w  #0x13,-(%sp)                    | 3c427212  3f3c 0013  signal number
        move.l  #0x0012001E,-(%sp)              | 3c427216  2f3c 0012 001e  "memory parity error"
        andi.w  #0xf8ff,%sr                     | 3c42721c  027c f8ff  IPL 0
        pea     (%sp)                           | 3c427220  4857  &descriptor
        pea     (0xc,%sp)                       | 3c427222  486f 000c  &frame
        jmp     (FIM_COM).l                     | 3c427226  4ef9 3c42 5844

        .endif
