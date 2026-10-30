/*
 * smd/sau2/interrupt_init.s - SMD_$INTERRUPT_INIT (hand-written assembly)
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image; address operands resolve to our objects.
 *
 * Original address (SAU2 map, segment "D E26F20 SMD_WIRED size = 5E0"):
 * SMD_$INTERRUPT_INIT 0x00E27284, 0x24 bytes (..0x00E272A7);
 * SMD_$START_SCROLL's trampoline (smd/sau2/scroll.s) follows at 0xE272A8.
 *
 * Code in a data segment, reaching SMD_$DISP1_INT with a 16-bit
 * PC-relative `lea' (smd/README.md).  SMD_$INIT calls it with
 * nothing pushed, `jsr 0x00e27284.l' (0xE34E82); it reads no argument
 * and leaves no result (smd/smd_internal.ins.pas).
 *
 * What it does: installs SMD_$DISP1_INT as the display interrupt's
 * handler: in PEB_$DISP_INT_ADDR (peb/m68k/int.s, map 0xE24478), which
 * the PEB's level-4 handler dispatches through, when PEB_$INFO's
 * `installed' byte (+0x1A, 0xE24C92) is nonzero, else straight into the
 * level-4 autovector at 0x70.  The test is `tst.b; beq', zero against
 * nonzero, not the usual Domain-boolean `bmi'.
 *
 *   00e27284  41fa fc9a       lea (-0x366,PC),A0      A0 = SMD_$DISP1_INT
 *   00e27288  43f9 00e2 4c78  lea (0xe24c78).l,A1     PEB_$INFO
 *   00e2728e  4a29 001a       tst.b (0x1a,A1)         .installed
 *   00e27292  6700 000c       beq.w 0x00e272a0
 *   00e27296  23c8 00e2 4478  move.l A0,(0x00e24478).l
 *   00e2729c  6000 0008       bra.w 0x00e272a6
 *   00e272a0  23c8 0000 0070  move.l A0,(0x00000070).l
 *   00e272a6  4e75            rts
 *
 * 0x70 is TRAP_PAGE's DISP1_VEC (map, with PEB_VEC at the same address:
 * "70 DISP1_VEC", "70 PEB_VEC"), the display's interrupt vector; the
 * operand is written as that symbol (an absolute of the TRAP_PAGE, which
 * this file does not define).
 */

        .section ".text.SMD_$INTERRUPT_INIT","ax",@progbits
        .globl  SMD_$INTERRUPT_INIT

SMD_$INTERRUPT_INIT:
        lea     (SMD_$DISP1_INT:w,%pc),%a0      /* 00e27284  41fa fc9a       */
        lea     (PEB_$INFO).l,%a1               /* 00e27288  43f9 00e2 4c78  */
        tst.b   (0x1a,%a1)                      /* 00e2728e  4a29 001a       */
        beq.w   .Lautovector                    /* 00e27292  6700 000c       */
        move.l  %a0,(PEB_$DISP_INT_ADDR).l      /* 00e27296  23c8 00e2 4478  */
        bra.w   .Ldone                          /* 00e2729c  6000 0008       */
.Lautovector:
        move.l  %a0,(DISP1_VEC).l               /* 00e272a0  23c8 0000 0070  */
.Ldone:
        rts                                     /* 00e272a6  4e75            */
