/*
 * fim/m68k/single_step.s - FIM_$SINGLE_STEP, resume a process for one
 * traced instruction (m68k/SAU2, SAU5)
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Transcribed from the SAU2 image, 0x00E217D4..0x00E21823 (map
 * FIM_$SINGLE_STEP to FIM_$INITIAL_STACK_SIZE, 80 bytes), in its own
 * section.
 *
 *   void FIM_$SINGLE_STEP(uint32_t *pc, uint16_t *sr, uint32_t *regs)
 *                                          0x4(SP), 0x8(SP), 0xC(SP)
 *
 * Inhibits quits for the current address space, presets its trace status
 * to "single step completed", builds a format-0 frame on the OS stack with
 * PC = *pc and SR = (*sr & 0xC01F) | T1, reloads USP from regs[15] and
 * D0..A6 from regs[0..14], and leaves through FIM_$EXIT's rte.
 *
 * Byte gate (tools/asm_compare.py): identical to the image modulo
 * relocations; `and.w #imm,D0' is the Apollo assembler's <ea>=#imm form
 * (c07c), gas writes ANDI (recognised by the gate).
 */

        .section ".text.FIM_$SINGLE_STEP","ax",@progbits
        .even

        .extern PROC1_$AS_ID            /* a word, proc1/proc1.ins.pas, map 0xE2060A */
        .extern FIM_$SETUP_RETURN       /* fim/m68k/fault_return.s, image 0xE21878 */
        .extern FIM_$EXIT               /* fim/m68k/exit.s, map 0xE228BC */

        /* fim/m68k/wired_data.s */
        .extern FIM_$TRACE_STS          /* map 0xE223A2, status_$t[58] */
        .extern FIM_$QUIT_INH           /* map 0xE2248A, a byte per AS */

        .global FIM_$SINGLE_STEP
FIM_$SINGLE_STEP:
        move.w  (PROC1_$AS_ID).l,%d0            /* e217d4 */
        lea     (FIM_$QUIT_INH).l,%a0           /* e217da  41f9 00e2 248a */
        st      (0,%a0,%d0.w)                   /* e217e0  quit_inh[asid] = 0xFF */
        lsl.w   #2,%d0                          /* e217e4 */
        lea     (FIM_$TRACE_STS).l,%a0          /* e217e6  41f9 00e2 23a2 */
        move.l  #0x00120015,(0,%a0,%d0.w)       /* e217ec  "single step completed" */
        bsr.w   FIM_$SETUP_RETURN               /* e217f4  6100 0082 */
        movea.l (0x4,%sp),%a1                   /* e217f8 */
        move.l  (%a1),-(%a0)                    /* e217fc  frame PC = *pc */
        movea.l (0x8,%sp),%a1                   /* e217fe */
        move.w  (%a1),%d0                       /* e21802 */
        and.w   #0xc01f,%d0                     /* e21804  c07c c01f: T1 T0 S . . XNZVC */
        bset.l  #15,%d0                         /* e21808  T1: trace */
        move.w  %d0,-(%a0)                      /* e2180c  frame SR */
        movea.l (0xc,%sp),%a1                   /* e2180e  A1 = regs */
        movea.l (0x3c,%a1),%a2                  /* e21812 */
        move.l  %a2,%usp                        /* e21816  USP = regs[15] */
        movea.l %a0,%sp                         /* e21818 */
        movem.l (%a1),%d0-%d7/%a0-%a6           /* e2181a */
        jmp     (FIM_$EXIT).l                   /* e2181e */
